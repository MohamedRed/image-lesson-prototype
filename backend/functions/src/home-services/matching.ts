import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { withMetrics } from "../shared/metrics";

try { admin.app(); } catch { admin.initializeApp(); }

const db = admin.firestore();

/**
 * Automatic matching when RFQ is created or updated to 'open' status
 * Matches pros based on skills, service area, and availability
 */
export const matchProfessionalsToRFQ = withMetrics("matchProfessionalsToRFQ",
  onDocumentCreated("rfqs/{rfqId}", async (event) => {
    const rfqData = event.data?.data();
    if (!rfqData || rfqData.status !== 'open') return;

    const rfqId = event.params.rfqId;
    await performMatching(rfqId, rfqData);
  })
);

/**
 * Re-match when RFQ status changes to 'open'
 */
export const rematchOnRFQUpdate = withMetrics("rematchOnRFQUpdate",
  onDocumentUpdated("rfqs/{rfqId}", async (event) => {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();
    
    if (!afterData || beforeData?.status === afterData.status) return;
    
    // Only match when status changes to 'open'
    if (afterData.status === 'open') {
      const rfqId = event.params.rfqId;
      await performMatching(rfqId, afterData);
    }
  })
);

async function performMatching(rfqId: string, rfqData: any) {
  try {
    const categoryId = rfqData.categoryId;
    const location = rfqData.location;
    
    if (!categoryId || !location) {
      logger.warn("RFQ missing required matching data", { rfqId, categoryId, location });
      return;
    }

    // Find professionals who service this category and location
    const proQuery = db.collection('proProfiles')
      .where('serviceCategories', 'array-contains', categoryId)
      .where('isActive', '==', true);

    const proSnapshot = await proQuery.get();
    const matchedPros: string[] = [];

    for (const proDoc of proSnapshot.docs) {
      const proData = proDoc.data();
      
      // Check service area
      if (!isInServiceArea(location, proData.serviceArea)) {
        continue;
      }

      // Check availability (basic check - could be enhanced)
      if (!isAvailable(proData.availability)) {
        continue;
      }

      // Check if pro hasn't been spammed recently
      if (await hasRecentCooldown(proDoc.id, categoryId)) {
        continue;
      }

      matchedPros.push(proDoc.id);
      
      // Limit to max 6 pros per RFQ as specified in plan
      if (matchedPros.length >= 6) {
        break;
      }
    }

    // Send notifications to matched professionals
    await sendNotificationsToMatchedPros(rfqId, matchedPros, rfqData);

    // Update RFQ with match metadata
    await db.collection('rfqs').doc(rfqId).update({
      matchedPros,
      matchedAt: admin.firestore.FieldValue.serverTimestamp(),
      notificationsSent: matchedPros.length
    });

    logger.info("RFQ matching completed", { 
      rfqId, 
      categoryId, 
      location: location.city,
      matchedCount: matchedPros.length 
    });

  } catch (error: any) {
    logger.error("Failed to perform RFQ matching", { 
      rfqId, 
      error: error.message 
    });
  }
}

function isInServiceArea(rfqLocation: any, serviceArea: any): boolean {
  if (!serviceArea) return false;

  // Check city match
  if (serviceArea.city && rfqLocation.city !== serviceArea.city) {
    return false;
  }

  // Check regions if specified
  if (serviceArea.regions && serviceArea.regions.length > 0) {
    if (!serviceArea.regions.includes(rfqLocation.region)) {
      return false;
    }
  }

  // Check radius if coordinates are available
  if (serviceArea.maxRadiusKm && rfqLocation.coordinates && serviceArea.centerCoordinates) {
    const distance = calculateDistance(
      rfqLocation.coordinates.latitude,
      rfqLocation.coordinates.longitude,
      serviceArea.centerCoordinates.latitude,
      serviceArea.centerCoordinates.longitude
    );
    
    if (distance > serviceArea.maxRadiusKm) {
      return false;
    }
  }

  return true;
}

function isAvailable(availability: any): boolean {
  if (!availability) return false;
  
  // Basic availability check - can be enhanced with actual scheduling
  const now = new Date();
  const currentDay = now.toLocaleDateString('en-US', { weekday: 'lowercase' });
  const currentHour = now.getHours();

  const todayHours = availability.workingHours?.[currentDay];
  if (!todayHours) return false;

  const startHour = parseInt(todayHours.start?.split(':')[0] || '0');
  const endHour = parseInt(todayHours.end?.split(':')[0] || '24');

  // Check if currently within working hours (basic approximation)
  return currentHour >= startHour && currentHour < endHour;
}

async function hasRecentCooldown(proId: string, categoryId: string): boolean {
  const cooldownHours = 24; // 24 hour cooldown to prevent spam
  const cooldownThreshold = new Date(Date.now() - cooldownHours * 60 * 60 * 1000);

  const recentNotifications = await db.collection('proNotifications')
    .where('proId', '==', proId)
    .where('categoryId', '==', categoryId)
    .where('sentAt', '>', admin.firestore.Timestamp.fromDate(cooldownThreshold))
    .limit(1)
    .get();

  return !recentNotifications.empty;
}

async function sendNotificationsToMatchedPros(rfqId: string, proIds: string[], rfqData: any) {
  const notifications = proIds.map(proId => ({
    proId,
    rfqId,
    categoryId: rfqData.categoryId,
    type: 'new_rfq',
    title: 'New Service Request',
    titleAr: 'طلب خدمة جديد',
    titleFr: 'Nouvelle demande de service',
    message: `New ${rfqData.scope?.title || 'service request'} in ${rfqData.location?.city}`,
    messageAr: `طلب جديد ${rfqData.scope?.titleAr || 'خدمة'} في ${rfqData.location?.city}`,
    messageFr: `Nouvelle demande ${rfqData.scope?.titleFr || 'de service'} à ${rfqData.location?.city}`,
    data: {
      rfqId,
      categoryId: rfqData.categoryId,
      city: rfqData.location?.city,
      budgetMin: rfqData.budgetRange?.minMAD?.toString(),
      budgetMax: rfqData.budgetRange?.maxMAD?.toString()
    },
    sentAt: admin.firestore.FieldValue.serverTimestamp()
  }));

  // Batch write notifications
  const batch = db.batch();
  notifications.forEach(notification => {
    const notificationRef = db.collection('proNotifications').doc();
    batch.set(notificationRef, notification);
  });

  await batch.commit();

  // In production, send FCM notifications here
  // await sendFCMToDevices(proIds, notificationData);

  logger.info("Notifications sent to matched professionals", { 
    rfqId, 
    proCount: proIds.length 
  });
}

function calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371; // Radius of the Earth in kilometers
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = 
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}