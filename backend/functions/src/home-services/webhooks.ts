import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { handlePSPWebhook } from "./paymentProvider";
import { DlocalService } from "../services/payments/dlocalService";
import { withMetrics } from "../shared/metrics";

/**
 * Webhook endpoint for payment service provider
 * POST /home/webhooks/payments
 */
export const paymentWebhook = withMetrics("paymentWebhook",
  onRequest({ cors: false }, async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    try {
      await handlePSPWebhook(req, res);
    } catch (error: any) {
      logger.error("Payment webhook failed", { error: error.message });
      res.status(500).json({ error: "Webhook processing failed" });
    }
  })
);

/**
 * dLocal (Wafacash) webhook for wallet top-ups and cash escrows
 * POST /home/webhooks/dlocal
 */
export const dlocalWebhook = withMetrics("dlocalWebhook",
  onRequest({ cors: false }, async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }
    try {
      const signature = req.headers['x-dlocal-signature'] as string | undefined;
      const ok = await DlocalService.verifyWebhookSignature(req.rawBody || JSON.stringify(req.body), signature);
      if (!ok) {
        res.status(401).json({ error: "Invalid signature" });
        return;
      }

      const event = req.body || {};
      const type = event.type || event.event_type;
      const data = event.data || {};
      const externalId: string | undefined = data.order_id || data.orderId;
      const paymentId: string | undefined = data.id || data.payment_id || data.paymentId;

      if (!type || !externalId) {
        res.status(400).json({ error: "Missing type or order_id" });
        return;
      }

      // Wallet top-up: order_id starts with wallet_
      if (String(externalId).startsWith('wallet_')) {
        const topupId = String(externalId).replace('wallet_', '');
        const topupRef = admin.firestore().collection('walletTopups').doc(topupId);
        const snap = await topupRef.get();
        if (!snap.exists) {
          res.json({ received: true });
          return;
        }
        if (type.includes('payment.succeeded') || type.includes('approved')) {
          await topupRef.update({ status: 'succeeded', providerRef: paymentId || snap.data()!.providerRef, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
          // credit wallet
          const t = snap.data() as any;
          const walletRef = admin.firestore().collection('proWallets').doc(t.userId);
          await admin.firestore().runTransaction(async (tx) => {
            const w = await tx.get(walletRef);
            const bal = (w.exists ? (w.data() as any).balanceMAD : 0) || 0;
            tx.set(walletRef, { balanceMAD: bal + t.amountMAD, currency: 'MAD', updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
            const txnRef = admin.firestore().collection('walletTransactions').doc();
            tx.set(txnRef, { userId: t.userId, type: 'topup', amountMAD: t.amountMAD, balanceAfterMAD: bal + t.amountMAD, relatedId: topupId, createdAt: admin.firestore.FieldValue.serverTimestamp() });
          });
        } else if (type.includes('payment.failed') || type.includes('rejected')) {
          await topupRef.update({ status: 'failed', providerRef: paymentId || snap.data()!.providerRef, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
        }
        res.json({ received: true });
        return;
      }

      // Escrow deposit: order_id starts with escrow_
      if (String(externalId).startsWith('escrow_')) {
        const contractId = String(externalId).replace('escrow_', '');
        const escrows = await admin.firestore().collection('escrows').where('contractId', '==', contractId).limit(1).get();
        if (!escrows.empty) {
          const escrowRef = escrows.docs[0].ref;
          if (type.includes('payment.succeeded') || type.includes('approved')) {
            await escrowRef.update({ status: 'held', transactionId: paymentId || null, paidAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() });
          } else if (type.includes('payment.failed') || type.includes('rejected')) {
            await escrowRef.update({ status: 'failed', failureReason: data.reason || data.status_detail || null, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
          }
        }
        res.json({ received: true });
        return;
      }

      res.json({ received: true });
    } catch (error: any) {
      logger.error("dLocal webhook failed", { error: error.message });
      res.status(500).json({ error: "Webhook processing failed" });
    }
  })
);