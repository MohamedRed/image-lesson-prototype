import { onDocumentWritten, onDocumentCreated } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { withMetrics } from "../shared/metrics";
import { withTrace } from "../shared/trace";
import Stripe from "stripe";
import { getSecret, secretPath, SECRET_IDS } from "../shared/secretManager";
import { StripePaymentService, StripeRefundService } from "../services/payments/stripeService";
import { RadarTripService, RadarUserService } from "../services/location/radarService";
import { sendToUser } from "../services/notifications/fcmService";
import { withIdempotency } from "../shared/idempotency";
import { withAudit } from "../shared/audit";
import { renderTemplate } from "../services/notifications/templates";
import { logEvent } from "../shared/analytics";
import { etaRestaurantToCustomer } from "../shared/eta/mapboxMatrix";

// Stripe client now handled by service layer

/**
 * Order State Machine Handler
 * Manages transitions between order states and triggers appropriate actions
 */
export const orderStateManager = withTrace(withMetrics("orderStateManager", onDocumentWritten("orders/{orderId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  
  if (!after || !event.params.orderId) return;

  const orderId = event.params.orderId;
  const beforeStatus = before?.status;
  const afterStatus = after.status;

  // Skip if status hasn't changed
  if (beforeStatus === afterStatus) return;

  logger.info("Order status transition", {
    orderId,
    from: beforeStatus,
    to: afterStatus,
    customerId: after.customerId,
    restaurantId: after.restaurantId
  });

  try {
    switch (afterStatus) {
      case "restaurant_accepted":
        await handleRestaurantAccepted(orderId, after);
        break;
      
      case "preparing":
        await handleOrderPreparing(orderId, after);
        break;
      
      case "ready_for_pickup":
        await handleOrderReady(orderId, after);
        break;
      
      case "picked_up":
        await handleOrderPickedUp(orderId, after);
        break;
      
      case "on_route":
        await handleOrderOnRoute(orderId, after);
        break;
      
      case "delivered":
        await handleOrderDelivered(orderId, after);
        break;
      
      case "cancelled_by_customer":
      case "cancelled_by_merchant":
      case "cancelled_no_courier":
        await handleOrderCancelled(orderId, after, afterStatus);
        break;
    }
  } catch (error: any) {
    logger.error("Order state transition failed", {
      orderId,
      status: afterStatus,
      error: error.message
    });
  }
})));

/**
 * Order Creation Handler
 * Validates and processes new orders, initiates payment and dispatch
 */
export const orderCreationHandler = withMetrics("orderCreationHandler", onDocumentCreated("orders/{orderId}", async (event) => {
  const order = event.data?.data();
  if (!order || order.status !== "created") return;

  const orderId = event.params.orderId!;

  try {
    // Validate order data
    const validationResult = await validateOrder(order);
    if (!validationResult.isValid) {
      await event.data!.ref.update({
        status: "validation_failed",
        cancellation: {
          by: "system",
          reasonCode: "validation_failed",
          notes: validationResult.errors.join(", ")
        },
        "timings.cancelledAt": admin.firestore.FieldValue.serverTimestamp()
      });
      return;
    }

    // Calculate pricing
    const pricingResult = await calculateOrderPricing(order);
    
    // Process payment if card payment
    if (order.payment.method === "card") {
      // Only create intent if not already present
      const hasIntent = !!order.payment?.intentId;
      const paymentResult = hasIntent ? { success: true } : await processCardPayment(order, pricingResult);
      if (!paymentResult.success) {
        await event.data!.ref.update({
          status: "payment_failed",
          "payment.status": "failed",
          "payment.errorMessage": paymentResult.error,
          cancellation: {
            by: "system",
            reasonCode: "payment_failed",
            notes: paymentResult.error
          },
          "timings.cancelledAt": admin.firestore.FieldValue.serverTimestamp()
        });
        return;
      }
    }

    // Update order with pricing and move to pending_restaurant
    await event.data!.ref.update({
      status: "pending_restaurant",
      subtotal: pricingResult.subtotal,
      deliveryFee: pricingResult.deliveryFee,
      serviceFee: pricingResult.serviceFee,
      total: pricingResult.total,
      "timings.etaSeconds": pricingResult.etaSeconds,
      "payment.status": order.payment.method === "card" ? "authorized" : "pending"
    });

    // Send notification to restaurant
    await sendRestaurantNotification(orderId, order.restaurantId, "new_order");

    logger.info("Order created successfully", {
      orderId,
      customerId: order.customerId,
      restaurantId: order.restaurantId,
      total: pricingResult.total,
      paymentMethod: order.payment.method
    });

  } catch (error: any) {
    logger.error("Order creation failed", {
      orderId,
      error: error.message,
      stack: error.stack
    });

    await event.data!.ref.update({
      status: "system_error",
      cancellation: {
        by: "system",
        reasonCode: "processing_error",
        notes: error.message
      },
      "timings.cancelledAt": admin.firestore.FieldValue.serverTimestamp()
    });
  }
}));

/**
 * Order Cancellation Handler
 * Processes order cancellations and handles refunds
 */
export const cancelOrder = onCall(async (request) => {
  try {
    const { orderId, reason, cancelledBy, notes } = request.data || {};
    
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    if (!orderId || !reason || !cancelledBy) {
      throw new HttpsError("invalid-argument", "Missing required fields");
    }

    const orderRef = admin.firestore().doc(`orders/${orderId}`);
    const orderDoc = await orderRef.get();
    if (!orderDoc.exists) {
      throw new HttpsError("not-found", "Order not found");
    }

    const order = orderDoc.data()!;
    
    // Check if order can be cancelled
    const cancellableStatuses = ["created", "pending_restaurant", "restaurant_accepted", "preparing"];
    if (!cancellableStatuses.includes(order.status)) {
      throw new HttpsError("failed-precondition", "Order cannot be cancelled at this stage");
    }

    // Process refund if payment was already captured
    if (order.payment?.method === "card" && order.payment?.status === "captured") {
      await processRefund(orderId, order, "full");
    }

    const cancellationStatus = `cancelled_by_${cancelledBy}`;
    await withIdempotency(`${orderId}_${cancellationStatus}`, "cancelOrder", async () => {
    await orderRef.update({
      status: cancellationStatus,
      cancellation: {
        by: cancelledBy,
        reasonCode: reason,
          notes: notes || null
      },
      "timings.cancelledAt": admin.firestore.FieldValue.serverTimestamp()
      });
    });

    // Send notifications
    await sendCancellationNotifications(orderId, order, cancelledBy, reason);
    try { await logEvent(request.auth.uid, cancellationStatus, { orderId, reason }); } catch {}

    return { success: true, orderId, status: cancellationStatus };

  } catch (error: any) {
    logger.error("Order cancellation failed", {
      error: error.message,
      data: request.data
    });
    throw new HttpsError("internal", "Order cancellation failed");
  }
});

/**
 * Order Pricing Calculator
 * Calculates dynamic pricing including delivery fees, surge, and promotions
 */
export const calculatePricing = onCall(async (request) => {
  try {
    const { restaurantId, items, deliveryAddress, promoCode } = request.data || {};
    if (!restaurantId || !items || !deliveryAddress) {
      throw new HttpsError("invalid-argument", "Missing required fields");
    }

    // Get restaurant details
    const restaurantDoc = await admin.firestore().doc(`restaurants/${restaurantId}`).get();
    if (!restaurantDoc.exists) {
      throw new HttpsError("not-found", "Restaurant not found");
    }

    const restaurant = restaurantDoc.data()!;
    
    // Calculate pricing
    const pricingResult = await calculateOrderPricing({
      restaurantId,
      items,
      addresses: { dropoff: deliveryAddress },
      restaurant
    });

    // Apply promotion if provided
    if (promoCode) {
      const promotionResult = await applyPromotion(promoCode, pricingResult, restaurantId);
      if (promotionResult.success) {
        pricingResult.discount = promotionResult.discount;
        pricingResult.total = pricingResult.total - promotionResult.discount;
        pricingResult.appliedPromotion = promotionResult.promotion;
      }
    }

    return { success: true, pricing: pricingResult };
  } catch (error: any) {
    logger.error("Pricing calculation failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Pricing calculation failed");
  }
});

/**
 * Update Delivery Status (callable)
 * Updates deliveryTracking document with status/location/proof
 */
export const updateDeliveryStatus = onCall(async (request) => {
  try {
    const { orderId, status, location, proof } = request.data || {};
    if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Authentication required");
    if (!orderId || !status) throw new HttpsError("invalid-argument", "orderId and status are required");

    const updateData: any = {
      status,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      progressValue: statusProgressValue(status)
    };
    if (location?.latitude && location?.longitude) {
      updateData.currentLocation = {
        latitude: location.latitude,
        longitude: location.longitude
      };
    }
    if (proof) {
      updateData.deliveryProof = {
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        location: location ? { latitude: location.latitude, longitude: location.longitude } : null,
        verificationMethod: proof.verificationMethod || "photo",
        photoUrl: proof.photoUrl || null,
        signatureData: proof.signatureData || null,
        notes: proof.notes || null
      };
    }

    await admin.firestore().doc(`deliveryTracking/${orderId}`).set(updateData, { merge: true });

    // Add basic customer update
    const update = {
      id: admin.firestore().collection("_ids").doc().id,
      orderId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      type: "statusUpdate",
      message: `Status updated: ${status}`,
      estimatedTime: null
    };
    await admin.firestore().doc(`deliveryTracking/${orderId}`).collection("customerUpdates").doc(update.id).set(update);

    return { success: true };
  } catch (error: any) {
    logger.error("updateDeliveryStatus failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Update delivery status failed");
  }
});

/**
 * Add Customer Update (callable)
 */
export const addCustomerUpdate = onCall(async (request) => {
  try {
    const { orderId, update } = request.data || {};
    if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Authentication required");
    if (!orderId || !update?.message || !update?.type) {
      throw new HttpsError("invalid-argument", "orderId and update fields are required");
    }
    const id = update.id || admin.firestore().collection("_ids").doc().id;
    const payload = {
      id,
      orderId,
      message: update.message,
      type: update.type,
      estimatedTime: update.estimatedTime ? admin.firestore.Timestamp.fromDate(new Date(update.estimatedTime)) : null,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    };
    await admin.firestore().doc(`deliveryTracking/${orderId}`).collection("customerUpdates").doc(id).set(payload);
    await admin.firestore().doc(`deliveryTracking/${orderId}`).set({ lastUpdated: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    return { success: true };
  } catch (error: any) {
    logger.error("addCustomerUpdate failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Add customer update failed");
  }
});

/**
 * Create Geofence Event (callable)
 */
export const createGeofenceEvent = onCall(async (request) => {
  try {
    const { orderId, event } = request.data || {};
    if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Authentication required");
    if (!orderId || !event?.courierId || !event?.eventType || !event?.location) {
      throw new HttpsError("invalid-argument", "Missing required fields");
    }
    const eventData = {
      orderId,
      courierId: event.courierId,
      type: event.eventType,
      location: { latitude: event.location.latitude, longitude: event.location.longitude },
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    };
    await admin.firestore().collection("geofenceEvents").add(eventData);
    return { success: true };
  } catch (error: any) {
    logger.error("createGeofenceEvent failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Create geofence event failed");
  }
});

function statusProgressValue(status: string): number {
  switch (status) {
    case "order_placed": return 0.1;
    case "restaurant_confirmed": return 0.2;
    case "preparing": return 0.4;
    case "ready_for_pickup": return 0.5;
    case "courier_assigned": return 0.6;
    case "courier_en_route":
    case "en_route_to_customer": return 0.7;
    case "picked_up": return 0.8;
    case "out_for_delivery":
    case "arrived_at_customer": return 0.9;
    case "delivered":
    case "order_delivered": return 1.0;
    case "cancelled":
    case "order_cancelled": return 0.0;
    default: return 0.0;
  }
}

// Create Order (callable) - creates order with basic fields; state machine/on-create handler finishes processing
export const createOrder = onCall(async (request) => {
  try {
    const { order, paymentMethod, idempotencyKey } = request.data || {};
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    if (!order || !paymentMethod) {
      throw new HttpsError("invalid-argument", "Missing order or payment method");
    }
    const result = await withIdempotency(idempotencyKey || `create_${request.auth.uid}_${Date.now()}`, "createOrder", async () => {
      const orderRef = admin.firestore().collection("orders").doc();
      const newOrder = {
        ...order,
        id: orderRef.id,
        customerId: request.auth!.uid,
        status: "created",
        payment: {
          ...(order.payment || {}),
          method: paymentMethod,
          status: paymentMethod === "card" ? "pending" : "pending"
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      };
      await orderRef.set(newOrder, { merge: true });
      try { await logEvent(request.auth!.uid, "order_created", { orderId: orderRef.id, paymentMethod }); } catch {}
      return { id: orderRef.id };
    });

    return { success: true, order: result };
  } catch (error: any) {
    logger.error("Create order callable failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Create order failed");
  }
});

// Remove Saved Address (callable) - used by client service
export const removeSavedAddress = onCall(async (request) => {
  try {
    const { userId, addressId } = request.data || {};
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    if (!addressId) {
      throw new HttpsError("invalid-argument", "addressId is required");
    }
    if (userId && userId !== uid) {
      throw new HttpsError("permission-denied", "Cannot modify another user's addresses");
    }

    const docRef = admin.firestore().doc(`customers/${uid}`);
    const doc = await docRef.get();
    if (!doc.exists) {
      throw new HttpsError("not-found", "Customer profile not found");
    }

    const data = doc.data() as any;
    const addresses: any[] = data?.defaultAddresses || [];
    const updated = addresses.filter((a) => a?.id !== addressId);
    await docRef.update({ defaultAddresses: updated });
    return { success: true };
  } catch (error: any) {
    logger.error("removeSavedAddress failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Failed to remove address");
  }
});

// MARK: - Helper Functions

async function handleRestaurantAccepted(orderId: string, order: any) {
  // Start preparation timer
  const prepTime = order.estimatedPrepTime || 30;
  
  const tpl = renderTemplate("order_preparing", { orderId, prepTime });
  await sendToUser("customer", order.customerId, { title: tpl.title, body: tpl.body, data: { orderId } });

  // Trigger courier dispatch if not already assigned
  if (!order.courierId) {
    await triggerCourierDispatch(orderId, order);
  }
}

async function handleOrderPreparing(orderId: string, order: any) {
  // Update ETA based on prep time
  const prepTime = order.estimatedPrepTime || 30;
  let etaSeconds = prepTime * 60; // baseline
  try {
    const accessToken = await getSecret(secretPath(SECRET_IDS.MAPBOX_ACCESS_TOKEN));
    const eta = await etaRestaurantToCustomer({
      accessToken,
      restaurant: { lat: order.restaurantLocation?.latitude ?? order.restaurant?.coordinates?.latitude, lng: order.restaurantLocation?.longitude ?? order.restaurant?.coordinates?.longitude },
      customer: { lat: order.addresses?.dropoff?.latitude, lng: order.addresses?.dropoff?.longitude },
    });
    etaSeconds = Math.max(eta.durationSeconds + prepTime * 60, etaSeconds);
  } catch {}

  await admin.firestore().doc(`orders/${orderId}`).update({
    "timings.etaSeconds": etaSeconds
  });

  const tpl = renderTemplate("order_preparing", { orderId });
  await sendToUser("customer", order.customerId, { title: tpl.title, body: tpl.body, data: { orderId } });
}

async function handleOrderReady(orderId: string, order: any) {
  // Notify assigned courier
  if (order.courierId) {
    const tC = renderTemplate("order_ready", { orderId });
    await sendToUser("courier", order.courierId, { title: tC.title, body: tC.body, data: { orderId } });
  }

  // Notify customer
  const t = renderTemplate("order_ready", { orderId });
  await sendToUser("customer", order.customerId, { title: t.title, body: t.body, data: { orderId } });
}

async function handleOrderPickedUp(orderId: string, order: any) {
  // Capture payment if card payment
  if (order.payment.method === "card" && order.payment.status === "authorized") {
    await capturePayment(order.payment.intentId, order.total);
    
    await admin.firestore().doc(`orders/${orderId}`).update({
      "payment.status": "captured",
      "payment.capturedAt": admin.firestore.FieldValue.serverTimestamp()
    });
  }

  // Update status to on_route
  await admin.firestore().doc(`orders/${orderId}`).update({
    status: "on_route"
  });

  const t = renderTemplate("order_picked_up", { orderId });
  await sendToUser("customer", order.customerId, { title: t.title, body: t.body, data: { orderId } });
}

async function handleOrderOnRoute(orderId: string, order: any) {
  // Start real-time tracking
  await startLocationTracking(order.courierId, orderId);

  // Notify customer with ETA if available
  const etaSec = order?.timings?.dispatchEtaSeconds || order?.timings?.etaSeconds;
  const tpl = renderTemplate("order_on_route", { orderId, etaMinutes: etaSec ? Math.ceil(etaSec / 60) : undefined });
  await sendToUser("customer", order.customerId, { title: tpl.title, body: tpl.body, data: { orderId } });
}

async function handleOrderDelivered(orderId: string, order: any) {
  // Stop location tracking
  await stopLocationTracking(order.courierId);

  // Update courier availability
  await admin.firestore().doc(`couriers/${order.courierId}`).update({
    currentOrderId: null,
    isAvailable: true
  });

  // Send completion notifications
  await Promise.all([
    (async () => { const tpl = renderTemplate("order_delivered", { orderId }); await sendToUser("customer", order.customerId, { title: tpl.title, body: tpl.body, data: { orderId } }); })(),
    (async () => { const tpl = renderTemplate("order_delivered", { orderId }); await sendToUser("courier", order.courierId, { title: tpl.title, body: tpl.body, data: { orderId } }); })(),
    (async () => { const tpl = renderTemplate("order_delivered", { orderId }); await sendToUser("restaurant", order.restaurantId, { title: tpl.title, body: tpl.body, data: { orderId } }); })()
  ]);

  // Process COD payment if applicable
  if (order.payment.method === "cod") {
    await admin.firestore().doc(`orders/${orderId}`).update({
      "payment.status": "completed",
      "payment.completedAt": admin.firestore.FieldValue.serverTimestamp()
    });
  }

  logger.info("Order delivered successfully", {
    orderId,
    customerId: order.customerId,
    courierId: order.courierId,
    total: order.total
  });
}

async function handleOrderCancelled(orderId: string, order: any, status: string) {
  // Process refund if needed
  if (order.payment.method === "card" && order.payment.status === "captured") {
    await processRefund(orderId, order, "full");
  }

  // Release courier if assigned
  if (order.courierId) {
    await admin.firestore().doc(`couriers/${order.courierId}`).update({
      currentOrderId: null,
      isAvailable: true
    });
  }

  const tpl = renderTemplate("order_cancelled", { orderId });
  await Promise.all([
    sendToUser("customer", order.customerId, { title: tpl.title, body: tpl.body, data: { orderId } }),
    order.courierId ? sendToUser("courier", order.courierId, { title: tpl.title, body: tpl.body, data: { orderId } }) : Promise.resolve({}),
    sendToUser("restaurant", order.restaurantId, { title: tpl.title, body: tpl.body, data: { orderId } })
  ]);
}

async function validateOrder(order: any): Promise<{ isValid: boolean; errors: string[] }> {
  const errors: string[] = [];

  // Validate required fields
  if (!order.customerId) errors.push("Customer ID is required");
  if (!order.restaurantId) errors.push("Restaurant ID is required");
  if (!order.items || order.items.length === 0) errors.push("Order items are required");
  if (!order.addresses?.dropoff) errors.push("Delivery address is required");
  if (!order.payment?.method) errors.push("Payment method is required");

  // Validate restaurant is open and accepts deliveries
  const restaurantDoc = await admin.firestore().doc(`restaurants/${order.restaurantId}`).get();
  if (!restaurantDoc.exists) {
    errors.push("Restaurant not found");
  } else {
    const restaurant = restaurantDoc.data()!;
    if (!restaurant.isOpen) {
      errors.push("Restaurant is currently closed");
    }
  }

  // Validate delivery address is in service area
  // TODO: Implement delivery zone validation

  return { isValid: errors.length === 0, errors };
}

async function calculateOrderPricing(order: any): Promise<any> {
  // Calculate subtotal
  let subtotal = 0;
  for (const item of order.items) {
    subtotal += item.totalPrice;
  }

  // Get restaurant delivery policy
  const restaurant = order.restaurant || (await admin.firestore().doc(`restaurants/${order.restaurantId}`).get()).data()!;
  const policy = restaurant.deliveryFeePolicy;

  // Calculate distance (mock for now)
  const distanceKm = 5.0; // TODO: Calculate actual distance using Mapbox

  // Calculate delivery fee
  let deliveryFee = policy.baseMAD + (policy.perKmMAD * distanceKm);

  // Apply surge pricing if active
  if (restaurant.surgeProfile?.isActive) {
    deliveryFee *= restaurant.surgeProfile.multiplier;
  }

  // Calculate service fee (3% of subtotal, max 15 MAD)
  const serviceFee = Math.min(subtotal * 0.03, 15.0);

  // Small order fee
  let smallOrderFee = 0;
  if (policy.minimumOrderMAD && subtotal < policy.minimumOrderMAD) {
    smallOrderFee = policy.smallOrderFeeMAD || 0;
  }

  const total = subtotal + deliveryFee + serviceFee + smallOrderFee;

  // Estimate delivery time
  const prepTime = restaurant.avgPrepMinutes || 30;
  const travelTime = Math.ceil(distanceKm * 3); // 3 minutes per km
  const etaSeconds = (prepTime + travelTime + 5) * 60; // +5 minutes buffer

  return {
    subtotal: Math.round(subtotal * 100) / 100,
    deliveryFee: Math.round(deliveryFee * 100) / 100,
    serviceFee: Math.round(serviceFee * 100) / 100,
    smallOrderFee: Math.round(smallOrderFee * 100) / 100,
    total: Math.round(total * 100) / 100,
    currency: "MAD",
    distanceKm,
    etaSeconds
  };
}

async function processCardPayment(order: any, pricing: any): Promise<{ success: boolean; error?: string }> {
  try {
    const paymentIntent = await StripePaymentService.createPaymentIntent({
      amount: Math.round(pricing.total * 100), // Convert to cents
      currency: "mad",
      metadata: {
        orderId: order.id,
        customerId: order.customerId,
        restaurantId: order.restaurantId
      },
      captureMethod: "manual" // Authorize now, capture on pickup
    });

    return { success: true };
  } catch (error: any) {
    logger.error("Payment processing failed", { error: error.message });
    return { success: false, error: error.message };
  }
}

async function capturePayment(paymentIntentId: string, amount: number): Promise<void> {
  try {
    await StripePaymentService.capturePaymentIntent(paymentIntentId, Math.round(amount * 100));
  } catch (error: any) {
    logger.error("Payment capture failed", { paymentIntentId, error: error.message });
    throw error;
  }
}

async function processRefund(orderId: string, order: any, type: "full" | "partial", amount?: number): Promise<void> {
  try {
    const refundAmount = type === "full" ? Math.round(order.total * 100) : Math.round((amount || 0) * 100);
    
    await StripeRefundService.createRefund({
      paymentIntentId: order.payment.intentId,
      amount: refundAmount
    });

    await admin.firestore().doc(`orders/${orderId}`).update({
      "payment.refundStatus": type,
      "payment.refundAmount": refundAmount / 100,
      "payment.refundedAt": admin.firestore.FieldValue.serverTimestamp()
    });
    try { await logEvent(order.customerId || null, "refund_issued", { orderId, amount: refundAmount / 100, type }); } catch {}

  } catch (error: any) {
    logger.error("Refund processing failed", { orderId, error: error.message });
    throw error;
  }
}

async function applyPromotion(code: string, pricing: any, restaurantId: string): Promise<any> {
  const promoDoc = await admin.firestore()
    .collection("promotions")
    .where("code", "==", code)
    .where("isActive", "==", true)
    .limit(1)
    .get();

  if (promoDoc.empty) {
    return { success: false, error: "Invalid promotion code" };
  }

  const promotion = promoDoc.docs[0].data();
  
  // Validate promotion
  const now = new Date();
  if (now < promotion.validFrom.toDate() || now > promotion.validUntil.toDate()) {
    return { success: false, error: "Promotion has expired" };
  }

  // Check usage limit
  if (promotion.maxUsageCount && promotion.currentUsageCount >= promotion.maxUsageCount) {
    return { success: false, error: "Promotion usage limit reached" };
  }

  // Check restaurant applicability
  if (promotion.applicableRestaurants.length > 0 && !promotion.applicableRestaurants.includes(restaurantId)) {
    return { success: false, error: "Promotion not applicable to this restaurant" };
  }

  // Check minimum order amount
  if (promotion.minimumOrderAmount && pricing.subtotal < promotion.minimumOrderAmount) {
    return { success: false, error: `Minimum order amount is ${promotion.minimumOrderAmount} MAD` };
  }

  // Calculate discount
  let discount = 0;
  if (promotion.discountType === "fixed") {
    discount = promotion.discountAmount;
  } else if (promotion.discountType === "percentage") {
    discount = pricing.subtotal * (promotion.discountAmount / 100);
    if (promotion.maxDiscountAmount) {
      discount = Math.min(discount, promotion.maxDiscountAmount);
    }
  }

  // Update usage count
  await promoDoc.docs[0].ref.update({
    currentUsageCount: admin.firestore.FieldValue.increment(1)
  });

  return { success: true, discount, promotion };
}

// Notification helpers (wired to FCM)
async function sendCustomerNotification(orderId: string, customerId: string, type: string, data?: any): Promise<void> {
  const tplKey = ((): any => {
    switch (type) {
      case "new_order": return "new_order";
      case "order_preparing": return "order_preparing";
      case "order_ready": return "order_ready";
      case "courier_assigned": return "courier_assigned";
      case "order_picked_up": return "order_picked_up";
      case "order_on_route": return "order_on_route";
      case "order_delivered": return "order_delivered";
      case "order_cancelled": return "order_cancelled";
      default: return "order_preparing";
    }
  })();
  const tpl = renderTemplate(tplKey, { orderId, ...(data || {}) });
  await sendToUser("customer", customerId, { title: tpl.title, body: tpl.body, data: { orderId, ...(data || {}) } });
}

async function sendCourierNotification(orderId: string, courierId: string, type: string, data?: any): Promise<void> {
  const tplKey = type === "courier_assigned" ? "courier_assigned" : type === "order_cancelled" ? "order_cancelled" : "order_ready";
  const tpl = renderTemplate(tplKey, { orderId, ...(data || {}) });
  await sendToUser("courier", courierId, { title: tpl.title, body: tpl.body, data: { orderId, ...(data || {}) } });
}

async function sendRestaurantNotification(orderId: string, restaurantId: string, type: string, data?: any): Promise<void> {
  const tplKey = ((): any => {
    switch (type) {
      case "new_order": return "new_order";
      case "order_preparing": return "order_preparing";
      case "order_ready": return "order_ready";
      case "courier_assigned": return "courier_assigned";
      case "order_delivered": return "order_delivered";
      case "order_cancelled": return "order_cancelled";
      default: return "new_order";
    }
  })();
  const tpl = renderTemplate(tplKey, { orderId, ...(data || {}) });
  await sendToUser("restaurant", restaurantId, { title: tpl.title, body: tpl.body, data: { orderId, ...(data || {}) } });
}

async function sendCancellationNotifications(orderId: string, order: any, cancelledBy: string, reason: string): Promise<void> {
  const tpl = renderTemplate("order_cancelled", { orderId, reason, cancelledBy });
  await Promise.all([
    sendToUser("customer", order.customerId, { title: tpl.title, body: tpl.body, data: { orderId, reason, cancelledBy } }),
    order.courierId ? sendToUser("courier", order.courierId, { title: tpl.title, body: tpl.body, data: { orderId, reason, cancelledBy } }) : Promise.resolve({}),
    sendToUser("restaurant", order.restaurantId, { title: tpl.title, body: tpl.body, data: { orderId, reason, cancelledBy } })
  ]);
}

async function getRestaurantName(restaurantId: string): Promise<string> {
  const doc = await admin.firestore().doc(`restaurants/${restaurantId}`).get();
  return doc.exists ? doc.data()!.name : "Restaurant";
}

async function triggerCourierDispatch(orderId: string, order: any): Promise<void> {
  // TODO: Trigger courier dispatch algorithm
  logger.info("Triggering courier dispatch", { orderId });
}

async function startLocationTracking(courierId: string, orderId: string): Promise<void> {
  try {
    // Start Radar trip tracking for food delivery
    await RadarTripService.startTrip(`courier_${courierId}`, {
      externalId: orderId,
      metadata: {
        type: 'food_delivery',
        orderId,
        courierId,
        phase: 'delivery'
      },
      mode: 'car' // Default to car, can be updated based on courier vehicle type
    });

    // Update courier metadata with current order
    await RadarUserService.updateUser(`courier_${courierId}`, {
      description: `Food delivery courier - Order ${orderId}`,
      metadata: {
        isDelivering: true,
        currentOrderId: orderId,
        service: 'food_delivery',
        lastUpdate: new Date().toISOString()
      }
    });

    logger.info("Radar tracking started for food delivery", { courierId, orderId });
  } catch (error: any) {
    logger.error("Failed to start Radar tracking", {
      courierId,
      orderId,
      error: error.message
    });
    // Continue without Radar if it fails
  }
}

async function stopLocationTracking(courierId: string): Promise<void> {
  try {
    // Complete Radar trip tracking
    await RadarTripService.completeTrip(`courier_${courierId}`, `delivery_completed`);

    // Update courier metadata to available state
    await RadarUserService.updateUser(`courier_${courierId}`, {
      description: `Food delivery courier - Available`,
      metadata: {
        isDelivering: false,
        currentOrderId: null,
        isAvailable: true,
        service: 'food_delivery',
        lastUpdate: new Date().toISOString()
      }
    });

    logger.info("Radar tracking stopped for food delivery", { courierId });
  } catch (error: any) {
    logger.error("Failed to stop Radar tracking", {
      courierId,
      error: error.message
    });
    // Continue without Radar if it fails
  }
}