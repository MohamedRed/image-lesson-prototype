import { onCall, HttpsError, onRequest } from "firebase-functions/v2/https";
import { onDocumentWritten, onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { withMetrics } from "../shared/metrics";
import { logEvent } from "../shared/analytics";

/**
 * User Interaction Tracker
 * Records user interactions for AI recommendations
 */
export const trackUserInteraction = onCall(async (request) => {
  try {
    const { type, entityId, entityType, context } = request.data || {};
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Authentication required");
    if (!type || !entityId || !entityType) throw new HttpsError("invalid-argument", "Missing required fields");

    // Record interaction
    await admin.firestore().collection("userInteractions").add({
      userId,
      type, // view, click, order, favorite, share
      entityId,
      entityType, // restaurant, menuItem, cuisine
      context: context || null,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      sessionId: request.data?.sessionId || null
    });
    // Emit analytics-friendly funnel events for key interactions
    try {
      if (type === "restaurant_viewed" || type === "item_added_to_cart" || type === "checkout_started") {
        await logEvent(userId, type, { entityId, entityType });
      }
    } catch {}

    // Update user profile with interaction data
    await updateUserProfile(userId, type, entityId, entityType);

    return { success: true };

  } catch (error: any) {
    logger.error("Track user interaction failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Track user interaction failed");
  }
});

/**
 * Get Personalized Restaurant Recommendations
 * Returns AI-powered restaurant recommendations based on user history
 */
export const getPersonalizedRecommendations = onCall(async (request) => {
  try {
    const { latitude, longitude, timeOfDay, limit = 20 } = request.data || {};
    const userId = request.auth?.uid;

    if (!userId || latitude === undefined || longitude === undefined) {
      throw new HttpsError("invalid-argument", "Missing required fields");
    }

    const userLocation = { latitude: parseFloat(String(latitude)), longitude: parseFloat(String(longitude)) };

    // Get user profile and interaction history
    const userProfile = await getUserProfile(userId as string);
    const userInteractions = await getUserInteractions(userId as string, 30); // Last 30 days

    // Get available restaurants near user
    const nearbyRestaurants = await getNearbyRestaurants(userLocation, 10.0); // 10km radius

    // Calculate recommendation scores
    const recommendations = await calculateRecommendationScores(
      nearbyRestaurants,
      userProfile,
      userInteractions,
      {
        timeOfDay: timeOfDay as string,
        location: userLocation
      }
    );

    // Sort by score and apply diversity
    const finalRecommendations = applyDiversityFilter(recommendations)
      .slice(0, parseInt(limit as string));

    return { success: true, recommendations: finalRecommendations, totalFound: recommendations.length };

  } catch (error: any) {
    logger.error("Get personalized recommendations failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Get recommendations failed");
  }
});

/**
 * Get Trending Items
 * Returns trending menu items based on recent orders and interactions
 */
export const getTrendingItems = onCall(async (request) => {
  try {
    const { timeWindow = "24", limit = 10, restaurantId } = request.data || {};

    const hours = parseInt(String(timeWindow));
    const startTime = new Date(Date.now() - hours * 60 * 60 * 1000);

    // Get recent orders
    let ordersQuery = admin.firestore()
      .collection("orders")
      .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(startTime))
      .where("status", "==", "delivered");

    if (restaurantId) ordersQuery = ordersQuery.where("restaurantId", "==", restaurantId);

    const ordersSnapshot = await ordersQuery.get();
    const orders = ordersSnapshot.docs.map(doc => doc.data());

    // Calculate trending scores
    const itemScores = calculateTrendingScores(orders, hours);

    // Get menu item details
    const trendingItems = await enrichTrendingItems(itemScores, parseInt(limit as string));

    return { success: true, trendingItems, timeWindow: `${hours} hours`, basedOnOrders: orders.length };

  } catch (error: any) {
    logger.error("Get trending items failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Get trending items failed");
  }
});

/**
 * Get Smart Suggestions
 * Returns comprehensive smart suggestions including reorders, similar items, etc.
 */
export const getSmartSuggestions = onCall(async (request) => {
  try {
    const { context } = request.data || {};
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError("unauthenticated", "Authentication required");

    // Get user's order history
    const recentOrders = await getUserRecentOrders(userId as string, 30); // Last 30 days
    const userProfile = await getUserProfile(userId as string);

    // Generate different types of suggestions
    const suggestions = await Promise.all([
      generateReorderSuggestions(recentOrders),
      generateSimilarRestaurantSuggestions(recentOrders, userProfile),
      generateNewCuisineSuggestions(userProfile),
      generateContextualSuggestions(context as string, userProfile)
    ]);

    const smartSuggestions = {
      reorderSuggestions: suggestions[0],
      similarRestaurants: suggestions[1],
      newCuisines: suggestions[2],
      contextualSuggestions: suggestions[3]
    };

    return { success: true, suggestions: smartSuggestions };

  } catch (error: any) {
    logger.error("Get smart suggestions failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Get smart suggestions failed");
  }
});

/**
 * Validate and Apply Promotion
 * Validates promotion codes and applies discounts
 */
export const validatePromotion = onCall(async (request) => {
  try {
    const { code, restaurantId, orderValue } = request.data || {};
    const customerId = request.auth?.uid;
    if (!customerId) throw new HttpsError("unauthenticated", "Authentication required");
    if (!code) throw new HttpsError("invalid-argument", "Code required");

    // Find promotion
    const promoSnapshot = await admin.firestore()
      .collection("promotions")
      .where("code", "==", code.toUpperCase())
      .where("isActive", "==", true)
      .limit(1)
      .get();

    if (promoSnapshot.empty) {
      throw new HttpsError("not-found", "Invalid promotion code");
    }

    const promotion = promoSnapshot.docs[0].data();
    const promotionId = promoSnapshot.docs[0].id;

    // Validate promotion
    const validation = await validatePromotionEligibility(
      promotion,
      customerId,
      restaurantId,
      orderValue
    );

    if (!validation.isValid) {
      throw new HttpsError("failed-precondition", validation.reason || "Promotion not eligible");
    }

    // Calculate discount
    const discount = calculatePromotionDiscount(promotion, orderValue);

    return { success: true, promotion: {
        id: promotionId,
        code: promotion.code,
        title: promotion.title,
        description: promotion.description,
        discountType: promotion.discountType,
        discountAmount: promotion.discountAmount
      }, discount, finalAmount: Math.max(0, orderValue - discount) };

  } catch (error: any) {
    logger.error("Validate promotion failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Validate promotion failed");
  }
});

/**
 * Get Active Promotions
 * Returns currently active promotions for a user
 */
export const getActivePromotions = onCall(async (request) => {
  try {
    const customerId = request.auth?.uid as string | undefined;
    const { restaurantId } = request.data || {};

    const now = admin.firestore.Timestamp.now();
    
    let promotionsQuery = admin.firestore()
      .collection("promotions")
      .where("isActive", "==", true)
      .where("validFrom", "<=", now)
      .where("validUntil", ">=", now);

    const promotionsSnapshot = await promotionsQuery.get();
    let promotions = promotionsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    // Filter promotions based on restaurant and customer eligibility
    if (restaurantId) {
      promotions = promotions.filter((promo: any) => 
        promo.applicableRestaurants.length === 0 || 
        promo.applicableRestaurants.includes(restaurantId)
      );
    }

    if (customerId) {
      // Check customer-specific eligibility (usage limits, etc.)
      promotions = await filterCustomerEligiblePromotions(promotions, customerId as string);
    }

    return { success: true, promotions: promotions.map((promo: any) => ({
        id: promo.id,
        code: promo.code,
        title: promo.title,
        description: promo.description,
        discountType: promo.discountType,
        discountAmount: promo.discountAmount,
        maxDiscountAmount: promo.maxDiscountAmount,
        minimumOrderAmount: promo.minimumOrderAmount,
        validUntil: promo.validUntil,
        usageRemaining: promo.maxUsageCount ? 
          Math.max(0, promo.maxUsageCount - promo.currentUsageCount) : null
      })) };

  } catch (error: any) {
    logger.error("Get active promotions failed", { error: error.message, data: request.data });
    throw new HttpsError("internal", "Get active promotions failed");
  }
});

/**
 * Update Recommendation Model
 * Periodic task to update AI recommendation models
 */
export const updateRecommendationModel = onSchedule("every 6 hours", async (context) => {
  try {
    logger.info("Starting recommendation model update");

    // Calculate collaborative filtering weights
    await updateCollaborativeFiltering();

    // Update trending items cache
    await updateTrendingItemsCache();

    // Update cuisine popularity scores
    await updateCuisinePopularity();

    // Clean old interaction data (keep last 90 days)
    await cleanOldInteractions();

    logger.info("Recommendation model update completed");

  } catch (error: any) {
    logger.error("Recommendation model update failed", { error: error.message });
  }
});

/**
 * User Profile Updater
 * Updates user taste profiles based on interactions and orders
 */
export const userProfileUpdater = withMetrics("userProfileUpdater", onDocumentCreated("orders/{orderId}", async (event) => {
  const order = event.data?.data();
  if (!order || order.status !== "delivered") return;

  try {
    // Update user taste profile based on completed order
    await updateUserTasteProfile(order.customerId, order);

    // Update restaurant popularity
    await updateRestaurantPopularity(order.restaurantId);

    // Update menu item popularity
    for (const item of order.items) {
      await updateMenuItemPopularity(item.menuItemId, order.restaurantId);
    }

  } catch (error: any) {
    logger.error("User profile update failed", {
      orderId: event.params.orderId,
      error: error.message
    });
  }
}));

// MARK: - Helper Functions

async function getUserProfile(userId: string): Promise<any> {
  const profileDoc = await admin.firestore().doc(`customers/${userId}`).get();
  return profileDoc.exists ? profileDoc.data() : { preferences: {}, tasteProfile: {} };
}

async function getUserInteractions(userId: string, days: number): Promise<any[]> {
  const startDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
  
  const interactionsSnapshot = await admin.firestore()
    .collection("userInteractions")
    .where("userId", "==", userId)
    .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(startDate))
    .orderBy("timestamp", "desc")
    .limit(500)
    .get();

  return interactionsSnapshot.docs.map(doc => doc.data());
}

async function getNearbyRestaurants(location: any, radiusKm: number): Promise<any[]> {
  // Mock implementation - in production, use geohash queries
  const restaurantsSnapshot = await admin.firestore()
    .collection("restaurants")
    .where("isOpen", "==", true)
    .limit(50)
    .get();

  return restaurantsSnapshot.docs.map(doc => ({
    id: doc.id,
    ...doc.data()
  }));
}

async function calculateRecommendationScores(
  restaurants: any[],
  userProfile: any,
  interactions: any[],
  context: any
): Promise<any[]> {
  
  return restaurants.map(restaurant => {
    let score = 0;

    // Base quality score (20% weight)
    score += (restaurant.rating / 5.0) * 0.2;

    // Cuisine preference score (30% weight)
    const cuisineScore = calculateCuisineScore(restaurant.cuisineTags, userProfile.tasteProfile);
    score += cuisineScore * 0.3;

    // Interaction history score (25% weight)
    const interactionScore = calculateInteractionScore(restaurant.id, interactions);
    score += interactionScore * 0.25;

    // Contextual score (15% weight)
    const contextScore = calculateContextualScore(restaurant, context);
    score += contextScore * 0.15;

    // Popularity score (10% weight)
    const popularityScore = restaurant.orderCount ? Math.min(1.0, restaurant.orderCount / 100) : 0;
    score += popularityScore * 0.1;

    return {
      ...restaurant,
      recommendationScore: Math.round(score * 100) / 100
    };
  }).sort((a, b) => b.recommendationScore - a.recommendationScore);
}

function calculateCuisineScore(cuisineTags: string[], tasteProfile: any): number {
  if (!tasteProfile?.preferredCuisines) return 0.5;

  const preferences = tasteProfile.preferredCuisines;
  let score = 0;
  let totalWeight = 0;

  for (const cuisine of cuisineTags) {
    if (preferences[cuisine]) {
      score += preferences[cuisine];
      totalWeight += 1;
    }
  }

  return totalWeight > 0 ? score / totalWeight : 0.3;
}

function calculateInteractionScore(restaurantId: string, interactions: any[]): number {
  const restaurantInteractions = interactions.filter(i => 
    i.entityId === restaurantId || 
    (i.entityType === "restaurant" && i.entityId === restaurantId)
  );

  if (restaurantInteractions.length === 0) return 0;

  // Weight different interaction types
  const weights = { view: 0.1, click: 0.3, favorite: 0.8, order: 1.0 };
  let totalScore = 0;

  for (const interaction of restaurantInteractions) {
    totalScore += weights[interaction.type as keyof typeof weights] || 0.1;
  }

  return Math.min(1.0, totalScore / 5); // Normalize to 0-1
}

function calculateContextualScore(restaurant: any, context: any): number {
  let score = 0.5; // Base score

  // Time-based scoring
  if (context.timeOfDay) {
    const timeScores = {
      morning: { fast_food: 0.8, breakfast: 1.0, coffee: 1.0 },
      lunch: { fast_food: 1.0, healthy: 0.9, sandwich: 1.0 },
      dinner: { fine_dining: 1.0, pizza: 0.9, burger: 0.8 },
      late_night: { fast_food: 1.0, pizza: 1.0 }
    };

    const timePrefs = timeScores[context.timeOfDay as keyof typeof timeScores];
    if (timePrefs) {
      for (const cuisine of restaurant.cuisineTags) {
        if (timePrefs[cuisine as keyof typeof timePrefs]) {
          score = Math.max(score, timePrefs[cuisine as keyof typeof timePrefs]);
        }
      }
    }
  }

  return Math.min(1.0, score);
}

function applyDiversityFilter(recommendations: any[]): any[] {
  const diverseRecommendations = [];
  const seenCuisines = new Set();
  
  // First, add top-scored restaurants from different cuisines
  for (const restaurant of recommendations) {
    const mainCuisine = restaurant.cuisineTags[0];
    if (!seenCuisines.has(mainCuisine) && diverseRecommendations.length < 15) {
      diverseRecommendations.push(restaurant);
      seenCuisines.add(mainCuisine);
    }
  }
  
  // Fill remaining slots with highest-scored restaurants
  for (const restaurant of recommendations) {
    if (!diverseRecommendations.includes(restaurant)) {
      diverseRecommendations.push(restaurant);
    }
  }
  
  return diverseRecommendations;
}

function calculateTrendingScores(orders: any[], timeWindowHours: number): Map<string, number> {
  const itemCounts = new Map<string, number>();
  const itemOrders = new Map<string, any[]>();

  // Count item frequencies
  for (const order of orders) {
    for (const item of order.items) {
      const itemId = item.menuItemId;
      itemCounts.set(itemId, (itemCounts.get(itemId) || 0) + item.quantity);
      
      if (!itemOrders.has(itemId)) {
        itemOrders.set(itemId, []);
      }
      itemOrders.get(itemId)!.push(order);
    }
  }

  // Calculate trending scores (frequency + recency)
  const trendingScores = new Map<string, number>();
  
  for (const [itemId, count] of itemCounts) {
    const orderTimes = itemOrders.get(itemId)!.map(o => o.createdAt.toDate());
    const avgRecency = orderTimes.reduce((sum, time) => 
      sum + (Date.now() - time.getTime()), 0) / orderTimes.length;
    
    // Combine frequency and recency (more recent = higher score)
    const frequencyScore = Math.log(count + 1);
    const recencyScore = Math.max(0, 1 - (avgRecency / (timeWindowHours * 60 * 60 * 1000)));
    
    trendingScores.set(itemId, frequencyScore * 0.7 + recencyScore * 0.3);
  }

  return trendingScores;
}

async function enrichTrendingItems(itemScores: Map<string, number>, limit: number): Promise<any[]> {
  const sortedItems = Array.from(itemScores.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, limit);

  const enrichedItems = [];

  for (const [itemId, score] of sortedItems) {
    const itemDoc = await admin.firestore().doc(`menuItems/${itemId}`).get();
    if (itemDoc.exists) {
      enrichedItems.push({
        ...itemDoc.data(),
        id: itemId,
        trendingScore: Math.round(score * 100) / 100
      });
    }
  }

  return enrichedItems;
}

async function updateUserProfile(userId: string, type: string, entityId: string, entityType: string): Promise<void> {
  const profileRef = admin.firestore().doc(`customers/${userId}`);
  
  // Update interaction counters
  const updateData: any = {
    [`interactions.${type}Count`]: admin.firestore.FieldValue.increment(1),
    lastActivity: admin.firestore.FieldValue.serverTimestamp()
  };

  // Update cuisine preferences for restaurant interactions
  if (entityType === "restaurant") {
    const restaurantDoc = await admin.firestore().doc(`restaurants/${entityId}`).get();
    if (restaurantDoc.exists) {
      const restaurant = restaurantDoc.data()!;
      for (const cuisine of restaurant.cuisineTags) {
        const weight = type === "order" ? 0.3 : 0.1;
        updateData[`tasteProfile.preferredCuisines.${cuisine}`] = admin.firestore.FieldValue.increment(weight);
      }
    }
  }

  await profileRef.update(updateData);
}

async function validatePromotionEligibility(
  promotion: any,
  customerId: string,
  restaurantId?: string,
  orderValue?: number
): Promise<{ isValid: boolean; reason?: string }> {
  
  // Check date validity
  const now = new Date();
  if (now < promotion.validFrom.toDate() || now > promotion.validUntil.toDate()) {
    return { isValid: false, reason: "Promotion has expired" };
  }

  // Check usage limits
  if (promotion.maxUsageCount && promotion.currentUsageCount >= promotion.maxUsageCount) {
    return { isValid: false, reason: "Promotion usage limit reached" };
  }

  // Check restaurant applicability
  if (restaurantId && promotion.applicableRestaurants.length > 0) {
    if (!promotion.applicableRestaurants.includes(restaurantId)) {
      return { isValid: false, reason: "Promotion not applicable to this restaurant" };
    }
  }

  // Check minimum order amount
  if (orderValue && promotion.minimumOrderAmount && orderValue < promotion.minimumOrderAmount) {
    return { isValid: false, reason: `Minimum order amount is ${promotion.minimumOrderAmount} MAD` };
  }

  // Check customer usage limit
  if (promotion.maxUsagePerCustomer) {
    const usageSnapshot = await admin.firestore()
      .collection("promotionUsage")
      .where("promotionId", "==", promotion.id)
      .where("customerId", "==", customerId)
      .get();
    
    if (usageSnapshot.size >= promotion.maxUsagePerCustomer) {
      return { isValid: false, reason: "You have reached the usage limit for this promotion" };
    }
  }

  return { isValid: true };
}

function calculatePromotionDiscount(promotion: any, orderValue: number): number {
  let discount = 0;

  if (promotion.discountType === "fixed") {
    discount = promotion.discountAmount;
  } else if (promotion.discountType === "percentage") {
    discount = orderValue * (promotion.discountAmount / 100);
    if (promotion.maxDiscountAmount) {
      discount = Math.min(discount, promotion.maxDiscountAmount);
    }
  }

  return Math.round(Math.min(discount, orderValue) * 100) / 100;
}

// Additional helper functions for comprehensive recommendations
async function getUserRecentOrders(userId: string, days: number): Promise<any[]> {
  const startDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
  
  const ordersSnapshot = await admin.firestore()
    .collection("orders")
    .where("customerId", "==", userId)
    .where("status", "==", "delivered")
    .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(startDate))
    .orderBy("createdAt", "desc")
    .limit(20)
    .get();

  return ordersSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
}

async function generateReorderSuggestions(recentOrders: any[]): Promise<any[]> {
  // Find frequently ordered items for easy reordering
  const itemFrequency = new Map<string, number>();
  
  for (const order of recentOrders) {
    for (const item of order.items) {
      itemFrequency.set(item.menuItemId, (itemFrequency.get(item.menuItemId) || 0) + 1);
    }
  }

  const topItems = Array.from(itemFrequency.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5);

  // Get restaurant details for these items
  const suggestions = [];
  for (const [itemId, frequency] of topItems) {
    const itemDoc = await admin.firestore().doc(`menuItems/${itemId}`).get();
    if (itemDoc.exists) {
      const item = itemDoc.data()!;
      const restaurantDoc = await admin.firestore().doc(`restaurants/${item.restaurantId}`).get();
      
      suggestions.push({
        menuItem: { id: itemId, ...item },
        restaurant: restaurantDoc.exists ? restaurantDoc.data() : null,
        orderFrequency: frequency
      });
    }
  }

  return suggestions;
}

async function generateSimilarRestaurantSuggestions(recentOrders: any[], userProfile: any): Promise<any[]> {
  // Find restaurants similar to user's favorites
  const restaurantIds = [...new Set(recentOrders.map(o => o.restaurantId))];
  const suggestions = [];

  for (const restaurantId of restaurantIds.slice(0, 3)) {
    const similarRestaurants = await findSimilarRestaurants(restaurantId);
    suggestions.push(...similarRestaurants.slice(0, 2));
  }

  return suggestions;
}

async function generateNewCuisineSuggestions(userProfile: any): Promise<any[]> {
  // Suggest cuisines the user hasn't tried based on popular cuisines
  const triedCuisines = Object.keys(userProfile.tasteProfile?.preferredCuisines || {});
  
  const popularCuisines = await getPopularCuisines();
  const newCuisines = popularCuisines.filter(cuisine => !triedCuisines.includes(cuisine.name));

  return newCuisines.slice(0, 3);
}

async function generateContextualSuggestions(context: string, userProfile: any): Promise<any[]> {
  // Generate suggestions based on context (weather, time, location, etc.)
  const suggestions = [];

  if (context && context.includes("rainy")) {
    // Suggest comfort food for rainy weather
    const comfortFoodRestaurants = await getRestaurantsByCuisine(["comfort_food", "soup", "hot"]);
    suggestions.push(...comfortFoodRestaurants.slice(0, 3));
  }

  return suggestions;
}

// Periodic maintenance functions
async function updateCollaborativeFiltering(): Promise<void> {
  // Update user similarity matrices for collaborative filtering
  logger.info("Updating collaborative filtering weights");
}

async function updateTrendingItemsCache(): Promise<void> {
  // Cache trending items for faster retrieval
  logger.info("Updating trending items cache");
}

async function updateCuisinePopularity(): Promise<void> {
  // Update cuisine popularity scores
  logger.info("Updating cuisine popularity scores");
}

async function cleanOldInteractions(): Promise<void> {
  // Remove interactions older than 90 days
  const cutoffDate = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);
  
  const oldInteractionsQuery = admin.firestore()
    .collection("userInteractions")
    .where("timestamp", "<", admin.firestore.Timestamp.fromDate(cutoffDate))
    .limit(1000);

  const snapshot = await oldInteractionsQuery.get();
  const batch = admin.firestore().batch();

  snapshot.docs.forEach(doc => {
    batch.delete(doc.ref);
  });

  if (snapshot.size > 0) {
    await batch.commit();
    logger.info(`Cleaned ${snapshot.size} old interactions`);
  }
}

async function updateUserTasteProfile(customerId: string, order: any): Promise<void> {
  // Update user taste profile based on completed order
  const profileRef = admin.firestore().doc(`customers/${customerId}`);
  
  // Get restaurant to extract cuisine tags
  const restaurantDoc = await admin.firestore().doc(`restaurants/${order.restaurantId}`).get();
  if (!restaurantDoc.exists) return;

  const restaurant = restaurantDoc.data()!;
  const updateData: any = {};

  // Update cuisine preferences
  for (const cuisine of restaurant.cuisineTags) {
    updateData[`tasteProfile.preferredCuisines.${cuisine}`] = admin.firestore.FieldValue.increment(0.5);
  }

  // Update ordering patterns
  updateData[`tasteProfile.averageOrderValue`] = admin.firestore.FieldValue.increment(order.total);
  updateData[`tasteProfile.totalOrders`] = admin.firestore.FieldValue.increment(1);

  await profileRef.update(updateData);
}

async function updateRestaurantPopularity(restaurantId: string): Promise<void> {
  await admin.firestore().doc(`restaurants/${restaurantId}`).update({
    orderCount: admin.firestore.FieldValue.increment(1),
    lastOrderAt: admin.firestore.FieldValue.serverTimestamp()
  });
}

async function updateMenuItemPopularity(menuItemId: string, restaurantId: string): Promise<void> {
  await admin.firestore().doc(`menuItems/${menuItemId}`).update({
    orderCount: admin.firestore.FieldValue.increment(1),
    lastOrderedAt: admin.firestore.FieldValue.serverTimestamp()
  });
}

async function filterCustomerEligiblePromotions(promotions: any[], customerId: string): Promise<any[]> {
  // Filter promotions based on customer eligibility
  return promotions; // Simplified for now
}

async function findSimilarRestaurants(restaurantId: string): Promise<any[]> {
  // Find restaurants with similar cuisine tags
  return []; // Simplified for now
}

async function getPopularCuisines(): Promise<any[]> {
  // Get popular cuisines from analytics
  return []; // Simplified for now
}

async function getRestaurantsByCuisine(cuisines: string[]): Promise<any[]> {
  // Get restaurants by cuisine types
  return []; // Simplified for now
}