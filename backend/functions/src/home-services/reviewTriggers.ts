import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import { withMetrics } from "../shared/metrics";

try { admin.app(); } catch { admin.initializeApp(); }

const db = admin.firestore();

export const updateRatingAggregations = withMetrics("updateRatingAggregations",
  onDocumentCreated("reviews/{reviewId}", async (event) => {
    const reviewData = event.data?.data();
    if (!reviewData || reviewData.isSuspicious) return;

    const { revieweeId, revieweeRole } = reviewData;
    if (revieweeRole === 'professional') {
      await calculateAndCacheProfessionalStats(revieweeId);
    }
  })
);

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
  const totalRating = reviews.reduce((sum, review: any) => sum + (review.rating || 0), 0);
  const averageRating = Math.round((totalRating / totalReviews) * 10) / 10;

  const ratingBreakdown: Record<number, number> = { 1:0, 2:0, 3:0, 4:0, 5:0 };
  reviews.forEach((r: any) => { if (r.rating) ratingBreakdown[r.rating] = (ratingBreakdown[r.rating] || 0) + 1; });

  const categoryBreakdown: Record<string, {count: number, average: number}> = {};
  reviews.forEach((r: any) => {
    if (r.serviceCategory) {
      if (!categoryBreakdown[r.serviceCategory]) categoryBreakdown[r.serviceCategory] = { count: 0, average: 0 };
      categoryBreakdown[r.serviceCategory].count++;
    }
  });
  Object.keys(categoryBreakdown).forEach((category) => {
    const rs = reviews.filter((r: any) => r.serviceCategory === category);
    const total = rs.reduce((sum, r: any) => sum + (r.rating || 0), 0);
    categoryBreakdown[category].average = Math.round((total / rs.length) * 10) / 10;
  });

  return { averageRating, totalReviews, ratingBreakdown, categoryBreakdown };
}

async function calculateAndCacheProfessionalStats(proId: string) {
  try {
    const stats = await calculateProfessionalStats(proId);
    await db.collection('proRatingStats').doc(proId).set({
      ...stats,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    });
    await db.collection('proProfiles').doc(proId).update({
      'rating.average': stats.averageRating,
      'rating.count': stats.totalReviews,
      'rating.breakdown': stats.ratingBreakdown,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    logger.info("Professional rating stats updated", { proId, averageRating: stats.averageRating, totalReviews: stats.totalReviews });
  } catch (e) {
    logger.error("Failed to update professional stats", { proId, e });
  }
}










