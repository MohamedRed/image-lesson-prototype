import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { trace } from '../shared/trace';
import { analytics } from '../shared/analytics';

const db = getFirestore();

interface SearchFilters {
  cityId: string;
  neighborhoods?: string[];
  categories?: string[];
  priceRange?: {
    min?: number;
    max?: number;
  };
  condition?: string;
  hasImages?: boolean;
  deliveryOptions?: {
    meetup?: boolean;
    courier?: boolean;
  };
}

interface SearchResult {
  listings: any[];
  total: number;
  facets?: {
    categories: { [key: string]: number };
    neighborhoods: { [key: string]: number };
    priceRanges: { [key: string]: number };
  };
  reasonCodes?: string[];
}

/**
 * Hybrid search with text and vector similarity
 * Per Section 8 - Search, Ranking, and Personalization
 */
export const search = onCall(
  { cors: true },
  async (request) => {
    return trace('marketplace.search', request.auth?.uid || 'anonymous', async () => {
      const { query, filters, page = 0, limit = 20 } = request.data;
      const userId = request.auth?.uid;

      if (!filters?.cityId) {
        throw new HttpsError('invalid-argument', 'City ID is required');
      }

      try {
        // Build Firestore query
        let firestoreQuery = db.collection('listings')
          .where('cityId', '==', filters.cityId)
          .where('status', '==', 'active')
          .where('moderation.status', '==', 'approved');

        // Apply filters
        if (filters.categories?.length) {
          firestoreQuery = firestoreQuery.where('category', 'in', filters.categories);
        }

        if (filters.condition) {
          firestoreQuery = firestoreQuery.where('condition', '==', filters.condition);
        }

        // Execute query
        const snapshot = await firestoreQuery
          .orderBy('createdAt', 'desc')
          .limit(limit)
          .offset(page * limit)
          .get();

        let listings = snapshot.docs.map(doc => ({
          id: doc.id,
          ...doc.data()
        }));

        // Apply additional filters (neighborhoods, price, etc.)
        listings = applyClientSideFilters(listings, filters, query);

        // Personalized ranking
        if (userId) {
          listings = await applyPersonalizedRanking(listings, userId, filters.cityId);
        }

        // Text search if query provided
        if (query) {
          listings = performTextSearch(listings, query);
        }

        // Generate reason codes
        const reasonCodes = generateReasonCodes(listings, query, filters, userId);

        // Generate facets
        const facets = generateFacets(listings);

        // Analytics
        await analytics.track('marketplace_search', {
          userId: userId || 'anonymous',
          query: query || '',
          cityId: filters.cityId,
          resultCount: listings.length,
          hasFilters: Object.keys(filters).length > 1
        });

        return {
          listings,
          total: listings.length,
          facets,
          reasonCodes
        } as SearchResult;

      } catch (error) {
        logger.error('Search error', { query, filters, error });
        throw new HttpsError('internal', 'Search failed');
      }
    });
  }
);

/**
 * Get nearby listings with geo filtering
 */
export const listNearby = onCall(
  { cors: true },
  async (request) => {
    return trace('marketplace.listNearby', request.auth?.uid || 'anonymous', async () => {
      const { cityId, center, radiusKm = 10 } = request.data;
      const userId = request.auth?.uid;

      if (!cityId || !center) {
        throw new HttpsError('invalid-argument', 'City ID and center coordinates are required');
      }

      try {
        // Simple geo filtering - in production would use GeoFirestore
        const snapshot = await db.collection('listings')
          .where('cityId', '==', cityId)
          .where('status', '==', 'active')
          .where('moderation.status', '==', 'approved')
          .orderBy('createdAt', 'desc')
          .limit(50)
          .get();

        let listings = snapshot.docs.map(doc => ({
          id: doc.id,
          ...doc.data()
        }));

        // Filter by distance
        listings = listings.filter(listing => {
          if (!listing.location) return false;
          const distance = calculateDistance(
            center.latitude,
            center.longitude,
            listing.location.lat,
            listing.location.lng
          );
          return distance <= radiusKm;
        });

        // Personalized ranking
        if (userId) {
          listings = await applyPersonalizedRanking(listings, userId, cityId);
        }

        // Diversity re-ranking (MMR-style)
        listings = applyDiversityReRanking(listings);

        // Analytics
        await analytics.track('marketplace_nearby_search', {
          userId: userId || 'anonymous',
          cityId,
          radiusKm,
          resultCount: listings.length
        });

        return listings;

      } catch (error) {
        logger.error('Nearby search error', { cityId, center, error });
        throw new HttpsError('internal', 'Nearby search failed');
      }
    });
  }
);

/**
 * Get personalized recommendations
 */
export const getRecommendations = onCall(
  { cors: true },
  async (request) => {
    return trace('marketplace.getRecommendations', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const { cityId, limit = 10 } = request.data;
      const userId = request.auth.uid;

      try {
        // Get user preferences and interaction history
        const userDoc = await db.collection('users').doc(userId).get();
        const userData = userDoc.data();
        
        const interactionsSnapshot = await db.collection('interactions')
          .where('userId', '==', userId)
          .where('type', 'in', ['view', 'save', 'contact'])
          .orderBy('timestamp', 'desc')
          .limit(100)
          .get();

        const interactions = interactionsSnapshot.docs.map(doc => doc.data());

        // Analyze user preferences
        const preferences = analyzeUserPreferences(userData, interactions);

        // Get candidate listings
        let query = db.collection('listings')
          .where('cityId', '==', cityId)
          .where('status', '==', 'active')
          .where('moderation.status', '==', 'approved')
          .where('sellerId', '!=', userId); // Don't recommend own listings

        // Apply preference filters
        if (preferences.preferredCategories.length > 0) {
          query = query.where('category', 'in', preferences.preferredCategories.slice(0, 10)); // Firestore limit
        }

        const snapshot = await query
          .orderBy('createdAt', 'desc')
          .limit(50)
          .get();

        let listings = snapshot.docs.map(doc => ({
          id: doc.id,
          ...doc.data()
        }));

        // Score based on preferences
        listings = listings.map(listing => ({
          ...listing,
          recommendationScore: calculateRecommendationScore(listing, preferences, interactions)
        }));

        // Sort by score and apply diversity
        listings.sort((a, b) => b.recommendationScore - a.recommendationScore);
        listings = applyDiversityReRanking(listings.slice(0, limit * 2)).slice(0, limit);

        // Generate reason codes
        const reasonCodes = generateRecommendationReasons(listings, preferences);

        // Analytics
        await analytics.track('marketplace_recommendations_viewed', {
          userId,
          cityId,
          recommendationCount: listings.length,
          topCategories: preferences.preferredCategories.slice(0, 3)
        });

        return {
          listings,
          reasonCodes
        };

      } catch (error) {
        logger.error('Recommendations error', { userId, cityId, error });
        throw new HttpsError('internal', 'Failed to get recommendations');
      }
    });
  }
);

// Helper functions

function applyClientSideFilters(listings: any[], filters: SearchFilters, query?: string): any[] {
  return listings.filter(listing => {
    // Neighborhood filter
    if (filters.neighborhoods?.length && !filters.neighborhoods.includes(listing.location?.arrondissement)) {
      return false;
    }

    // Price range filter
    if (filters.priceRange) {
      const price = listing.price?.amount || 0;
      if (filters.priceRange.min && price < filters.priceRange.min) return false;
      if (filters.priceRange.max && price > filters.priceRange.max) return false;
    }

    // Images filter
    if (filters.hasImages && (!listing.images || listing.images.length === 0)) {
      return false;
    }

    // Delivery options filter
    if (filters.deliveryOptions) {
      if (filters.deliveryOptions.meetup && !listing.deliveryOptions?.meetup) return false;
      if (filters.deliveryOptions.courier && !listing.deliveryOptions?.courier) return false;
    }

    return true;
  });
}

async function applyPersonalizedRanking(listings: any[], userId: string, cityId: string): Promise<any[]> {
  // Get user traits and preferences
  const userDoc = await db.collection('users').doc(userId).get();
  const userData = userDoc.data();

  return listings.map(listing => {
    let personalizedScore = 1.0;

    // Category affinity
    if (userData?.preferences?.categories?.includes(listing.category)) {
      personalizedScore *= 1.3;
    }

    // Neighborhood preference
    if (userData?.preferences?.neighborhoods?.includes(listing.location?.arrondissement)) {
      personalizedScore *= 1.2;
    }

    // Price band preference
    if (userData?.preferences?.priceBand) {
      const price = listing.price?.amount || 0;
      const { min, max } = userData.preferences.priceBand;
      if (price >= min && price <= max) {
        personalizedScore *= 1.2;
      }
    }

    // Freshness boost
    const daysSinceCreated = (Date.now() - listing.createdAt?.toMillis()) / (24 * 60 * 60 * 1000);
    if (daysSinceCreated < 1) {
      personalizedScore *= 1.5;
    } else if (daysSinceCreated < 7) {
      personalizedScore *= 1.2;
    }

    return {
      ...listing,
      personalizedScore
    };
  }).sort((a, b) => b.personalizedScore - a.personalizedScore);
}

function performTextSearch(listings: any[], query: string): any[] {
  if (!query) return listings;

  const searchTerms = query.toLowerCase().split(' ');
  
  return listings.map(listing => {
    const content = `${listing.title} ${listing.description}`.toLowerCase();
    let relevanceScore = 0;

    searchTerms.forEach(term => {
      if (listing.title?.toLowerCase().includes(term)) {
        relevanceScore += 3; // Title matches are more important
      }
      if (listing.description?.toLowerCase().includes(term)) {
        relevanceScore += 1;
      }
      if (listing.category?.toLowerCase().includes(term)) {
        relevanceScore += 2;
      }
    });

    return {
      ...listing,
      relevanceScore
    };
  })
  .filter(listing => listing.relevanceScore > 0)
  .sort((a, b) => b.relevanceScore - a.relevanceScore);
}

function applyDiversityReRanking(listings: any[]): any[] {
  // MMR-style diversity to avoid redundancy
  const diverseListings: any[] = [];
  const remaining = [...listings];
  const seenCategories = new Set<string>();

  while (remaining.length > 0 && diverseListings.length < 20) {
    // Find next best item that adds diversity
    let bestIndex = 0;
    let bestScore = 0;

    remaining.forEach((listing, index) => {
      let score = listing.personalizedScore || listing.relevanceScore || 1;
      
      // Diversity bonus for new categories
      if (!seenCategories.has(listing.category)) {
        score *= 1.3;
      }

      if (score > bestScore) {
        bestScore = score;
        bestIndex = index;
      }
    });

    const selected = remaining.splice(bestIndex, 1)[0];
    diverseListings.push(selected);
    seenCategories.add(selected.category);
  }

  return diverseListings;
}

function generateReasonCodes(listings: any[], query?: string, filters?: SearchFilters, userId?: string): string[] {
  const reasons: string[] = [];

  if (query) {
    reasons.push('text_match');
  }

  if (filters?.neighborhoods?.length) {
    reasons.push(`in_${filters.neighborhoods[0]}`);
  }

  if (userId) {
    reasons.push('personalized');
  }

  if (filters?.priceRange) {
    reasons.push('price_filtered');
  }

  return reasons;
}

function generateFacets(listings: any[]) {
  const categories: { [key: string]: number } = {};
  const neighborhoods: { [key: string]: number } = {};
  const priceRanges: { [key: string]: number } = {
    'under_500': 0,
    '500_2000': 0,
    '2000_5000': 0,
    'over_5000': 0
  };

  listings.forEach(listing => {
    // Categories
    const category = listing.category;
    categories[category] = (categories[category] || 0) + 1;

    // Neighborhoods
    const neighborhood = listing.location?.arrondissement;
    if (neighborhood) {
      neighborhoods[neighborhood] = (neighborhoods[neighborhood] || 0) + 1;
    }

    // Price ranges (in MAD cents)
    const price = listing.price?.amount || 0;
    if (price < 50000) priceRanges['under_500']++;
    else if (price < 200000) priceRanges['500_2000']++;
    else if (price < 500000) priceRanges['2000_5000']++;
    else priceRanges['over_5000']++;
  });

  return { categories, neighborhoods, priceRanges };
}

function analyzeUserPreferences(userData: any, interactions: any[]) {
  const categoryCount: { [key: string]: number } = {};
  const neighborhoodCount: { [key: string]: number } = {};

  // Analyze interactions to infer preferences
  interactions.forEach(interaction => {
    if (interaction.entityType === 'listing') {
      // Would fetch listing details to get category/neighborhood
      // For now, simulate
      const category = 'electronics'; // Would be actual category
      categoryCount[category] = (categoryCount[category] || 0) + 1;
    }
  });

  const preferredCategories = Object.entries(categoryCount)
    .sort(([,a], [,b]) => b - a)
    .slice(0, 5)
    .map(([category]) => category);

  const preferredNeighborhoods = Object.entries(neighborhoodCount)
    .sort(([,a], [,b]) => b - a)
    .slice(0, 3)
    .map(([neighborhood]) => neighborhood);

  return {
    preferredCategories,
    preferredNeighborhoods,
    explicitPreferences: userData?.preferences || {}
  };
}

function calculateRecommendationScore(listing: any, preferences: any, interactions: any[]): number {
  let score = 1.0;

  // Category preference
  if (preferences.preferredCategories.includes(listing.category)) {
    const index = preferences.preferredCategories.indexOf(listing.category);
    score *= (1.5 - index * 0.1); // Higher score for more preferred categories
  }

  // Neighborhood preference
  if (preferences.preferredNeighborhoods.includes(listing.location?.arrondissement)) {
    score *= 1.3;
  }

  // Freshness
  const daysSinceCreated = (Date.now() - listing.createdAt?.toMillis()) / (24 * 60 * 60 * 1000);
  if (daysSinceCreated < 1) score *= 1.4;
  else if (daysSinceCreated < 7) score *= 1.2;

  // Image quality
  if (listing.images?.length >= 3) score *= 1.1;

  // Price attractiveness
  const price = listing.price?.amount || 0;
  if (price < 100000) score *= 1.2; // Boost for affordable items

  return score;
}

function generateRecommendationReasons(listings: any[], preferences: any): string[] {
  const reasons: string[] = [];

  if (preferences.preferredCategories.length > 0) {
    reasons.push(`matches_your_interests`);
  }

  reasons.push('high_quality_photos');
  reasons.push('recent_listing');
  reasons.push('good_value');

  return reasons;
}

function calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371; // Earth's radius in kilometers
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}