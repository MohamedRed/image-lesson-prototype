import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { FirestoreEvent } from "firebase-functions/v2/firestore";
import { withMetrics } from "../shared/metrics";

// Ensure Firebase app initialized
try { admin.app(); } catch { admin.initializeApp(); }

// Configurable retention period - defaults to 30 days as per GDPR requirements
const RETENTION_DAYS = parseInt(process.env?.RETENTION_DAYS || '30');

export async function reconcileLegCompletion(after: any, db: admin.firestore.Firestore = admin.firestore()) {
  const driverId = after.driverId;
  const pickupZoneId = after.pickupZoneId;

  await db.runTransaction(async (tx: admin.firestore.Transaction) => {
    if (driverId) {
      const driverRef = db.doc(`drivers/${driverId}`);
      const dSnap = await tx.get(driverRef);
      if (dSnap.exists) {
        tx.update(driverRef, {
          activePickups: admin.firestore.FieldValue.increment(-1),
        });
      }
    }

    if (pickupZoneId) {
      const zoneRef = db.doc(`pickupZones/${pickupZoneId}`);
      const zSnap = await tx.get(zoneRef);
      if (zSnap.exists) {
        tx.update(zoneRef, {
          activePickups: admin.firestore.FieldValue.increment(-1),
        });
      }
    }
  });
}

/**
 * S6 – Resource Sweeper (edge-triggered)
 * Fires when rideLegs/{rideId}/{legId}.status transitions to "completed".
 * Frees driver seat/cargo ledgers and decrements pickup counts.
 */
export const resourceSweeper = withMetrics("resourceSweeper", onDocumentWritten(
  "rideLegs/{rideId}/{legId}",
  async (event: FirestoreEvent<any, { rideId: string; legId: string }>) => {
    const before = event.data?.before.data() as any | undefined;
    const after = event.data?.after.data() as any | undefined;
    if (!after) return;

    if (before?.status === "completed" || after.status !== "completed") {
      // Not a transition to completed
      return;
    }

    await reconcileLegCompletion(after);

    logger.info("ResourceSweeper freed resources", { rideId: event.params.rideId, legId: event.params.legId });
  }
));

export async function performHourlySweep(db: admin.firestore.Firestore = admin.firestore()) {
  const THRESHOLD_HOURS = 6;
  const cutoff = admin.firestore.Timestamp.fromDate(new Date(Date.now() - THRESHOLD_HOURS * 3600 * 1000));

  const snap = await db
    .collectionGroup("rideLegs")
    .where("status", "in", ["proposed", "enroute", "accepted"])
    .where("updatedAt", "<", cutoff)
    .get();

  for (const doc of snap.docs) {
    await doc.ref.update({ status: "completed", swept: true, sweptAt: admin.firestore.FieldValue.serverTimestamp() });
  }

  logger.info("Hourly resource sweep completed", { swept: snap.size });
}

/**
 * S6b – Hourly fallback sweep to catch missed completions.
 * Looks for rideLegs where status in [proposed, enroute] older than 6h and marks completed.
 */
export const hourlySweep = withMetrics("hourlySweep", onSchedule("0 * * * *", async () => {
  const db = admin.firestore();
  await performHourlySweep(db);
}));

export const hourlySweeper = onSchedule('0 * * * *', async (event: any) => {
  const db = admin.firestore();
  logger.info(`Starting hourly sweeper with ${RETENTION_DAYS} day retention period`);
  
  const cutoffTime = new Date();
  cutoffTime.setDate(cutoffTime.getDate() - RETENTION_DAYS);
  const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffTime);
  
  const batch = db.batch();
  let deletedCount = 0;

  try {
    // Clean up expired ride requests (GDPR compliance)
    const expiredRideRequests = await db.collection('rideRequests')
      .where('createdAt', '<', cutoffTimestamp)
      .where('state', 'in', ['completed', 'cancelled'])
      .limit(500)
      .get();

    expiredRideRequests.forEach((doc: any) => {
      batch.delete(doc.ref);
      deletedCount++;
    });

    // Clean up completed ride legs
    const expiredRideLegs = await db.collectionGroup('rideLegs')
      .where('completedAt', '<', cutoffTimestamp)
      .where('status', '==', 'completed')
      .limit(500)
      .get();

    expiredRideLegs.forEach((doc: any) => {
      batch.delete(doc.ref);
      deletedCount++;
    });

    // Clean up old driver location history (privacy)
    const expiredDriverHistory = await db.collection('driverLocationHistory')
      .where('timestamp', '<', cutoffTimestamp)
      .limit(500)
      .get();

    expiredDriverHistory.forEach((doc: any) => {
      batch.delete(doc.ref);
      deletedCount++;
    });

    // Release stuck resource reservations
    const stuckReservations = await db.collection('resourceReservations')
      .where('createdAt', '<', admin.firestore.Timestamp.fromDate(new Date(Date.now() - 30 * 60 * 1000))) // 30 minutes ago
      .where('status', '==', 'reserved')
      .limit(100)
      .get();

    stuckReservations.forEach((doc: any) => {
      batch.update(doc.ref, { 
        status: 'expired',
        expiredAt: admin.firestore.Timestamp.now()
      });
      deletedCount++;
    });

    await batch.commit();
    
    logger.info(`Hourly sweeper completed: ${deletedCount} records processed`);
    
    // Record metrics for monitoring
    await db.collection('systemMetrics').add({
      type: 'sweeper_run',
      recordsProcessed: deletedCount,
      retentionDays: RETENTION_DAYS,
      timestamp: admin.firestore.Timestamp.now()
    });

  } catch (error) {
    logger.error('Hourly sweeper failed:', error);
    throw error;
  }
}); 