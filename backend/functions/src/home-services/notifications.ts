import { onRequest } from "firebase-functions/v2/https";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { withMetrics } from "../shared/metrics";

try { admin.app(); } catch { admin.initializeApp(); }

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Register device token for push notifications
 * POST /home/notifications/register
 */
export const registerDeviceToken = withMetrics("registerDeviceToken",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { deviceToken, platform, appVersion } = req.body;
      
      if (!deviceToken) {
        res.status(400).json({ error: "Device token is required" });
        return;
      }

      const deviceData = {
        userId,
        deviceToken,
        platform: platform || 'unknown', // 'ios', 'android', 'web'
        appVersion: appVersion || 'unknown',
        isActive: true,
        registeredAt: admin.firestore.FieldValue.serverTimestamp(),
        lastSeenAt: admin.firestore.FieldValue.serverTimestamp()
      };

      // Store device token (replace if exists)
      await db.collection('deviceTokens').doc(deviceToken).set(deviceData);

      // Subscribe to relevant FCM topics
      await subscribeToTopics(deviceToken, userId);

      logger.info("Device token registered", { 
        userId, 
        platform,
        tokenPrefix: deviceToken.substring(0, 20) + "..." 
      });

      res.json({ success: true });
    } catch (error: any) {
      logger.error("Failed to register device token", { error: error.message });
      res.status(500).json({ error: "Failed to register device token" });
    }
  })
);

/**
 * Update notification preferences
 * POST /home/notifications/preferences
 */
export const updateNotificationPreferences = withMetrics("updateNotificationPreferences",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const preferences = req.body;
      
      // Validate preferences structure
      const validKeys = [
        'newBids', 'bidAccepted', 'contractUpdates', 'paymentNotifications',
        'disputeUpdates', 'reviewRequests', 'messageNotifications', 'marketingEmails'
      ];
      
      const filteredPreferences = Object.keys(preferences)
        .filter(key => validKeys.includes(key))
        .reduce((obj, key) => {
          obj[key] = Boolean(preferences[key]);
          return obj;
        }, {} as Record<string, boolean>);

      await db.collection('notificationPreferences').doc(userId).set({
        userId,
        ...filteredPreferences,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });

      logger.info("Notification preferences updated", { userId, preferences: filteredPreferences });

      res.json({ success: true });
    } catch (error: any) {
      logger.error("Failed to update notification preferences", { error: error.message });
      res.status(500).json({ error: "Failed to update preferences" });
    }
  })
);

/**
 * Send notification to specific user
 * POST /home/notifications/send
 */
export const sendNotification = withMetrics("sendNotification",
  onRequest({ cors: true }, async (req, res) => {
    try {
      if (!req.auth?.token?.admin) {
        res.status(403).json({ error: "Admin access required" });
        return;
      }

      const { userId, title, message, data, type } = req.body;
      
      if (!userId || !title || !message) {
        res.status(400).json({ error: "User ID, title, and message are required" });
        return;
      }

      const notificationData = {
        userId,
        type: type || 'general',
        title,
        message,
        data: data || {},
        sent: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      };

      const notificationRef = await db.collection('notifications').add(notificationData);

      // Send push notification
      await sendPushNotification(userId, {
        title,
        body: message,
        data: {
          notificationId: notificationRef.id,
          type: type || 'general',
          ...data
        }
      });

      await notificationRef.update({ sent: true });

      logger.info("Notification sent", { 
        notificationId: notificationRef.id,
        userId, 
        type 
      });

      res.json({ 
        notificationId: notificationRef.id,
        success: true 
      });
    } catch (error: any) {
      logger.error("Failed to send notification", { error: error.message });
      res.status(500).json({ error: "Failed to send notification" });
    }
  })
);

/**
 * Get user notifications
 * GET /home/notifications
 */
export const getUserNotifications = withMetrics("getUserNotifications",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { limit = 20, unreadOnly = false } = req.query;

      let query = db.collection('notifications')
        .where('userId', '==', userId)
        .orderBy('createdAt', 'desc')
        .limit(Number(limit));

      if (unreadOnly === 'true') {
        query = query.where('read', '==', false);
      }

      const snapshot = await query.get();
      
      const notifications = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));

      res.json({ notifications });
    } catch (error: any) {
      logger.error("Failed to get user notifications", { error: error.message });
      res.status(500).json({ error: "Failed to get notifications" });
    }
  })
);

/**
 * Mark notifications as read
 * POST /home/notifications/mark-read
 */
export const markNotificationsAsRead = withMetrics("markNotificationsAsRead",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { notificationIds } = req.body;
      
      if (!Array.isArray(notificationIds) || notificationIds.length === 0) {
        res.status(400).json({ error: "Notification IDs array is required" });
        return;
      }

      const batch = db.batch();
      
      for (const notificationId of notificationIds) {
        const notificationRef = db.collection('notifications').doc(notificationId);
        batch.update(notificationRef, {
          read: true,
          readAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }

      await batch.commit();

      logger.info("Notifications marked as read", { 
        userId, 
        count: notificationIds.length 
      });

      res.json({ success: true });
    } catch (error: any) {
      logger.error("Failed to mark notifications as read", { error: error.message });
      res.status(500).json({ error: "Failed to mark notifications as read" });
    }
  })
);

/**
 * Auto-send notifications when new bid is created
 */
export const notifyNewBid = withMetrics("notifyNewBid",
  onDocumentCreated("bids/{bidId}", async (event) => {
    const bidData = event.data?.data();
    if (!bidData) return;

    try {
      // Check if customer wants new bid notifications
      const canNotify = await checkNotificationPermission(bidData.customerId, 'newBids');
      if (!canNotify) return;

      const notification = {
        userId: bidData.customerId,
        type: 'new_bid',
        title: 'New Bid Received! 🎯',
        titleAr: 'تم استلام عرض جديد! 🎯',
        titleFr: 'Nouvelle offre reçue! 🎯',
        message: `You received a new bid of ${bidData.priceMAD} MAD for your service request.`,
        messageAr: `تلقيت عرضاً جديداً بقيمة ${bidData.priceMAD} درهم لطلب الخدمة الخاص بك.`,
        messageFr: `Vous avez reçu une nouvelle offre de ${bidData.priceMAD} MAD pour votre demande de service.`,
        data: {
          bidId: event.params.bidId,
          rfqId: bidData.rfqId,
          amount: bidData.priceMAD.toString(),
          proId: bidData.proId
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      };

      const notificationRef = await db.collection('notifications').add(notification);

      // Send push notification
      await sendPushNotification(bidData.customerId, {
        title: notification.title,
        body: notification.message,
        data: notification.data
      });

      await notificationRef.update({ sent: true });

      logger.info("New bid notification sent", { 
        bidId: event.params.bidId,
        customerId: bidData.customerId 
      });

    } catch (error: any) {
      logger.error("Failed to send new bid notification", { 
        bidId: event.params.bidId,
        error: error.message 
      });
    }
  })
);

/**
 * Auto-send notifications when bid is accepted
 */
export const notifyBidAccepted = withMetrics("notifyBidAccepted",
  onDocumentUpdated("bids/{bidId}", async (event) => {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();
    
    if (!beforeData || !afterData) return;
    
    // Only notify when status changes to 'accepted'
    if (beforeData.status !== 'accepted' && afterData.status === 'accepted') {
      try {
        // Check if professional wants bid acceptance notifications
        const canNotify = await checkNotificationPermission(afterData.proId, 'bidAccepted');
        if (!canNotify) return;

        const notification = {
          userId: afterData.proId,
          type: 'bid_accepted',
          title: 'Congratulations! Bid Accepted! 🎉',
          titleAr: 'تهانينا! تم قبول عرضك! 🎉',
          titleFr: 'Félicitations! Offre acceptée! 🎉',
          message: `Your bid of ${afterData.priceMAD} MAD has been accepted! You can start working on the project.`,
          messageAr: `تم قبول عرضك بقيمة ${afterData.priceMAD} درهم! يمكنك البدء في العمل على المشروع.`,
          messageFr: `Votre offre de ${afterData.priceMAD} MAD a été acceptée! Vous pouvez commencer à travailler sur le projet.`,
          data: {
            bidId: event.params.bidId,
            rfqId: afterData.rfqId,
            customerId: afterData.customerId,
            amount: afterData.priceMAD.toString()
          },
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        };

        const notificationRef = await db.collection('notifications').add(notification);

        await sendPushNotification(afterData.proId, {
          title: notification.title,
          body: notification.message,
          data: notification.data
        });

        await notificationRef.update({ sent: true });

        logger.info("Bid accepted notification sent", { 
          bidId: event.params.bidId,
          proId: afterData.proId 
        });

      } catch (error: any) {
        logger.error("Failed to send bid accepted notification", { 
          bidId: event.params.bidId,
          error: error.message 
        });
      }
    }
  })
);

/**
 * Auto-send notifications when contract is completed
 */
export const notifyContractCompleted = withMetrics("notifyContractCompleted",
  onDocumentUpdated("contracts/{contractId}", async (event) => {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();
    
    if (!beforeData || !afterData) return;
    
    // Only notify when status changes to 'completed'
    if (beforeData.status !== 'completed' && afterData.status === 'completed') {
      try {
        // Notify both customer and professional
        const notifications = [
          {
            userId: afterData.customerId,
            type: 'contract_completed',
            title: 'Service Completed! ✅',
            titleAr: 'تم إكمال الخدمة! ✅',
            titleFr: 'Service terminé! ✅',
            message: 'Your service has been completed. Please leave a review for the professional.',
            messageAr: 'تم إكمال خدمتك. يرجى ترك تقييم للمهني.',
            messageFr: 'Votre service a été terminé. Veuillez laisser un avis pour le professionnel.',
            data: {
              contractId: event.params.contractId,
              rfqId: afterData.rfqId,
              proId: afterData.proId,
              role: 'customer'
            }
          },
          {
            userId: afterData.proId,
            type: 'contract_completed',
            title: 'Service Completed! ✅',
            titleAr: 'تم إكمال الخدمة! ✅',
            titleFr: 'Service terminé! ✅',
            message: 'You have successfully completed the service. Payment will be released shortly.',
            messageAr: 'لقد أكملت الخدمة بنجاح. سيتم إطلاق الدفعة قريباً.',
            messageFr: 'Vous avez terminé le service avec succès. Le paiement sera libéré sous peu.',
            data: {
              contractId: event.params.contractId,
              rfqId: afterData.rfqId,
              customerId: afterData.customerId,
              role: 'professional'
            }
          }
        ];

        for (const notification of notifications) {
          const canNotify = await checkNotificationPermission(notification.userId, 'contractUpdates');
          if (!canNotify) continue;

          const notificationRef = await db.collection('notifications').add({
            ...notification,
            createdAt: admin.firestore.FieldValue.serverTimestamp()
          });

          await sendPushNotification(notification.userId, {
            title: notification.title,
            body: notification.message,
            data: notification.data
          });

          await notificationRef.update({ sent: true });
        }

        logger.info("Contract completed notifications sent", { 
          contractId: event.params.contractId 
        });

      } catch (error: any) {
        logger.error("Failed to send contract completed notifications", { 
          contractId: event.params.contractId,
          error: error.message 
        });
      }
    }
  })
);

/**
 * Send bulk notifications to user segments
 * POST /home/notifications/broadcast
 */
export const broadcastNotification = withMetrics("broadcastNotification",
  onRequest({ cors: true }, async (req, res) => {
    try {
      if (!req.auth?.token?.admin) {
        res.status(403).json({ error: "Admin access required" });
        return;
      }

      const { 
        title, 
        message, 
        data, 
        targetSegment, 
        filters 
      } = req.body;
      
      if (!title || !message || !targetSegment) {
        res.status(400).json({ error: "Title, message, and target segment are required" });
        return;
      }

      // Get users based on segment
      const targetUsers = await getUsersBySegment(targetSegment, filters);

      let sentCount = 0;
      const batchSize = 500; // FCM batch limit

      for (let i = 0; i < targetUsers.length; i += batchSize) {
        const batch = targetUsers.slice(i, i + batchSize);
        
        try {
          await sendBatchNotifications(batch, {
            title,
            body: message,
            data: data || {}
          });
          
          sentCount += batch.length;
        } catch (error) {
          logger.error("Failed to send batch notifications", { 
            batchStart: i,
            batchSize: batch.length,
            error 
          });
        }
      }

      logger.info("Broadcast notification sent", { 
        targetSegment,
        targetCount: targetUsers.length,
        sentCount 
      });

      res.json({ 
        success: true,
        targetCount: targetUsers.length,
        sentCount 
      });
    } catch (error: any) {
      logger.error("Failed to broadcast notification", { error: error.message });
      res.status(500).json({ error: "Failed to broadcast notification" });
    }
  })
);

// Helper Functions

async function subscribeToTopics(deviceToken: string, userId: string): Promise<void> {
  try {
    // Subscribe to general topics
    await messaging.subscribeToTopic([deviceToken], 'home_services_general');
    
    // Get user profile to determine specific topics
    const proProfile = await db.collection('proProfiles').doc(userId).get();
    
    if (proProfile.exists) {
      // Professional - subscribe to category-specific topics
      const categories = proProfile.data()?.serviceCategories || [];
      for (const category of categories) {
        await messaging.subscribeToTopic([deviceToken], `category_${category}`);
      }
      
      // Subscribe to professional-specific topics
      await messaging.subscribeToTopic([deviceToken], 'professionals');
      
      const serviceArea = proProfile.data()?.serviceArea?.city;
      if (serviceArea) {
        await messaging.subscribeToTopic([deviceToken], `city_${serviceArea.toLowerCase()}`);
      }
    } else {
      // Customer - subscribe to customer-specific topics
      await messaging.subscribeToTopic([deviceToken], 'customers');
    }

    logger.info("User subscribed to FCM topics", { userId });
  } catch (error) {
    logger.error("Failed to subscribe to topics", { userId, error });
  }
}

async function checkNotificationPermission(userId: string, notificationType: string): Promise<boolean> {
  try {
    const prefsDoc = await db.collection('notificationPreferences').doc(userId).get();
    
    if (!prefsDoc.exists) {
      return true; // Default to allowing notifications
    }
    
    const prefs = prefsDoc.data()!;
    return prefs[notificationType] !== false; // Allow unless explicitly disabled
  } catch (error) {
    logger.error("Failed to check notification permission", { userId, notificationType, error });
    return true; // Default to allowing on error
  }
}

async function sendPushNotification(userId: string, payload: {
  title: string;
  body: string;
  data: Record<string, string>;
}): Promise<void> {
  try {
    // Get user's device tokens
    const tokensSnapshot = await db.collection('deviceTokens')
      .where('userId', '==', userId)
      .where('isActive', '==', true)
      .get();

    if (tokensSnapshot.empty) {
      logger.info("No active device tokens found", { userId });
      return;
    }

    const tokens = tokensSnapshot.docs.map(doc => doc.data().deviceToken);

    const message = {
      notification: {
        title: payload.title,
        body: payload.body
      },
      data: payload.data,
      tokens
    };

    const response = await messaging.sendMulticast(message);

    // Handle failed tokens
    if (response.failureCount > 0) {
      const failedTokens: string[] = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          failedTokens.push(tokens[idx]);
          logger.warn("Failed to send to token", { 
            token: tokens[idx].substring(0, 20) + "...",
            error: resp.error?.message 
          });
        }
      });

      // Remove invalid tokens
      await removeInvalidTokens(failedTokens);
    }

    logger.info("Push notification sent", { 
      userId,
      successCount: response.successCount,
      failureCount: response.failureCount 
    });
  } catch (error) {
    logger.error("Failed to send push notification", { userId, error });
  }
}

async function sendBatchNotifications(userIds: string[], payload: {
  title: string;
  body: string;
  data: Record<string, string>;
}): Promise<void> {
  const promises = userIds.map(userId => sendPushNotification(userId, payload));
  await Promise.allSettled(promises);
}

async function getUsersBySegment(segment: string, filters: any = {}): Promise<string[]> {
  let userIds: string[] = [];

  try {
    switch (segment) {
      case 'all_users':
        // Get all users from device tokens (active users)
        const tokensSnapshot = await db.collection('deviceTokens')
          .where('isActive', '==', true)
          .get();
        userIds = [...new Set(tokensSnapshot.docs.map(doc => doc.data().userId))];
        break;

      case 'professionals':
        const prosSnapshot = await db.collection('proProfiles')
          .where('isActive', '==', true)
          .get();
        userIds = prosSnapshot.docs.map(doc => doc.data().userId);
        break;

      case 'customers':
        // Get users who have created RFQs
        const rfqsSnapshot = await db.collection('rfqs')
          .orderBy('createdAt', 'desc')
          .limit(1000)
          .get();
        userIds = [...new Set(rfqsSnapshot.docs.map(doc => doc.data().customerId))];
        break;

      case 'city':
        if (filters.city) {
          const cityProsSnapshot = await db.collection('proProfiles')
            .where('serviceArea.city', '==', filters.city)
            .where('isActive', '==', true)
            .get();
          userIds = cityProsSnapshot.docs.map(doc => doc.data().userId);
        }
        break;

      case 'category':
        if (filters.category) {
          const categoryProsSnapshot = await db.collection('proProfiles')
            .where('serviceCategories', 'array-contains', filters.category)
            .where('isActive', '==', true)
            .get();
          userIds = categoryProsSnapshot.docs.map(doc => doc.data().userId);
        }
        break;

      default:
        logger.warn("Unknown segment type", { segment });
    }
  } catch (error) {
    logger.error("Failed to get users by segment", { segment, error });
  }

  return userIds;
}

async function removeInvalidTokens(failedTokens: string[]): Promise<void> {
  const batch = db.batch();
  
  for (const token of failedTokens) {
    const tokenRef = db.collection('deviceTokens').doc(token);
    batch.update(tokenRef, { isActive: false });
  }
  
  await batch.commit();
  logger.info("Removed invalid device tokens", { count: failedTokens.length });
}