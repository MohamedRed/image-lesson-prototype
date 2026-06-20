import { onCall } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import { withMetrics } from "../shared/metrics";
import { StripePaymentService } from "../services/payments/stripeService";
import { DlocalService } from "../services/payments/dlocalService";

try { admin.app(); } catch { admin.initializeApp(); }
const db = admin.firestore();

type Currency = 'MAD';

function authUid(ctx: any): string {
  const uid = ctx.auth?.uid;
  if (!uid) throw new Error("Authentication required");
  return uid;
}

const COLLECTIONS = {
  wallets: 'proWallets',
  topups: 'walletTopups',
  txns: 'walletTransactions',
};

// Public callables (pro)
export const getWallet = withMetrics("wallet:getWallet", onCall(async (req) => {
  const uid = authUid(req);
  const snap = await db.collection(COLLECTIONS.wallets).doc(uid).get();
  if (!snap.exists) {
    const initial = { balanceMAD: 0, reservedMAD: 0, minBalanceMAD: 0, currency: 'MAD', updatedAt: admin.firestore.FieldValue.serverTimestamp() };
    await db.collection(COLLECTIONS.wallets).doc(uid).set(initial);
    return { ...initial, id: uid };
  }
  return { id: uid, ...snap.data() };
}));

export const createTopUp = withMetrics("wallet:createTopUp", onCall(async (req) => {
  const uid = authUid(req);
  const { amount, method } = req.data || {};
  if (!(amount > 0)) throw new Error("amount must be > 0");
  const supported = ['card', 'mobile_wallet', 'cash_agent'];
  if (!supported.includes(String(method))) throw new Error("unsupported method");

  const ref = await db.collection(COLLECTIONS.topups).add({
    userId: uid,
    amountMAD: Number(amount),
    currency: 'MAD',
    method,
    status: 'pending',
    providerRef: null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Initiate provider flow
  let clientSecret: string | null = null;
  let redirectUrl: string | null = null;
  if (method === 'card') {
    const intent = await StripePaymentService.createPaymentIntent({
      amount: Math.round(Number(amount) * 100),
      currency: 'mad',
      metadata: { topupId: ref.id, userId: uid, type: 'wallet_topup' },
      captureMethod: 'automatic',
    });
    clientSecret = (intent as any).client_secret || (intent as any).clientSecret || null;
    await ref.update({ providerRef: intent.id });
  } else if (method === 'cash_agent') {
    const init = await DlocalService.initPayment({
      amount: Number(amount),
      currency: 'MAD',
      orderId: `wallet_${ref.id}`,
      description: `Wallet top-up ${ref.id}`,
      method: 'CASH',
      channel: 'WAFACASH',
      metadata: { userId: uid },
    });
    redirectUrl = init.redirectUrl || null;
    await ref.update({ providerRef: init.id });
  }

  logger.info("Wallet top-up created", { topupId: ref.id, userId: uid, method, amount });
  return { topupId: ref.id, clientSecret, redirectUrl };
}));

export const confirmTopUp = withMetrics("wallet:confirmTopUp", onCall(async (req) => {
  const uid = authUid(req);
  const { topupId, providerRef } = req.data || {};
  if (!topupId) throw new Error("topupId required");
  const topupRef = db.collection(COLLECTIONS.topups).doc(topupId);
  await db.runTransaction(async (tx) => {
    const tDoc = await tx.get(topupRef);
    if (!tDoc.exists) throw new Error("Top-up not found");
    const t = tDoc.data() as any;
    if (t.userId !== uid) throw new Error("Access denied");
    if (t.status !== 'pending') throw new Error("Top-up already processed");

    const walletRef = db.collection(COLLECTIONS.wallets).doc(uid);
    const wDoc = await tx.get(walletRef);
    const balance = (wDoc.exists ? (wDoc.data() as any).balanceMAD : 0) || 0;

    tx.update(topupRef, {
      status: 'succeeded',
      providerRef: providerRef || null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    tx.set(walletRef, {
      balanceMAD: balance + t.amountMAD,
      reservedMAD: (wDoc.exists ? (wDoc.data() as any).reservedMAD : 0) || 0,
      minBalanceMAD: (wDoc.exists ? (wDoc.data() as any).minBalanceMAD : 0) || 0,
      currency: 'MAD',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    const txnRef = db.collection(COLLECTIONS.txns).doc();
    tx.set(txnRef, {
      userId: uid,
      type: 'topup',
      amountMAD: t.amountMAD,
      balanceAfterMAD: balance + t.amountMAD,
      relatedId: topupId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return { success: true };
}));

// Internal helpers (used by other modules via callables or import)
export async function reserveCommission(proId: string, amountMAD: number): Promise<void> {
  if (amountMAD <= 0) return;
  const walletRef = db.collection(COLLECTIONS.wallets).doc(proId);
  await db.runTransaction(async (tx) => {
    const wDoc = await tx.get(walletRef);
    const w = (wDoc.exists ? wDoc.data() : { balanceMAD: 0, reservedMAD: 0, minBalanceMAD: 0 }) as any;
    const available = (w.balanceMAD || 0) - (w.reservedMAD || 0);
    if (available < amountMAD) {
      throw new Error("INSUFFICIENT_WALLET_BALANCE");
    }
    tx.set(walletRef, {
      balanceMAD: w.balanceMAD,
      reservedMAD: (w.reservedMAD || 0) + amountMAD,
      minBalanceMAD: w.minBalanceMAD || 0,
      currency: 'MAD',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    const txnRef = db.collection(COLLECTIONS.txns).doc();
    tx.set(txnRef, {
      userId: proId,
      type: 'reserve',
      amountMAD,
      balanceAfterMAD: w.balanceMAD,
      reservedAfterMAD: (w.reservedMAD || 0) + amountMAD,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

export async function releaseCommission(proId: string, amountMAD: number): Promise<void> {
  if (amountMAD <= 0) return;
  const walletRef = db.collection(COLLECTIONS.wallets).doc(proId);
  await db.runTransaction(async (tx) => {
    const wDoc = await tx.get(walletRef);
    const w = (wDoc.exists ? wDoc.data() : { balanceMAD: 0, reservedMAD: 0, minBalanceMAD: 0 }) as any;
    const newReserved = Math.max(0, (w.reservedMAD || 0) - amountMAD);
    tx.set(walletRef, {
      reservedMAD: newReserved,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    const txnRef = db.collection(COLLECTIONS.txns).doc();
    tx.set(txnRef, {
      userId: proId,
      type: 'release',
      amountMAD,
      balanceAfterMAD: w.balanceMAD,
      reservedAfterMAD: newReserved,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

export async function captureCommission(proId: string, amountMAD: number): Promise<void> {
  if (amountMAD <= 0) return;
  const walletRef = db.collection(COLLECTIONS.wallets).doc(proId);
  await db.runTransaction(async (tx) => {
    const wDoc = await tx.get(walletRef);
    const w = (wDoc.exists ? wDoc.data() : { balanceMAD: 0, reservedMAD: 0, minBalanceMAD: 0 }) as any;
    const reserved = (w.reservedMAD || 0);
    if (reserved < amountMAD) throw new Error("RESERVED_INSUFFICIENT");
    const newReserved = reserved - amountMAD;
    const newBalance = Math.max(0, (w.balanceMAD || 0) - amountMAD);
    tx.set(walletRef, {
      balanceMAD: newBalance,
      reservedMAD: newReserved,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    const txnRef = db.collection(COLLECTIONS.txns).doc();
    tx.set(txnRef, {
      userId: proId,
      type: 'capture',
      amountMAD,
      balanceAfterMAD: newBalance,
      reservedAfterMAD: newReserved,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}


