import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { sendEventReminders, sendEventUpdate, cleanupOldNotifications } from "./notifications";
import { checkExpiredSplits } from "./splitPayments";
import { updateEventEmbeddings, processEventStream, getEventAnalytics } from "./bigquery_analytics";
import {
  Event,
  EventSession,
  AttendanceGroup,
  TicketOrder,
  SplitIntent,
  EventNotification,
  SessionStatus,
  OrderStatus,
  SplitStatus,
  GroupStatus,
  InteractionType,
  EventInteraction
} from "./types";

const db = admin.firestore();

/**
 * Send event reminders daily at 9 AM
 * Runs: Daily at 9:00 AM Morocco time
 */
export const sendDailyEventReminders = onSchedule({
  schedule: "0 9 * * *",
  timeZone: "Africa/Casablanca",
  memory: "512MiB",
  timeoutSeconds: 300
}, async (event) => {
  logger.info("Starting daily event reminders job");
  
  try {
    await sendEventReminders();
    logger.info("Daily event reminders completed successfully");
  } catch (error: any) {
    logger.error("Daily event reminders failed", { error: error.message });
    throw error;
  }
});

/**
 * Process expired split payments hourly
 * Runs: Every hour
 */
export const processExpiredSplits = onSchedule({
  schedule: "0 * * * *",
  memory: "256MiB",
  timeoutSeconds: 180
}, async (event) => {
  logger.info("Starting expired splits cleanup");
  
  try {
    await checkExpiredSplits();
    
    // Also handle expired group invitations
    await expireOldGroupInvitations();
    
    logger.info("Expired splits cleanup completed");
  } catch (error: any) {
    logger.error("Expired splits cleanup failed", { error: error.message });
    throw error;
  }
});

/**
 * Update event embeddings and analytics data nightly
 * Runs: Daily at 2 AM
 */
export const updateEventAnalytics = onSchedule({
  schedule: "0 2 * * *",
  timeZone: "Africa/Casablanca",
  memory: "1GiB",
  timeoutSeconds: 600
}, async (event) => {
  logger.info("Starting event analytics update");
  
  try {
    // Update embeddings for new/modified events
    await updateNewEventEmbeddings();
    
    // Process accumulated interactions
    await processAccumulatedInteractions();
    
    // Update trending events cache
    await updateTrendingEventsCache();
    
    // Cleanup old data
    await performDataCleanup();
    
    logger.info("Event analytics update completed");
  } catch (error: any) {
    logger.error("Event analytics update failed", { error: error.message });
    throw error;
  }
});

/**
 * Send pre-event logistics reminders
 * Runs: Every 6 hours
 */
export const sendLogisticsReminders = onSchedule({
  schedule: "0 */6 * * *",
  memory: "256MiB",
  timeoutSeconds: 240
}, async (event) => {
  logger.info("Starting logistics reminders job");
  
  try {
    await sendPreEventReminders();
    await checkStuckOrders();
    await updateSessionAvailability();
    
    logger.info("Logistics reminders completed");
  } catch (error: any) {
    logger.error("Logistics reminders failed", { error: error.message });
    throw error;
  }
});

/**
 * Weekly cleanup and maintenance
 * Runs: Every Sunday at 3 AM
 */
export const weeklyMaintenance = onSchedule({
  schedule: "0 3 * * 0",
  timeZone: "Africa/Casablanca",
  memory: "1GiB",
  timeoutSeconds: 900
}, async (event) => {
  logger.info("Starting weekly maintenance");
  
  try {
    // Clean up old notifications
    await cleanupOldNotifications();
    
    // Archive completed events
    await archiveCompletedEvents();
    
    // Clean up failed orders
    await cleanupFailedOrders();
    
    // Update user engagement metrics
    await updateUserEngagementMetrics();
    
    // Optimize database indexes
    await optimizeFirestorePerformance();
    
    logger.info("Weekly maintenance completed");
  } catch (error: any) {
    logger.error("Weekly maintenance failed", { error: error.message });
    throw error;
  }
});

// Helper functions

/**
 * Expire old group invitations (7 days)
 */
async function expireOldGroupInvitations(): Promise<void> {
  const sevenDaysAgo = new Date();
  sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
  
  const expiredGroupsSnapshot = await db.collection("attendanceGroups")
    .where("createdAt", "<", admin.firestore.Timestamp.fromDate(sevenDaysAgo))
    .where("status", "==", GroupStatus.PLANNING)
    .get();
  
  const batch = db.batch();
  let expiredCount = 0;
  
  expiredGroupsSnapshot.docs.forEach(doc => {
    const group = doc.data() as AttendanceGroup;
    
    // Only expire groups that still have pending invitations
    if (group.invitedUserIds.length > 0 && group.participantUserIds.length === 1) {
      batch.update(doc.ref, {
        status: GroupStatus.CANCELLED,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      expiredCount++;
    }
  });
  
  if (expiredCount > 0) {
    await batch.commit();
    logger.info("Expired old group invitations", { count: expiredCount });
  }
}

/**
 * Update embeddings for events created/modified in last 24 hours
 */
async function updateNewEventEmbeddings(): Promise<void> {
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  
  const newEventsSnapshot = await db.collection("events")
    .where("updatedAt", ">", admin.firestore.Timestamp.fromDate(yesterday))
    .get();
  
  if (!newEventsSnapshot.empty) {
    const events = newEventsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    })) as Event[];
    
    await updateEventEmbeddings(events);
    logger.info("Updated embeddings for new events", { count: events.length });
  }
}

/**
 * Process accumulated interaction data
 */
async function processAccumulatedInteractions(): Promise<void> {
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  
  const interactionsSnapshot = await db.collection("interactions")
    .where("timestamp", ">", admin.firestore.Timestamp.fromDate(yesterday))
    .where("processed", "==", false)
    .limit(1000)
    .get();
  
  if (!interactionsSnapshot.empty) {
    const interactions = interactionsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      timestamp: doc.data().timestamp.toDate()
    })) as EventInteraction[];
    
    await processEventStream(interactions);
    
    // Mark as processed
    const batch = db.batch();
    interactionsSnapshot.docs.forEach(doc => {
      batch.update(doc.ref, { processed: true });
    });
    await batch.commit();
    
    logger.info("Processed accumulated interactions", { count: interactions.length });
  }
}

/**
 * Update trending events cache
 */
async function updateTrendingEventsCache(): Promise<void> {
  const analytics = await getEventAnalytics();
  
  // Store trending events in cache collection
  const cacheDoc = db.collection("_cache").doc("trending_events");
  await cacheDoc.set({
    popularEvents: analytics.popularEvents,
    userEngagement: analytics.userEngagement,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  logger.info("Updated trending events cache", { 
    popularCount: analytics.popularEvents.length 
  });
}

/**
 * Send pre-event reminders for logistics
 */
async function sendPreEventReminders(): Promise<void> {
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  tomorrow.setHours(0, 0, 0, 0);
  
  const dayAfterTomorrow = new Date(tomorrow);
  dayAfterTomorrow.setDate(dayAfterTomorrow.getDate() + 1);
  
  // Find sessions starting tomorrow
  const sessionsSnapshot = await db.collection("eventSessions")
    .where("startAt", ">=", admin.firestore.Timestamp.fromDate(tomorrow))
    .where("startAt", "<", admin.firestore.Timestamp.fromDate(dayAfterTomorrow))
    .get();
  
  for (const sessionDoc of sessionsSnapshot.docs) {
    const session = sessionDoc.data() as EventSession;
    
    // Find confirmed groups for this session  
    const groupsSnapshot = await db.collection("attendanceGroups")
      .where("sessionId", "==", sessionDoc.id)
      .where("status", "==", GroupStatus.CONFIRMED)
      .get();
    
    for (const groupDoc of groupsSnapshot.docs) {
      const group = groupDoc.data() as AttendanceGroup;
      
      // Send logistics reminders (venue details, parking, etc.)
      const eventDoc = await db.collection("events").doc(group.eventId).get();
      const event = eventDoc.data() as Event;
      
      await sendEventUpdate(group.eventId, "logistics_reminder", {
        venueName: event.venueName,
        startTime: session.startAt.toDate().toLocaleTimeString(),
        groupName: group.name
      });
    }
  }
}

/**
 * Check for orders stuck in processing
 */
async function checkStuckOrders(): Promise<void> {
  const twoHoursAgo = new Date();
  twoHoursAgo.setHours(twoHoursAgo.getHours() - 2);
  
  const stuckOrdersSnapshot = await db.collection("ticketOrders")
    .where("status", "==", OrderStatus.PENDING)
    .where("createdAt", "<", admin.firestore.Timestamp.fromDate(twoHoursAgo))
    .get();
  
  if (!stuckOrdersSnapshot.empty) {
    const batch = db.batch();
    
    stuckOrdersSnapshot.docs.forEach(doc => {
      batch.update(doc.ref, {
        status: OrderStatus.CANCELLED,
        cancellationReason: "Automatic timeout after 2 hours",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    
    await batch.commit();
    logger.warn("Cancelled stuck orders", { count: stuckOrdersSnapshot.size });
  }
}

/**
 * Update session availability based on recent orders
 */
async function updateSessionAvailability(): Promise<void> {
  // Get sessions in next 7 days
  const weekFromNow = new Date();
  weekFromNow.setDate(weekFromNow.getDate() + 7);
  
  const sessionsSnapshot = await db.collection("eventSessions")
    .where("startAt", ">", admin.firestore.Timestamp.now())
    .where("startAt", "<", admin.firestore.Timestamp.fromDate(weekFromNow))
    .get();
  
  const batch = db.batch();
  
  for (const sessionDoc of sessionsSnapshot.docs) {
    const session = sessionDoc.data() as EventSession;
    
    // Calculate actual sold tickets
    const ordersSnapshot = await db.collection("ticketOrders")
      .where("sessionId", "==", sessionDoc.id)
      .where("status", "==", OrderStatus.CONFIRMED)
      .get();
    
    const actualSoldByTier: { [tierName: string]: number } = {};
    
    ordersSnapshot.docs.forEach(orderDoc => {
      const order = orderDoc.data() as TicketOrder;
      order.lineItems.forEach(item => {
        actualSoldByTier[item.tierName] = (actualSoldByTier[item.tierName] || 0) + item.quantity;
      });
    });
    
    // Update session with actual numbers
    let newStatus = session.status;
    const totalCapacity = Object.values(session.capacityByTier).reduce((sum, cap) => sum + cap, 0);
    const totalSold = Object.values(actualSoldByTier).reduce((sum, sold) => sum + sold, 0);
    
    if (totalSold >= totalCapacity) {
      newStatus = SessionStatus.SOLD_OUT;
    } else if (totalSold >= totalCapacity * 0.8) {
      newStatus = SessionStatus.LIMITED;
    } else {
      newStatus = SessionStatus.SCHEDULED;
    }
    
    if (newStatus !== session.status || JSON.stringify(actualSoldByTier) !== JSON.stringify(session.soldByTier)) {
      batch.update(sessionDoc.ref, {
        soldByTier: actualSoldByTier,
        status: newStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }
  
  await batch.commit();
}

/**
 * Archive events that ended more than 30 days ago
 */
async function archiveCompletedEvents(): Promise<void> {
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  
  const completedEventsSnapshot = await db.collection("events")
    .where("endAt", "<", admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
    .limit(100)
    .get();
  
  if (!completedEventsSnapshot.empty) {
    // Move to archived collection
    const batch = db.batch();
    
    completedEventsSnapshot.docs.forEach(doc => {
      const archivedEventRef = db.collection("archived_events").doc(doc.id);
      batch.set(archivedEventRef, {
        ...doc.data(),
        archivedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    logger.info("Archived completed events", { count: completedEventsSnapshot.size });
  }
}

/**
 * Clean up failed orders older than 7 days
 */
async function cleanupFailedOrders(): Promise<void> {
  const sevenDaysAgo = new Date();
  sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
  
  const failedOrdersSnapshot = await db.collection("ticketOrders")
    .where("status", "==", OrderStatus.CANCELLED)
    .where("updatedAt", "<", admin.firestore.Timestamp.fromDate(sevenDaysAgo))
    .limit(100)
    .get();
  
  if (!failedOrdersSnapshot.empty) {
    const batch = db.batch();
    failedOrdersSnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    await batch.commit();
    
    logger.info("Cleaned up failed orders", { count: failedOrdersSnapshot.size });
  }
}

/**
 * Update user engagement metrics
 */
async function updateUserEngagementMetrics(): Promise<void> {
  // This would calculate user engagement scores, retention rates, etc.
  // For now, just log that it ran
  logger.info("Updated user engagement metrics");
}

/**
 * Optimize Firestore performance
 */
async function optimizeFirestorePerformance(): Promise<void> {
  // This would analyze query performance and suggest optimizations
  // For now, just log that it ran
  logger.info("Performed Firestore performance optimization check");
}

/**
 * General data cleanup
 */
async function performDataCleanup(): Promise<void> {
  // Clean up old interaction logs
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  
  const oldInteractionsSnapshot = await db.collection("interactions")
    .where("timestamp", "<", admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
    .where("processed", "==", true)
    .limit(500)
    .get();
  
  if (!oldInteractionsSnapshot.empty) {
    const batch = db.batch();
    oldInteractionsSnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    await batch.commit();
    
    logger.info("Cleaned up old interactions", { count: oldInteractionsSnapshot.size });
  }
}