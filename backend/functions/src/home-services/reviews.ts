import { onRequest } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { withMetrics } from "../shared/metrics";

try { admin.app(); } catch { admin.initializeApp(); }

const db = admin.firestore();

/**
 * Create a review for a completed contract
 * POST /home/reviews
 */
export const createReview = withMetrics("createReview",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { contractId, rating, text, categories } = req.body;
      
      if (!contractId || rating == null) {
        res.status(400).json({ error: "Contract ID and rating are required" });
        return;
      }

      if (rating < 1 || rating > 5) {
        res.status(400).json({ error: "Rating must be between 1 and 5" });
        return;
      }

      // Validate contract and user permissions
      const contractDoc = await db.collection('contracts').doc(contractId).get();
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
        .limit(1)
        .get();

      if (!existingReview.empty) {
        res.status(400).json({ error: "Review already exists for this contract" });
        return;
      }

      // Check for fraud patterns
      const fraudCheck = await checkForFraudPatterns(userId, rating, contractData);
      if (fraudCheck.isSuspicious) {
        logger.warn("Suspicious review detected", { 
          contractId, 
          reviewerId: userId, 
          reasons: fraudCheck.reasons 
        });
      }

      const reviewData = {
        contractId,
        rfqId: contractData.rfqId,
        reviewerId: userId,
        revieweeId: isCustomer ? contractData.proId : contractData.customerId,
        reviewerRole: isCustomer ? 'customer' : 'professional',
        revieweeRole: isCustomer ? 'professional' : 'customer',
        rating: Number(rating),
        text: text || null,
        categories: categories || [], // Array of category-specific ratings
        contractValue: contractData.priceMAD,
        serviceCategory: contractData.categoryId || null,
        isSuspicious: fraudCheck.isSuspicious,
        fraudReasons: fraudCheck.reasons,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      const reviewRef = await db.collection('reviews').add(reviewData);

      logger.info("Review created", { 
        reviewId: reviewRef.id,
        contractId, 
        reviewerId: userId, 
        rating,
        reviewerRole: reviewData.reviewerRole,
        isSuspicious: fraudCheck.isSuspicious
      });

      res.json({ 
        reviewId: reviewRef.id,
        success: true 
      });
    } catch (error: any) {
      logger.error("Failed to create review", { error: error.message });
      res.status(500).json({ error: "Failed to create review" });
    }
  })
);

/**
 * Get reviews for a professional
 * GET /home/reviews/pro/:proId
 */
export const getProfessionalReviews = withMetrics("getProfessionalReviews",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const { proId } = req.query;
      const { limit = 20, offset = 0, category } = req.query;
      
      if (!proId) {
        res.status(400).json({ error: "Professional ID is required" });
        return;
      }

      let query = db.collection('reviews')
        .where('revieweeId', '==', proId)
        .where('revieweeRole', '==', 'professional')
        .where('isSuspicious', '==', false); // Only show non-suspicious reviews

      if (category) {
        query = query.where('serviceCategory', '==', category);
      }

      const snapshot = await query
        .orderBy('createdAt', 'desc')
        .limit(Number(limit))
        .offset(Number(offset))
        .get();

      const reviews = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
        // Don't expose fraud detection fields to public
        isSuspicious: undefined,
        fraudReasons: undefined
      }));

      res.json({ 
        reviews,
        hasMore: snapshot.size === Number(limit)
      });
    } catch (error: any) {
      logger.error("Failed to get professional reviews", { error: error.message });
      res.status(500).json({ error: "Failed to get reviews" });
    }
  })
);

/**
 * Get aggregated rating stats for a professional
 * GET /home/reviews/pro/:proId/stats
 */
export const getProfessionalRatingStats = withMetrics("getProfessionalRatingStats",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const { proId } = req.query;
      
      if (!proId) {
        res.status(400).json({ error: "Professional ID is required" });
        return;
      }

      // Get cached stats first
      const statsDoc = await db.collection('proRatingStats').doc(proId as string).get();
      
      if (statsDoc.exists) {
        const stats = statsDoc.data()!;
        
        // Check if stats are recent (within 1 hour)
        const lastUpdate = stats.lastUpdated?.toDate() || new Date(0);
        const hourAgo = new Date(Date.now() - 60 * 60 * 1000);
        
        if (lastUpdate > hourAgo) {
          res.json(stats);
          return;
        }
      }

      // Recalculate stats if not cached or stale
      const stats = await calculateProfessionalStats(proId as string);
      
      // Cache the updated stats
      await db.collection('proRatingStats').doc(proId as string).set({
        ...stats,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      });

      res.json(stats);
    } catch (error: any) {
      logger.error("Failed to get professional rating stats", { error: error.message });
      res.status(500).json({ error: "Failed to get rating stats" });
    }
  })
);

/**
 * Automatically update rating aggregations when new review is created
 */
export const updateRatingAggregations = withMetrics("updateRatingAggregations",
  onDocumentCreated("reviews/{reviewId}", async (event) => {
    const reviewData = event.data?.data();
    if (!reviewData || reviewData.isSuspicious) return;

    const { revieweeId, revieweeRole } = reviewData;
    
    if (revieweeRole === 'professional') {
      // Update professional rating stats
      await calculateAndCacheProfessionalStats(revieweeId);
    }
  })
);

/**
 * Report a review as inappropriate
 * POST /home/reviews/:reviewId/report
 */
export const reportReview = withMetrics("reportReview",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { reviewId } = req.query;
      const { reason, details } = req.body;
      
      if (!reviewId || !reason) {
        res.status(400).json({ error: "Review ID and reason are required" });
        return;
      }

      const reviewDoc = await db.collection('reviews').doc(reviewId as string).get();
      if (!reviewDoc.exists) {
        res.status(404).json({ error: "Review not found" });
        return;
      }

      const reportData = {
        reviewId: reviewId as string,
        reporterId: userId,
        reason,
        details: details || null,
        status: 'pending',
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      };

      const reportRef = await db.collection('reviewReports').add(reportData);

      logger.info("Review reported", { 
        reportId: reportRef.id,
        reviewId, 
        reporterId: userId, 
        reason 
      });

      res.json({ 
        reportId: reportRef.id,
        success: true 
      });
    } catch (error: any) {
      logger.error("Failed to report review", { error: error.message });
      res.status(500).json({ error: "Failed to report review" });
    }
  })
);

// Helper Functions

async function checkForFraudPatterns(reviewerId: string, rating: number, contractData: any): Promise<{isSuspicious: boolean, reasons: string[]}> {
  const reasons: string[] = [];
  
  try {
    // Check for rapid-fire reviews from same user
    const recentReviews = await db.collection('reviews')
      .where('reviewerId', '==', reviewerId)
      .where('createdAt', '>', admin.firestore.Timestamp.fromDate(new Date(Date.now() - 60 * 60 * 1000))) // Last hour
      .get();
    
    if (recentReviews.size > 3) {
      reasons.push('rapid_reviews');
    }

    // Check for unusual rating patterns
    const userReviews = await db.collection('reviews')
      .where('reviewerId', '==', reviewerId)
      .orderBy('createdAt', 'desc')
      .limit(10)
      .get();

    if (userReviews.size >= 5) {
      const ratings = userReviews.docs.map(doc => doc.data().rating);
      const avgRating = ratings.reduce((sum, r) => sum + r, 0) / ratings.length;
      
      // Flag if all ratings are 5 stars or all ratings are 1 star
      if (ratings.every(r => r === 5) || ratings.every(r => r === 1)) {
        reasons.push('uniform_ratings');
      }
      
      // Flag extreme deviation from user's average
      if (Math.abs(rating - avgRating) > 3) {
        reasons.push('rating_deviation');
      }
    }

    // Check contract value vs rating relationship
    if (contractData.priceMAD < 100 && rating === 5) {
      // Very small contract with perfect rating might be suspicious
      reasons.push('low_value_perfect_rating');
    }

    // Check for immediate review after completion
    const contractCompletedAt = contractData.completedAt?.toDate();
    if (contractCompletedAt) {
      const timeDiff = Date.now() - contractCompletedAt.getTime();
      if (timeDiff < 60000) { // Less than 1 minute
        reasons.push('immediate_review');
      }
    }

  } catch (error) {
    logger.error("Error checking fraud patterns", { error, reviewerId });
  }

  return {
    isSuspicious: reasons.length > 0,
    reasons
  };
}

async function calculateProfessionalStats(proId: string) {
  const reviewsSnapshot = await db.collection('reviews')
    .where('revieweeId', '==', proId)
    .where('revieweeRole', '==', 'professional')
    .where('isSuspicious', '==', false)
    .get();

  if (reviewsSnapshot.empty) {
    return {
      averageRating: 0,
      totalReviews: 0,
      ratingBreakdown: { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 },
      categoryBreakdown: {}
    };
  }

  const reviews = reviewsSnapshot.docs.map(doc => doc.data());
  const totalReviews = reviews.length;
  
  // Calculate average rating
  const totalRating = reviews.reduce((sum, review) => sum + review.rating, 0);
  const averageRating = Math.round((totalRating / totalReviews) * 10) / 10;

  // Calculate rating breakdown
  const ratingBreakdown = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
  reviews.forEach(review => {
    ratingBreakdown[review.rating as keyof typeof ratingBreakdown]++;
  });

  // Calculate category breakdown
  const categoryBreakdown: Record<string, {count: number, average: number}> = {};
  reviews.forEach(review => {
    if (review.serviceCategory) {
      if (!categoryBreakdown[review.serviceCategory]) {
        categoryBreakdown[review.serviceCategory] = { count: 0, average: 0 };
      }
      categoryBreakdown[review.serviceCategory].count++;
    }
  });

  // Calculate averages for each category
  Object.keys(categoryBreakdown).forEach(category => {
    const categoryReviews = reviews.filter(r => r.serviceCategory === category);
    const categoryTotal = categoryReviews.reduce((sum, review) => sum + review.rating, 0);
    categoryBreakdown[category].average = Math.round((categoryTotal / categoryReviews.length) * 10) / 10;
  });

  return {
    averageRating,
    totalReviews,
    ratingBreakdown,
    categoryBreakdown
  };
}

async function calculateAndCacheProfessionalStats(proId: string) {
  try {
    const stats = await calculateProfessionalStats(proId);
    
    await db.collection('proRatingStats').doc(proId).set({
      ...stats,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    });

    // Also update the professional profile with basic stats
    await db.collection('proProfiles').doc(proId).update({
      'rating.average': stats.averageRating,
      'rating.count': stats.totalReviews,
      'rating.breakdown': stats.ratingBreakdown,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    logger.info("Professional rating stats updated", { 
      proId, 
      averageRating: stats.averageRating, 
      totalReviews: stats.totalReviews 
    });
  } catch (error) {
    logger.error("Failed to update professional stats", { proId, error });
  }
}