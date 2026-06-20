import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { withMetrics } from "../shared/metrics";

try { admin.app(); } catch { admin.initializeApp(); }

const db = admin.firestore();

/**
 * Expire open RFQs that have passed their expiration date
 * Runs every hour
 */
export const expireOpenRfqs = withMetrics("expireOpenRfqs",
  onSchedule("0 * * * *", async () => {
    try {
      const now = admin.firestore.Timestamp.now();
      
      // Find expired RFQs
      const expiredRfqsSnapshot = await db.collection('rfqs')
        .where('status', '==', 'open')
        .where('expiresAt', '<=', now)
        .get();

      if (expiredRfqsSnapshot.empty) {
        logger.info("No expired RFQs found");
        return;
      }

      const batch = db.batch();
      const expiredRfqIds: string[] = [];

      expiredRfqsSnapshot.docs.forEach(doc => {
        expiredRfqIds.push(doc.id);
        batch.update(doc.ref, {
          status: 'expired',
          expiredAt: now,
          updatedAt: now
        });
      });

      await batch.commit();

      // Also expire all active bids for these RFQs
      if (expiredRfqIds.length > 0) {
        await expireBidsForRfqs(expiredRfqIds);
      }

      logger.info("Expired open RFQs", { 
        count: expiredRfqIds.length, 
        rfqIds: expiredRfqIds 
      });

    } catch (error: any) {
      logger.error("Failed to expire open RFQs", { error: error.message });
      throw error;
    }
  })
);

/**
 * Expire bids that have passed their expiration date
 * Runs every 30 minutes
 */
export const expireBids = withMetrics("expireBids",
  onSchedule("*/30 * * * *", async () => {
    try {
      const now = admin.firestore.Timestamp.now();
      
      // Find expired bids
      const expiredBidsSnapshot = await db.collection('bids')
        .where('status', 'in', ['submitted', 'negotiating'])
        .where('expiresAt', '<=', now)
        .get();

      if (expiredBidsSnapshot.empty) {
        logger.info("No expired bids found");
        return;
      }

      const batch = db.batch();
      const expiredBidIds: string[] = [];

      expiredBidsSnapshot.docs.forEach(doc => {
        expiredBidIds.push(doc.id);
        batch.update(doc.ref, {
          status: 'expired',
          expiredAt: now,
          updatedAt: now
        });
      });

      await batch.commit();

      logger.info("Expired bids", { 
        count: expiredBidIds.length, 
        bidIds: expiredBidIds 
      });

    } catch (error: any) {
      logger.error("Failed to expire bids", { error: error.message });
      throw error;
    }
  })
);

/**
 * Auto-accept best offers for RFQs that have enabled auto-accept
 * Runs every 2 hours
 */
export const autoAcceptBestOffer = withMetrics("autoAcceptBestOffer",
  onSchedule("0 */2 * * *", async () => {
    try {
      // Find RFQs with auto-accept enabled that have been open for at least 24 hours
      const cutoffTime = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() - 24 * 60 * 60 * 1000)
      );

      const rfqsSnapshot = await db.collection('rfqs')
        .where('status', '==', 'open')
        .where('autoAccept.enabled', '==', true)
        .where('createdAt', '<=', cutoffTime)
        .get();

      if (rfqsSnapshot.empty) {
        logger.info("No RFQs eligible for auto-accept found");
        return;
      }

      const autoAcceptedCount = await Promise.all(
        rfqsSnapshot.docs.map(async (rfqDoc) => {
          try {
            const rfqData = rfqDoc.data();
            const autoAcceptThreshold = rfqData.autoAccept?.thresholdMAD;
            
            if (!autoAcceptThreshold) return false;

            // Find bids that meet the auto-accept criteria
            const eligibleBidsSnapshot = await db.collection('bids')
              .where('rfqId', '==', rfqDoc.id)
              .where('status', '==', 'submitted')
              .where('priceMAD', '<=', autoAcceptThreshold)
              .orderBy('priceMAD', 'asc')
              .orderBy('createdAt', 'asc') // Earliest bid wins if tie
              .limit(1)
              .get();

            if (eligibleBidsSnapshot.empty) return false;

            const winningBid = eligibleBidsSnapshot.docs[0];
            const bidData = winningBid.data();

            // Auto-accept this bid
            await acceptBidAutomatically(rfqDoc.id, winningBid.id, bidData, rfqData);
            
            logger.info("Auto-accepted bid", { 
              rfqId: rfqDoc.id, 
              bidId: winningBid.id, 
              amount: bidData.priceMAD,
              threshold: autoAcceptThreshold
            });

            return true;
          } catch (error) {
            logger.error("Failed to auto-accept bid", { 
              rfqId: rfqDoc.id, 
              error: error.message 
            });
            return false;
          }
        })
      );

      const successCount = autoAcceptedCount.filter(Boolean).length;
      logger.info("Auto-accept process completed", { 
        processed: rfqsSnapshot.size, 
        accepted: successCount 
      });

    } catch (error: any) {
      logger.error("Failed to auto-accept best offers", { error: error.message });
      throw error;
    }
  })
);

/**
 * Retry failed payouts
 * Runs every 4 hours
 */
export const retryPayouts = withMetrics("retryPayouts",
  onSchedule("0 */4 * * *", async () => {
    try {
      // Find escrows with failed payouts that should be retried
      const failedPayoutsSnapshot = await db.collection('escrows')
        .where('status', '==', 'payout_failed')
        .where('retryCount', '<', 3) // Max 3 retries
        .get();

      if (failedPayoutsSnapshot.empty) {
        logger.info("No failed payouts to retry");
        return;
      }

      const retryResults = await Promise.all(
        failedPayoutsSnapshot.docs.map(async (escrowDoc) => {
          try {
            const escrowData = escrowDoc.data();
            const retryCount = (escrowData.retryCount || 0) + 1;

            // Attempt to retry the payout
            await retryEscrowPayout(escrowDoc.id, escrowData);

            await escrowDoc.ref.update({
              retryCount,
              lastRetryAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });

            logger.info("Payout retry successful", { 
              escrowId: escrowDoc.id, 
              retryCount 
            });

            return { success: true, escrowId: escrowDoc.id };
          } catch (error) {
            logger.error("Payout retry failed", { 
              escrowId: escrowDoc.id, 
              error: error.message 
            });
            return { success: false, escrowId: escrowDoc.id };
          }
        })
      );

      const successCount = retryResults.filter(r => r.success).length;
      logger.info("Payout retry process completed", { 
        processed: failedPayoutsSnapshot.size, 
        successful: successCount 
      });

    } catch (error: any) {
      logger.error("Failed to retry payouts", { error: error.message });
      throw error;
    }
  })
);

/**
 * Clean up old notifications
 * Runs daily at 2 AM
 */
export const cleanupOldNotifications = withMetrics("cleanupOldNotifications",
  onSchedule("0 2 * * *", async () => {
    try {
      // Delete notifications older than 30 days
      const cutoffDate = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
      );

      const oldNotificationsSnapshot = await db.collection('proNotifications')
        .where('sentAt', '<', cutoffDate)
        .limit(500) // Process in batches
        .get();

      if (oldNotificationsSnapshot.empty) {
        logger.info("No old notifications to clean up");
        return;
      }

      const batch = db.batch();
      oldNotificationsSnapshot.docs.forEach(doc => {
        batch.delete(doc.ref);
      });

      await batch.commit();

      logger.info("Cleaned up old notifications", { 
        count: oldNotificationsSnapshot.size 
      });

    } catch (error: any) {
      logger.error("Failed to clean up old notifications", { error: error.message });
      throw error;
    }
  })
);

/**
 * Update professional availability status
 * Runs every 15 minutes during business hours
 */
export const updateProfessionalAvailability = withMetrics("updateProfessionalAvailability",
  onSchedule("*/15 6-22 * * *", async () => {
    try {
      const now = new Date();
      const currentDay = now.toLocaleDateString('en-US', { weekday: 'lowercase' });
      const currentHour = now.getHours();

      // Get all active professional profiles
      const prosSnapshot = await db.collection('proProfiles')
        .where('isActive', '==', true)
        .get();

      const batch = db.batch();
      let updatedCount = 0;

      prosSnapshot.docs.forEach(doc => {
        const proData = doc.data();
        const availability = proData.availability;
        
        if (!availability?.workingHours) return;

        const todayHours = availability.workingHours[currentDay];
        let isCurrentlyAvailable = false;

        if (todayHours) {
          const startHour = parseInt(todayHours.start?.split(':')[0] || '0');
          const endHour = parseInt(todayHours.end?.split(':')[0] || '24');
          isCurrentlyAvailable = currentHour >= startHour && currentHour < endHour;
        }

        // Update if status has changed
        if (proData.isCurrentlyAvailable !== isCurrentlyAvailable) {
          batch.update(doc.ref, {
            isCurrentlyAvailable,
            lastAvailabilityUpdate: admin.firestore.FieldValue.serverTimestamp()
          });
          updatedCount++;
        }
      });

      if (updatedCount > 0) {
        await batch.commit();
        logger.info("Updated professional availability status", { 
          updatedCount, 
          totalPros: prosSnapshot.size 
        });
      }

    } catch (error: any) {
      logger.error("Failed to update professional availability", { error: error.message });
      throw error;
    }
  })
);

// Helper Functions

async function expireBidsForRfqs(rfqIds: string[]) {
  const now = admin.firestore.Timestamp.now();
  
  for (const rfqId of rfqIds) {
    const bidsSnapshot = await db.collection('bids')
      .where('rfqId', '==', rfqId)
      .where('status', 'in', ['submitted', 'negotiating'])
      .get();

    if (!bidsSnapshot.empty) {
      const batch = db.batch();
      bidsSnapshot.docs.forEach(doc => {
        batch.update(doc.ref, {
          status: 'expired',
          expiredAt: now,
          updatedAt: now
        });
      });
      await batch.commit();
    }
  }
}

async function acceptBidAutomatically(rfqId: string, bidId: string, bidData: any, rfqData: any) {
  // Create contract
  const contractData = {
    rfqId,
    bidId,
    customerId: rfqData.customerId,
    proId: bidData.proId,
    agreedScope: rfqData.scope,
    priceMAD: bidData.priceMAD,
    milestones: bidData.milestones || [],
    status: 'pending_payment',
    autoAccepted: true,
    depositAmount: Math.round(bidData.priceMAD * 0.2), // 20% deposit
    depositPercent: 20,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    startAt: null,
    completedAt: null
  };

  await db.runTransaction(async (transaction) => {
    const contractRef = db.collection('contracts').doc();
    transaction.set(contractRef, contractData);

    // Update bid status
    transaction.update(db.collection('bids').doc(bidId), {
      status: 'accepted',
      acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      autoAccepted: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Update RFQ status
    transaction.update(db.collection('rfqs').doc(rfqId), {
      status: 'awarded',
      awardedBidId: bidId,
      autoAccepted: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Reject other bids
    const otherBidsSnapshot = await db.collection('bids')
      .where('rfqId', '==', rfqId)
      .where('status', 'in', ['submitted', 'negotiating'])
      .get();

    otherBidsSnapshot.docs.forEach(doc => {
      if (doc.id !== bidId) {
        transaction.update(doc.ref, {
          status: 'rejected',
          rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
          rejectionReason: 'auto_accepted_other_bid',
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }
    });
  });
}

async function retryEscrowPayout(escrowId: string, escrowData: any) {
  // In production, this would integrate with the actual payment processor
  // For now, simulate a retry attempt
  
  const success = Math.random() > 0.3; // 70% success rate for simulation
  
  if (success) {
    await db.collection('escrows').doc(escrowId).update({
      status: 'completed',
      payoutRetrySuccessful: true,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  } else {
    throw new Error('Payout retry failed - payment processor error');
  }
}