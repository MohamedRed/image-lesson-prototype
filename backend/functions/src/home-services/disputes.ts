import { onRequest } from "firebase-functions/v2/https";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { withMetrics } from "../shared/metrics";

try { admin.app(); } catch { admin.initializeApp(); }

const db = admin.firestore();

/**
 * Create a dispute for a contract
 * POST /home/disputes
 */
export const createDispute = withMetrics("createDispute",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { contractId, reason, description, evidence, requestedResolution } = req.body;
      
      if (!contractId || !reason || !description) {
        res.status(400).json({ error: "Contract ID, reason, and description are required" });
        return;
      }

      // Validate contract exists and user has access
      const contractDoc = await db.collection('contracts').doc(contractId).get();
      if (!contractDoc.exists) {
        res.status(404).json({ error: "Contract not found" });
        return;
      }

      const contractData = contractDoc.data()!;
      const isCustomer = contractData.customerId === userId;
      const isProfessional = contractData.proId === userId;
      
      if (!isCustomer && !isProfessional) {
        res.status(403).json({ error: "Access denied to this contract" });
        return;
      }

      // Check if dispute already exists for this contract
      const existingDispute = await db.collection('disputes')
        .where('contractId', '==', contractId)
        .where('status', 'in', ['open', 'investigating', 'mediation'])
        .limit(1)
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
        respondentId: isCustomer ? contractData.proId : contractData.customerId,
        respondentRole: isCustomer ? 'professional' : 'customer',
        reason: reason, // 'quality_issues', 'payment_dispute', 'communication', 'timeline', 'other'
        description,
        evidence: evidence || [],
        requestedResolution: requestedResolution || null,
        status: 'open',
        priority: calculateDisputePriority(reason, contractData),
        escalationLevel: 1, // 1: Customer Service, 2: Senior Agent, 3: Legal
        assignedTo: null,
        internalNotes: [],
        timeline: [{
          action: 'created',
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          userId,
          role: isCustomer ? 'customer' : 'professional',
          details: 'Dispute created'
        }],
        responses: [],
        resolution: null,
        resolutionType: null, // 'refund', 'redo_work', 'partial_refund', 'compensation', 'mediation'
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        dueDate: admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) // 7 days to resolve
        )
      };

      const disputeRef = await db.collection('disputes').add(disputeData);

      // Update contract status
      await contractDoc.ref.update({
        status: 'disputed',
        disputeId: disputeRef.id,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Notify the other party
      await notifyDisputeCreated(disputeRef.id, disputeData);

      // Auto-assign to customer service queue
      await assignToCustomerService(disputeRef.id);

      logger.info("Dispute created", { 
        disputeId: disputeRef.id,
        contractId, 
        reporterId: userId,
        reason,
        priority: disputeData.priority
      });

      res.json({ 
        disputeId: disputeRef.id,
        status: 'open',
        estimatedResolutionTime: '3-7 business days'
      });
    } catch (error: any) {
      logger.error("Failed to create dispute", { error: error.message });
      res.status(500).json({ error: "Failed to create dispute" });
    }
  })
);

/**
 * Add response to a dispute
 * POST /home/disputes/:id/respond
 */
export const respondToDispute = withMetrics("respondToDispute",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { disputeId } = req.query;
      const { message, evidence, proposedResolution } = req.body;
      
      if (!disputeId || !message) {
        res.status(400).json({ error: "Dispute ID and message are required" });
        return;
      }

      const disputeRef = db.collection('disputes').doc(disputeId as string);
      const disputeDoc = await disputeRef.get();
      
      if (!disputeDoc.exists) {
        res.status(404).json({ error: "Dispute not found" });
        return;
      }

      const disputeData = disputeDoc.data()!;

      // Check if user has access to this dispute
      const hasAccess = disputeData.customerId === userId || 
                       disputeData.proId === userId ||
                       req.auth?.token?.admin;
      
      if (!hasAccess) {
        res.status(403).json({ error: "Access denied" });
        return;
      }

      // Check if dispute is still open for responses
      if (!['open', 'investigating', 'mediation'].includes(disputeData.status)) {
        res.status(400).json({ error: "Dispute is not open for responses" });
        return;
      }

      const userRole = disputeData.customerId === userId ? 'customer' : 
                      disputeData.proId === userId ? 'professional' : 'admin';

      const responseData = {
        userId,
        role: userRole,
        message,
        evidence: evidence || [],
        proposedResolution: proposedResolution || null,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      };

      const timelineEntry = {
        action: 'response_added',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        userId,
        role: userRole,
        details: `Response added by ${userRole}`
      };

      await disputeRef.update({
        responses: admin.firestore.FieldValue.arrayUnion(responseData),
        timeline: admin.firestore.FieldValue.arrayUnion(timelineEntry),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastResponseAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Notify other parties
      await notifyDisputeResponse(disputeId as string, disputeData, responseData);

      logger.info("Dispute response added", { 
        disputeId, 
        userId, 
        role: userRole 
      });

      res.json({ success: true });
    } catch (error: any) {
      logger.error("Failed to respond to dispute", { error: error.message });
      res.status(500).json({ error: "Failed to respond to dispute" });
    }
  })
);

/**
 * Admin: Assign dispute to agent
 * POST /home/disputes/:id/assign
 */
export const assignDispute = withMetrics("assignDispute",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId || !req.auth?.token?.admin) {
        res.status(403).json({ error: "Admin access required" });
        return;
      }

      const { disputeId } = req.query;
      const { assigneeId, escalationLevel, notes } = req.body;
      
      if (!disputeId || !assigneeId) {
        res.status(400).json({ error: "Dispute ID and assignee ID are required" });
        return;
      }

      const disputeRef = db.collection('disputes').doc(disputeId as string);
      const disputeDoc = await disputeRef.get();
      
      if (!disputeDoc.exists) {
        res.status(404).json({ error: "Dispute not found" });
        return;
      }

      const timelineEntry = {
        action: 'assigned',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        userId,
        role: 'admin',
        details: `Assigned to agent ${assigneeId}${escalationLevel ? ` (Level ${escalationLevel})` : ''}`
      };

      const updateData: any = {
        assignedTo: assigneeId,
        assignedAt: admin.firestore.FieldValue.serverTimestamp(),
        assignedBy: userId,
        timeline: admin.firestore.FieldValue.arrayUnion(timelineEntry),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      if (escalationLevel) {
        updateData.escalationLevel = escalationLevel;
      }

      if (notes) {
        updateData.internalNotes = admin.firestore.FieldValue.arrayUnion({
          note: notes,
          addedBy: userId,
          timestamp: admin.firestore.FieldValue.serverTimestamp()
        });
      }

      await disputeRef.update(updateData);

      logger.info("Dispute assigned", { 
        disputeId, 
        assigneeId, 
        assignedBy: userId,
        escalationLevel 
      });

      res.json({ success: true });
    } catch (error: any) {
      logger.error("Failed to assign dispute", { error: error.message });
      res.status(500).json({ error: "Failed to assign dispute" });
    }
  })
);

/**
 * Admin: Resolve dispute
 * POST /home/disputes/:id/resolve
 */
export const resolveDispute = withMetrics("resolveDispute",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId || !req.auth?.token?.admin) {
        res.status(403).json({ error: "Admin access required" });
        return;
      }

      const { disputeId } = req.query;
      const { resolutionType, resolution, compensation, notes } = req.body;
      
      if (!disputeId || !resolutionType || !resolution) {
        res.status(400).json({ error: "Dispute ID, resolution type, and resolution are required" });
        return;
      }

      const disputeRef = db.collection('disputes').doc(disputeId as string);
      const disputeDoc = await disputeRef.get();
      
      if (!disputeDoc.exists) {
        res.status(404).json({ error: "Dispute not found" });
        return;
      }

      const disputeData = disputeDoc.data()!;

      if (disputeData.status === 'resolved') {
        res.status(400).json({ error: "Dispute is already resolved" });
        return;
      }

      // Execute resolution actions
      await executeResolution(disputeData, resolutionType, compensation);

      const timelineEntry = {
        action: 'resolved',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        userId,
        role: 'admin',
        details: `Resolved with ${resolutionType}`
      };

      await disputeRef.update({
        status: 'resolved',
        resolutionType,
        resolution,
        compensation: compensation || null,
        resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
        resolvedBy: userId,
        timeline: admin.firestore.FieldValue.arrayUnion(timelineEntry),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        internalNotes: notes ? admin.firestore.FieldValue.arrayUnion({
          note: notes,
          addedBy: userId,
          timestamp: admin.firestore.FieldValue.serverTimestamp()
        }) : admin.firestore.FieldValue.delete()
      });

      // Update contract status
      await db.collection('contracts').doc(disputeData.contractId).update({
        status: getContractStatusAfterResolution(resolutionType),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Notify parties of resolution
      await notifyDisputeResolution(disputeId as string, disputeData, resolutionType, resolution);

      logger.info("Dispute resolved", { 
        disputeId, 
        resolutionType, 
        resolvedBy: userId 
      });

      res.json({ success: true });
    } catch (error: any) {
      logger.error("Failed to resolve dispute", { error: error.message });
      res.status(500).json({ error: "Failed to resolve dispute" });
    }
  })
);

/**
 * Get disputes for a user
 * GET /home/disputes/mine
 */
export const getUserDisputes = withMetrics("getUserDisputes",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { status, limit = 20 } = req.query;

      let query = db.collection('disputes');
      
      // User can see disputes where they are customer or professional
      const [customerDisputes, proDisputes] = await Promise.all([
        query.where('customerId', '==', userId).get(),
        query.where('proId', '==', userId).get()
      ]);

      let allDisputes = [
        ...customerDisputes.docs.map(doc => ({ id: doc.id, ...doc.data() })),
        ...proDisputes.docs.map(doc => ({ id: doc.id, ...doc.data() }))
      ];

      // Filter by status if provided
      if (status) {
        allDisputes = allDisputes.filter(dispute => dispute.status === status);
      }

      // Sort by creation date (newest first)
      allDisputes.sort((a, b) => {
        const aTime = a.createdAt?.toMillis() || 0;
        const bTime = b.createdAt?.toMillis() || 0;
        return bTime - aTime;
      });

      // Limit results
      allDisputes = allDisputes.slice(0, Number(limit));

      res.json({ disputes: allDisputes });
    } catch (error: any) {
      logger.error("Failed to get user disputes", { error: error.message });
      res.status(500).json({ error: "Failed to get disputes" });
    }
  })
);

/**
 * Admin: Get all disputes with filters
 * GET /home/disputes/admin
 */
export const getAdminDisputes = withMetrics("getAdminDisputes",
  onRequest({ cors: true }, async (req, res) => {
    try {
      if (!req.auth?.token?.admin) {
        res.status(403).json({ error: "Admin access required" });
        return;
      }

      const { status, priority, assignedTo, limit = 50 } = req.query;

      let query = db.collection('disputes').orderBy('createdAt', 'desc');
      
      if (status) {
        query = query.where('status', '==', status);
      }
      
      if (priority) {
        query = query.where('priority', '==', priority);
      }
      
      if (assignedTo) {
        query = query.where('assignedTo', '==', assignedTo);
      }

      const snapshot = await query.limit(Number(limit)).get();
      
      const disputes = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));

      res.json({ disputes });
    } catch (error: any) {
      logger.error("Failed to get admin disputes", { error: error.message });
      res.status(500).json({ error: "Failed to get admin disputes" });
    }
  })
);

/**
 * Get dispute details
 * GET /home/disputes/:id
 */
export const getDisputeDetails = withMetrics("getDisputeDetails",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { disputeId } = req.query;
      
      if (!disputeId) {
        res.status(400).json({ error: "Dispute ID is required" });
        return;
      }

      const disputeDoc = await db.collection('disputes').doc(disputeId as string).get();
      
      if (!disputeDoc.exists) {
        res.status(404).json({ error: "Dispute not found" });
        return;
      }

      const disputeData = disputeDoc.data()!;

      // Check if user has access to this dispute
      const hasAccess = disputeData.customerId === userId || 
                       disputeData.proId === userId ||
                       req.auth?.token?.admin;
      
      if (!hasAccess) {
        res.status(403).json({ error: "Access denied" });
        return;
      }

      // Get related contract details
      const contractDoc = await db.collection('contracts').doc(disputeData.contractId).get();
      const contractData = contractDoc.exists ? contractDoc.data() : null;

      res.json({
        dispute: { id: disputeDoc.id, ...disputeData },
        contract: contractData ? { id: contractDoc.id, ...contractData } : null
      });
    } catch (error: any) {
      logger.error("Failed to get dispute details", { error: error.message });
      res.status(500).json({ error: "Failed to get dispute details" });
    }
  })
);

/**
 * Auto-escalate disputes that are overdue
 */
export const autoEscalateDisputes = withMetrics("autoEscalateDisputes",
  onRequest({ cors: true }, async () => {
    try {
      const now = admin.firestore.Timestamp.now();
      
      // Find overdue disputes
      const overdueDisputes = await db.collection('disputes')
        .where('status', 'in', ['open', 'investigating'])
        .where('dueDate', '<', now)
        .where('escalationLevel', '<', 3)
        .get();

      for (const disputeDoc of overdueDisputes.docs) {
        const disputeData = disputeDoc.data();
        const newEscalationLevel = Math.min(disputeData.escalationLevel + 1, 3);
        
        await disputeDoc.ref.update({
          escalationLevel: newEscalationLevel,
          dueDate: admin.firestore.Timestamp.fromDate(
            new Date(Date.now() + 3 * 24 * 60 * 60 * 1000) // Extend by 3 days
          ),
          timeline: admin.firestore.FieldValue.arrayUnion({
            action: 'escalated',
            timestamp: now,
            userId: 'system',
            role: 'system',
            details: `Auto-escalated to level ${newEscalationLevel}`
          }),
          updatedAt: now
        });
        
        logger.info("Dispute auto-escalated", { 
          disputeId: disputeDoc.id, 
          escalationLevel: newEscalationLevel 
        });
      }

      logger.info("Auto-escalation completed", { 
        processedCount: overdueDisputes.size 
      });
    } catch (error: any) {
      logger.error("Failed to auto-escalate disputes", { error: error.message });
    }
  })
);

// Helper Functions

function calculateDisputePriority(reason: string, contractData: any): 'low' | 'medium' | 'high' | 'urgent' {
  // High value contracts get higher priority
  if (contractData.priceMAD > 5000) return 'high';
  
  // Certain reasons get higher priority
  const highPriorityReasons = ['payment_dispute', 'safety_concern'];
  if (highPriorityReasons.includes(reason)) return 'high';
  
  const mediumPriorityReasons = ['quality_issues', 'timeline'];
  if (mediumPriorityReasons.includes(reason)) return 'medium';
  
  return 'low';
}

async function assignToCustomerService(disputeId: string) {
  // Auto-assign to available customer service agent
  // In production, this would use a queue system
  const timelineEntry = {
    action: 'auto_assigned',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    userId: 'system',
    role: 'system',
    details: 'Auto-assigned to customer service queue'
  };

  await db.collection('disputes').doc(disputeId).update({
    assignedTo: 'customer_service_queue',
    assignedAt: admin.firestore.FieldValue.serverTimestamp(),
    timeline: admin.firestore.FieldValue.arrayUnion(timelineEntry),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
}

async function executeResolution(disputeData: any, resolutionType: string, compensation: any) {
  // Execute different types of resolutions
  switch (resolutionType) {
    case 'refund':
      await processRefund(disputeData, compensation);
      break;
    case 'partial_refund':
      await processPartialRefund(disputeData, compensation);
      break;
    case 'compensation':
      await processCompensation(disputeData, compensation);
      break;
    case 'redo_work':
      await scheduleRedoWork(disputeData);
      break;
    // Add more resolution types as needed
  }
}

async function processRefund(disputeData: any, compensation: any) {
  // In production, integrate with payment processor for refunds
  const escrowSnapshot = await db.collection('escrows')
    .where('contractId', '==', disputeData.contractId)
    .limit(1)
    .get();

  if (!escrowSnapshot.empty) {
    const escrowDoc = escrowSnapshot.docs[0];
    await escrowDoc.ref.update({
      status: 'refunded',
      refund: {
        amount: compensation?.amount || escrowDoc.data().totalAmount,
        reason: 'dispute_resolution',
        processedAt: admin.firestore.FieldValue.serverTimestamp()
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  }
}

async function processPartialRefund(disputeData: any, compensation: any) {
  // Similar to refund but with partial amount
  await processRefund(disputeData, { 
    ...compensation, 
    amount: compensation?.amount || 0 
  });
}

async function processCompensation(disputeData: any, compensation: any) {
  // Add compensation to customer account or process separate payment
  // Implementation depends on payment system
  logger.info("Processing compensation", { 
    disputeId: disputeData.id, 
    amount: compensation?.amount 
  });
}

async function scheduleRedoWork(disputeData: any) {
  // Reset contract to allow work to be redone
  await db.collection('contracts').doc(disputeData.contractId).update({
    status: 'active',
    redoScheduled: true,
    redoScheduledAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
}

function getContractStatusAfterResolution(resolutionType: string): string {
  switch (resolutionType) {
    case 'refund':
    case 'partial_refund':
      return 'cancelled';
    case 'redo_work':
      return 'active';
    case 'compensation':
      return 'completed';
    default:
      return 'completed';
  }
}

async function notifyDisputeCreated(disputeId: string, disputeData: any) {
  // Notify the respondent about the new dispute
  const notificationData = {
    userId: disputeData.respondentId,
    type: 'dispute_created',
    title: 'New Dispute Created',
    message: `A dispute has been created for contract ${disputeData.contractId}`,
    data: {
      disputeId,
      contractId: disputeData.contractId,
      reason: disputeData.reason
    },
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    read: false
  };

  await db.collection('notifications').add(notificationData);
}

async function notifyDisputeResponse(disputeId: string, disputeData: any, responseData: any) {
  // Notify other parties when someone responds
  const notifyUsers = [disputeData.customerId, disputeData.proId].filter(
    id => id !== responseData.userId
  );

  for (const userId of notifyUsers) {
    const notificationData = {
      userId,
      type: 'dispute_response',
      title: 'New Dispute Response',
      message: `New response added to dispute ${disputeId}`,
      data: {
        disputeId,
        contractId: disputeData.contractId,
        responderId: responseData.userId
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false
    };

    await db.collection('notifications').add(notificationData);
  }
}

async function notifyDisputeResolution(disputeId: string, disputeData: any, resolutionType: string, resolution: string) {
  // Notify both parties of resolution
  const notifyUsers = [disputeData.customerId, disputeData.proId];

  for (const userId of notifyUsers) {
    const notificationData = {
      userId,
      type: 'dispute_resolved',
      title: 'Dispute Resolved',
      message: `Your dispute has been resolved: ${resolutionType}`,
      data: {
        disputeId,
        contractId: disputeData.contractId,
        resolutionType,
        resolution
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false
    };

    await db.collection('notifications').add(notificationData);
  }
}