import { onSchedule } from 'firebase-functions/v2/scheduler';
import { logger } from 'firebase-functions';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';

// Initialize Firebase Admin if not already done
if (!initializeApp.length) {
  initializeApp();
}

const db = getFirestore();
const storage = getStorage();

// MARK: - Price Cache Refresh

export const refreshPriceCaches = onSchedule('0 2 * * *', async (event) => {
  logger.info('Starting nightly price cache refresh');
  
  try {
    // Get all stores that need price updates
    const storesSnapshot = await db.collection('priceCaches').get();
    const updatePromises: Promise<void>[] = [];
    
    for (const storeDoc of storesSnapshot.docs) {
      const storeId = storeDoc.id;
      const storeData = storeDoc.data();
      
      // Skip if updated recently (within 6 hours)
      const lastUpdate = storeData.lastUpdated?.toDate();
      if (lastUpdate && Date.now() - lastUpdate.getTime() < 6 * 60 * 60 * 1000) {
        continue;
      }
      
      updatePromises.push(refreshStoresPrices(storeId));
    }
    
    await Promise.all(updatePromises);
    
    logger.info(`Refreshed price caches for ${updatePromises.length} stores`);
  } catch (error) {
    logger.error('Error refreshing price caches:', error);
    throw error;
  }
});

async function refreshStoresPrices(storeId: string): Promise<void> {
  try {
    // Get store configuration
    const storeDoc = await db.collection('stores').doc(storeId).get();
    if (!storeDoc.exists) {
      logger.warn(`Store ${storeId} not found`);
      return;
    }
    
    const store = storeDoc.data()!;
    
    // Refresh prices based on store type
    switch (store.type) {
      case 'kroger':
        await refreshKrogerPrices(storeId, store);
        break;
      case 'walmart':
        await refreshWalmartPrices(storeId, store);
        break;
      case 'target':
        await refreshTargetPrices(storeId, store);
        break;
      case 'instacart':
        await refreshInstacartPrices(storeId, store);
        break;
      default:
        logger.warn(`Unknown store type: ${store.type}`);
    }
    
    // Update last refresh timestamp
    await db.collection('priceCaches').doc(storeId).update({
      lastUpdated: new Date(),
      lastRefreshStatus: 'success'
    });
    
  } catch (error) {
    logger.error(`Error refreshing prices for store ${storeId}:`, error);
    
    // Log failure but don't throw to allow other stores to continue
    await db.collection('priceCaches').doc(storeId).update({
      lastUpdated: new Date(),
      lastRefreshStatus: 'error',
      lastError: error.message
    });
  }
}

// MARK: - Store-Specific Price Refreshers

async function refreshKrogerPrices(storeId: string, store: any): Promise<void> {
  // Implementation would use Kroger API
  logger.info(`Refreshing Kroger prices for store ${storeId}`);
  
  // Mock implementation - replace with actual Kroger API calls
  const mockPrices = await generateMockPrices(storeId, 'kroger');
  
  await db.collection('priceCaches').doc(storeId).collection('prices').doc('current').set({
    prices: mockPrices,
    updatedAt: new Date()
  });
}

async function refreshWalmartPrices(storeId: string, store: any): Promise<void> {
  // Implementation would use Walmart API
  logger.info(`Refreshing Walmart prices for store ${storeId}`);
  
  const mockPrices = await generateMockPrices(storeId, 'walmart');
  
  await db.collection('priceCaches').doc(storeId).collection('prices').doc('current').set({
    prices: mockPrices,
    updatedAt: new Date()
  });
}

async function refreshTargetPrices(storeId: string, store: any): Promise<void> {
  // Implementation would use Target API
  logger.info(`Refreshing Target prices for store ${storeId}`);
  
  const mockPrices = await generateMockPrices(storeId, 'target');
  
  await db.collection('priceCaches').doc(storeId).collection('prices').doc('current').set({
    prices: mockPrices,
    updatedAt: new Date()
  });
}

async function refreshInstacartPrices(storeId: string, store: any): Promise<void> {
  // Implementation would use Instacart API
  logger.info(`Refreshing Instacart prices for store ${storeId}`);
  
  const mockPrices = await generateMockPrices(storeId, 'instacart');
  
  await db.collection('priceCaches').doc(storeId).collection('prices').doc('current').set({
    prices: mockPrices,
    updatedAt: new Date()
  });
}

async function generateMockPrices(storeId: string, storeType: string): Promise<Record<string, number>> {
  // Generate mock prices for common grocery items
  const baseItems = [
    'milk_1gallon', 'eggs_dozen', 'bread_white', 'chicken_breast_lb',
    'ground_beef_lb', 'bananas_lb', 'apples_lb', 'potatoes_5lb',
    'onions_lb', 'tomatoes_lb', 'lettuce_head', 'carrots_lb',
    'rice_white_2lb', 'pasta_1lb', 'olive_oil_500ml', 'salt_1lb'
  ];
  
  const prices: Record<string, number> = {};
  
  for (const item of baseItems) {
    // Base price with store-specific multiplier
    const basePrice = getBasePriceForItem(item);
    const storeMultiplier = getStoreMultiplier(storeType);
    const randomVariation = 0.9 + Math.random() * 0.2; // ±10% variation
    
    prices[item] = Math.round(basePrice * storeMultiplier * randomVariation * 100) / 100;
  }
  
  return prices;
}

function getBasePriceForItem(item: string): number {
  const basePrices: Record<string, number> = {
    'milk_1gallon': 3.50,
    'eggs_dozen': 2.25,
    'bread_white': 1.25,
    'chicken_breast_lb': 4.99,
    'ground_beef_lb': 5.49,
    'bananas_lb': 0.68,
    'apples_lb': 1.99,
    'potatoes_5lb': 2.99,
    'onions_lb': 1.29,
    'tomatoes_lb': 1.89,
    'lettuce_head': 1.49,
    'carrots_lb': 0.99,
    'rice_white_2lb': 1.99,
    'pasta_1lb': 1.29,
    'olive_oil_500ml': 4.99,
    'salt_1lb': 0.89
  };
  
  return basePrices[item] || 1.99;
}

function getStoreMultiplier(storeType: string): number {
  const multipliers: Record<string, number> = {
    'kroger': 1.0,
    'walmart': 0.95,    // Typically 5% cheaper
    'target': 1.05,     // Typically 5% more expensive
    'instacart': 1.15   // Typically 15% more expensive due to markup + delivery
  };
  
  return multipliers[storeType] || 1.0;
}

// MARK: - Weekly Meal Plan Optimization

export const optimizeWeeklyMealPlans = onSchedule('0 1 * * 0', async (event) => {
  logger.info('Starting weekly meal plan optimization');
  
  try {
    // Get all users who have meal plans that need optimization
    const usersSnapshot = await db.collection('users')
      .where('mealPlanPreferences.weeklyOptimization', '==', true)
      .get();
    
    const optimizationPromises: Promise<void>[] = [];
    
    for (const userDoc of usersSnapshot.docs) {
      optimizationPromises.push(optimizeUserMealPlans(userDoc.id, userDoc.data()));
    }
    
    await Promise.all(optimizationPromises);
    
    logger.info(`Optimized meal plans for ${optimizationPromises.length} users`);
  } catch (error) {
    logger.error('Error optimizing weekly meal plans:', error);
    throw error;
  }
});

async function optimizeUserMealPlans(userId: string, userData: any): Promise<void> {
  try {
    // Get user's recent meal plans
    const mealPlansSnapshot = await db.collection('users').doc(userId)
      .collection('mealPlans')
      .where('weekStartDate', '>=', getWeeksAgo(4))
      .orderBy('weekStartDate', 'desc')
      .limit(4)
      .get();
    
    if (mealPlansSnapshot.empty) {
      return;
    }
    
    // Analyze patterns and generate suggestions
    const suggestions = await generateOptimizationSuggestions(userId, mealPlansSnapshot.docs);
    
    // Store suggestions
    await db.collection('users').doc(userId)
      .collection('optimizationSuggestions')
      .add({
        suggestions,
        createdAt: new Date(),
        type: 'weekly_optimization'
      });
    
  } catch (error) {
    logger.error(`Error optimizing meal plans for user ${userId}:`, error);
  }
}

async function generateOptimizationSuggestions(userId: string, mealPlanDocs: any[]): Promise<any[]> {
  const suggestions = [];
  
  // Analyze recipe variety
  const usedRecipes = new Set();
  for (const doc of mealPlanDocs) {
    const mealPlan = doc.data();
    for (const day of mealPlan.days || []) {
      for (const meal of day.meals || []) {
        if (meal.recipeId) {
          usedRecipes.add(meal.recipeId);
        }
      }
    }
  }
  
  if (usedRecipes.size < 15) {
    suggestions.push({
      type: 'variety',
      title: 'Try More Recipe Variety',
      description: 'You\'ve used the same recipes frequently. Try exploring new cuisines!',
      action: 'explore_recipes'
    });
  }
  
  // Analyze nutrition patterns
  // This would involve more complex nutrition analysis
  
  // Analyze cost patterns
  // This would involve analyzing shopping list costs
  
  return suggestions;
}

function getWeeksAgo(weeks: number): Date {
  const date = new Date();
  date.setDate(date.getDate() - (weeks * 7));
  return date;
}

// MARK: - Asset Cleanup

export const cleanupTempAssets = onSchedule('0 3 * * *', async (event) => {
  logger.info('Starting temporary asset cleanup');
  
  try {
    const bucket = storage.bucket();
    
    // Clean up temporary recipe import assets older than 24 hours
    const oneDayAgo = new Date();
    oneDayAgo.setDate(oneDayAgo.getDate() - 1);
    
    const [tempFiles] = await bucket.getFiles({
      prefix: 'temp/recipe-import/',
      maxResults: 1000
    });
    
    const filesToDelete = tempFiles.filter(file => {
      const metadata = file.metadata;
      const created = new Date(metadata.timeCreated);
      return created < oneDayAgo;
    });
    
    if (filesToDelete.length > 0) {
      await Promise.all(filesToDelete.map(file => file.delete()));
      logger.info(`Deleted ${filesToDelete.length} temporary files`);
    }
    
    // Clean up orphaned video segments older than 7 days
    const weekAgo = new Date();
    weekAgo.setDate(weekAgo.getDate() - 7);
    
    const [segmentFiles] = await bucket.getFiles({
      prefix: 'video-segments/',
      maxResults: 1000
    });
    
    const segmentsToDelete = segmentFiles.filter(file => {
      const metadata = file.metadata;
      const created = new Date(metadata.timeCreated);
      return created < weekAgo && !metadata.customMetadata?.permanent;
    });
    
    if (segmentsToDelete.length > 0) {
      await Promise.all(segmentsToDelete.map(file => file.delete()));
      logger.info(`Deleted ${segmentsToDelete.length} old video segments`);
    }
    
  } catch (error) {
    logger.error('Error cleaning up temporary assets:', error);
    throw error;
  }
});

// MARK: - Analytics Aggregation

export const aggregateAnalytics = onSchedule('0 4 * * *', async (event) => {
  logger.info('Starting daily analytics aggregation');
  
  try {
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    yesterday.setHours(0, 0, 0, 0);
    
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    // Aggregate meal planning metrics
    const metrics = await aggregateMealPlanningMetrics(yesterday, today);
    
    // Store aggregated metrics
    await db.collection('analytics')
      .doc('daily')
      .collection('mealPlanning')
      .doc(yesterday.toISOString().split('T')[0])
      .set(metrics);
    
    logger.info('Analytics aggregation completed', metrics);
    
  } catch (error) {
    logger.error('Error aggregating analytics:', error);
    throw error;
  }
});

async function aggregateMealPlanningMetrics(startDate: Date, endDate: Date): Promise<any> {
  // Get recipe imports
  const importsSnapshot = await db.collection('recipe-imports')
    .where('createdAt', '>=', startDate)
    .where('createdAt', '<', endDate)
    .get();
  
  // Get meal plan generations
  const mealPlansSnapshot = await db.collection('meal-plans')
    .where('createdAt', '>=', startDate)
    .where('createdAt', '<', endDate)
    .get();
  
  // Get shopping lists created
  const shoppingListsSnapshot = await db.collection('shopping-lists')
    .where('createdAt', '>=', startDate)
    .where('createdAt', '<', endDate)
    .get();
  
  return {
    date: startDate.toISOString().split('T')[0],
    recipeImports: {
      total: importsSnapshot.size,
      successful: importsSnapshot.docs.filter(doc => doc.data().status === 'completed').length,
      failed: importsSnapshot.docs.filter(doc => doc.data().status === 'failed').length
    },
    mealPlans: {
      total: mealPlansSnapshot.size,
      avgGenerationTime: calculateAvgGenerationTime(mealPlansSnapshot.docs),
      mostPopularCuisines: getMostPopularCuisines(mealPlansSnapshot.docs)
    },
    shoppingLists: {
      total: shoppingListsSnapshot.size,
      avgItemCount: calculateAvgItemCount(shoppingListsSnapshot.docs),
      priceComparisonUsage: shoppingListsSnapshot.docs.filter(doc => doc.data().pricesCompared).length
    },
    aggregatedAt: new Date()
  };
}

function calculateAvgGenerationTime(docs: any[]): number {
  if (docs.length === 0) return 0;
  
  const times = docs
    .map(doc => doc.data().generationTimeMs)
    .filter(time => typeof time === 'number');
  
  if (times.length === 0) return 0;
  
  return times.reduce((sum, time) => sum + time, 0) / times.length;
}

function getMostPopularCuisines(docs: any[]): string[] {
  const cuisineCount: Record<string, number> = {};
  
  for (const doc of docs) {
    const data = doc.data();
    const cuisines = data.preferences?.cuisines || [];
    for (const cuisine of cuisines) {
      cuisineCount[cuisine] = (cuisineCount[cuisine] || 0) + 1;
    }
  }
  
  return Object.entries(cuisineCount)
    .sort(([,a], [,b]) => b - a)
    .slice(0, 5)
    .map(([cuisine]) => cuisine);
}

function calculateAvgItemCount(docs: any[]): number {
  if (docs.length === 0) return 0;
  
  const itemCounts = docs
    .map(doc => doc.data().normalizedItems?.length || 0);
  
  return itemCounts.reduce((sum, count) => sum + count, 0) / itemCounts.length;
}