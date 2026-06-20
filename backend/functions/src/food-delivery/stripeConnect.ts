import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import { StripeAccountService, getStripeClient } from "../services/payments/stripeService";
import { logEvent } from "../shared/analytics";
import { withAudit } from "../shared/audit";

function getReturnUrls(): { returnUrl: string; refreshUrl: string } {
  const base = process.env.APP_BASE_URL || "https://example.com";
  return {
    returnUrl: `${base}/onboarding/return`,
    refreshUrl: `${base}/onboarding/refresh`,
  };
}

export const getMerchantOnboardingLink = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentication required");
  const { restaurantId } = request.data || {};
  if (!restaurantId) throw new HttpsError("invalid-argument", "restaurantId is required");

  const restRef = admin.firestore().doc(`restaurants/${restaurantId}`);
  const restSnap = await restRef.get();
  if (!restSnap.exists) throw new HttpsError("not-found", "Restaurant not found");
  const restaurant = restSnap.data() as any;
  if (restaurant.ownerId && restaurant.ownerId !== uid) {
    throw new HttpsError("permission-denied", "Not owner");
  }

  try {
    // Ensure Stripe account exists
    let accountId: string | undefined = restaurant?.payouts?.stripeAccountId;
    if (!accountId) {
      const acct = await StripeAccountService.createAccount({ type: "express", country: "MA", email: restaurant?.email || undefined, metadata: { restaurantId } });
      accountId = acct.id;
      await restRef.set({ payouts: { ...(restaurant.payouts || {}), stripeAccountId: accountId } }, { merge: true });
    }

    const { returnUrl, refreshUrl } = getReturnUrls();
    const link = await StripeAccountService.createAccountLink(accountId!, { returnUrl, refreshUrl, type: "account_onboarding" });

    await withAudit(uid, "getMerchantOnboardingLink", restaurantId, async () => Promise.resolve(), "merchant", { accountId });
    try { await logEvent(uid, "onboarding_started", { role: "merchant", restaurantId, accountId }); } catch {}
    return { success: true, url: link.url, accountId };
  } catch (e: any) {
    logger.error("Failed to create merchant onboarding link", { error: e.message, restaurantId });
    throw new HttpsError("internal", "Failed to create onboarding link");
  }
});

export const getCourierOnboardingLink = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentication required");

  const courierRef = admin.firestore().doc(`couriers/${uid}`);
  const courierSnap = await courierRef.get();
  if (!courierSnap.exists) throw new HttpsError("not-found", "Courier not found");
  const courier = courierSnap.data() as any;

  try {
    // Ensure Stripe account exists
    let accountId: string | undefined = courier?.payouts?.stripeAccountId;
    if (!accountId) {
      const acct = await StripeAccountService.createAccount({ type: "express", country: "MA", email: courier?.email || undefined, metadata: { courierId: uid } });
      accountId = acct.id;
      await courierRef.set({ payouts: { ...(courier.payouts || {}), stripeAccountId: accountId } }, { merge: true });
    }

    const { returnUrl, refreshUrl } = getReturnUrls();
    const link = await StripeAccountService.createAccountLink(accountId!, { returnUrl, refreshUrl, type: "account_onboarding" });

    await withAudit(uid, "getCourierOnboardingLink", uid, async () => Promise.resolve(), "courier", { accountId });
    try { await logEvent(uid, "onboarding_started", { role: "courier", accountId }); } catch {}
    return { success: true, url: link.url, accountId };
  } catch (e: any) {
    logger.error("Failed to create courier onboarding link", { error: e.message, courierId: uid });
    throw new HttpsError("internal", "Failed to create onboarding link");
  }
});

export const refreshConnectStatus = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentication required");
  const { role, restaurantId } = request.data || {} as { role: "merchant" | "courier"; restaurantId?: string };
  if (!role) throw new HttpsError("invalid-argument", "role is required");

  let accountId: string | undefined;
  let ref: FirebaseFirestore.DocumentReference;

  if (role === "merchant") {
    if (!restaurantId) throw new HttpsError("invalid-argument", "restaurantId required for merchant");
    ref = admin.firestore().doc(`restaurants/${restaurantId}`);
    const snap = await ref.get();
    if (!snap.exists) throw new HttpsError("not-found", "Restaurant not found");
    const data = snap.data() as any;
    if (data.ownerId && data.ownerId !== uid) throw new HttpsError("permission-denied", "Not owner");
    accountId = data?.payouts?.stripeAccountId;
  } else {
    ref = admin.firestore().doc(`couriers/${uid}`);
    const snap = await ref.get();
    if (!snap.exists) throw new HttpsError("not-found", "Courier not found");
    const data = snap.data() as any;
    accountId = data?.payouts?.stripeAccountId;
  }

  if (!accountId) throw new HttpsError("failed-precondition", "No Stripe account");

  try {
    const reqs = await StripeAccountService.checkAccountRequirements(accountId);
    let status: string = reqs.isPayoutEnabled ? "approved" : (reqs.detailsSubmitted ? "pending" : "incomplete");
    await ref.set({ kyc: { ...(role === "merchant" ? (await ref.get()).data()?.kyc || {} : (await ref.get()).data()?.kyc || {}), status, reviewedAt: admin.firestore.FieldValue.serverTimestamp() } }, { merge: true });
    await withAudit(uid, "refreshConnectStatus", ref.path, async () => Promise.resolve(), role, { accountId, status });
    if (status === "approved") {
      try { await logEvent(uid, "onboarding_completed", { role, accountId }); } catch {}
    }
    return { success: true, status, accountId, requirementsDue: reqs.requirementsDue };
  } catch (e: any) {
    logger.error("Failed to refresh connect status", { error: e.message, accountId });
    throw new HttpsError("internal", "Failed to refresh connect status");
  }
});

// Basic settlements summary for a connected account
export const getSettlementSummary = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentication required");
  const { role, restaurantId, accountId: explicitAccountId, timeframeDays = 7 } = request.data || {};

  let accountId: string | undefined = explicitAccountId;
  try {
    if (!accountId) {
      if (role === "merchant") {
        if (!restaurantId) throw new HttpsError("invalid-argument", "restaurantId required for merchant");
        const rest = await admin.firestore().doc(`restaurants/${restaurantId}`).get();
        if (!rest.exists) throw new HttpsError("not-found", "Restaurant not found");
        const data = rest.data() as any;
        if (data.ownerId && data.ownerId !== uid) throw new HttpsError("permission-denied", "Not owner");
        accountId = data?.payouts?.stripeAccountId;
      } else if (role === "courier") {
        const c = await admin.firestore().doc(`couriers/${uid}`).get();
        if (!c.exists) throw new HttpsError("not-found", "Courier not found");
        accountId = (c.data() as any)?.payouts?.stripeAccountId;
      }
    }
    if (!accountId) throw new HttpsError("failed-precondition", "No Stripe account");

    const stripe = await getStripeClient();
    // List recent payouts for the connected account
    const payouts = await stripe.payouts.list({ limit: 10 }, { stripeAccount: accountId });
    // Compute basic totals within timeframe
    const since = Date.now() - Number(timeframeDays) * 24 * 60 * 60 * 1000;
    const recent = payouts.data.filter(p => (p.created || 0) * 1000 >= since);
    const totalAmount = recent.reduce((sum, p) => sum + (p.amount || 0), 0) / 100;

    return {
      success: true,
      accountId,
      timeframeDays: Number(timeframeDays),
      count: recent.length,
      totalAmount,
      payouts: recent.map(p => ({ id: p.id, amount: (p.amount || 0) / 100, currency: p.currency, status: p.status, arrivalDate: p.arrival_date }))
    };
  } catch (e: any) {
    logger.error("Failed to fetch settlement summary", { error: e.message, accountId });
    throw new HttpsError("internal", "Failed to fetch settlements");
  }
});


