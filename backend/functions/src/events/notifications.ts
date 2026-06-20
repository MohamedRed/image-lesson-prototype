import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import {
  EventNotification,
  NotificationType,
  Event,
  EventSession,
  AttendanceGroup,
  TicketOrder
} from "./types";

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Send a notification to a user
 */
export async function sendNotification(notification: {
  userId: string;
  type: NotificationType;
  title: string;
  body: string;
  data?: { [key: string]: any };
}): Promise<void> {
  try {
    // Store notification in database
    const notificationRef = await db.collection("eventNotifications").add({
      userId: notification.userId,
      type: notification.type,
      title: notification.title,
      body: notification.body,
      data: notification.data || {},
      read: false,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Get user's FCM tokens
    const userDoc = await db.collection("users").doc(notification.userId).get();
    const fcmTokens = userDoc.data()?.fcmTokens as string[] | undefined;

    if (!fcmTokens || fcmTokens.length === 0) {
      logger.warn("No FCM tokens for user", { userId: notification.userId });
      return;
    }

    // Send push notification
    const message: admin.messaging.MulticastMessage = {
      tokens: fcmTokens,
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: {
        type: notification.type,
        notificationId: notificationRef.id,
        ...notification.data,
      },
      apns: {
        payload: {
          aps: {
            badge: await getUnreadCount(notification.userId),
            sound: "default",
            contentAvailable: true,
          },
        },
      },
      android: {
        priority: "high",
        notification: {
          channelId: "events",
          priority: "high",
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
    };

    const response = await messaging.sendMulticast(message);
    
    // Remove invalid tokens
    if (response.failureCount > 0) {
      const invalidTokens: string[] = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success && 
            (resp.error?.code === "messaging/invalid-registration-token" ||
             resp.error?.code === "messaging/registration-token-not-registered")) {
          invalidTokens.push(fcmTokens[idx]);
        }
      });

      if (invalidTokens.length > 0) {
        await removeInvalidTokens(notification.userId, invalidTokens);
      }
    }

    logger.info("Notification sent", {
      userId: notification.userId,
      type: notification.type,
      successCount: response.successCount,
    });

  } catch (error: any) {
    logger.error("Failed to send notification", { error: error.message });
  }
}

/**
 * Send event reminder notifications
 */
export async function sendEventReminders(): Promise<void> {
  try {
    const now = new Date();
    const reminderTime = new Date(now.getTime() + 24 * 60 * 60 * 1000); // 24 hours from now

    // Find events starting in the next 24 hours
    const sessionsSnapshot = await db.collection("eventSessions")
      .where("startAt", ">", admin.firestore.Timestamp.fromDate(now))
      .where("startAt", "<", admin.firestore.Timestamp.fromDate(reminderTime))
      .where("status", "in", ["scheduled", "limited"])
      .get();

    for (const sessionDoc of sessionsSnapshot.docs) {
      const session = sessionDoc.data() as EventSession;
      
      // Find confirmed groups for this session
      const groupsSnapshot = await db.collection("attendanceGroups")
        .where("sessionId", "==", sessionDoc.id)
        .where("status", "==", "confirmed")
        .get();

      for (const groupDoc of groupsSnapshot.docs) {
        const group = groupDoc.data() as AttendanceGroup;
        
        // Get event details
        const eventDoc = await db.collection("events").doc(group.eventId).get();
        const event = eventDoc.data() as Event;

        // Send reminder to all participants
        const notifications = group.participantUserIds.map(userId =>
          sendNotification({
            userId,
            type: NotificationType.EVENT_REMINDER,
            title: "Event Tomorrow!",
            body: `Don't forget: ${event.title} is tomorrow at ${formatTime(session.startAt.toDate())}`,
            data: {
              eventId: group.eventId,
              sessionId: sessionDoc.id,
              groupId: groupDoc.id,
            }
          })
        );

        await Promise.all(notifications);
      }
    }

    logger.info("Event reminders sent");

  } catch (error: any) {
    logger.error("Failed to send event reminders", { error: error.message });
  }
}

/**
 * Send event update notifications
 */
export async function sendEventUpdate(
  eventId: string,
  updateType: "time_change" | "venue_change" | "cancelled",
  details: { [key: string]: any }
): Promise<void> {
  try {
    // Get event details
    const eventDoc = await db.collection("events").doc(eventId).get();
    if (!eventDoc.exists) {
      logger.error("Event not found for update notification", { eventId });
      return;
    }
    const event = eventDoc.data() as Event;

    // Find all groups for this event
    const groupsSnapshot = await db.collection("attendanceGroups")
      .where("eventId", "==", eventId)
      .where("status", "in", ["planning", "ordering", "confirmed"])
      .get();

    const allUserIds = new Set<string>();
    groupsSnapshot.docs.forEach(doc => {
      const group = doc.data() as AttendanceGroup;
      group.participantUserIds.forEach(userId => allUserIds.add(userId));
    });

    // Prepare notification based on update type
    let title = "";
    let body = "";

    switch (updateType) {
      case "time_change":
        title = "Event Time Changed";
        body = `${event.title} has been rescheduled to ${details.newTime}`;
        break;
      case "venue_change":
        title = "Venue Change";
        body = `${event.title} venue changed to ${details.newVenue}`;
        break;
      case "cancelled":
        title = "Event Cancelled";
        body = `${event.title} has been cancelled. ${details.reason || ""}`;
        break;
    }

    // Send notifications
    const notifications = Array.from(allUserIds).map(userId =>
      sendNotification({
        userId,
        type: updateType === "cancelled" 
          ? NotificationType.EVENT_CANCELLED 
          : NotificationType.EVENT_UPDATE,
        title,
        body,
        data: {
          eventId,
          updateType,
          ...details
        }
      })
    );

    await Promise.all(notifications);

    logger.info("Event update notifications sent", {
      eventId,
      updateType,
      recipientCount: allUserIds.size
    });

  } catch (error: any) {
    logger.error("Failed to send event update", { error: error.message });
  }
}

/**
 * Mark notification as read
 */
export async function markNotificationRead(
  notificationId: string,
  userId: string
): Promise<void> {
  try {
    const notificationRef = db.collection("eventNotifications").doc(notificationId);
    const notificationDoc = await notificationRef.get();

    if (!notificationDoc.exists) {
      throw new Error("Notification not found");
    }

    const notification = notificationDoc.data() as EventNotification;
    
    if (notification.userId !== userId) {
      throw new Error("Not authorized to mark this notification");
    }

    await notificationRef.update({
      read: true,
      readAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info("Notification marked as read", { notificationId, userId });

  } catch (error: any) {
    logger.error("Failed to mark notification as read", { error: error.message });
    throw error;
  }
}

/**
 * Get unread notification count for badge
 */
async function getUnreadCount(userId: string): Promise<number> {
  try {
    const snapshot = await db.collection("eventNotifications")
      .where("userId", "==", userId)
      .where("read", "==", false)
      .count()
      .get();

    return snapshot.data().count;

  } catch (error: any) {
    logger.error("Failed to get unread count", { error: error.message });
    return 0;
  }
}

/**
 * Remove invalid FCM tokens
 */
async function removeInvalidTokens(userId: string, invalidTokens: string[]): Promise<void> {
  try {
    await db.collection("users").doc(userId).update({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
    });

    logger.info("Invalid tokens removed", { userId, count: invalidTokens.length });

  } catch (error: any) {
    logger.error("Failed to remove invalid tokens", { error: error.message });
  }
}

/**
 * Format time for notification
 */
function formatTime(date: Date): string {
  return date.toLocaleTimeString("en-US", {
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  });
}

/**
 * Send order status update
 */
export async function sendOrderStatusUpdate(
  order: TicketOrder,
  newStatus: string,
  details?: { [key: string]: any }
): Promise<void> {
  try {
    // Get group details
    const groupDoc = await db.collection("attendanceGroups").doc(order.groupId).get();
    const group = groupDoc.data() as AttendanceGroup;

    // Get event details
    const eventDoc = await db.collection("events").doc(order.eventId).get();
    const event = eventDoc.data() as Event;

    let title = "";
    let body = "";

    switch (newStatus) {
      case "confirmed":
        title = "Order Confirmed!";
        body = `Your tickets for ${event.title} are confirmed`;
        break;
      case "cancelled":
        title = "Order Cancelled";
        body = `Your order for ${event.title} has been cancelled`;
        break;
      case "refunded":
        title = "Order Refunded";
        body = `Your order for ${event.title} has been refunded`;
        break;
      default:
        title = "Order Update";
        body = `Your order for ${event.title} has been updated`;
    }

    // Send to all group participants
    const notifications = group.participantUserIds.map(userId =>
      sendNotification({
        userId,
        type: NotificationType.ORDER_CONFIRMATION,
        title,
        body,
        data: {
          orderId: order.id,
          eventId: order.eventId,
          groupId: order.groupId,
          status: newStatus,
          ...details
        }
      })
    );

    await Promise.all(notifications);

    logger.info("Order status notifications sent", {
      orderId: order.id,
      status: newStatus,
      recipientCount: group.participantUserIds.length
    });

  } catch (error: any) {
    logger.error("Failed to send order status update", { error: error.message });
  }
}

/**
 * Clean up old notifications (scheduled job)
 */
export async function cleanupOldNotifications(): Promise<void> {
  try {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const oldNotifications = await db.collection("eventNotifications")
      .where("sentAt", "<", admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
      .where("read", "==", true)
      .limit(500)
      .get();

    const batch = db.batch();
    oldNotifications.docs.forEach(doc => {
      batch.delete(doc.ref);
    });

    await batch.commit();

    logger.info("Old notifications cleaned up", { count: oldNotifications.size });

  } catch (error: any) {
    logger.error("Failed to cleanup old notifications", { error: error.message });
  }
}