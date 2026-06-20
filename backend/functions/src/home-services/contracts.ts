import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { withMetrics } from "../shared/metrics";

try { admin.app(); } catch { admin.initializeApp(); }

const db = admin.firestore();

/**
 * Get contracts for a user (customer or professional) (HTTP)
 * GET /home/contracts
 */
export const getContractsHttp = withMetrics("getContractsHttp",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { status, role } = req.query;

      // Build query based on user role
      let query = db.collection('contracts');
      
      if (role === 'customer') {
        query = query.where('customerId', '==', userId);
      } else if (role === 'professional') {
        query = query.where('proId', '==', userId);
      } else {
        // Get contracts where user is either customer or professional
        const customerContracts = await db.collection('contracts')
          .where('customerId', '==', userId)
          .get();
        
        const proContracts = await db.collection('contracts')
          .where('proId', '==', userId)
          .get();

        const allContracts = [
          ...customerContracts.docs.map(doc => ({ id: doc.id, ...doc.data() })),
          ...proContracts.docs.map(doc => ({ id: doc.id, ...doc.data() }))
        ];

        // Sort by creation date
        allContracts.sort((a, b) => {
          const aTime = a.createdAt?.toMillis() || 0;
          const bTime = b.createdAt?.toMillis() || 0;
          return bTime - aTime;
        });

        res.json({ contracts: allContracts });
        return;
      }

      if (status) {
        query = query.where('status', '==', status);
      }

      const snapshot = await query
        .orderBy('createdAt', 'desc')
        .get();

      const contracts = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));

      res.json({ contracts });
    } catch (error: any) {
      logger.error("Failed to get contracts", { error: error.message });
      res.status(500).json({ error: "Failed to get contracts" });
    }
  })
);

/**
 * Get a specific contract (HTTP)
 * GET /home/contracts/:id
 */
export const getContractHttp = withMetrics("getContractHttp",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { contractId } = req.query;
      
      if (!contractId) {
        res.status(400).json({ error: "Contract ID is required" });
        return;
      }

      const contractDoc = await db.collection('contracts').doc(contractId as string).get();
      
      if (!contractDoc.exists) {
        res.status(404).json({ error: "Contract not found" });
        return;
      }

      const contractData = contractDoc.data()!;

      // Check if user has permission to view this contract
      const isCustomer = contractData.customerId === userId;
      const isProfessional = contractData.proId === userId;
      
      if (!isCustomer && !isProfessional) {
        res.status(403).json({ error: "Access denied" });
        return;
      }

      res.json({
        id: contractDoc.id,
        ...contractData
      });
    } catch (error: any) {
      logger.error("Failed to get contract", { error: error.message });
      res.status(500).json({ error: "Failed to get contract" });
    }
  })
);

/**
 * Start a contract (after payment confirmation) (HTTP)
 * POST /home/contracts/:id/start
 */
export const startContractHttp = withMetrics("startContractHttp",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { contractId } = req.query;
      
      if (!contractId) {
        res.status(400).json({ error: "Contract ID is required" });
        return;
      }

      const contractRef = db.collection('contracts').doc(contractId as string);
      const contractDoc = await contractRef.get();
      
      if (!contractDoc.exists) {
        res.status(404).json({ error: "Contract not found" });
        return;
      }

      const contractData = contractDoc.data()!;

      // Only customer or admin can start contract
      const isCustomer = contractData.customerId === userId;
      const isAdmin = req.auth?.token?.admin === true;
      
      if (!isCustomer && !isAdmin) {
        res.status(403).json({ error: "Access denied" });
        return;
      }

      // Contract must be in pending_payment status
      if (contractData.status !== 'pending_payment') {
        res.status(400).json({ error: "Contract cannot be started in current state" });
        return;
      }

      await contractRef.update({
        status: 'active',
        startAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      logger.info("Contract started", { contractId, customerId: userId });

      res.json({ success: true });
    } catch (error: any) {
      logger.error("Failed to start contract", { error: error.message });
      res.status(500).json({ error: "Failed to start contract" });
    }
  })
);

/**
 * Complete a contract (HTTP)
 * POST /home/contracts/:id/complete
 */
export const completeContractHttp = withMetrics("completeContractHttp",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { contractId } = req.query;
      
      if (!contractId) {
        res.status(400).json({ error: "Contract ID is required" });
        return;
      }

      const contractRef = db.collection('contracts').doc(contractId as string);
      const contractDoc = await contractRef.get();
      
      if (!contractDoc.exists) {
        res.status(404).json({ error: "Contract not found" });
        return;
      }

      const contractData = contractDoc.data()!;

      // Both customer and professional can mark as complete
      const isCustomer = contractData.customerId === userId;
      const isProfessional = contractData.proId === userId;
      
      if (!isCustomer && !isProfessional) {
        res.status(403).json({ error: "Access denied" });
        return;
      }

      // Contract must be active
      if (contractData.status !== 'active') {
        res.status(400).json({ error: "Contract must be active to complete" });
        return;
      }

      await contractRef.update({
        status: 'completed',
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      logger.info("Contract completed", { contractId, userId, role: isCustomer ? 'customer' : 'professional' });

      res.json({ success: true });
    } catch (error: any) {
      logger.error("Failed to complete contract", { error: error.message });
      res.status(500).json({ error: "Failed to complete contract" });
    }
  })
);

/**
 * Update milestone status (HTTP)
 * PUT /home/contracts/:id/milestones/:milestoneId
 */
export const updateMilestoneHttp = withMetrics("updateMilestoneHttp",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { contractId, milestoneId } = req.query;
      const { status } = req.body;
      
      if (!contractId || !milestoneId || !status) {
        res.status(400).json({ error: "Contract ID, milestone ID, and status are required" });
        return;
      }

      const contractRef = db.collection('contracts').doc(contractId as string);
      const contractDoc = await contractRef.get();
      
      if (!contractDoc.exists) {
        res.status(404).json({ error: "Contract not found" });
        return;
      }

      const contractData = contractDoc.data()!;

      // Check user permissions
      const isCustomer = contractData.customerId === userId;
      const isProfessional = contractData.proId === userId;
      
      if (!isCustomer && !isProfessional) {
        res.status(403).json({ error: "Access denied" });
        return;
      }

      // Find and update the milestone
      const milestones = contractData.milestones || [];
      const milestoneIndex = milestones.findIndex((m: any) => m.id === milestoneId);
      
      if (milestoneIndex === -1) {
        res.status(404).json({ error: "Milestone not found" });
        return;
      }

      const milestone = milestones[milestoneIndex];

      // Validate status transitions
      if (status === 'completed' && !isProfessional) {
        res.status(403).json({ error: "Only professional can mark milestone as completed" });
        return;
      }

      if (status === 'approved' && !isCustomer) {
        res.status(403).json({ error: "Only customer can approve milestone" });
        return;
      }

      if (status === 'approved' && milestone.status !== 'completed') {
        res.status(400).json({ error: "Can only approve completed milestones" });
        return;
      }

      // Update milestone
      milestones[milestoneIndex] = {
        ...milestone,
        status,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      await contractRef.update({
        milestones,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      logger.info("Milestone updated", { 
        contractId, 
        milestoneId, 
        status, 
        userId, 
        role: isCustomer ? 'customer' : 'professional' 
      });

      res.json({ success: true });
    } catch (error: any) {
      logger.error("Failed to update milestone", { error: error.message });
      res.status(500).json({ error: "Failed to update milestone" });
    }
  })
);

/**
 * Submit a review for a contract (HTTP)
 * POST /home/contracts/:id/review
 */
export const submitReviewHttp = withMetrics("submitReviewHttp",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { contractId } = req.query;
      const { rating, text } = req.body;
      
      if (!contractId || rating == null) {
        res.status(400).json({ error: "Contract ID and rating are required" });
        return;
      }

      if (rating < 1 || rating > 5) {
        res.status(400).json({ error: "Rating must be between 1 and 5" });
        return;
      }

      const contractDoc = await db.collection('contracts').doc(contractId as string).get();
      
      if (!contractDoc.exists) {
        res.status(404).json({ error: "Contract not found" });
        return;
      }

      const contractData = contractDoc.data()!;

      // Check if user is part of this contract
      const isCustomer = contractData.customerId === userId;
      const isProfessional = contractData.proId === userId;
      
      if (!isCustomer && !isProfessional) {
        res.status(403).json({ error: "Access denied" });
        return;
      }

      // Contract must be completed
      if (contractData.status !== 'completed') {
        res.status(400).json({ error: "Can only review completed contracts" });
        return;
      }

      // Check if review already exists
      const existingReview = await db.collection('reviews')
        .where('contractId', '==', contractId)
        .where('reviewerId', '==', userId)
        .get();

      if (!existingReview.empty) {
        res.status(400).json({ error: "Review already exists for this contract" });
        return;
      }

      const reviewData = {
        contractId,
        rfqId: contractData.rfqId,
        reviewerId: userId,
        revieweeId: isCustomer ? contractData.proId : contractData.customerId,
        reviewerRole: isCustomer ? 'customer' : 'professional',
        rating: Number(rating),
        text: text || null,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      };

      await db.collection('reviews').add(reviewData);

      logger.info("Review submitted", { 
        contractId, 
        reviewerId: userId, 
        rating,
        reviewerRole: isCustomer ? 'customer' : 'professional'
      });

      res.json({ success: true });
    } catch (error: any) {
      logger.error("Failed to submit review", { error: error.message });
      res.status(500).json({ error: "Failed to submit review" });
    }
  })
);

/**
 * Create a dispute for a contract (HTTP)
 * POST /home/contracts/:id/dispute
 */
export const createDisputeHttp = withMetrics("createDisputeHttp",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { contractId } = req.query;
      const { reason, description, evidence } = req.body;
      
      if (!contractId || !reason || !description) {
        res.status(400).json({ error: "Contract ID, reason, and description are required" });
        return;
      }

      const contractDoc = await db.collection('contracts').doc(contractId as string).get();
      
      if (!contractDoc.exists) {
        res.status(404).json({ error: "Contract not found" });
        return;
      }

      const contractData = contractDoc.data()!;

      // Check if user is part of this contract
      const isCustomer = contractData.customerId === userId;
      const isProfessional = contractData.proId === userId;
      
      if (!isCustomer && !isProfessional) {
        res.status(403).json({ error: "Access denied" });
        return;
      }

      // Check if dispute already exists
      const existingDispute = await db.collection('disputes')
        .where('contractId', '==', contractId)
        .where('status', 'in', ['open', 'investigating'])
        .get();

      if (!existingDispute.empty) {
        res.status(400).json({ error: "Active dispute already exists for this contract" });
        return;
      }

      const disputeData = {
        contractId,
        rfqId: contractData.rfqId,
        customerId: contractData.customerId,
        proId: contractData.proId,
        reporterId: userId,
        reporterRole: isCustomer ? 'customer' : 'professional',
        reason,
        description,
        evidence: evidence || [],
        status: 'open',
        resolution: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      const disputeRef = await db.collection('disputes').add(disputeData);

      // Update contract status
      await db.collection('contracts').doc(contractId as string).update({
        status: 'disputed',
        disputeId: disputeRef.id,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      logger.info("Dispute created", { 
        contractId, 
        disputeId: disputeRef.id,
        reporterId: userId, 
        reason
      });

      res.json({ 
        success: true, 
        disputeId: disputeRef.id 
      });
    } catch (error: any) {
      logger.error("Failed to create dispute", { error: error.message });
      res.status(500).json({ error: "Failed to create dispute" });
    }
  })
);

/**
 * Cancel a contract (before it starts) (HTTP)
 * POST /home/contracts/:id/cancel
 */
export const cancelContractHttp = withMetrics("cancelContractHttp",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { contractId } = req.query;
      const { reason } = req.body;
      
      if (!contractId) {
        res.status(400).json({ error: "Contract ID is required" });
        return;
      }

      const contractRef = db.collection('contracts').doc(contractId as string);
      const contractDoc = await contractRef.get();
      
      if (!contractDoc.exists) {
        res.status(404).json({ error: "Contract not found" });
        return;
      }

      const contractData = contractDoc.data()!;

      // Check if user has permission to cancel
      const isCustomer = contractData.customerId === userId;
      const isProfessional = contractData.proId === userId;
      
      if (!isCustomer && !isProfessional) {
        res.status(403).json({ error: "Access denied" });
        return;
      }

      // Can only cancel contracts that haven't started
      if (contractData.status !== 'pending_payment') {
        res.status(400).json({ error: "Can only cancel contracts before they start" });
        return;
      }

      await contractRef.update({
        status: 'cancelled',
        cancelledBy: userId,
        cancelledRole: isCustomer ? 'customer' : 'professional',
        cancellationReason: reason || null,
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      logger.info("Contract cancelled", { 
        contractId, 
        cancelledBy: userId,
        role: isCustomer ? 'customer' : 'professional',
        reason 
      });

      res.json({ success: true });
    } catch (error: any) {
      logger.error("Failed to cancel contract", { error: error.message });
      res.status(500).json({ error: "Failed to cancel contract" });
    }
  })
);