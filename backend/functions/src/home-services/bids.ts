import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { withMetrics } from "../shared/metrics";

try { admin.app(); } catch { admin.initializeApp(); }

const db = admin.firestore();

/**
 * Submit a bid on an RFQ (HTTP)
 * POST /home/bids
 */
export const submitBidHttp = withMetrics("submitBidHttp",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { rfqId, proposal, priceMAD, milestones, timeline } = req.body;

      if (!rfqId || !proposal || priceMAD == null) {
        res.status(400).json({ error: "RFQ ID, proposal, and price are required" });
        return;
      }

      // Validate RFQ exists and is open
      const rfqDoc = await db.collection('rfqs').doc(rfqId).get();
      if (!rfqDoc.exists) {
        res.status(400).json({ error: "RFQ not found" });
        return;
      }

      const rfqData = rfqDoc.data()!;
      if (rfqData.status !== 'open') {
        res.status(400).json({ error: "RFQ is not open for bidding" });
        return;
      }

      // Can't bid on own RFQ
      if (rfqData.customerId === userId) {
        res.status(400).json({ error: "Cannot bid on your own RFQ" });
        return;
      }

      // Check if user already has a bid on this RFQ
      const existingBid = await db.collection('bids')
        .where('rfqId', '==', rfqId)
        .where('proId', '==', userId)
        .get();

      if (!existingBid.empty) {
        res.status(400).json({ error: "You have already submitted a bid for this RFQ" });
        return;
      }

      const bidData = {
        rfqId,
        proId: userId,
        customerId: rfqData.customerId,
        proposal: {
          description: proposal.description,
          approach: proposal.approach || null,
          experience: proposal.experience || null,
          portfolio: proposal.portfolio || []
        },
        priceMAD: Number(priceMAD),
        milestones: milestones || [],
        timeline: timeline ? {
          estimatedDays: timeline.estimatedDays,
          startDate: timeline.startDate ? admin.firestore.Timestamp.fromDate(new Date(timeline.startDate)) : null,
          details: timeline.details || null
        } : null,
        status: 'submitted',
        negotiationRound: 0,
        maxNegotiationRounds: 3,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      // Use transaction to create bid and update RFQ
      await db.runTransaction(async (transaction) => {
        const bidRef = db.collection('bids').doc();
        transaction.set(bidRef, bidData);
        
        // Increment bid count on RFQ
        transaction.update(rfqDoc.ref, {
          bidCount: admin.firestore.FieldValue.increment(1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      });

      logger.info("Bid submitted", { 
        rfqId, 
        proId: userId, 
        priceMAD 
      });

      res.json({
        success: true,
        bidId: rfqId + "_" + userId
      });
    } catch (error: any) {
      logger.error("Failed to submit bid", { error: error.message });
      res.status(500).json({ error: "Failed to submit bid" });
    }
  })
);

/**
 * Get bids for an RFQ (customer view)
 * GET /home/rfqs/:rfqId/bids
 */
export const getRFQBids = withMetrics("getRFQBids",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { rfqId } = req.query;
      
      if (!rfqId) {
        res.status(400).json({ error: "RFQ ID is required" });
        return;
      }

      // Verify user owns this RFQ
      const rfqDoc = await db.collection('rfqs').doc(rfqId as string).get();
      if (!rfqDoc.exists) {
        res.status(404).json({ error: "RFQ not found" });
        return;
      }

      const rfqData = rfqDoc.data()!;
      if (rfqData.customerId !== userId) {
        res.status(403).json({ error: "Access denied" });
        return;
      }

      const bidsSnapshot = await db.collection('bids')
        .where('rfqId', '==', rfqId)
        .orderBy('createdAt', 'desc')
        .get();

      const bids = bidsSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));

      res.json({ bids });
    } catch (error: any) {
      logger.error("Failed to get RFQ bids", { error: error.message });
      res.status(500).json({ error: "Failed to get bids" });
    }
  })
);

/**
 * Get professional's bids
 * GET /home/bids/mine
 */
export const getMyBids = withMetrics("getMyBids",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const bidsSnapshot = await db.collection('bids')
        .where('proId', '==', userId)
        .orderBy('createdAt', 'desc')
        .get();

      const bids = bidsSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));

      res.json({ bids });
    } catch (error: any) {
      logger.error("Failed to get my bids", { error: error.message });
      res.status(500).json({ error: "Failed to get my bids" });
    }
  })
);

/**
 * Get a specific bid
 * GET /home/bids/:id
 */
export const getBid = withMetrics("getBid",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { bidId } = req.query;
      
      if (!bidId) {
        res.status(400).json({ error: "Bid ID is required" });
        return;
      }

      const bidDoc = await db.collection('bids').doc(bidId as string).get();
      
      if (!bidDoc.exists) {
        res.status(404).json({ error: "Bid not found" });
        return;
      }

      const bidData = bidDoc.data()!;

      // Check if user has permission to view this bid
      const isProOwner = bidData.proId === userId;
      const isCustomer = bidData.customerId === userId;
      
      if (!isProOwner && !isCustomer) {
        res.status(403).json({ error: "Access denied" });
        return;
      }

      res.json({
        id: bidDoc.id,
        ...bidData
      });
    } catch (error: any) {
      logger.error("Failed to get bid", { error: error.message });
      res.status(500).json({ error: "Failed to get bid" });
    }
  })
);

/**
 * Accept a bid (customer action) (HTTP)
 * POST /home/bids/:id/accept
 */
export const acceptBidHttp = withMetrics("acceptBidHttp",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { bidId } = req.query;
      const { depositPercent = 20 } = req.body;
      
      if (!bidId) {
        res.status(400).json({ error: "Bid ID is required" });
        return;
      }

      await db.runTransaction(async (transaction) => {
        const bidRef = db.collection('bids').doc(bidId as string);
        const bidDoc = await transaction.get(bidRef);
        
        if (!bidDoc.exists) {
          throw new Error("Bid not found");
        }

        const bidData = bidDoc.data()!;

        // Verify user is the customer
        if (bidData.customerId !== userId) {
          throw new Error("Access denied");
        }

        // Verify bid is still valid
        if (bidData.status !== 'submitted' && bidData.status !== 'negotiating') {
          throw new Error("Bid is no longer available");
        }

        // Get the RFQ
        const rfqRef = db.collection('rfqs').doc(bidData.rfqId);
        const rfqDoc = await transaction.get(rfqRef);
        
        if (!rfqDoc.exists) {
          throw new Error("RFQ not found");
        }

        const rfqData = rfqDoc.data()!;
        if (rfqData.status !== 'open') {
          throw new Error("RFQ is no longer open");
        }

        // Calculate deposit amount
        const depositAmount = Math.round(bidData.priceMAD * (depositPercent / 100));

        // Create contract
        const contractData = {
          rfqId: bidData.rfqId,
          bidId: bidDoc.id,
          customerId: bidData.customerId,
          proId: bidData.proId,
          agreedScope: rfqData.scope,
          priceMAD: bidData.priceMAD,
          milestones: bidData.milestones || [],
          status: 'pending_payment',
          depositAmount,
          depositPercent,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          startAt: null,
          completedAt: null
        };

        const contractRef = db.collection('contracts').doc();
        transaction.set(contractRef, contractData);

        // Update bid status
        transaction.update(bidRef, {
          status: 'accepted',
          acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // Update RFQ status
        transaction.update(rfqRef, {
          status: 'awarded',
          awardedBidId: bidDoc.id,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // Reject all other bids
        const otherBidsSnapshot = await db.collection('bids')
          .where('rfqId', '==', bidData.rfqId)
          .where('status', 'in', ['submitted', 'negotiating'])
          .get();

        otherBidsSnapshot.docs.forEach(doc => {
          if (doc.id !== bidDoc.id) {
            transaction.update(doc.ref, {
              status: 'rejected',
              rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
          }
        });

        return contractRef.id;
      });

      logger.info("Bid accepted", { 
        bidId, 
        customerId: userId,
        depositPercent
      });

      res.json({ success: true });
    } catch (error: any) {
      logger.error("Failed to accept bid", { error: error.message });
      res.status(500).json({ error: error.message || "Failed to accept bid" });
    }
  })
);

/**
 * Counter-offer on a bid (customer action) (HTTP)
 * POST /home/bids/:id/counter
 */
export const counterOfferHttp = withMetrics("counterOfferHttp",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { bidId } = req.query;
      const { priceMAD, message, milestones } = req.body;
      
      if (!bidId || priceMAD == null) {
        res.status(400).json({ error: "Bid ID and price are required" });
        return;
      }

      const bidRef = db.collection('bids').doc(bidId as string);
      const bidDoc = await bidRef.get();
      
      if (!bidDoc.exists) {
        res.status(404).json({ error: "Bid not found" });
        return;
      }

      const bidData = bidDoc.data()!;

      // Verify user is the customer
      if (bidData.customerId !== userId) {
        res.status(403).json({ error: "Access denied" });
        return;
      }

      // Check negotiation limits
      if (bidData.negotiationRound >= bidData.maxNegotiationRounds) {
        res.status(400).json({ error: "Maximum negotiation rounds reached" });
        return;
      }

      // Verify bid is in valid state for negotiation
      if (!['submitted', 'negotiating'].includes(bidData.status)) {
        res.status(400).json({ error: "Bid cannot be negotiated in current state" });
        return;
      }

      const counterOfferData = {
        priceMAD: Number(priceMAD),
        milestones: milestones || bidData.milestones,
        message: message || null,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        round: bidData.negotiationRound + 1,
        from: 'customer'
      };

      await bidRef.update({
        status: 'negotiating',
        negotiationRound: admin.firestore.FieldValue.increment(1),
        lastCounterOffer: counterOfferData,
        counterOffers: admin.firestore.FieldValue.arrayUnion(counterOfferData),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      logger.info("Counter offer submitted", { 
        bidId, 
        customerId: userId,
        priceMAD,
        round: bidData.negotiationRound + 1
      });

      res.json({ success: true });
    } catch (error: any) {
      logger.error("Failed to submit counter offer", { error: error.message });
      res.status(500).json({ error: "Failed to submit counter offer" });
    }
  })
);

/**
 * Respond to counter-offer (professional action) (HTTP)
 * POST /home/bids/:id/respond
 */
export const respondToCounterHttp = withMetrics("respondToCounterHttp",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { bidId } = req.query;
      const { action, priceMAD, message, milestones } = req.body;
      
      if (!bidId || !action) {
        res.status(400).json({ error: "Bid ID and action are required" });
        return;
      }

      const bidRef = db.collection('bids').doc(bidId as string);
      const bidDoc = await bidRef.get();
      
      if (!bidDoc.exists) {
        res.status(404).json({ error: "Bid not found" });
        return;
      }

      const bidData = bidDoc.data()!;

      // Verify user is the professional
      if (bidData.proId !== userId) {
        res.status(403).json({ error: "Access denied" });
        return;
      }

      if (action === 'accept') {
        // Accept the customer's counter-offer
        const lastOffer = bidData.lastCounterOffer;
        if (!lastOffer) {
          res.status(400).json({ error: "No counter-offer to accept" });
          return;
        }

        await bidRef.update({
          priceMAD: lastOffer.priceMAD,
          milestones: lastOffer.milestones || bidData.milestones,
          status: 'submitted',
          counterOfferAccepted: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        logger.info("Counter offer accepted", { bidId, proId: userId });

      } else if (action === 'counter') {
        // Submit a new counter-offer
        if (priceMAD == null) {
          res.status(400).json({ error: "Price is required for counter-offer" });
          return;
        }

        // Check negotiation limits
        if (bidData.negotiationRound >= bidData.maxNegotiationRounds) {
          res.status(400).json({ error: "Maximum negotiation rounds reached" });
          return;
        }

        const counterOfferData = {
          priceMAD: Number(priceMAD),
          milestones: milestones || bidData.milestones,
          message: message || null,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          round: bidData.negotiationRound + 1,
          from: 'professional'
        };

        await bidRef.update({
          negotiationRound: admin.firestore.FieldValue.increment(1),
          lastCounterOffer: counterOfferData,
          counterOffers: admin.firestore.FieldValue.arrayUnion(counterOfferData),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        logger.info("Professional counter offer", { bidId, proId: userId, priceMAD });

      } else if (action === 'decline') {
        // Decline the negotiation
        await bidRef.update({
          status: 'declined',
          declinedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        logger.info("Counter offer declined", { bidId, proId: userId });

      } else {
        res.status(400).json({ error: "Invalid action" });
        return;
      }

      res.json({ success: true });
    } catch (error: any) {
      logger.error("Failed to respond to counter offer", { error: error.message });
      res.status(500).json({ error: "Failed to respond to counter offer" });
    }
  })
);

/**
 * Withdraw a bid (professional action) (HTTP)
 * DELETE /home/bids/:id
 */
export const withdrawBidHttp = withMetrics("withdrawBidHttp",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { bidId } = req.query;
      
      if (!bidId) {
        res.status(400).json({ error: "Bid ID is required" });
        return;
      }

      const bidRef = db.collection('bids').doc(bidId as string);
      const bidDoc = await bidRef.get();
      
      if (!bidDoc.exists) {
        res.status(404).json({ error: "Bid not found" });
        return;
      }

      const bidData = bidDoc.data()!;

      // Verify user is the professional
      if (bidData.proId !== userId) {
        res.status(403).json({ error: "Access denied" });
        return;
      }

      // Can't withdraw accepted bids
      if (bidData.status === 'accepted') {
        res.status(400).json({ error: "Cannot withdraw accepted bid" });
        return;
      }

      await bidRef.update({
        status: 'withdrawn',
        withdrawnAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      logger.info("Bid withdrawn", { bidId, proId: userId });

      res.json({ success: true });
    } catch (error: any) {
      logger.error("Failed to withdraw bid", { error: error.message });
      res.status(500).json({ error: "Failed to withdraw bid" });
    }
  })
);