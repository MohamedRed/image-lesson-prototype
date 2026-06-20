import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { withMetrics } from "../shared/metrics";

// Initialise Firebase app if it hasn't already been initialised in another module.
try {
  admin.app();
} catch {
  admin.initializeApp();
}

/**
 * S4 – Congestion Cron (runs every minute)
 *
 * 1. Reconciles driver.activePickups with the number of live rideRequests in
 *    states [proposed, priced, accepted, riderPickupSoon]. This prevents the
 *    ledger from drifting if a sweeper update was missed.
 * 2. Updates pickupZones.activePickups in the same fashion.
 * 3. If a pickupZone is over capacity (activePickups > capacityCars) it writes
 *    a `curbLoadFactor` field the planner can soft-penalise (value >1).
 */
export async function reconcileCongestion(db: admin.firestore.Firestore = admin.firestore()) {
  // -------------------------------
  // Step 1 – reconcile driver counts
  // -------------------------------
  const driversSnap = await db.collection("drivers").get();
  for (const driverDoc of driversSnap.docs) {
    const driverId = driverDoc.id;
    const liveReqSnap = await db
      .collection("rideRequests")
      .where("assignedDriverId", "==", driverId)
      .where("state", "in", ["proposed", "priced", "accepted", "riderPickupSoon"])
      .get();

    const actual = liveReqSnap.size;
    const recorded = (driverDoc.data() as any).activePickups ?? 0;

    if (actual !== recorded) {
      await driverDoc.ref.update({ activePickups: actual });
      logger.info("Driver activePickups reconciled", { driverId, recorded, actual });
    }
  }

  // -------------------------------
  // Step 2 – reconcile pickup zone counts + load factor
  // -------------------------------
  const zonesSnap = await db.collection("pickupZones").get();
  for (const zoneDoc of zonesSnap.docs) {
    const zoneId = zoneDoc.id;
    const zoneData = zoneDoc.data() as any;
    const capacity = zoneData.capacityCars ?? 0;

    const legsSnap = await db
      .collectionGroup("rideLegs")
      .where("pickupZoneId", "==", zoneId)
      .where("status", "!=", "completed")
      .get();

    const actual = legsSnap.size;
    const recorded = zoneData.activePickups ?? 0;

    const updates: Record<string, any> = { activePickups: actual };

    if (capacity > 0 && actual > capacity) {
      updates.curbLoadFactor = actual / capacity;
      const shrinkBy = Math.min(100, 20*(actual-capacity));
      updates.driveIsoShrinkMeters = shrinkBy; // planner can shrink driving iso
    } else {
      if (zoneData.curbLoadFactor) {
        updates.curbLoadFactor = admin.firestore.FieldValue.delete();
      }
      if (zoneData.driveIsoShrinkMeters) {
        updates.driveIsoShrinkMeters = admin.firestore.FieldValue.delete();
      }
    }

    if (actual !== recorded || updates.curbLoadFactor !== undefined) {
      await zoneDoc.ref.update(updates);
      logger.info("Pickup zone reconciled", { zoneId, recorded, actual, capacity });
    }
  }
}

export const congestionCron = withMetrics("congestionCron", onSchedule("*/1 * * * *", async () => {
  const db = admin.firestore();
  await reconcileCongestion(db);
  logger.info("Congestion cron run completed");
})); 