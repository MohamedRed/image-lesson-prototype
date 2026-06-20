import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import Stripe from "stripe";
import { withMetrics } from "../shared/metrics";
import { getSecret, secretPath, SECRET_IDS } from "../shared/secretManager";
import { StripeAccountService, StripeTransferService } from "../services/payments/stripeService";

try { admin.app(); } catch { admin.initializeApp(); }

// Stripe client now handled by service layer

const DRIVER_SHARE = Number(process.env.DRIVER_SHARE_PERCENT || 80) / 100; // 80%

export interface PayoutResult { driverId: string; amountUsd: number; transferId: string; }

export async function performPayoutRun(db = admin.firestore(), stripeClient?: Stripe): Promise<PayoutResult[]> {
  const cfgRef = db.collection("_internal").doc("payoutScheduler");
  const cfgSnap = await cfgRef.get();
  const lastRun = cfgSnap.exists ? (cfgSnap.data()?.lastRun?.toDate() as Date) : new Date(0);

  // collect completed rideRequests since lastRun
  const snap = await db
    .collection("rideRequests")
    .where("state", "==", "completed")
    .where("completedAt", ">", admin.firestore.Timestamp.fromDate(lastRun))
    .get();

  if (snap.empty) {
    logger.info("No completed rides to payout");
    await cfgRef.set({ lastRun: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    return [];
  }

  // aggregate amounts
  const totals: Record<string, number> = {};
  snap.forEach((doc) => {
    const d: any = doc.data();
    const driverId = d.assignedDriverId;
    if (!driverId) return;
    const total = d.fareBreakdown?.total ?? 0;
    totals[driverId] = (totals[driverId] || 0) + total;
  });

  const results: PayoutResult[] = [];
  for (const [driverId, rideTotal] of Object.entries(totals)) {
    // driver share
    const payoutAmount = rideTotal * DRIVER_SHARE;
    if (payoutAmount <= 0) continue;

    // fetch driver stripe account
    const driverSnap = await db.doc(`drivers/${driverId}`).get();
    if (!driverSnap.exists) continue;
    const stripeAccountId = driverSnap.data()?.stripeAccountId;
    if (!stripeAccountId) continue;

    // Create driver payout using service layer
    const payoutResult = await StripeTransferService.createDriverPayout({
      driverId,
      stripeAccountId,
      amountUsd: payoutAmount,
      validateAccount: true, // Check account requirements
    });

    if (!payoutResult.success) {
      logger.warn("Driver payout failed", { 
        driverId, 
        error: payoutResult.error 
      });
      continue;
    }

    // Record successful payout
    await db.collection("payouts").add({
      driverId,
      amountUsd: payoutAmount,
      currency: "usd",
      transferId: payoutResult.transfer!.id,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    results.push({ 
      driverId, 
      amountUsd: payoutAmount, 
      transferId: payoutResult.transfer!.id 
    });
  }

  await cfgRef.set({ lastRun: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  logger.info("Payout run completed", { payouts: results.length });
  return results;
}

export const payoutSchedulerDaily = withMetrics("payoutSchedulerDaily", onSchedule("0 4 * * *", async () => {
  await performPayoutRun();
})); 