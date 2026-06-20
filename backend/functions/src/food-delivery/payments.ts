import { onCall, HttpsError, onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import Stripe from "stripe";
import { getSecret, secretPath, SECRET_IDS } from "../shared/secretManager";
import { StripeWebhookService, StripePaymentService, StripeRefundService } from "../services/payments/stripeService";
import { withIdempotency } from "../shared/idempotency";
import { withAudit } from "../shared/audit";
import { logEvent } from "../shared/analytics";

// Stripe client now handled by service layer

/**
 * Food Delivery Stripe Webhook
 * Handles payment events for food delivery orders
 */
export const foodDeliveryStripeWebhook = onRequest({ cors: true }, async (req, res) => {
  const sig = req.headers["stripe-signature"] as string | undefined;
  if (!sig) {
    res.status(400).send("Missing signature");
    return;
  }

  let event: Stripe.Event;
  try {
    event = await StripeWebhookService.constructEvent(req.rawBody as Buffer, sig);
  } catch (err: any) {
    logger.error("⚠️  Food delivery webhook signature verification failed", err);
    res.status(400).send(`Webhook Error: ${err.message}`);
    return;
  }

  try {
    switch (event.type) {
      case "payment_intent.succeeded":
        await handlePaymentSucceeded(event.data.object as Stripe.PaymentIntent);
        break;
      
      case "payment_intent.payment_failed":
        await handlePaymentFailed(event.data.object as Stripe.PaymentIntent);
        break;
      
      case "payment_intent.amount_capturable_updated":
        await handleAmountCapturableUpdated(event.data.object as Stripe.PaymentIntent);
        break;
      
      case "charge.dispute.created":
        await handleChargeDispute(event.data.object as Stripe.Dispute);
        break;
      
      case "refund.created":
        await handleRefundCreated(event.data.object as Stripe.Refund);
        break;
      
      default:
        logger.info("Unhandled food delivery webhook event type", { type: event.type });
    }

    res.json({ received: true });

  } catch (error: any) {
    logger.error("Food delivery webhook processing failed", {
      eventType: event.type,
      error: error.message
    });
    res.status(500).send("Webhook processing failed");
  }
});

/**
 * Create Payment Intent
 * Creates a Stripe payment intent for an order
 */
export const createPaymentIntent = onCall(async (request) => {
  try {
    const { orderId, amount, currency = "mad", idempotencyKey } = request.data || {};
    if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Authentication required");
    if (!orderId || amount === undefined) throw new HttpsError("invalid-argument", "Missing required fields");

    // Get order details
    const orderDoc = await admin.firestore().doc(`orders/${orderId}`).get();
    if (!orderDoc.exists) throw new HttpsError("not-found", "Order not found");

    const order = orderDoc.data()!;
    const result = await withIdempotency(idempotencyKey || orderId, "createPaymentIntent", async () => {
      if (order.payment?.intentId && order.payment?.status === "pending") {
        const existingIntentId = order.payment.intentId as string;
        return { clientSecret: order.payment.clientSecret || null, paymentIntentId: existingIntentId };
      }
      const paymentIntent = await StripePaymentService.createPaymentIntent({
        amount: Math.round(amount * 100),
        currency: currency.toLowerCase(),
        metadata: {
          orderId,
          customerId: order.customerId,
          restaurantId: order.restaurantId,
          type: "food_delivery",
          idempotencyKey: idempotencyKey || `${orderId}`
        },
        captureMethod: "manual",
      });
      await admin.firestore().doc(`orders/${orderId}`).update({
        "payment.intentId": paymentIntent.id,
        "payment.clientSecret": paymentIntent.client_secret,
        "payment.status": "pending",
        "payment.method": "card"
      });
      try { await logEvent(order.customerId || null, "payment_authorized", { orderId, paymentIntentId: paymentIntent.id, amount }); } catch {}
      return { clientSecret: paymentIntent.client_secret, paymentIntentId: paymentIntent.id };
    });

    return { success: true, ...result };

  } catch (error: any) {
    logger.error("Create payment intent failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Create payment intent failed");
  }
});

/**
 * Capture Payment
 * Captures an authorized payment when order is picked up
 */
export const capturePayment = onCall(async (request) => {
  try {
    const { paymentIntentId, amount, idempotencyKey } = request.data || {};
    if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Authentication required");
    if (!paymentIntentId) throw new HttpsError("invalid-argument", "paymentIntentId is required");
    const wrapped = await withIdempotency(idempotencyKey || paymentIntentId, "capturePayment", async () => {
      const amountToCapture = amount ? Math.round(amount * 100) : undefined;
      const intent = await StripePaymentService.capturePaymentIntent(paymentIntentId, amountToCapture);
      const orderId = intent.metadata?.orderId;
      if (orderId) {
        await admin.firestore().doc(`orders/${orderId}`).update({
          "payment.status": "captured",
          "payment.capturedAmount": (intent.amount_received || 0) / 100,
          "payment.capturedAt": admin.firestore.FieldValue.serverTimestamp()
        });
      }
      return { intent };
    });

    const paymentIntent = wrapped.intent as Stripe.PaymentIntent;
    return { success: true, paymentIntentId, status: paymentIntent.status, amountCaptured: (paymentIntent.amount_received || 0) / 100 };

  } catch (error: any) {
    logger.error("Capture payment failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Capture payment failed");
  }
});

/**
 * Process Refund
 * Processes full or partial refunds for orders
 */
export const processRefund = onCall(async (request) => {
  try {
    const { orderId, amount, reason } = request.data || {};
    if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Authentication required");
    if (!orderId || !reason) throw new HttpsError("invalid-argument", "Missing required fields");

    // Get order details
    const orderDoc = await admin.firestore().doc(`orders/${orderId}`).get();
    if (!orderDoc.exists) throw new HttpsError("not-found", "Order not found");

    const order = orderDoc.data()!;
    
    if (!order.payment?.intentId) {
      throw new HttpsError("failed-precondition", "No payment intent found for order");
    }

    // Create refund
    const refund = await StripeRefundService.createRefund({
      paymentIntentId: order.payment.intentId,
      amount: amount ? Math.round(amount * 100) : undefined,
      reason: reason === "duplicate" ? "duplicate" : "requested_by_customer",
      metadata: {
        orderId,
        refundReason: reason
      }
    });

    // Update order with refund information
    const refundAmount = refund.amount / 100;
    const isFullRefund = !amount || refundAmount >= order.total;

    await admin.firestore().doc(`orders/${orderId}`).update({
      "payment.refundStatus": isFullRefund ? "full" : "partial",
      "payment.refundAmount": refundAmount,
      "payment.refundId": refund.id,
      "payment.refundReason": reason,
      "payment.refundedAt": admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: true, refundId: refund.id, amount: refundAmount, status: refund.status };

  } catch (error: any) {
    logger.error("Process refund failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Process refund failed");
  }
});

// Backward-compatibility alias expected by iOS client
export const requestRefund = onCall(async (request) => {
  try {
    const { orderId, amount, reason } = request.data || {};
    if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Authentication required");
    if (!orderId || !reason) throw new HttpsError("invalid-argument", "Missing required fields");

    const orderDoc = await admin.firestore().doc(`orders/${orderId}`).get();
    if (!orderDoc.exists) throw new HttpsError("not-found", "Order not found");
    const order = orderDoc.data()!;
    if (!order.payment?.intentId) throw new HttpsError("failed-precondition", "No payment intent found for order");

    const refund = await StripeRefundService.createRefund({
      paymentIntentId: order.payment.intentId,
      amount: amount ? Math.round(amount * 100) : undefined,
      reason: reason === "duplicate" ? "duplicate" : "requested_by_customer",
      metadata: { orderId, refundReason: reason }
    });

    const refundAmount = refund.amount / 100;
    const isFullRefund = !amount || refundAmount >= order.total;
    await admin.firestore().doc(`orders/${orderId}`).update({
      "payment.refundStatus": isFullRefund ? "full" : "partial",
      "payment.refundAmount": refundAmount,
      "payment.refundId": refund.id,
      "payment.refundReason": reason,
      "payment.refundedAt": admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: true, refundId: refund.id, amount: refundAmount, status: refund.status };
  } catch (error: any) {
    logger.error("requestRefund failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Request refund failed");
  }
});

/**
 * Handle COD Payment
 * Processes cash on delivery payments
 */
export const processCODPayment = onCall(async (request) => {
  try {
    const { orderId, amountReceived, idempotencyKey } = request.data || {};
    const courierId = request.auth?.uid;
    if (!courierId) throw new HttpsError("unauthenticated", "Authentication required");
    if (!orderId || amountReceived === undefined) throw new HttpsError("invalid-argument", "Missing required fields");
    const output = await withIdempotency(idempotencyKey || `${orderId}_${courierId}_cod`, "processCODPayment", async () => {
      const orderDoc = await admin.firestore().doc(`orders/${orderId}`).get();
      if (!orderDoc.exists) throw new HttpsError("not-found", "Order not found");
      const order = orderDoc.data()!;
      if (order.payment.method !== "cod") throw new HttpsError("failed-precondition", "This is not a COD order");
      if (order.courierId !== courierId) throw new HttpsError("permission-denied", "Unauthorized");

      await admin.firestore().doc(`orders/${orderId}`).update({
        "payment.status": "completed",
        "payment.codAmountReceived": amountReceived,
        "payment.codReceivedAt": admin.firestore.FieldValue.serverTimestamp(),
        "payment.codReceivedBy": courierId
      });
      await admin.firestore().doc(`couriers/${courierId}`).update({
        "codBalance": admin.firestore.FieldValue.increment(amountReceived),
        "totalCODCollected": admin.firestore.FieldValue.increment(amountReceived),
        "lastCODCollection": admin.firestore.FieldValue.serverTimestamp()
      });
      await admin.firestore().collection("codTransactions").add({
        orderId,
        courierId,
        amount: amountReceived,
        expectedAmount: order.total,
        difference: amountReceived - order.total,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        type: "collection"
      });
      return { expectedAmount: order.total };
    });

    return { success: true, orderId, amountReceived, expectedAmount: output.expectedAmount, difference: amountReceived - output.expectedAmount };

  } catch (error: any) {
    logger.error("COD payment processing failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "COD processing failed");
  }
});

/**
 * Courier COD Settlement
 * Handles COD balance settlement for couriers
 */
export const settleCODBalance = onCall(async (request) => {
  try {
    const { courierId, settlementAmount, method, idempotencyKey } = request.data || {};
    if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Authentication required");
    if (!courierId || settlementAmount === undefined || !method) throw new HttpsError("invalid-argument", "Missing required fields");
    const data = await withIdempotency(idempotencyKey || `${courierId}_${settlementAmount}_${method}`, "settleCODBalance", async () => {
      const courierDoc = await admin.firestore().doc(`couriers/${courierId}`).get();
      if (!courierDoc.exists) throw new HttpsError("not-found", "Courier not found");
      const courier = courierDoc.data()!;
      const currentBalance = courier.codBalance || 0;
      if (settlementAmount > currentBalance) throw new HttpsError("failed-precondition", "Settlement exceeds balance");
      await admin.firestore().doc(`couriers/${courierId}`).update({
        "codBalance": admin.firestore.FieldValue.increment(-settlementAmount),
        "totalCODSettled": admin.firestore.FieldValue.increment(settlementAmount),
        "lastCODSettlement": admin.firestore.FieldValue.serverTimestamp()
      });
      await admin.firestore().collection("codTransactions").add({
        courierId,
        amount: settlementAmount,
        method,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        type: "settlement",
        balanceBefore: currentBalance,
        balanceAfter: currentBalance - settlementAmount
      });
      return { remainingBalance: currentBalance - settlementAmount };
    });

    return { success: true, courierId, settledAmount: settlementAmount, remainingBalance: data.remainingBalance };

  } catch (error: any) {
    logger.error("COD settlement failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "COD settlement failed");
  }
});

/**
 * Get Payment Analytics
 * Returns payment analytics for restaurants and overall system
 */
export const getPaymentAnalytics = onCall(async (request) => {
  try {
    const { restaurantId, timeframe = "week" } = request.data || {};

    // Calculate date range
    const now = new Date();
    let startDate: Date;
    
    switch (timeframe) {
      case "day":
        startDate = new Date(now.getTime() - 24 * 60 * 60 * 1000);
        break;
      case "month":
        startDate = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
        break;
      default: // week
        startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    }

    let query = admin.firestore()
      .collection("orders")
      .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(startDate))
      .where("status", "==", "delivered");

    if (restaurantId) {
      query = query.where("restaurantId", "==", restaurantId);
    }

    const ordersSnapshot = await query.get();
    const orders = ordersSnapshot.docs.map(doc => doc.data());

    // Calculate analytics
    const analytics = calculatePaymentAnalytics(orders);

    return { success: true, timeframe, period: { start: startDate.toISOString(), end: now.toISOString() }, analytics };

  } catch (error: any) {
    logger.error("Get payment analytics failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Get payment analytics failed");
  }
});

// MARK: - Webhook Event Handlers

async function handlePaymentSucceeded(paymentIntent: Stripe.PaymentIntent): Promise<void> {
  const orderId = paymentIntent.metadata?.orderId;
  if (!orderId) return;

  await admin.firestore().doc(`orders/${orderId}`).update({
    "payment.status": "succeeded",
    "payment.succeededAt": admin.firestore.FieldValue.serverTimestamp()
  });

  logger.info("Payment succeeded", {
    orderId,
    paymentIntentId: paymentIntent.id,
    amount: paymentIntent.amount / 100
  });
  await logEvent(null, "payment_succeeded", { orderId, paymentIntentId: paymentIntent.id, amount: paymentIntent.amount / 100 });
}

async function handlePaymentFailed(paymentIntent: Stripe.PaymentIntent): Promise<void> {
  const orderId = paymentIntent.metadata?.orderId;
  if (!orderId) return;

  await admin.firestore().doc(`orders/${orderId}`).update({
    "payment.status": "failed",
    "payment.failureReason": paymentIntent.last_payment_error?.message,
    "payment.failedAt": admin.firestore.FieldValue.serverTimestamp(),
    status: "payment_failed"
  });

  logger.error("Payment failed", {
    orderId,
    paymentIntentId: paymentIntent.id,
    error: paymentIntent.last_payment_error?.message
  });
  await logEvent(null, "payment_failed", { orderId, paymentIntentId: paymentIntent.id, error: paymentIntent.last_payment_error?.message });
}

async function handleAmountCapturableUpdated(paymentIntent: Stripe.PaymentIntent): Promise<void> {
  const orderId = paymentIntent.metadata?.orderId;
  if (!orderId) return;

  await admin.firestore().doc(`orders/${orderId}`).update({
    "payment.capturableAmount": paymentIntent.amount_capturable / 100,
    "payment.lastUpdated": admin.firestore.FieldValue.serverTimestamp()
  });
}

async function handleChargeDispute(dispute: Stripe.Dispute): Promise<void> {
  const paymentIntentId = dispute.payment_intent as string;
  
  // Find order by payment intent
  const ordersSnapshot = await admin.firestore()
    .collection("orders")
    .where("payment.intentId", "==", paymentIntentId)
    .limit(1)
    .get();

  if (!ordersSnapshot.empty) {
    const orderDoc = ordersSnapshot.docs[0];
    
    await orderDoc.ref.update({
      "payment.disputeId": dispute.id,
      "payment.disputeReason": dispute.reason,
      "payment.disputeStatus": dispute.status,
      "payment.disputeAmount": dispute.amount / 100,
      "payment.disputeCreatedAt": admin.firestore.FieldValue.serverTimestamp()
    });

    logger.warn("Charge dispute created", {
      orderId: orderDoc.id,
      disputeId: dispute.id,
      amount: dispute.amount / 100,
      reason: dispute.reason
    });
  }
}

async function handleRefundCreated(refund: Stripe.Refund): Promise<void> {
  const orderId = refund.metadata?.orderId;
  if (!orderId) return;

  await admin.firestore().doc(`orders/${orderId}`).update({
    "payment.refundProcessedAt": admin.firestore.FieldValue.serverTimestamp(),
    "payment.refundStatus": refund.status
  });

  logger.info("Refund processed", {
    orderId,
    refundId: refund.id,
    amount: refund.amount / 100
  });
}

// MARK: - Helper Functions

function calculatePaymentAnalytics(orders: any[]): any {
  const cardOrders = orders.filter(o => o.payment?.method === "card");
  const codOrders = orders.filter(o => o.payment?.method === "cod");
  
  const totalRevenue = orders.reduce((sum, o) => sum + (o.total || 0), 0);
  const cardRevenue = cardOrders.reduce((sum, o) => sum + (o.total || 0), 0);
  const codRevenue = codOrders.reduce((sum, o) => sum + (o.total || 0), 0);
  
  const totalOrders = orders.length;
  const avgOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0;
  
  const paymentMethodBreakdown = {
    card: {
      count: cardOrders.length,
      percentage: totalOrders > 0 ? (cardOrders.length / totalOrders) * 100 : 0,
      revenue: cardRevenue
    },
    cod: {
      count: codOrders.length,
      percentage: totalOrders > 0 ? (codOrders.length / totalOrders) * 100 : 0,
      revenue: codRevenue
    }
  };

  // Calculate refund analytics
  const refundedOrders = orders.filter(o => o.payment?.refundAmount > 0);
  const totalRefunds = refundedOrders.reduce((sum, o) => sum + (o.payment?.refundAmount || 0), 0);
  const refundRate = totalOrders > 0 ? (refundedOrders.length / totalOrders) * 100 : 0;

  return {
    totalRevenue: Math.round(totalRevenue * 100) / 100,
    totalOrders,
    averageOrderValue: Math.round(avgOrderValue * 100) / 100,
    paymentMethodBreakdown,
    refunds: {
      totalRefunded: Math.round(totalRefunds * 100) / 100,
      refundedOrders: refundedOrders.length,
      refundRate: Math.round(refundRate * 100) / 100
    }
  };
}