import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { withMetrics } from "../shared/metrics";

try { admin.app(); } catch { admin.initializeApp(); }

const db = admin.firestore();

/**
 * Create a new RFQ (Request for Quote) (HTTP)
 * POST /home/rfqs
 */
export const createRFQHttp = withMetrics("createRFQHttp",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { categoryId, scope, location, budgetRange } = req.body;

      if (!categoryId || !scope || !location) {
        res.status(400).json({ error: "Category, scope, and location are required" });
        return;
      }

      // Validate category exists
      const categoryDoc = await db.collection('serviceCategories').doc(categoryId).get();
      if (!categoryDoc.exists) {
        res.status(400).json({ error: "Invalid category" });
        return;
      }

      const rfqData = {
        customerId: userId,
        categoryId,
        scope: {
          title: scope.title,
          description: scope.description,
          urgency: scope.urgency || 'flexible',
          serviceDate: scope.serviceDate ? admin.firestore.Timestamp.fromDate(new Date(scope.serviceDate)) : null,
          timeWindow: scope.timeWindow || null,
          requirements: scope.requirements || [],
          photos: scope.photos || []
        },
        location: {
          address: location.address,
          coordinates: new admin.firestore.GeoPoint(location.coordinates.latitude, location.coordinates.longitude),
          city: location.city,
          region: location.region
        },
        budgetRange: budgetRange ? {
          minMAD: budgetRange.minMAD,
          maxMAD: budgetRange.maxMAD,
          currency: "MAD"
        } : null,
        status: 'open',
        bidCount: 0,
        viewCount: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) // 7 days from now
        )
      };

      const docRef = await db.collection('rfqs').add(rfqData);

      logger.info("RFQ created", { 
        rfqId: docRef.id, 
        customerId: userId, 
        categoryId 
      });

      res.json({
        rfqId: docRef.id,
        ...rfqData
      });
    } catch (error: any) {
      logger.error("Failed to create RFQ", { error: error.message });
      res.status(500).json({ error: "Failed to create RFQ" });
    }
  })
);

/**
 * Get all RFQs for a customer
 * GET /home/rfqs?customerId=:id
 */
export const getCustomerRFQs = withMetrics("getCustomerRFQs",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const snapshot = await db.collection('rfqs')
        .where('customerId', '==', userId)
        .orderBy('createdAt', 'desc')
        .get();

      const rfqs = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));

      res.json({ rfqs });
    } catch (error: any) {
      logger.error("Failed to get customer RFQs", { error: error.message });
      res.status(500).json({ error: "Failed to get RFQs" });
    }
  })
);

/**
 * Get available RFQs for professionals to bid on
 * GET /home/rfqs/available?categoryId=:id&location=:lat,:lng&radius=:km
 */
export const getAvailableRFQs = withMetrics("getAvailableRFQs",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { categoryId, location, radius = 50 } = req.query;

      let query = db.collection('rfqs')
        .where('status', '==', 'open')
        .where('expiresAt', '>', admin.firestore.Timestamp.now());

      if (categoryId) {
        query = query.where('categoryId', '==', categoryId);
      }

      const snapshot = await query
        .orderBy('expiresAt')
        .orderBy('createdAt', 'desc')
        .limit(50)
        .get();

      let rfqs = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));

      // Filter by location if provided
      if (location && typeof location === 'string') {
        const [lat, lng] = location.split(',').map(Number);
        if (!isNaN(lat) && !isNaN(lng)) {
          const radiusKm = Number(radius);
          rfqs = rfqs.filter(rfq => {
            if (!rfq.location?.coordinates) return true;
            const distance = calculateDistance(
              lat, lng,
              rfq.location.coordinates.latitude,
              rfq.location.coordinates.longitude
            );
            return distance <= radiusKm;
          });
        }
      }

      res.json({ rfqs });
    } catch (error: any) {
      logger.error("Failed to get available RFQs", { error: error.message });
      res.status(500).json({ error: "Failed to get available RFQs" });
    }
  })
);

/**
 * Get a specific RFQ by ID
 * GET /home/rfqs/:id
 */
export const getRFQ = withMetrics("getRFQ",
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

      const doc = await db.collection('rfqs').doc(rfqId as string).get();
      
      if (!doc.exists) {
        res.status(404).json({ error: "RFQ not found" });
        return;
      }

      const rfqData = doc.data()!;

      // Check if user has permission to view this RFQ
      const isOwner = rfqData.customerId === userId;
      const isPublicView = rfqData.status === 'open';
      
      if (!isOwner && !isPublicView) {
        res.status(403).json({ error: "Access denied" });
        return;
      }

      // Increment view count for non-owners
      if (!isOwner) {
        await doc.ref.update({
          viewCount: admin.firestore.FieldValue.increment(1)
        });
      }

      res.json({
        id: doc.id,
        ...rfqData
      });
    } catch (error: any) {
      logger.error("Failed to get RFQ", { error: error.message });
      res.status(500).json({ error: "Failed to get RFQ" });
    }
  })
);

/**
 * Update an RFQ
 * PUT /home/rfqs/:id
 */
export const updateRFQ = withMetrics("updateRFQ",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { rfqId } = req.query;
      const updates = req.body;

      if (!rfqId) {
        res.status(400).json({ error: "RFQ ID is required" });
        return;
      }

      const doc = await db.collection('rfqs').doc(rfqId as string).get();
      
      if (!doc.exists) {
        res.status(404).json({ error: "RFQ not found" });
        return;
      }

      const rfqData = doc.data()!;

      // Only owner can update
      if (rfqData.customerId !== userId) {
        res.status(403).json({ error: "Only the RFQ owner can update it" });
        return;
      }

      // Can't update if RFQ is not open
      if (rfqData.status !== 'open') {
        res.status(400).json({ error: "Cannot update RFQ that is not open" });
        return;
      }

      // Remove fields that shouldn't be updated directly
      delete updates.customerId;
      delete updates.createdAt;
      delete updates.bidCount;
      delete updates.viewCount;
      updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();

      await doc.ref.update(updates);

      logger.info("RFQ updated", { rfqId, customerId: userId });

      res.json({ success: true });
    } catch (error: any) {
      logger.error("Failed to update RFQ", { error: error.message });
      res.status(500).json({ error: "Failed to update RFQ" });
    }
  })
);

/**
 * Cancel an RFQ
 * DELETE /home/rfqs/:id
 */
export const cancelRFQ = withMetrics("cancelRFQ",
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

      const doc = await db.collection('rfqs').doc(rfqId as string).get();
      
      if (!doc.exists) {
        res.status(404).json({ error: "RFQ not found" });
        return;
      }

      const rfqData = doc.data()!;

      // Only owner can cancel
      if (rfqData.customerId !== userId) {
        res.status(403).json({ error: "Only the RFQ owner can cancel it" });
        return;
      }

      // Can't cancel if already has accepted bid
      if (rfqData.status === 'awarded') {
        res.status(400).json({ error: "Cannot cancel RFQ with accepted bid" });
        return;
      }

      await doc.ref.update({
        status: 'cancelled',
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      logger.info("RFQ cancelled", { rfqId, customerId: userId });

      res.json({ success: true });
    } catch (error: any) {
      logger.error("Failed to cancel RFQ", { error: error.message });
      res.status(500).json({ error: "Failed to cancel RFQ" });
    }
  })
);

// Helper function to calculate distance between two coordinates
function calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371; // Radius of the Earth in kilometers
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = 
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}