import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { withMetrics } from "../shared/metrics";

try { admin.app(); } catch { admin.initializeApp(); }

const db = admin.firestore();

/**
 * Create an escrow payment for a contract (HTTP)
 * POST /home/payments/escrow
 */
export const createEscrowPaymentHttp = withMetrics("createEscrowPaymentHttp",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { contractId, paymentMethod } = req.body;
      
      if (!contractId || !paymentMethod) {
        res.status(400).json({ error: "Contract ID and payment method are required" });
        return;
      }

      const contractDoc = await db.collection('contracts').doc(contractId).get();
      
      if (!contractDoc.exists) {
        res.status(404).json({ error: "Contract not found" });
        return;
      }

      const contractData = contractDoc.data()!;

      // Only customer can create escrow payment
      if (contractData.customerId !== userId) {
        res.status(403).json({ error: "Only customer can create escrow payment" });
        return;
      }

      // Contract must be in pending_payment status
      if (contractData.status !== 'pending_payment') {
        res.status(400).json({ error: "Contract is not awaiting payment" });
        return;
      }

      // Check if escrow already exists
      const existingEscrow = await db.collection('escrows')
        .where('contractId', '==', contractId)
        .where('status', 'in', ['pending', 'held'])
        .get();

      if (!existingEscrow.empty) {
        res.status(400).json({ error: "Escrow payment already exists for this contract" });
        return;
      }

      const escrowData = {
        contractId,
        customerId: contractData.customerId,
        proId: contractData.proId,
        totalAmount: contractData.priceMAD,
        depositAmount: contractData.depositAmount,
        remainingAmount: contractData.priceMAD - contractData.depositAmount,
        currency: "MAD",
        paymentMethod: {
          type: paymentMethod.type, // 'card', 'bank_transfer', 'mobile_money'
          provider: paymentMethod.provider || null,
          last4: paymentMethod.last4 || null
        },
        status: 'pending',
        milestonePayments: [],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        // Payment processor fields (would integrate with actual payment provider)
        paymentIntentId: null,
        transactionId: null
      };

      const escrowRef = await db.collection('escrows').add(escrowData);

      // In a real implementation, you would integrate with a payment processor here
      // For now, we'll simulate payment processing
      
      logger.info("Escrow payment created", { 
        escrowId: escrowRef.id,
        contractId, 
        customerId: userId,
        amount: contractData.priceMAD
      });

      res.json({ 
        success: true,
        escrowId: escrowRef.id,
        amount: contractData.priceMAD,
        currency: "MAD",
        // In production, return payment processor client_secret for frontend
        paymentIntentId: `pi_mock_${escrowRef.id}`
      });
    } catch (error: any) {
      logger.error("Failed to create escrow payment", { error: error.message });
      res.status(500).json({ error: "Failed to create escrow payment" });
    }
  })
);

/**
 * Confirm escrow payment (webhook from payment processor) (HTTP)
 * POST /home/payments/confirm
 */
export const confirmEscrowPaymentHttp = withMetrics("confirmEscrowPaymentHttp",
  onRequest({ cors: true }, async (req, res) => {
    try {
      // In production, verify webhook signature from payment processor
      const { escrowId, paymentIntentId, transactionId, status } = req.body;
      
      if (!escrowId || !paymentIntentId) {
        res.status(400).json({ error: "Escrow ID and payment intent ID are required" });
        return;
      }

      const escrowRef = db.collection('escrows').doc(escrowId);
      const escrowDoc = await escrowRef.get();
      
      if (!escrowDoc.exists) {
        res.status(404).json({ error: "Escrow not found" });
        return;
      }

      const escrowData = escrowDoc.data()!;

      if (status === 'succeeded') {
        // Payment successful - hold funds in escrow
        await db.runTransaction(async (transaction) => {
          // Update escrow status
          transaction.update(escrowRef, {
            status: 'held',
            paymentIntentId,
            transactionId: transactionId || null,
            paidAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });

          // Update contract status to active
          const contractRef = db.collection('contracts').doc(escrowData.contractId);
          transaction.update(contractRef, {
            status: 'active',
            escrowId: escrowRef.id,
            startAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        });

        logger.info("Escrow payment confirmed", { 
          escrowId, 
          contractId: escrowData.contractId,
          amount: escrowData.totalAmount
        });

      } else if (status === 'failed') {
        // Payment failed
        await escrowRef.update({
          status: 'failed',
          paymentIntentId,
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        logger.warn("Escrow payment failed", { 
          escrowId, 
          contractId: escrowData.contractId 
        });
      }

      res.json({ success: true });
    } catch (error: any) {
      logger.error("Failed to confirm escrow payment", { error: error.message });
      res.status(500).json({ error: "Failed to confirm payment" });
    }
  })
);

/**
 * Release milestone payment to professional (HTTP)
 * POST /home/payments/release
 */
export const releaseMilestonePaymentHttp = withMetrics("releaseMilestonePaymentHttp",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { escrowId, milestoneId, amount } = req.body;
      
      if (!escrowId || !milestoneId || amount == null) {
        res.status(400).json({ error: "Escrow ID, milestone ID, and amount are required" });
        return;
      }

      const escrowRef = db.collection('escrows').doc(escrowId);
      const escrowDoc = await escrowRef.get();
      
      if (!escrowDoc.exists) {
        res.status(404).json({ error: "Escrow not found" });
        return;
      }

      const escrowData = escrowDoc.data()!;

      // Only customer can release payments
      if (escrowData.customerId !== userId) {
        res.status(403).json({ error: "Only customer can release payments" });
        return;
      }

      // Escrow must be in held status
      if (escrowData.status !== 'held') {
        res.status(400).json({ error: "Escrow is not in held status" });
        return;
      }

      // Check if milestone payment already exists
      const existingPayment = escrowData.milestonePayments?.find(
        (p: any) => p.milestoneId === milestoneId
      );

      if (existingPayment) {
        res.status(400).json({ error: "Payment for this milestone already released" });
        return;
      }

      const milestonePayment = {
        milestoneId,
        amount: Number(amount),
        releasedAt: admin.firestore.FieldValue.serverTimestamp(),
        transactionId: `txn_milestone_${Date.now()}`
      };

      await escrowRef.update({
        milestonePayments: admin.firestore.FieldValue.arrayUnion(milestonePayment),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // In production, transfer funds to professional's account here

      logger.info("Milestone payment released", { 
        escrowId,
        milestoneId, 
        amount,
        customerId: userId,
        proId: escrowData.proId
      });

      res.json({ 
        success: true,
        transactionId: milestonePayment.transactionId
      });
    } catch (error: any) {
      logger.error("Failed to release milestone payment", { error: error.message });
      res.status(500).json({ error: "Failed to release payment" });
    }
  })
);

/**
 * Release final payment on contract completion (HTTP)
 * POST /home/payments/complete
 */
export const completeFinalPaymentHttp = withMetrics("completeFinalPaymentHttp",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { escrowId } = req.body;
      
      if (!escrowId) {
        res.status(400).json({ error: "Escrow ID is required" });
        return;
      }

      const escrowRef = db.collection('escrows').doc(escrowId);
      const escrowDoc = await escrowRef.get();
      
      if (!escrowDoc.exists) {
        res.status(404).json({ error: "Escrow not found" });
        return;
      }

      const escrowData = escrowDoc.data()!;

      // Only customer can complete final payment
      if (escrowData.customerId !== userId) {
        res.status(403).json({ error: "Only customer can complete final payment" });
        return;
      }

      // Check contract is completed
      const contractDoc = await db.collection('contracts').doc(escrowData.contractId).get();
      const contractData = contractDoc.data()!;
      
      if (contractData.status !== 'completed') {
        res.status(400).json({ error: "Contract must be completed first" });
        return;
      }

      // Calculate remaining amount
      const releasedAmount = escrowData.milestonePayments?.reduce(
        (total: number, payment: any) => total + payment.amount, 
        0
      ) || 0;
      
      const remainingAmount = escrowData.totalAmount - releasedAmount;

      if (remainingAmount <= 0) {
        res.status(400).json({ error: "No remaining amount to release" });
        return;
      }

      await escrowRef.update({
        status: 'completed',
        finalPayment: {
          amount: remainingAmount,
          releasedAt: admin.firestore.FieldValue.serverTimestamp(),
          transactionId: `txn_final_${Date.now()}`
        },
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // In production, transfer remaining funds to professional's account here

      logger.info("Final payment completed", { 
        escrowId,
        amount: remainingAmount,
        customerId: userId,
        proId: escrowData.proId
      });

      res.json({ 
        success: true,
        finalAmount: remainingAmount,
        transactionId: `txn_final_${Date.now()}`
      });
    } catch (error: any) {
      logger.error("Failed to complete final payment", { error: error.message });
      res.status(500).json({ error: "Failed to complete final payment" });
    }
  })
);

/**
 * Refund escrow payment (in case of cancellation/dispute) (HTTP)
 * POST /home/payments/refund
 */
export const refundEscrowPaymentHttp = withMetrics("refundEscrowPaymentHttp",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { escrowId, reason, partialAmount } = req.body;
      
      if (!escrowId || !reason) {
        res.status(400).json({ error: "Escrow ID and reason are required" });
        return;
      }

      // Only admin can process refunds for now
      if (!req.auth?.token?.admin) {
        res.status(403).json({ error: "Admin access required for refunds" });
        return;
      }

      const escrowRef = db.collection('escrows').doc(escrowId);
      const escrowDoc = await escrowRef.get();
      
      if (!escrowDoc.exists) {
        res.status(404).json({ error: "Escrow not found" });
        return;
      }

      const escrowData = escrowDoc.data()!;

      // Can only refund held funds
      if (escrowData.status !== 'held') {
        res.status(400).json({ error: "Can only refund held escrow payments" });
        return;
      }

      // Calculate refund amount
      const releasedAmount = escrowData.milestonePayments?.reduce(
        (total: number, payment: any) => total + payment.amount, 
        0
      ) || 0;
      
      const availableToRefund = escrowData.totalAmount - releasedAmount;
      const refundAmount = partialAmount ? Math.min(partialAmount, availableToRefund) : availableToRefund;

      if (refundAmount <= 0) {
        res.status(400).json({ error: "No funds available to refund" });
        return;
      }

      await escrowRef.update({
        status: 'refunded',
        refund: {
          amount: refundAmount,
          reason,
          processedBy: userId,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          transactionId: `txn_refund_${Date.now()}`
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // In production, process actual refund to customer's payment method here

      logger.info("Escrow refund processed", { 
        escrowId,
        refundAmount,
        reason,
        processedBy: userId
      });

      res.json({ 
        success: true,
        refundAmount,
        transactionId: `txn_refund_${Date.now()}`
      });
    } catch (error: any) {
      logger.error("Failed to process refund", { error: error.message });
      res.status(500).json({ error: "Failed to process refund" });
    }
  })
);

/**
 * Get payment history for a user (HTTP)
 * GET /home/payments/history
 */
export const getPaymentHistoryHttp = withMetrics("getPaymentHistoryHttp",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { role } = req.query;

      let query = db.collection('escrows');
      
      if (role === 'customer') {
        query = query.where('customerId', '==', userId);
      } else if (role === 'professional') {
        query = query.where('proId', '==', userId);
      } else {
        // Get payments where user is either customer or professional
        const customerPayments = await db.collection('escrows')
          .where('customerId', '==', userId)
          .get();
        
        const proPayments = await db.collection('escrows')
          .where('proId', '==', userId)
          .get();

        const allPayments = [
          ...customerPayments.docs.map(doc => ({ id: doc.id, ...doc.data() })),
          ...proPayments.docs.map(doc => ({ id: doc.id, ...doc.data() }))
        ];

        // Sort by creation date
        allPayments.sort((a, b) => {
          const aTime = a.createdAt?.toMillis() || 0;
          const bTime = b.createdAt?.toMillis() || 0;
          return bTime - aTime;
        });

        res.json({ payments: allPayments });
        return;
      }

      const snapshot = await query
        .orderBy('createdAt', 'desc')
        .limit(50)
        .get();

      const payments = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));

      res.json({ payments });
    } catch (error: any) {
      logger.error("Failed to get payment history", { error: error.message });
      res.status(500).json({ error: "Failed to get payment history" });
    }
  })
);

/**
 * Get escrow details (HTTP)
 * GET /home/payments/escrow/:id
 */
export const getEscrowDetailsHttp = withMetrics("getEscrowDetailsHttp",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { escrowId } = req.query;
      
      if (!escrowId) {
        res.status(400).json({ error: "Escrow ID is required" });
        return;
      }

      const escrowDoc = await db.collection('escrows').doc(escrowId as string).get();
      
      if (!escrowDoc.exists) {
        res.status(404).json({ error: "Escrow not found" });
        return;
      }

      const escrowData = escrowDoc.data()!;

      // Check if user has permission to view this escrow
      const isCustomer = escrowData.customerId === userId;
      const isProfessional = escrowData.proId === userId;
      const isAdmin = req.auth?.token?.admin === true;
      
      if (!isCustomer && !isProfessional && !isAdmin) {
        res.status(403).json({ error: "Access denied" });
        return;
      }

      res.json({
        id: escrowDoc.id,
        ...escrowData
      });
    } catch (error: any) {
      logger.error("Failed to get escrow details", { error: error.message });
      res.status(500).json({ error: "Failed to get escrow details" });
    }
  })
);