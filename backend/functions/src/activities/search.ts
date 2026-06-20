import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { logger } from 'firebase-functions';
import { 
  Activity,
  ActivitySearchRequest,
  ActivitySearchResponse,
  ActivityFilters,
  ActivitiesError,
  ErrorCodes,
  ActivityCategory
} from './models';
import { incrementCounter } from '../shared/metrics';
import { haversineKm } from '../shared/geoHelpers';

const db = admin.firestore();

// Main search function
export const searchActivities = functions.https.onCall(async (data, context) => {
  try {
    const request: ActivitySearchRequest = data;
    const { query, filters, geo, timeWindow, limit = 20, offset = 0 } = request;

    // Track search interaction
    if (context.auth) {
      await db.collection('interactions').add({
        userId: context.auth.uid,
        type: 'search',
        entityId: 'activities',
        entityType: 'activity',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        context: { query, filters }
      });
    }

    // Build base query
    let firestoreQuery = db.collection('activities')
      .where('isActive', '==', true);

    // Apply category filter
    if (filters.categories && filters.categories.length > 0) {
      firestoreQuery = firestoreQuery.where('category', 'in', filters.categories);
    }

    // Apply price range filter
    if (filters.priceRange) {
      if (filters.priceRange.min > 0) {
        firestoreQuery = firestoreQuery.where('pricePerUnit', '>=', filters.priceRange.min);
      }
      if (filters.priceRange.max > 0) {
        firestoreQuery = firestoreQuery.where('pricePerUnit', '<=', filters.priceRange.max);
      }
    }

    // Apply participant filters
    if (filters.minParticipants) {
      firestoreQuery = firestoreQuery.where('maxParticipants', '>=', filters.minParticipants);
    }
    if (filters.maxParticipants) {
      firestoreQuery = firestoreQuery.where('minParticipants', '<=', filters.maxParticipants);
    }

    // Execute query
    const snapshot = await firestoreQuery
      .orderBy('createdAt', 'desc')
      .limit(limit + offset)
      .get();

    let activities = snapshot.docs
      .slice(offset)
      .map(doc => ({
        id: doc.id,
        ...doc.data()
      })) as Activity[];

    // Post-processing filters
    const reasonCodes: string[] = [];

    // Text search (simple keyword matching)
    if (query && query.trim()) {
      const keywords = query.toLowerCase().trim().split(/\s+/);
      activities = activities.filter(activity => {
        const searchText = `${activity.title} ${activity.description} ${activity.tags.join(' ')}`.toLowerCase();
        return keywords.some(keyword => searchText.includes(keyword));
      });
      reasonCodes.push(`Text search: "${query}"`);
    }

    // Geo filtering
    if (geo && geo.lat && geo.lng) {
      const radiusKm = geo.radiusKm || 10; // Default 10km radius
      activities = activities.filter(activity => {
        const distance = haversineKm(
          geo.lat, geo.lng,
          activity.location.lat, activity.location.lng
        );
        return distance <= radiusKm;
      });
      reasonCodes.push(`Within ${radiusKm}km of location`);

      // Sort by distance
      activities.sort((a, b) => {
        const distA = haversineKm(geo.lat, geo.lng, a.location.lat, a.location.lng);
        const distB = haversineKm(geo.lat, geo.lng, b.location.lat, b.location.lng);
        return distA - distB;
      });
    }

    // Skill level filtering
    if (filters.skillLevel) {
      activities = activities.filter(activity => 
        !activity.skillLevel || 
        activity.skillLevel === 'any' || 
        activity.skillLevel === filters.skillLevel
      );
      reasonCodes.push(`Skill level: ${filters.skillLevel}`);
    }

    // Neighborhood filtering
    if (filters.neighborhoods && filters.neighborhoods.length > 0) {
      activities = activities.filter(activity => 
        !activity.location.neighborhood || 
        filters.neighborhoods!.includes(activity.location.neighborhood)
      );
      reasonCodes.push(`Neighborhoods: ${filters.neighborhoods.join(', ')}`);
    }

    // Availability filtering (if requested)
    if (filters.availableOnly && timeWindow) {
      activities = await filterByAvailability(activities, timeWindow.from, timeWindow.to);
      reasonCodes.push('Has available sessions');
    }

    // Apply personalization if user is authenticated
    if (context.auth) {
      activities = await personalizeResults(activities, context.auth.uid);
      reasonCodes.push('Personalized for you');
    }

    // Weather-aware suggestions (placeholder)
    const weatherReasonCodes = await applyWeatherLogic(activities, geo);
    reasonCodes.push(...weatherReasonCodes);

    await incrementCounter('activities_searches', 1);

    const response: ActivitySearchResponse = {
      activities: activities.slice(0, limit),
      total: activities.length,
      reasonCodes,
    };

    return response;

  } catch (error) {
    logger.error('Error in search:', error);
    throw new functions.https.HttpsError('internal', 'Search failed');
  }
});

// Helper function to filter activities by session availability
async function filterByAvailability(
  activities: Activity[], 
  from: Date, 
  to: Date
): Promise<Activity[]> {
  const fromTimestamp = admin.firestore.Timestamp.fromDate(from);
  const toTimestamp = admin.firestore.Timestamp.fromDate(to);

  const availableActivityIds = new Set<string>();

  // Check sessions in batches (Firestore limit)
  const batches = [];
  for (let i = 0; i < activities.length; i += 10) {
    batches.push(activities.slice(i, i + 10));
  }

  for (const batch of batches) {
    const activityIds = batch.map(a => a.id);
    
    const sessionsSnapshot = await db.collection('activitySessions')
      .where('activityId', 'in', activityIds)
      .where('startAt', '>=', fromTimestamp)
      .where('startAt', '<=', toTimestamp)
      .where('status', 'in', ['open', 'limited'])
      .get();

    sessionsSnapshot.docs.forEach(doc => {
      availableActivityIds.add(doc.data().activityId);
    });
  }

  return activities.filter(activity => availableActivityIds.has(activity.id));
}

// Apply personalization based on user traits and history
async function personalizeResults(activities: Activity[], userId: string): Promise<Activity[]> {
  try {
    // Get user traits if available
    const userTraitsDoc = await db.collection('userTraits').doc(userId).get();
    const userTraits = userTraitsDoc.exists ? userTraitsDoc.data() : null;

    // Get user interaction history
    const interactionsSnapshot = await db.collection('interactions')
      .where('userId', '==', userId)
      .where('entityType', '==', 'activity')
      .orderBy('timestamp', 'desc')
      .limit(50)
      .get();

    const viewedActivityIds = new Set(
      interactionsSnapshot.docs.map(doc => doc.data().entityId)
    );

    // Calculate personalized scores
    return activities.map(activity => {
      let score = 0;

      // Boost based on user's favorite sports/categories
      if (userTraits?.traits?.favoriteSports?.includes(activity.category)) {
        score += 10;
      }

      // Boost based on skill level match
      if (userTraits?.traits?.skillLevels?.[activity.category] === activity.skillLevel) {
        score += 5;
      }

      // Boost based on budget fit
      if (userTraits?.traits?.budgetBand) {
        const { min, max } = userTraits.traits.budgetBand;
        if (activity.pricePerUnit >= min && activity.pricePerUnit <= max) {
          score += 3;
        }
      }

      // Slight penalty for previously viewed activities
      if (viewedActivityIds.has(activity.id)) {
        score -= 2;
      }

      return { ...activity, _personalizedScore: score };
    }).sort((a, b) => (b as any)._personalizedScore - (a as any)._personalizedScore);

  } catch (error) {
    logger.warn('Error in personalization, returning original order:', error);
    return activities;
  }
}

// Apply weather-aware logic (placeholder implementation)
async function applyWeatherLogic(
  activities: Activity[], 
  geo?: { lat: number; lng: number }
): Promise<string[]> {
  const reasonCodes: string[] = [];

  // TODO: Integrate with weather API
  // For now, use simple heuristics
  
  // Boost indoor activities during certain conditions
  const indoorCategories: ActivityCategory[] = ['game', 'workshop', 'culture', 'education'];
  const outdoorCategories: ActivityCategory[] = ['sport', 'outdoor', 'fitness'];

  // Placeholder weather condition (would come from weather API)
  const isRainyDay = Math.random() > 0.8; // 20% chance of "rain"

  if (isRainyDay) {
    // Boost indoor activities, demote outdoor ones
    activities.forEach((activity, index) => {
      if (indoorCategories.includes(activity.category)) {
        (activity as any)._weatherScore = 5;
      } else if (outdoorCategories.includes(activity.category)) {
        (activity as any)._weatherScore = -3;
      } else {
        (activity as any)._weatherScore = 0;
      }
    });

    reasonCodes.push('Rainy weather - indoor activities recommended');
  } else {
    reasonCodes.push('Good weather for all activities');
  }

  return reasonCodes;
}

// Enhanced search with AI/ML features (for future implementation)
export const searchWithAI = functions.https.onCall(async (data, context) => {
  // TODO: Implement vector similarity search
  // TODO: Use embeddings for semantic search
  // TODO: Machine learning ranking
  
  // For now, delegate to regular search
  return searchActivities(data, context);
});

// Get search suggestions/autocomplete
export const getSearchSuggestions = functions.https.onCall(async (data, context) => {
  const { query, limit = 10 } = data;

  if (!query || query.length < 2) {
    return { suggestions: [] };
  }

  try {
    // Get activity titles and tags that match
    const activitiesSnapshot = await db.collection('activities')
      .where('isActive', '==', true)
      .limit(100)
      .get();

    const suggestions = new Set<string>();
    const queryLower = query.toLowerCase();

    activitiesSnapshot.docs.forEach(doc => {
      const activity = doc.data() as Activity;
      
      // Check title
      if (activity.title.toLowerCase().includes(queryLower)) {
        suggestions.add(activity.title);
      }

      // Check tags
      activity.tags.forEach(tag => {
        if (tag.toLowerCase().includes(queryLower)) {
          suggestions.add(tag);
        }
      });

      // Check category
      if (activity.category.toLowerCase().includes(queryLower)) {
        suggestions.add(activity.category);
      }
    });

    return {
      suggestions: Array.from(suggestions).slice(0, limit)
    };

  } catch (error) {
    logger.error('Error getting search suggestions:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get suggestions');
  }
});

// Get popular activities
export const getPopularActivities = functions.https.onCall(async (data, context) => {
  const { cityId, category, limit = 10 } = data;

  try {
    // Get activities with most recent interactions
    const interactionsSnapshot = await db.collection('interactions')
      .where('entityType', '==', 'activity')
      .where('type', 'in', ['view', 'book'])
      .where('timestamp', '>', admin.firestore.Timestamp.fromDate(new Date(Date.now() - 7 * 24 * 60 * 60 * 1000))) // Last 7 days
      .get();

    // Count interactions per activity
    const activityCounts = new Map<string, number>();
    interactionsSnapshot.docs.forEach(doc => {
      const activityId = doc.data().entityId;
      activityCounts.set(activityId, (activityCounts.get(activityId) || 0) + 1);
    });

    // Get top activity IDs
    const topActivityIds = Array.from(activityCounts.entries())
      .sort(([,a], [,b]) => b - a)
      .slice(0, limit * 2) // Get more to filter later
      .map(([id]) => id);

    if (topActivityIds.length === 0) {
      return { activities: [] };
    }

    // Get activity details
    const activities: Activity[] = [];
    const batches = [];
    for (let i = 0; i < topActivityIds.length; i += 10) {
      batches.push(topActivityIds.slice(i, i + 10));
    }

    for (const batch of batches) {
      const activitiesSnapshot = await db.collection('activities')
        .where(admin.firestore.FieldPath.documentId(), 'in', batch)
        .where('isActive', '==', true)
        .get();

      activitiesSnapshot.docs.forEach(doc => {
        activities.push({ id: doc.id, ...doc.data() } as Activity);
      });
    }

    // Filter by category if specified
    let filteredActivities = activities;
    if (category) {
      filteredActivities = activities.filter(a => a.category === category);
    }

    return {
      activities: filteredActivities.slice(0, limit)
    };

  } catch (error) {
    logger.error('Error getting popular activities:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get popular activities');
  }
});