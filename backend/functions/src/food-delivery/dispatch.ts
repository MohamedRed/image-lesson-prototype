import { onDocumentWritten, onDocumentCreated } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { withMetrics } from "../shared/metrics";
import { withTrace } from "../shared/trace";
import { haversineKm } from "../shared/geoHelpers";
import { RadarTripService, RadarUserService, RadarGeofenceService } from "../services/location/radarService";
import { getSecret, secretPath, SECRET_IDS } from "../shared/secretManager";
import { etaCourierToRestaurantToCustomer } from "../shared/eta/mapboxMatrix";
import { withIdempotency } from "../shared/idempotency";
import { sendToUser } from "../services/notifications/fcmService";
import { renderTemplate } from "../services/notifications/templates";
import { withAudit } from "../shared/audit";
import { logEvent } from "../shared/analytics";

/**
 * Courier Dispatch Algorithm
 * Triggered when orders transition to ready_for_pickup or when couriers come online
 */
export const courierDispatcher = withTrace(withMetrics("courierDispatcher", onDocumentWritten("orders/{orderId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  
  if (!after || !event.params.orderId) return;

  const orderId = event.params.orderId;
  const beforeStatus = before?.status;
  const afterStatus = after.status;

  // Trigger dispatch when order moves to ready_for_pickup and no courier assigned
  if (afterStatus === "ready_for_pickup" && !after.courierId) {
    await dispatchCourier(orderId, after);
  }

  // Handle courier assignment acceptance/rejection
  if (beforeStatus !== afterStatus && afterStatus === "courier_assigned") {
    await handleCourierAssigned(orderId, after);
  }
})));

/**
 * Courier Location Tracker
 * Updates courier locations and manages availability
 */
export const courierLocationTracker = withMetrics("courierLocationTracker", onDocumentWritten("couriers/{courierId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  
  if (!after || !event.params.courierId) return;

  const courierId = event.params.courierId;
  
  // Update last seen timestamp
  await event.data!.after.ref.update({
    lastSeen: admin.firestore.FieldValue.serverTimestamp()
  });

  // Check if courier went online/offline
  const wasOnline = before?.isOnline;
  const isOnline = after.isOnline;
  
  if (!wasOnline && isOnline) {
    await handleCourierWentOnline(courierId, after);
  } else if (wasOnline && !isOnline) {
    await handleCourierWentOffline(courierId, after);
  }

  // Update location-based availability if location changed significantly
  const oldLocation = before?.location;
  const newLocation = after.location;
  
  if (newLocation && (!oldLocation || hasLocationChangedSignificantly(oldLocation, newLocation))) {
    await updateCourierZoneAvailability(courierId, newLocation);
  }
}));

/**
 * Courier Assignment API
 * Allows couriers to accept or decline order assignments
 */
export const acceptCourierOrder = onCall(async (request) => {
  try {
    const { orderId } = request.data || {};
    const courierId = request.auth?.uid;
    if (!courierId) throw new HttpsError("unauthenticated", "Authentication required");
    if (!orderId) throw new HttpsError("invalid-argument", "orderId is required");
    const result = await withIdempotency(`${orderId}_${courierId}_accept`, "acceptCourierOrder", async () => {
      const orderRef = admin.firestore().doc(`orders/${orderId}`);
      const orderDoc = await orderRef.get();
      if (!orderDoc.exists) throw new HttpsError("not-found", "Order not found");
      const order = orderDoc.data()!;
      if (order.assignedCourierId !== courierId) throw new HttpsError("permission-denied", "Unauthorized");
      if (order.status !== "courier_assigned") {
        throw new HttpsError("failed-precondition", "Order is no longer available");
      }
      const batch = admin.firestore().batch();
      batch.update(orderRef, {
        status: "picked_up",
        courierId: courierId,
        "timings.acceptedByCourierAt": admin.firestore.FieldValue.serverTimestamp()
      });
      batch.update(admin.firestore().doc(`couriers/${courierId}`), {
        currentOrderId: orderId,
        isAvailable: false
      });
      await batch.commit();
      return { ok: true };
    });
    await withAudit(courierId, "acceptCourierOrder", orderId, async () => Promise.resolve(), "courier");
    // Surface ETA fields for client UI if present on order
    const updated = await admin.firestore().doc(`orders/${orderId}`).get();
    const ord = updated.data() || {};
    const etaSec = ord?.timings?.dispatchEtaSeconds || ord?.timings?.etaSeconds || null;
    return { success: true, orderId, courierId, etaSeconds: etaSec };

  } catch (error: any) {
    logger.error("Courier order acceptance failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Acceptance failed");
  }
});

// Backward-compat alias for iOS client that calls "assignCourier"
export const assignCourier = onCall(async (request) => {
  try {
    const { orderId } = request.data || {};
    const courierId = request.auth?.uid;
    if (!courierId) throw new HttpsError("unauthenticated", "Authentication required");
    if (!orderId) throw new HttpsError("invalid-argument", "orderId is required");
    await withIdempotency(`${orderId}_${courierId}_assign`, "assignCourier", async () => {
      const orderRef = admin.firestore().doc(`orders/${orderId}`);
      const orderDoc = await orderRef.get();
      if (!orderDoc.exists) throw new HttpsError("not-found", "Order not found");
      const order = orderDoc.data()!;
      if (order.assignedCourierId && order.assignedCourierId !== courierId) {
        throw new HttpsError("failed-precondition", "Order already assigned");
      }
      const batch = admin.firestore().batch();
      batch.update(orderRef, {
        status: "courier_assigned",
        assignedCourierId: courierId,
        courierId: courierId,
        "timings.assignedAt": admin.firestore.FieldValue.serverTimestamp()
      });
      batch.update(admin.firestore().doc(`couriers/${courierId}`), {
        pendingOrderId: orderId,
        isAvailable: false
      });
      await batch.commit();
    });
    await withAudit(courierId, "assignCourier", orderId, async () => Promise.resolve(), "courier");
    await logEvent(courierId!, "courier_assigned", { orderId });
    const updated = await admin.firestore().doc(`orders/${orderId}`).get();
    const ord = updated.data() || {};
    const etaSec = ord?.timings?.dispatchEtaSeconds || ord?.timings?.etaSeconds || null;
    return { success: true, orderId, courierId, etaSeconds: etaSec };
  } catch (error: any) {
    logger.error("assignCourier failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "assignCourier failed");
  }
});

export const declineCourierOrder = onCall(async (request) => {
  try {
    const { orderId, reason } = request.data || {};
    const courierId = request.auth?.uid;
    if (!courierId) throw new HttpsError("unauthenticated", "Authentication required");
    if (!orderId) throw new HttpsError("invalid-argument", "orderId is required");
    await withIdempotency(`${orderId}_${courierId}_decline_${reason || 'none'}`, "declineCourierOrder", async () => {
      const orderRef = admin.firestore().doc(`orders/${orderId}`);
      const orderDoc = await orderRef.get();
      if (!orderDoc.exists) throw new HttpsError("not-found", "Order not found");
      const order = orderDoc.data()!;
      if (order.assignedCourierId !== courierId) throw new HttpsError("permission-denied", "Unauthorized");
      await recordCourierDecline(courierId, orderId, reason);
      await orderRef.update({
        assignedCourierId: admin.firestore.FieldValue.delete(),
        courierDeclines: admin.firestore.FieldValue.arrayUnion({
          courierId,
          reason,
          timestamp: admin.firestore.FieldValue.serverTimestamp()
        })
      });
      await dispatchCourier(orderId, order);
    });
    await withAudit(courierId, "declineCourierOrder", orderId, async () => Promise.resolve(), "courier", { reason });
    return { success: true, orderId };

  } catch (error: any) {
    logger.error("Courier order decline failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Decline failed");
  }
});

/**
 * Courier Location Update API
 * Updates courier's real-time location during delivery
 */
export const updateCourierLocation = onCall(async (request) => {
  try {
    const { latitude, longitude } = request.data || {};
    const courierId = request.auth?.uid;
    if (!courierId) throw new HttpsError("unauthenticated", "Authentication required");
    if (latitude === undefined || longitude === undefined) throw new HttpsError("invalid-argument", "Missing required fields");

    await admin.firestore().doc(`couriers/${courierId}`).update({
      "location.latitude": latitude,
      "location.longitude": longitude,
      "location.lastUpdatedAt": admin.firestore.FieldValue.serverTimestamp()
    });

    // Update active order tracking if courier has an order
    const courierDoc = await admin.firestore().doc(`couriers/${courierId}`).get();
    const courier = courierDoc.data();

    if (courier?.currentOrderId) {
      await updateOrderTracking(courier.currentOrderId, {
        latitude,
        longitude
      });
    }

    return { success: true };

  } catch (error: any) {
    logger.error("Courier location update failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Location update failed");
  }
});

/**
 * Delivery Confirmation API
 * Handles pickup and delivery confirmations
 */
export const confirmPickup = onCall(async (request) => {
  try {
    const { orderId } = request.data || {};
    const courierId = request.auth?.uid;
    if (!courierId) throw new HttpsError("unauthenticated", "Authentication required");
    if (!orderId) throw new HttpsError("invalid-argument", "orderId is required");
    await withIdempotency(`${orderId}_${courierId}_pickup`, "confirmPickup", async () => {
      const orderRef = admin.firestore().doc(`orders/${orderId}`);
      const orderDoc = await orderRef.get();
      if (!orderDoc.exists) throw new HttpsError("not-found", "Order not found");
      const order = orderDoc.data()!;
      if (order.courierId !== courierId) throw new HttpsError("permission-denied", "Unauthorized");
      await orderRef.update({
        status: "picked_up",
        "timings.pickedUpAt": admin.firestore.FieldValue.serverTimestamp()
      });
    });
    await withAudit(courierId, "confirmPickup", orderId, async () => Promise.resolve(), "courier");
    await logEvent(courierId!, "order_picked_up", { orderId });
    return { success: true, orderId };

  } catch (error: any) {
    logger.error("Pickup confirmation failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Pickup confirmation failed");
  }
});

export const confirmDelivery = onCall(async (request) => {
  try {
    const { orderId, proofImageUrl } = request.data || {};
    const courierId = request.auth?.uid;
    if (!courierId) throw new HttpsError("unauthenticated", "Authentication required");
    if (!orderId) throw new HttpsError("invalid-argument", "orderId is required");
    await withIdempotency(`${orderId}_${courierId}_delivered`, "confirmDelivery", async () => {
      const orderRef = admin.firestore().doc(`orders/${orderId}`);
      const orderDoc = await orderRef.get();
      if (!orderDoc.exists) throw new HttpsError("not-found", "Order not found");
      const order = orderDoc.data()!;
      if (order.courierId !== courierId) throw new HttpsError("permission-denied", "Unauthorized");
      const updateData: any = {
        status: "delivered",
        "timings.deliveredAt": admin.firestore.FieldValue.serverTimestamp()
      };
      if (proofImageUrl) {
        updateData["tracking.handoffProofUrl"] = proofImageUrl;
      }
      await orderRef.update(updateData);
    });
    await withAudit(courierId, "confirmDelivery", orderId, async () => Promise.resolve(), "courier", { proof: !!proofImageUrl });
    await logEvent(courierId!, "order_delivered", { orderId });
    return { success: true, orderId };

  } catch (error: any) {
    logger.error("Delivery confirmation failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Delivery confirmation failed");
  }
});

/**
 * Zone Performance Monitor
 * Monitors delivery zones and optimizes courier distribution
 */
export const zonePerformanceMonitor = onSchedule("every 5 minutes", async (context) => {
  try {
    const zones = await getDeliveryZones();
    
    for (const zone of zones) {
      const performance = await calculateZonePerformance(zone.zoneId);
      
      // Update zone performance metrics
      await admin.firestore().doc(`zonePerformance/${zone.zoneId}`).set({
        ...performance,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });

      // Trigger rebalancing if needed
      if (performance.demandLevel === "critical") {
        await triggerCourierRebalancing(zone.zoneId);
      }
    }

  } catch (error: any) {
    logger.error("Zone performance monitoring failed", { error: error.message });
  }
});

/**
 * Get Available Orders for Courier
 * Returns orders available for pickup in courier's area
 */
export const getAvailableOrders = onCall(async (request) => {
  try {
    const courierId = request.auth?.uid;
    if (!courierId) throw new HttpsError("unauthenticated", "Authentication required");

    // Get courier location
    const courierDoc = await admin.firestore().doc(`couriers/${courierId}`).get();
    if (!courierDoc.exists) {
      throw new HttpsError("not-found", "Courier not found");
    }

    const courier = courierDoc.data()!;
    
    if (!courier.location) {
      throw new HttpsError("failed-precondition", "Courier location not available");
    }

    // Find available orders within radius
    const availableOrders = await findAvailableOrdersNearLocation(
      courier.location,
      5.0, // 5km radius
      courier.vehicleType
    );

    // Attach ETA hint per order for UI if possible
    const accessToken = await getSecret(secretPath(SECRET_IDS.MAPBOX_ACCESS_TOKEN));
    const withEtas = await Promise.all(availableOrders.map(async (o) => {
      try {
        const eta = await etaCourierToRestaurantToCustomer({
          accessToken,
          courier: { lat: courier.location.latitude, lng: courier.location.longitude },
          restaurant: { lat: o.pickupLocation.latitude, lng: o.pickupLocation.longitude },
          customer: { lat: o.addresses?.dropoff?.latitude ?? 0, lng: o.addresses?.dropoff?.longitude ?? 0 }
        });
        return { ...o, etaSeconds: eta.durationSeconds };
      } catch {
        return { ...o };
      }
    }));

    return { success: true, orders: withEtas };

  } catch (error: any) {
    logger.error("Get available orders failed", { error: error.message });
    throw new HttpsError("internal", "Get available orders failed");
  }
});

/**
 * Courier availability management (optional wrap)
 */
export const goOnline = onCall(async (request) => {
  try {
    const courierId = request.auth?.uid;
    if (!courierId) throw new HttpsError("unauthenticated", "Authentication required");

    const courierRef = admin.firestore().doc(`couriers/${courierId}`);
    const doc = await courierRef.get();
    if (!doc.exists) throw new HttpsError("not-found", "Courier profile not found");
    const courier = doc.data()!;

    // Extended eligibility
    // Support nested KYC object (restaurant-style) and legacy flat field
    const kycStatus = courier.kyc?.status || courier.kycStatus;
    if (kycStatus && kycStatus !== "approved") {
      await withAudit(courierId, "goOnline_denied_kyc", courierId, async () => Promise.resolve(), "courier", { kycStatus: courier.kycStatus });
      throw new HttpsError("failed-precondition", "KYC not approved");
    }
    if (courier.deviceIntegrity === false) {
      await withAudit(courierId, "goOnline_denied_device_integrity", courierId, async () => Promise.resolve(), "courier");
      throw new HttpsError("failed-precondition", "Device integrity failed");
    }
    if (courier.allowlistedZones && courier.allowlistedZones.length > 0 && courier.currentZone && !courier.allowlistedZones.includes(courier.currentZone)) {
      await withAudit(courierId, "goOnline_denied_zone", courierId, async () => Promise.resolve(), "courier", { zone: courier.currentZone });
      throw new HttpsError("failed-precondition", "Not allowed to work in this zone");
    }

    // Minimum app version check (optional client header)
    const minVersion = (await admin.firestore().doc("_internal/appConfig").get()).data()?.minCourierAppVersion;
    const clientVersion = (request.rawRequest?.headers?.["x-app-version"] as string | undefined) || undefined;
    if (minVersion && clientVersion && clientVersion < minVersion) {
      await withAudit(courierId, "goOnline_denied_version", courierId, async () => Promise.resolve(), "courier", { clientVersion, minVersion });
      throw new HttpsError("failed-precondition", "Please update the app to the latest version");
    }

    await courierRef.update({
      isOnline: true,
      isAvailable: true,
      lastOnline: admin.firestore.FieldValue.serverTimestamp()
    });

    await withAudit(courierId, "goOnline", courierId, async () => Promise.resolve(), "courier");
    await logEvent(courierId!, "courier_online");

    // Optionally sync with Radar
    try {
      await RadarUserService.updateUser(`courier_${courierId}`, {
        metadata: { isOnline: true, isAvailable: true, service: 'food_delivery', lastOnline: new Date().toISOString() }
      });
    } catch {}

    return { success: true };
  } catch (error: any) {
    throw new HttpsError("internal", error.message || "goOnline failed");
  }
});

export const goOffline = onCall(async (request) => {
  try {
    const courierId = request.auth?.uid;
    if (!courierId) throw new HttpsError("unauthenticated", "Authentication required");

    const courierRef = admin.firestore().doc(`couriers/${courierId}`);
    const doc = await courierRef.get();
    if (!doc.exists) throw new HttpsError("not-found", "Courier profile not found");
    const courier = doc.data()!;

    // Prevent offline with active order
    if (courier.currentOrderId) {
      throw new HttpsError("failed-precondition", "Cannot go offline with active order");
    }

    await courierRef.update({
      isOnline: false,
      isAvailable: false,
      lastOffline: admin.firestore.FieldValue.serverTimestamp()
    });

    await withAudit(courierId, "goOffline", courierId, async () => Promise.resolve(), "courier");
    await logEvent(courierId!, "courier_offline");

    try {
      await RadarUserService.updateUser(`courier_${courierId}`, {
        metadata: { isOnline: false, isAvailable: false, service: 'food_delivery', lastOffline: new Date().toISOString() }
      });
    } catch {}

    return { success: true };
  } catch (error: any) {
    throw new HttpsError("internal", error.message || "goOffline failed");
  }
});

// MARK: - Core Dispatch Logic

async function dispatchCourier(orderId: string, order: any): Promise<void> {
  try {
    // Get restaurant location
    const restaurantDoc = await admin.firestore().doc(`restaurants/${order.restaurantId}`).get();
    if (!restaurantDoc.exists) {
      logger.error("Restaurant not found for order", { orderId, restaurantId: order.restaurantId });
      return;
    }

    const restaurant = restaurantDoc.data()!;
    const pickupLocation = restaurant.coordinates;

    // Find available couriers
    const availableCouriers = await findAvailableCouriers(pickupLocation, 8.0); // 8km radius

    if (availableCouriers.length === 0) {
      logger.warn("No available couriers found", { orderId, location: pickupLocation });
      
      // Update order status to indicate no courier available
      await admin.firestore().doc(`orders/${orderId}`).update({
        status: "searching_courier",
        searchAttempts: admin.firestore.FieldValue.increment(1)
      });
      return;
    }

    // Score and rank couriers (ETA-based with Mapbox Matrix)
    const accessToken = await getSecret(secretPath(SECRET_IDS.MAPBOX_ACCESS_TOKEN));
    const scoredCouriers = [] as any[];
    for (const c of availableCouriers) {
      try {
        const eta = await etaCourierToRestaurantToCustomer({
          accessToken,
          courier: { lat: c.location.latitude, lng: c.location.longitude },
          restaurant: { lat: pickupLocation.latitude, lng: pickupLocation.longitude },
          customer: { lat: order.addresses.dropoff.latitude, lng: order.addresses.dropoff.longitude },
        });
        const vehicleScore = calculateVehicleSuitability(c.vehicleType, order.total, c.distance);
        const timeScore = Math.max(0, 1 - (eta.durationSeconds / 1800)); // prefer <30m
        const score = 0.7 * timeScore + 0.3 * vehicleScore;
        scoredCouriers.push({ ...c, score, etaSeconds: eta.durationSeconds });
      } catch (e) {
        const fallback = await scoreCouriers([c], order, pickupLocation);
        scoredCouriers.push({ ...fallback[0] });
      }
    }
    const bestCourier = scoredCouriers.sort((a,b)=> (b.score ?? 0) - (a.score ?? 0))[0];

    // Assign order to best courier; store ETA hint
    await assignOrderToCourier(orderId, bestCourier.courierId, bestCourier.score);
    await admin.firestore().doc(`orders/${orderId}`).set({
      "timings.dispatchEtaSeconds": bestCourier.etaSeconds || null
    }, { merge: true });

    // Notify customer about courier assignment with ETA
    const tpl = renderTemplate("courier_assigned", { orderId, etaMinutes: bestCourier.etaSeconds ? Math.ceil(bestCourier.etaSeconds / 60) : undefined });
    await sendToUser("customer", order.customerId, { title: tpl.title, body: tpl.body, data: { orderId } });

    logger.info("Order assigned to courier", {
      orderId,
      courierId: bestCourier.courierId,
      score: bestCourier.score,
      distance: bestCourier.distance
    });

  } catch (error: any) {
    logger.error("Courier dispatch failed", {
      orderId,
      error: error.message
    });
  }
}

async function findAvailableCouriers(location: any, radiusKm: number): Promise<any[]> {
  // Get online couriers
  const couriersSnapshot = await admin.firestore()
    .collection("couriers")
    .where("isOnline", "==", true)
    .where("isAvailable", "==", true)
    .get();

  const availableCouriers = [];

  for (const courierDoc of couriersSnapshot.docs) {
    const courier = courierDoc.data();
    
    if (!courier.location) continue;

    // Calculate distance
    const distance = haversineKm(
      location.latitude,
      location.longitude,
      courier.location.latitude,
      courier.location.longitude
    );

    if (distance <= radiusKm) {
      availableCouriers.push({
        courierId: courierDoc.id,
        ...courier,
        distance
      });
    }
  }

  return availableCouriers;
}

async function scoreCouriers(couriers: any[], order: any, pickupLocation: any): Promise<any[]> {
  const scoredCouriers = couriers.map(courier => {
    let score = 0;

    // Distance score (40% weight) - closer is better
    const maxDistance = 8.0;
    const distanceScore = Math.max(0, (maxDistance - courier.distance) / maxDistance);
    score += distanceScore * 0.4;

    // Rating score (25% weight)
    const ratingScore = courier.rating / 5.0;
    score += ratingScore * 0.25;

    // Experience score (15% weight)
    const experienceScore = Math.min(1.0, courier.completedDeliveries / 100);
    score += experienceScore * 0.15;

    // Vehicle suitability score (10% weight)
    const vehicleScore = calculateVehicleSuitability(courier.vehicleType, order.total, courier.distance);
    score += vehicleScore * 0.1;

    // Acceptance rate score (10% weight)
    const acceptanceScore = courier.acceptanceRate || 0.8;
    score += acceptanceScore * 0.1;

    return {
      ...courier,
      score: Math.round(score * 100) / 100
    };
  });

  return scoredCouriers.sort((a, b) => b.score - a.score);
}

function calculateVehicleSuitability(vehicleType: string, orderValue: number, distance: number): number {
  switch (vehicleType) {
    case "bike":
      if (distance <= 3 && orderValue <= 200) return 1.0;
      if (distance <= 5 && orderValue <= 400) return 0.7;
      return 0.3;
    
    case "motorbike":
      if (distance <= 8 && orderValue <= 600) return 1.0;
      if (distance <= 12) return 0.8;
      return 0.4;
    
    case "car":
      if (orderValue >= 400 || distance >= 8) return 1.0;
      if (distance >= 5) return 0.8;
      return 0.6;
    
    default:
      return 0.5;
  }
}

async function assignOrderToCourier(orderId: string, courierId: string, score: number): Promise<void> {
  const batch = admin.firestore().batch();

  // Update order
  batch.update(admin.firestore().doc(`orders/${orderId}`), {
    status: "courier_assigned",
    assignedCourierId: courierId,
    dispatchScore: score,
    "timings.assignedAt": admin.firestore.FieldValue.serverTimestamp()
  });

  // Update courier
  batch.update(admin.firestore().doc(`couriers/${courierId}`), {
    pendingOrderId: orderId,
    isAvailable: false
  });

  await batch.commit();

  // Send notification to courier
  await sendCourierAssignmentNotification(courierId, orderId);
}

// MARK: - Helper Functions

async function handleCourierWentOnline(courierId: string, courier: any): Promise<void> {
  logger.info("Courier went online", { courierId });
  
  try {
    // Update courier in Radar system
    await RadarUserService.updateUser(`courier_${courierId}`, {
      description: `Food delivery courier - ${courier.name}`,
      metadata: {
        isOnline: true,
        isAvailable: true,
        vehicleType: courier.vehicleType,
        service: 'food_delivery',
        lastOnline: new Date().toISOString()
      }
    });

    // Check for pending orders that need assignment
    await checkForPendingOrders(courierId, courier);
  } catch (error: any) {
    logger.error("Failed to update courier in Radar", {
      courierId,
      error: error.message
    });
    // Continue without Radar if it fails
    await checkForPendingOrders(courierId, courier);
  }
}

async function handleCourierWentOffline(courierId: string, courier: any): Promise<void> {
  logger.info("Courier went offline", { courierId });
  
  try {
    // Update courier status in Radar system
    await RadarUserService.updateUser(`courier_${courierId}`, {
      description: `Food delivery courier - ${courier.name} (Offline)`,
      metadata: {
        isOnline: false,
        isAvailable: false,
        service: 'food_delivery',
        lastOffline: new Date().toISOString()
      }
    });
  } catch (error: any) {
    logger.error("Failed to update courier offline status in Radar", {
      courierId,
      error: error.message
    });
  }
  
  // Handle any pending assignments
  if (courier.pendingOrderId) {
    await reassignPendingOrder(courier.pendingOrderId);
  }
}

async function handleCourierAssigned(orderId: string, order: any): Promise<void> {
  // Send notification to courier about new order assignment
  await sendCourierAssignmentNotification(order.assignedCourierId, orderId);
  // Also notify restaurant that a courier is assigned
  const tpl = renderTemplate("courier_assigned", { orderId });
  await sendToUser("restaurant", order.restaurantId, { title: tpl.title, body: tpl.body, data: { orderId } });
}

function hasLocationChangedSignificantly(oldLocation: any, newLocation: any): boolean {
  const distance = haversineKm(
    oldLocation.latitude,
    oldLocation.longitude,
    newLocation.latitude,
    newLocation.longitude
  );
  return distance > 0.1; // 100 meters
}

async function updateCourierZoneAvailability(courierId: string, location: any): Promise<void> {
  // Update courier's current zone for better dispatch efficiency
  const zone = await determineZone(location);
  
  await admin.firestore().doc(`couriers/${courierId}`).update({
    currentZone: zone,
    "location.lastUpdatedAt": admin.firestore.FieldValue.serverTimestamp()
  });
}

async function updateOrderTracking(orderId: string, location: any): Promise<void> {
  await admin.firestore().doc(`orders/${orderId}`).update({
    "tracking.currentCourierLocation": {
      latitude: location.latitude,
      longitude: location.longitude
    },
    "tracking.lastUpdated": admin.firestore.FieldValue.serverTimestamp()
  });
}

async function recordCourierDecline(courierId: string, orderId: string, reason: string): Promise<void> {
  // Update courier's acceptance rate
  const courierRef = admin.firestore().doc(`couriers/${courierId}`);
  const courierDoc = await courierRef.get();
  
  if (courierDoc.exists) {
    const courier = courierDoc.data()!;
    const totalAssignments = (courier.totalAssignments || 0) + 1;
    const acceptedAssignments = courier.acceptedAssignments || 0;
    const acceptanceRate = acceptedAssignments / totalAssignments;

    await courierRef.update({
      totalAssignments,
      acceptanceRate,
      lastDeclineReason: reason,
      lastDeclineAt: admin.firestore.FieldValue.serverTimestamp()
    });
  }
}

async function getDeliveryZones(): Promise<any[]> {
  // Mock implementation - return predefined zones
  return [
    { zoneId: "casa_center", name: "Casablanca Center" },
    { zoneId: "casa_maarif", name: "Maarif" },
    { zoneId: "casa_anfa", name: "Anfa" }
  ];
}

async function calculateZonePerformance(zoneId: string): Promise<any> {
  // Calculate zone metrics
  const now = new Date();
  const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);

  // Get orders in the zone in the last hour
  const ordersSnapshot = await admin.firestore()
    .collection("orders")
    .where("zone", "==", zoneId)
    .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(oneHourAgo))
    .get();

  const orders = ordersSnapshot.docs.map(doc => doc.data());
  const pendingOrders = orders.filter(o => ["ready_for_pickup", "searching_courier"].includes(o.status));
  
  // Get active couriers in the zone
  const couriersSnapshot = await admin.firestore()
    .collection("couriers")
    .where("currentZone", "==", zoneId)
    .where("isOnline", "==", true)
    .get();

  const activeCouriers = couriersSnapshot.size;
  
  // Calculate demand level
  const demandRatio = activeCouriers > 0 ? pendingOrders.length / activeCouriers : Infinity;
  let demandLevel = "low";
  
  if (demandRatio > 3) demandLevel = "critical";
  else if (demandRatio > 1.5) demandLevel = "high";
  else if (demandRatio > 0.5) demandLevel = "normal";

  return {
    zoneId,
    activeCouriers,
    pendingOrders: pendingOrders.length,
    totalOrders: orders.length,
    demandLevel,
    demandRatio: Math.round(demandRatio * 100) / 100
  };
}

async function triggerCourierRebalancing(zoneId: string): Promise<void> {
  logger.info("Triggering courier rebalancing", { zoneId });
  // TODO: Implement courier rebalancing logic
}

async function findAvailableOrdersNearLocation(location: any, radiusKm: number, vehicleType: string): Promise<any[]> {
  // Find orders ready for pickup near the courier
  const ordersSnapshot = await admin.firestore()
    .collection("orders")
    .where("status", "==", "ready_for_pickup")
    .get();

  const availableOrders = [];

  for (const orderDoc of ordersSnapshot.docs) {
    const order = orderDoc.data();
    
    // Get restaurant location
    const restaurantDoc = await admin.firestore().doc(`restaurants/${order.restaurantId}`).get();
    if (!restaurantDoc.exists) continue;
    
    const restaurant = restaurantDoc.data()!;
    const distance = haversineKm(
      location.latitude,
      location.longitude,
      restaurant.coordinates.latitude,
      restaurant.coordinates.longitude
    );

    if (distance <= radiusKm) {
      availableOrders.push({
        orderId: orderDoc.id,
        ...order,
        distance,
        restaurantName: restaurant.name,
        pickupLocation: restaurant.coordinates
      });
    }
  }

  return availableOrders.sort((a, b) => a.distance - b.distance);
}

async function checkForPendingOrders(courierId: string, courier: any): Promise<void> {
  // Check if there are orders waiting for couriers near this courier
  if (courier.location) {
    const nearbyOrders = await findAvailableOrdersNearLocation(courier.location, 5.0, courier.vehicleType);
    
    // Auto-assign the best order if available
    if (nearbyOrders.length > 0) {
      const bestOrder = nearbyOrders[0];
      await assignOrderToCourier(bestOrder.orderId, courierId, 0.8);
    }
  }
}

async function reassignPendingOrder(orderId: string): Promise<void> {
  // Remove current assignment and trigger redispatch
  await admin.firestore().doc(`orders/${orderId}`).update({
    assignedCourierId: admin.firestore.FieldValue.delete(),
    status: "ready_for_pickup"
  });
}

async function determineZone(location: any): Promise<string> {
  // Mock implementation - determine zone based on location
  return "casa_center";
}

// Notification helper functions
async function sendCourierAssignmentNotification(courierId: string, orderId: string): Promise<void> {
  try {
    const tpl = renderTemplate("courier_assigned", { orderId });
    await sendToUser("courier", courierId, { title: tpl.title, body: tpl.body, data: { orderId } });
  } catch (e: any) {
    logger.error("Failed to send courier assignment notification", { courierId, orderId, error: e?.message });
  }
}