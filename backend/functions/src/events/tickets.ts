import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import { CallableContext } from "firebase-functions/v2/https";
import { getStripeClient } from "../services/payments/stripeService";
import {
  TicketOrder,
  OrderStatus,
  OrderLineItem,
  Ticket,
  OrderSettlement,
  Event,
  EventSession,
  SessionStatus,
  AttendanceGroup,
  GroupStatus,
  EventInteraction,
  InteractionType,
  NotificationType
} from "./types";
import { updateGroupStatus } from "./groups";
import { sendNotification } from "./notifications";
import { updateSessionCapacity } from "./catalog";

const db = admin.firestore();

/**
 * Create a ticket order for a group
 */
export async function createTicketOrder(
  data: {
    groupId: string;
    eventId: string;
    sessionId?: string;
    lineItems: OrderLineItem[];
  },
  context: CallableContext
): Promise<TicketOrder> {
  try {
    if (!context.auth) {
      throw new Error("Authentication required");
    }

    const organizerId = context.auth.uid;

    // Validate group and authorization
    const groupDoc = await db.collection("attendanceGroups").doc(data.groupId).get();
    if (!groupDoc.exists) {
      throw new Error("Group not found");
    }

    const group = groupDoc.data() as AttendanceGroup;
    if (group.organizerId !== organizerId) {
      throw new Error("Only group organizer can create orders");
    }

    if (group.eventId !== data.eventId) {
      throw new Error("Event mismatch with group");
    }

    // Get event details
    const eventDoc = await db.collection("events").doc(data.eventId).get();
    if (!eventDoc.exists) {
      throw new Error("Event not found");
    }
    const event = eventDoc.data() as Event;

    // Validate session and capacity if specified
    let session: EventSession | undefined;
    if (data.sessionId) {
      const sessionDoc = await db.collection("eventSessions").doc(data.sessionId).get();
      if (!sessionDoc.exists || sessionDoc.data()?.eventId !== data.eventId) {
        throw new Error("Invalid session");
      }
      session = sessionDoc.data() as EventSession;
      
      // Check capacity
      await validateCapacity(session, data.lineItems);
    }

    // Calculate total amount
    const totalAmount = calculateOrderTotal(data.lineItems, event);

    // Create order in transaction
    const orderId = await db.runTransaction(async (transaction) => {
      // Reserve capacity if session specified
      if (session && data.sessionId) {
        await reserveCapacity(transaction, data.sessionId, session, data.lineItems);
      }

      // Create order
      const orderRef = db.collection("ticketOrders").doc();
      const orderData: Omit<TicketOrder, "id"> = {
        groupId: data.groupId,
        eventId: data.eventId,
        sessionId: data.sessionId,
        promoterId: event.promoterId,
        organizerId,
        lineItems: data.lineItems,
        totalAmount,
        currency: "MAD",
        status: OrderStatus.PENDING,
        tickets: [], // Will be generated upon confirmation
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      transaction.set(orderRef, orderData);

      // Update group status
      transaction.update(groupDoc.ref, {
        status: GroupStatus.ORDERING,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return orderRef.id;
    });

    // Create payment intent
    const paymentIntent = await createPaymentIntent(orderId, totalAmount, group);

    // Update order with payment intent
    await db.collection("ticketOrders").doc(orderId).update({
      paymentIntentId: paymentIntent.id,
    });

    // Notify group participants
    await notifyOrderCreated(group, event.title, totalAmount);

    // Track interaction
    await trackInteraction({
      userId: organizerId,
      type: InteractionType.ORDER,
      entityId: orderId,
      entityType: "order",
      context: { eventId: data.eventId, groupId: data.groupId }
    });

    logger.info("Ticket order created", { orderId, groupId: data.groupId });

    const orderDoc = await db.collection("ticketOrders").doc(orderId).get();
    return { id: orderId, ...orderDoc.data() } as TicketOrder;

  } catch (error: any) {
    logger.error("Failed to create ticket order", { error: error.message });
    throw error;
  }
}

/**
 * Link external tickets to an order
 */
export async function linkExternalTickets(
  data: {
    groupId: string;
    eventId: string;
    externalUrl: string;
    provider?: string;
  },
  context: CallableContext
): Promise<{ success: boolean; ticketCodes?: string[]; message?: string }> {
  try {
    if (!context.auth) {
      throw new Error("Authentication required");
    }

    // Validate group
    const groupDoc = await db.collection("attendanceGroups").doc(data.groupId).get();
    if (!groupDoc.exists) {
      throw new Error("Group not found");
    }

    const group = groupDoc.data() as AttendanceGroup;
    if (!group.participantUserIds.includes(context.auth.uid)) {
      throw new Error("Not a group participant");
    }

    // Store external ticket link
    const ticketLinkRef = await db.collection("externalTicketLinks").add({
      groupId: data.groupId,
      eventId: data.eventId,
      userId: context.auth.uid,
      externalUrl: data.externalUrl,
      provider: data.provider,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Try to extract ticket codes (provider-specific logic)
    const ticketCodes = await extractTicketCodes(data.externalUrl, data.provider);

    logger.info("External tickets linked", { 
      linkId: ticketLinkRef.id, 
      groupId: data.groupId 
    });

    return {
      success: true,
      ticketCodes,
      message: "Tickets linked successfully"
    };

  } catch (error: any) {
    logger.error("Failed to link external tickets", { error: error.message });
    return {
      success: false,
      message: error.message
    };
  }
}

/**
 * Confirm a ticket order (after payment)
 */
export async function confirmOrder(
  orderId: string,
  paymentIntentId?: string
): Promise<TicketOrder> {
  try {
    const orderRef = db.collection("ticketOrders").doc(orderId);
    const orderDoc = await orderRef.get();
    
    if (!orderDoc.exists) {
      throw new Error("Order not found");
    }

    const order = orderDoc.data() as TicketOrder;
    
    if (order.status !== OrderStatus.PENDING && order.status !== OrderStatus.AWAITING_SPLIT) {
      throw new Error("Order cannot be confirmed in current status");
    }

    // Verify payment if provided
    if (paymentIntentId) {
      const stripe = await getStripeClient();
      const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);
      
      if (paymentIntent.status !== "succeeded") {
        throw new Error("Payment not completed");
      }
    }

    // Generate tickets
    const tickets = await generateTickets(order);

    // Update order
    await orderRef.update({
      status: OrderStatus.CONFIRMED,
      tickets,
      settlement: {
        collectedAt: admin.firestore.FieldValue.serverTimestamp(),
        splits: [], // Will be populated from split intents
        fees: calculateFees(order.totalAmount),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update group status
    await updateGroupStatus(order.groupId, GroupStatus.CONFIRMED);

    // Send confirmation notifications
    await sendOrderConfirmation(order);

    // Track interaction
    await trackInteraction({
      userId: order.organizerId,
      type: InteractionType.PAY,
      entityId: orderId,
      entityType: "order",
      context: { confirmed: true }
    });

    logger.info("Order confirmed", { orderId });

    const updatedDoc = await orderRef.get();
    return { id: orderId, ...updatedDoc.data() } as TicketOrder;

  } catch (error: any) {
    logger.error("Failed to confirm order", { error: error.message });
    throw error;
  }
}

/**
 * Cancel a ticket order
 */
export async function cancelOrder(
  data: { orderId: string },
  context: CallableContext
): Promise<void> {
  try {
    if (!context.auth) {
      throw new Error("Authentication required");
    }

    const orderRef = db.collection("ticketOrders").doc(data.orderId);
    const orderDoc = await orderRef.get();
    
    if (!orderDoc.exists) {
      throw new Error("Order not found");
    }

    const order = orderDoc.data() as TicketOrder;
    
    // Verify authorization
    if (order.organizerId !== context.auth.uid) {
      throw new Error("Not authorized to cancel this order");
    }

    if (order.status === OrderStatus.CONFIRMED) {
      throw new Error("Confirmed orders must be refunded, not cancelled");
    }

    // Cancel in transaction
    await db.runTransaction(async (transaction) => {
      // Release capacity if session specified
      if (order.sessionId) {
        await releaseCapacity(transaction, order.sessionId, order.lineItems);
      }

      // Update order status
      transaction.update(orderRef, {
        status: OrderStatus.CANCELLED,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update group status back to planning
      const groupRef = db.collection("attendanceGroups").doc(order.groupId);
      transaction.update(groupRef, {
        status: GroupStatus.PLANNING,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    // Cancel payment intent if exists
    if (order.paymentIntentId) {
      const stripe = await getStripeClient();
      await stripe.paymentIntents.cancel(order.paymentIntentId);
    }

    logger.info("Order cancelled", { orderId: data.orderId });

  } catch (error: any) {
    logger.error("Failed to cancel order", { error: error.message });
    throw error;
  }
}

/**
 * Validate capacity for line items
 */
async function validateCapacity(
  session: EventSession,
  lineItems: OrderLineItem[]
): Promise<void> {
  const soldByTier = session.soldByTier || {};
  
  for (const item of lineItems) {
    const available = (session.capacityByTier[item.tierName] || 0) - 
                     (soldByTier[item.tierName] || 0);
    
    if (available < item.quantity) {
      throw new Error(`Insufficient capacity for ${item.tierName}. Available: ${available}`);
    }
  }
}

/**
 * Reserve capacity in transaction
 */
async function reserveCapacity(
  transaction: admin.firestore.Transaction,
  sessionId: string,
  session: EventSession,
  lineItems: OrderLineItem[]
): Promise<void> {
  const sessionRef = db.collection("eventSessions").doc(sessionId);
  const soldByTier = { ...(session.soldByTier || {}) };
  
  for (const item of lineItems) {
    soldByTier[item.tierName] = (soldByTier[item.tierName] || 0) + item.quantity;
  }
  
  // Check if session should be marked as limited or sold out
  let status = session.status;
  const totalSold = Object.values(soldByTier).reduce((sum, count) => sum + count, 0);
  const totalCapacity = Object.values(session.capacityByTier).reduce((sum, count) => sum + count, 0);
  
  if (totalSold >= totalCapacity) {
    status = SessionStatus.SOLD_OUT;
  } else if (totalSold >= totalCapacity * 0.8) {
    status = SessionStatus.LIMITED;
  }
  
  transaction.update(sessionRef, {
    soldByTier,
    status,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Release capacity in transaction
 */
async function releaseCapacity(
  transaction: admin.firestore.Transaction,
  sessionId: string,
  lineItems: OrderLineItem[]
): Promise<void> {
  const sessionRef = db.collection("eventSessions").doc(sessionId);
  const sessionDoc = await transaction.get(sessionRef);
  
  if (!sessionDoc.exists) return;
  
  const session = sessionDoc.data() as EventSession;
  const soldByTier = { ...(session.soldByTier || {}) };
  
  for (const item of lineItems) {
    soldByTier[item.tierName] = Math.max(0, (soldByTier[item.tierName] || 0) - item.quantity);
  }
  
  transaction.update(sessionRef, {
    soldByTier,
    status: SessionStatus.SCHEDULED, // Reset to scheduled
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Calculate order total
 */
function calculateOrderTotal(lineItems: OrderLineItem[], event: Event): number {
  let total = 0;
  
  for (const item of lineItems) {
    const tier = event.priceTiers.find(t => t.name === item.tierName);
    if (!tier) {
      throw new Error(`Invalid tier: ${item.tierName}`);
    }
    total += tier.priceMAD * item.quantity;
  }
  
  return total;
}

/**
 * Create Stripe payment intent
 */
async function createPaymentIntent(
  orderId: string,
  amount: number,
  group: AttendanceGroup
): Promise<any> {
  const stripe = await getStripeClient();
  
  return stripe.paymentIntents.create({
    amount: Math.round(amount * 100), // Convert to cents
    currency: "mad",
    metadata: {
      orderId,
      groupId: group.id,
      type: "event_tickets"
    },
    capture_method: "automatic",
  });
}

/**
 * Generate ticket codes
 */
async function generateTickets(order: TicketOrder): Promise<Ticket[]> {
  const tickets: Ticket[] = [];
  
  for (const item of order.lineItems) {
    for (let i = 0; i < item.quantity; i++) {
      const code = generateTicketCode(order.id!, item.tierName, i);
      const qrUrl = await generateQRCode(code);
      
      tickets.push({
        code,
        qrUrl,
        tierName: item.tierName,
        seat: undefined, // Will be assigned for seated events
      });
    }
  }
  
  return tickets;
}

/**
 * Generate unique ticket code
 */
function generateTicketCode(orderId: string, tierName: string, index: number): string {
  const timestamp = Date.now().toString(36);
  const random = Math.random().toString(36).substring(2, 8);
  return `${orderId.substring(0, 6)}-${tierName.substring(0, 3)}-${index}-${timestamp}-${random}`.toUpperCase();
}

/**
 * Generate QR code URL
 */
async function generateQRCode(code: string): Promise<string> {
  // In production, this would generate actual QR code and upload to storage
  // For now, using a placeholder service
  return `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(code)}`;
}

/**
 * Calculate platform fees
 */
function calculateFees(totalAmount: number): Array<{ type: string; amount: number }> {
  return [
    { type: "platform", amount: totalAmount * 0.025 }, // 2.5% platform fee
    { type: "payment", amount: totalAmount * 0.029 + 0.30 }, // Stripe fee
  ];
}

/**
 * Extract ticket codes from external URL (provider-specific)
 */
async function extractTicketCodes(url: string, provider?: string): Promise<string[] | undefined> {
  // This would implement provider-specific extraction logic
  // For MVP, just return undefined
  return undefined;
}

/**
 * Send order confirmation notifications
 */
async function sendOrderConfirmation(order: TicketOrder): Promise<void> {
  const groupDoc = await db.collection("attendanceGroups").doc(order.groupId).get();
  const group = groupDoc.data() as AttendanceGroup;
  
  const eventDoc = await db.collection("events").doc(order.eventId).get();
  const event = eventDoc.data() as Event;
  
  // Notify all participants
  const notifications = group.participantUserIds.map(userId =>
    sendNotification({
      userId,
      type: NotificationType.ORDER_CONFIRMATION,
      title: "Tickets Confirmed!",
      body: `Your tickets for ${event.title} are confirmed`,
      data: {
        orderId: order.id,
        eventId: order.eventId,
        groupId: order.groupId,
      }
    })
  );
  
  await Promise.all(notifications);
}

/**
 * Notify group about order creation
 */
async function notifyOrderCreated(
  group: AttendanceGroup,
  eventTitle: string,
  totalAmount: number
): Promise<void> {
  const notifications = group.participantUserIds
    .filter(userId => userId !== group.organizerId)
    .map(userId =>
      sendNotification({
        userId,
        type: NotificationType.SPLIT_REQUEST,
        title: "Payment Required",
        body: `Split payment of ${totalAmount} MAD for ${eventTitle}`,
        data: {
          groupId: group.id,
          totalAmount,
        }
      })
    );
  
  await Promise.all(notifications);
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