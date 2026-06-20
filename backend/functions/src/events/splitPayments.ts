import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import { CallableContext } from "firebase-functions/v2/https";
import { getStripeClient } from "../services/payments/stripeService";
import {
  SplitIntent,
  SplitStatus,
  ShareType,
  SplitShare,
  TicketOrder,
  OrderStatus,
  AttendanceGroup,
  NotificationType,
  EventInteraction,
  InteractionType
} from "./types";
import { sendNotification } from "./notifications";
import { confirmOrder } from "./tickets";

const db = admin.firestore();

// Split expiry time (24 hours)
const SPLIT_EXPIRY_HOURS = 24;

/**
 * Create a split payment intent for an order
 */
export async function createSplitIntent(
  data: {
    orderId: string;
    shareType: ShareType;
    customShares?: { [userId: string]: number };
  },
  context: CallableContext
): Promise<SplitIntent> {
  try {
    if (!context.auth) {
      throw new Error("Authentication required");
    }

    // Get order details
    const orderDoc = await db.collection("ticketOrders").doc(data.orderId).get();
    if (!orderDoc.exists) {
      throw new Error("Order not found");
    }

    const order = orderDoc.data() as TicketOrder;
    
    // Verify user is order organizer
    if (order.organizerId !== context.auth.uid) {
      throw new Error("Only order organizer can create split intents");
    }

    if (order.status !== OrderStatus.PENDING) {
      throw new Error("Order is not in pending status");
    }

    // Get group details
    const groupDoc = await db.collection("attendanceGroups").doc(order.groupId).get();
    const group = groupDoc.data() as AttendanceGroup;

    // Calculate shares
    const shares = calculateShares(
      order.totalAmount,
      group.participantUserIds,
      data.shareType,
      data.customShares
    );

    // Create split intent
    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + SPLIT_EXPIRY_HOURS);

    const splitData: Omit<SplitIntent, "id"> = {
      orderId: data.orderId,
      shareType: data.shareType,
      shares,
      status: SplitStatus.PENDING,
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const splitRef = await db.collection("splitIntents").add(splitData);
    const splitId = splitRef.id;

    // Update order status
    await db.collection("ticketOrders").doc(data.orderId).update({
      status: OrderStatus.AWAITING_SPLIT,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Send split payment notifications
    await sendSplitNotifications(splitId, shares, order, group);

    // Schedule expiry check
    await scheduleSplitExpiry(splitId, expiresAt);

    logger.info("Split intent created", { splitId, orderId: data.orderId });

    return { id: splitId, ...splitData } as SplitIntent;

  } catch (error: any) {
    logger.error("Failed to create split intent", { error: error.message });
    throw error;
  }
}

/**
 * Pay a split share
 */
export async function paySplit(
  data: {
    splitId: string;
    paymentMethodId?: string;
  },
  context: CallableContext
): Promise<{ success: boolean; message: string }> {
  try {
    if (!context.auth) {
      throw new Error("Authentication required");
    }

    const userId = context.auth.uid;

    // Get split intent
    const splitRef = db.collection("splitIntents").doc(data.splitId);
    const splitDoc = await splitRef.get();

    if (!splitDoc.exists) {
      throw new Error("Split intent not found");
    }

    const split = splitDoc.data() as SplitIntent;

    // Check if expired
    if (split.expiresAt.toDate() < new Date()) {
      throw new Error("Split payment has expired");
    }

    if (split.status !== SplitStatus.PENDING) {
      throw new Error("Split is no longer pending");
    }

    // Find user's share
    const shareIndex = split.shares.findIndex(s => s.userId === userId);
    if (shareIndex === -1) {
      throw new Error("No share found for user");
    }

    const share = split.shares[shareIndex];
    if (share.isPaid) {
      return { success: true, message: "Share already paid" };
    }

    // Process payment
    const paymentResult = await processSharePayment(
      share,
      data.paymentMethodId,
      split.orderId
    );

    // Update share status in transaction
    await db.runTransaction(async (transaction) => {
      const currentSplitDoc = await transaction.get(splitRef);
      const currentSplit = currentSplitDoc.data() as SplitIntent;
      
      // Update the specific share
      currentSplit.shares[shareIndex] = {
        ...share,
        isPaid: true,
        paidAt: admin.firestore.Timestamp.now(),
        paymentIntentId: paymentResult.paymentIntentId,
      };

      // Check if all shares are paid
      const allPaid = currentSplit.shares.every(s => s.isPaid);
      
      if (allPaid) {
        // Update split status
        transaction.update(splitRef, {
          shares: currentSplit.shares,
          status: SplitStatus.PAID,
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Trigger order confirmation
        await confirmOrderAfterSplit(split.orderId);
      } else {
        // Just update the shares
        transaction.update(splitRef, {
          shares: currentSplit.shares,
        });
      }
    });

    // Notify organizer of payment
    await notifySharePaid(split, share, userId);

    // Track interaction
    await trackInteraction({
      userId,
      type: InteractionType.PAY,
      entityId: data.splitId,
      entityType: "order",
      context: { shareAmount: share.amount }
    });

    logger.info("Split share paid", { splitId: data.splitId, userId });

    return { 
      success: true, 
      message: "Payment successful" 
    };

  } catch (error: any) {
    logger.error("Failed to pay split", { error: error.message });
    throw error;
  }
}

/**
 * Get split intent status
 */
export async function getSplitStatus(
  splitId: string,
  userId: string
): Promise<{
  split: SplitIntent;
  userShare?: SplitShare;
  totalPaid: number;
  totalPending: number;
}> {
  try {
    const splitDoc = await db.collection("splitIntents").doc(splitId).get();
    if (!splitDoc.exists) {
      throw new Error("Split intent not found");
    }

    const split = { id: splitDoc.id, ...splitDoc.data() } as SplitIntent;
    
    const userShare = split.shares.find(s => s.userId === userId);
    
    const totalPaid = split.shares
      .filter(s => s.isPaid)
      .reduce((sum, s) => sum + s.amount, 0);
    
    const totalPending = split.shares
      .filter(s => !s.isPaid)
      .reduce((sum, s) => sum + s.amount, 0);

    return {
      split,
      userShare,
      totalPaid,
      totalPending
    };

  } catch (error: any) {
    logger.error("Failed to get split status", { error: error.message });
    throw error;
  }
}

/**
 * Calculate shares based on type
 */
function calculateShares(
  totalAmount: number,
  participantIds: string[],
  shareType: ShareType,
  customShares?: { [userId: string]: number }
): SplitShare[] {
  const shares: SplitShare[] = [];

  if (shareType === ShareType.EVEN) {
    // Equal split among all participants
    const shareAmount = Math.ceil(totalAmount / participantIds.length);
    
    participantIds.forEach(userId => {
      shares.push({
        userId,
        amount: shareAmount,
        isPaid: false
      });
    });
    
  } else if (shareType === ShareType.CUSTOM && customShares) {
    // Custom amounts per user
    let totalAssigned = 0;
    
    Object.entries(customShares).forEach(([userId, amount]) => {
      if (participantIds.includes(userId)) {
        shares.push({
          userId,
          amount,
          isPaid: false
        });
        totalAssigned += amount;
      }
    });
    
    // Validate total matches
    if (Math.abs(totalAssigned - totalAmount) > 1) {
      throw new Error(`Custom shares total ${totalAssigned} doesn't match order total ${totalAmount}`);
    }
  }

  return shares;
}

/**
 * Process payment for a share
 */
async function processSharePayment(
  share: SplitShare,
  paymentMethodId: string | undefined,
  orderId: string
): Promise<{ paymentIntentId: string }> {
  const stripe = await getStripeClient();

  // Get user's Stripe customer ID
  const userDoc = await db.collection("users").doc(share.userId).get();
  const stripeCustomerId = userDoc.data()?.stripeCustomerId;

  // Create payment intent for the share
  const paymentIntent = await stripe.paymentIntents.create({
    amount: Math.round(share.amount * 100), // Convert to cents
    currency: "mad",
    customer: stripeCustomerId,
    payment_method: paymentMethodId,
    confirm: !!paymentMethodId,
    metadata: {
      orderId,
      userId: share.userId,
      type: "event_split_payment"
    },
  });

  if (paymentIntent.status !== "succeeded" && paymentIntent.status !== "processing") {
    throw new Error("Payment failed");
  }

  return { paymentIntentId: paymentIntent.id };
}

/**
 * Confirm order after all splits are paid
 */
async function confirmOrderAfterSplit(orderId: string): Promise<void> {
  try {
    await confirmOrder(orderId);
    logger.info("Order confirmed after split completion", { orderId });
  } catch (error: any) {
    logger.error("Failed to confirm order after split", { 
      orderId, 
      error: error.message 
    });
    throw error;
  }
}

/**
 * Send split payment notifications
 */
async function sendSplitNotifications(
  splitId: string,
  shares: SplitShare[],
  order: TicketOrder,
  group: AttendanceGroup
): Promise<void> {
  const eventDoc = await db.collection("events").doc(order.eventId).get();
  const eventTitle = eventDoc.data()?.title || "Event";

  const notifications = shares
    .filter(share => share.userId !== order.organizerId)
    .map(share =>
      sendNotification({
        userId: share.userId,
        type: NotificationType.SPLIT_REQUEST,
        title: "Payment Request",
        body: `Please pay ${share.amount} MAD for ${eventTitle}`,
        data: {
          splitId,
          orderId: order.id,
          amount: share.amount,
          groupName: group.name,
          eventTitle
        }
      })
    );

  await Promise.all(notifications);
}

/**
 * Notify organizer when share is paid
 */
async function notifySharePaid(
  split: SplitIntent,
  share: SplitShare,
  userId: string
): Promise<void> {
  const orderDoc = await db.collection("ticketOrders").doc(split.orderId).get();
  const order = orderDoc.data() as TicketOrder;

  const userDoc = await db.collection("users").doc(userId).get();
  const userName = userDoc.data()?.displayName || "Someone";

  await sendNotification({
    userId: order.organizerId,
    type: NotificationType.SPLIT_PAID,
    title: "Payment Received",
    body: `${userName} paid their share of ${share.amount} MAD`,
    data: {
      splitId: split.id,
      userId,
      amount: share.amount
    }
  });
}

/**
 * Schedule split expiry check
 */
async function scheduleSplitExpiry(splitId: string, expiryTime: Date): Promise<void> {
  // In production, this would use Cloud Scheduler or Cloud Tasks
  // For MVP, we'll check expiry on each access
  logger.info("Split expiry scheduled", { splitId, expiryTime });
}

/**
 * Check and expire splits (called by scheduled function)
 */
export async function checkExpiredSplits(): Promise<void> {
  try {
    const now = admin.firestore.Timestamp.now();
    
    const expiredSplits = await db.collection("splitIntents")
      .where("status", "==", SplitStatus.PENDING)
      .where("expiresAt", "<", now)
      .get();

    const batch = db.batch();
    
    expiredSplits.docs.forEach(doc => {
      batch.update(doc.ref, {
        status: SplitStatus.EXPIRED,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // TODO: Cancel associated order
      // TODO: Send expiry notifications
    });

    await batch.commit();
    
    logger.info("Expired splits processed", { count: expiredSplits.size });

  } catch (error: any) {
    logger.error("Failed to check expired splits", { error: error.message });
  }
}

/**
 * Refund a split payment
 */
export async function refundSplit(
  splitId: string,
  userId: string,
  reason: string
): Promise<void> {
  try {
    const splitDoc = await db.collection("splitIntents").doc(splitId).get();
    if (!splitDoc.exists) {
      throw new Error("Split not found");
    }

    const split = splitDoc.data() as SplitIntent;
    const share = split.shares.find(s => s.userId === userId);
    
    if (!share || !share.isPaid || !share.paymentIntentId) {
      throw new Error("No paid share found for user");
    }

    // Process refund via Stripe
    const stripe = await getStripeClient();
    await stripe.refunds.create({
      payment_intent: share.paymentIntentId,
      reason: "requested_by_customer",
      metadata: {
        splitId,
        userId,
        reason
      }
    });

    // Update share status
    await db.collection("splitIntents").doc(splitId).update({
      [`shares.${split.shares.indexOf(share)}.isPaid`]: false,
      [`shares.${split.shares.indexOf(share)}.refundedAt`]: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info("Split refunded", { splitId, userId, reason });

  } catch (error: any) {
    logger.error("Failed to refund split", { error: error.message });
    throw error;
  }
}

/**
 * Track interaction
 */
async function trackInteraction(interaction: Omit<EventInteraction, "id" | "timestamp">): Promise<void> {
  try {
    await db.collection("interactions").add({
      ...interaction,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
  } catch (error: any) {
    logger.error("Failed to track interaction", { error: error.message });
  }
}