import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import { CallableContext } from "firebase-functions/v2/https";
import { BigQuery } from "@google-cloud/bigquery";
import { vectorSearchEvents, processEventStream, getEventAnalytics } from "./bigquery_analytics";
import {
  Event,
  EventFilters,
  SearchQuery,
  SearchResult,
  EventStatus,
  SearchFacets,
  EventInteraction,
  InteractionType,
  UserTraits,
  ConsentGrant,
  ConsentScope
} from "./types";

const db = admin.firestore();
const bigquery = new BigQuery();

/**
 * Search events with hybrid text + vector search, filters, and personalization
 */
export async function searchEvents(
  data: SearchQuery,
  context: CallableContext
): Promise<SearchResult> {
  try {
    const userId = context.auth?.uid;
    
    // Track search interaction
    if (userId) {
      await trackInteraction({
        userId,
        type: InteractionType.VIEW,
        entityId: "search",
        entityType: "event",
        context: { query: data.query, filters: data.filters }
      });
    }

    // Build base query
    let query = db.collection("events")
      .where("status", "==", EventStatus.PUBLISHED)
      .where("startAt", ">", admin.firestore.Timestamp.now());

    // Apply filters
    query = applyFilters(query, data.filters);

    // Use vector search if query is provided, otherwise use basic filtering
    let events: Event[];
    let relevanceScores: number[] = [];
    
    if (data.query && data.query.trim()) {
      // Use BigQuery vector search for text queries
      const vectorResult = await vectorSearchEvents(
        data.query,
        data.filters,
        userId,
        data.limit || 50
      );
      events = vectorResult.events;
      relevanceScores = vectorResult.relevanceScores;
    } else {
      // Use basic Firestore filtering for browsing
      const snapshot = await query.limit(data.limit || 50).get();
      events = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      })) as Event[];
    }

    // Apply personalization and social signals
    if (userId) {
      events = await applyPersonalization(events, userId);
    }

    // Calculate facets for filtering UI
    const facets = calculateFacets(events);

    // Generate reason codes
    const reasonCodes = generateReasonCodes(events, data, userId);

    logger.info("Search completed", {
      query: data.query,
      resultsCount: events.length,
      userId
    });

    return {
      events: events.slice(0, data.limit || 50),
      totalCount: events.length,
      facets,
      reasonCodes
    };

  } catch (error: any) {
    logger.error("Search failed", { error: error.message });
    throw error;
  }
}

/**
 * Apply filters to Firestore query
 */
function applyFilters(
  query: admin.firestore.Query,
  filters: EventFilters
): admin.firestore.Query {
  
  // Category filter
  if (filters.categories && filters.categories.length > 0) {
    query = query.where("category", "in", filters.categories);
  }

  // Date range filter
  if (filters.dateRange) {
    const fromDate = admin.firestore.Timestamp.fromDate(new Date(filters.dateRange.from));
    const toDate = admin.firestore.Timestamp.fromDate(new Date(filters.dateRange.to));
    query = query.where("startAt", ">=", fromDate)
                 .where("startAt", "<=", toDate);
  }

  // Indoor filter
  if (filters.indoor !== undefined) {
    query = query.where("indoor", "==", filters.indoor);
  }

  // City filter
  if (filters.cityId) {
    query = query.where("cityId", "==", filters.cityId);
  }

  // Neighborhood filter
  if (filters.neighborhood) {
    query = query.where("neighborhood", "==", filters.neighborhood);
  }

  return query;
}

/**
 * Apply text search using BigQuery for vector similarity
 */
async function applyTextSearch(events: Event[], queryText: string): Promise<Event[]> {
  try {
    // Simple text matching for MVP
    // In production, this would use BigQuery ML for semantic search
    const searchTerms = queryText.toLowerCase().split(" ");
    
    return events.filter(event => {
      const searchableText = [
        event.title,
        event.description,
        event.venueName,
        ...event.tags
      ].join(" ").toLowerCase();
      
      return searchTerms.every(term => searchableText.includes(term));
    }).sort((a, b) => {
      // Rank by match quality
      const aScore = calculateTextMatchScore(a, searchTerms);
      const bScore = calculateTextMatchScore(b, searchTerms);
      return bScore - aScore;
    });
    
  } catch (error: any) {
    logger.error("Text search failed", { error: error.message });
    return events; // Fallback to unfiltered results
  }
}

/**
 * Calculate text match score for ranking
 */
function calculateTextMatchScore(event: Event, searchTerms: string[]): number {
  let score = 0;
  
  searchTerms.forEach(term => {
    // Title matches worth more
    if (event.title.toLowerCase().includes(term)) score += 10;
    // Description matches
    if (event.description.toLowerCase().includes(term)) score += 5;
    // Tag matches
    if (event.tags.some(tag => tag.toLowerCase().includes(term))) score += 3;
    // Venue matches
    if (event.venueName.toLowerCase().includes(term)) score += 2;
  });
  
  return score;
}

/**
 * Apply personalization based on user traits and social signals
 */
async function applyPersonalization(events: Event[], userId: string): Promise<Event[]> {
  try {
    // Check consent for personalization
    const hasConsent = await checkUserConsent(userId, ConsentScope.PERSONALIZATION);
    if (!hasConsent) {
      return events;
    }

    // Get user traits
    const userTraits = await getUserTraits(userId);
    if (!userTraits) {
      return events;
    }

    // Get friend signals if consent granted
    let friendEventIds: Set<string> = new Set();
    if (await checkUserConsent(userId, ConsentScope.SOCIAL_SIGNALS)) {
      friendEventIds = await getFriendEventSignals(userId);
    }

    // Score and sort events
    return events.map(event => {
      let score = 0;
      
      // Category preference
      if (userTraits.preferredCategories.includes(event.category)) {
        score += 20;
      }
      
      // Budget fit
      if (userTraits.budgetBandMAD) {
        const minPrice = Math.min(...event.priceTiers.map(t => t.priceMAD));
        if (minPrice >= userTraits.budgetBandMAD.min && 
            minPrice <= userTraits.budgetBandMAD.max) {
          score += 15;
        }
      }
      
      // Neighborhood preference
      if (event.neighborhood && userTraits.preferredNeighborhoods?.includes(event.neighborhood)) {
        score += 10;
      }
      
      // Friend attending boost
      if (friendEventIds.has(event.id!)) {
        score += 25;
      }
      
      // Interest match
      const interestMatch = userTraits.interests.some(interest => 
        event.tags.includes(interest) || 
        event.description.toLowerCase().includes(interest.toLowerCase())
      );
      if (interestMatch) {
        score += 10;
      }
      
      return { ...event, _score: score };
    }).sort((a: any, b: any) => b._score - a._score)
      .map(({ _score, ...event }) => event as Event);
    
  } catch (error: any) {
    logger.error("Personalization failed", { error: error.message });
    return events;
  }
}

/**
 * Get user traits for personalization
 */
async function getUserTraits(userId: string): Promise<UserTraits | null> {
  try {
    const doc = await db.collection("userTraits").doc(userId).get();
    if (!doc.exists) {
      return null;
    }
    return doc.data() as UserTraits;
  } catch (error: any) {
    logger.error("Failed to get user traits", { error: error.message });
    return null;
  }
}

/**
 * Check if user has granted consent for a specific scope
 */
async function checkUserConsent(userId: string, scope: ConsentScope): Promise<boolean> {
  try {
    const snapshot = await db.collection("consentGrants")
      .where("userId", "==", userId)
      .where("scope", "==", scope)
      .where("granted", "==", true)
      .limit(1)
      .get();
    
    if (snapshot.empty) {
      return false;
    }
    
    const consent = snapshot.docs[0].data() as ConsentGrant;
    
    // Check if consent has expired
    if (consent.expiresAt && consent.expiresAt.toDate() < new Date()) {
      return false;
    }
    
    return !consent.revokedAt;
  } catch (error: any) {
    logger.error("Failed to check consent", { error: error.message });
    return false;
  }
}

/**
 * Get events that user's friends are attending
 */
async function getFriendEventSignals(userId: string): Promise<Set<string>> {
  try {
    // Get user's friend list from Friends feature
    const friendsDoc = await db.collection("userTraits").doc(userId).get();
    const friendIds = friendsDoc.data()?.friendUserIds || [];
    
    if (friendIds.length === 0) {
      return new Set();
    }
    
    // Get events friends are attending
    const groupsSnapshot = await db.collection("attendanceGroups")
      .where("participantUserIds", "array-contains-any", friendIds)
      .where("status", "in", ["confirmed", "ordering"])
      .get();
    
    const eventIds = new Set<string>();
    groupsSnapshot.docs.forEach(doc => {
      const group = doc.data();
      eventIds.add(group.eventId);
    });
    
    return eventIds;
  } catch (error: any) {
    logger.error("Failed to get friend signals", { error: error.message });
    return new Set();
  }
}

/**
 * Calculate facets for filter UI
 */
function calculateFacets(events: Event[]): SearchFacets {
  const facets: SearchFacets = {
    categories: {},
    priceRanges: {},
    neighborhoods: {},
    tags: {}
  };
  
  events.forEach(event => {
    // Category facets
    facets.categories[event.category] = (facets.categories[event.category] || 0) + 1;
    
    // Price range facets
    const minPrice = Math.min(...event.priceTiers.map(t => t.priceMAD));
    const priceRange = getPriceRangeBucket(minPrice);
    facets.priceRanges[priceRange] = (facets.priceRanges[priceRange] || 0) + 1;
    
    // Neighborhood facets
    if (event.neighborhood) {
      facets.neighborhoods[event.neighborhood] = (facets.neighborhoods[event.neighborhood] || 0) + 1;
    }
    
    // Tag facets
    event.tags.forEach(tag => {
      facets.tags[tag] = (facets.tags[tag] || 0) + 1;
    });
  });
  
  return facets;
}

/**
 * Get price range bucket for faceting
 */
function getPriceRangeBucket(price: number): string {
  if (price < 100) return "0-100";
  if (price < 200) return "100-200";
  if (price < 500) return "200-500";
  if (price < 1000) return "500-1000";
  return "1000+";
}

/**
 * Generate reason codes explaining search results
 */
function generateReasonCodes(
  events: Event[],
  query: SearchQuery,
  userId?: string
): string[] {
  const codes: string[] = [];
  
  if (query.query) {
    codes.push(`text_match:${query.query}`);
  }
  
  if (query.filters.categories && query.filters.categories.length > 0) {
    codes.push(`category:${query.filters.categories.join(",")}`);
  }
  
  if (query.filters.priceRange) {
    codes.push(`price:${query.filters.priceRange.min}-${query.filters.priceRange.max}`);
  }
  
  if (query.filters.dateRange) {
    codes.push("date_filtered");
  }
  
  if (userId) {
    codes.push("personalized");
  }
  
  return codes;
}

/**
 * Track user interaction for analytics
 */
async function trackInteraction(interaction: Omit<EventInteraction, "id" | "timestamp">): Promise<void> {
  try {
    await db.collection("interactions").add({
      ...interaction,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
  } catch (error: any) {
    logger.error("Failed to track interaction", { error: error.message });
  }
}

/**
 * Get trending events based on interactions
 */
export async function getTrendingEvents(
  cityId: string,
  limit: number = 10
): Promise<Event[]> {
  try {
    // Query BigQuery for trending event IDs
    const query = `
      SELECT 
        entityId as eventId,
        COUNT(*) as interactions,
        COUNT(DISTINCT userId) as uniqueUsers
      FROM \`${process.env.GCP_PROJECT}.events.interactions\`
      WHERE 
        entityType = 'event'
        AND type IN ('view', 'save', 'rsvp')
        AND timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
      GROUP BY entityId
      ORDER BY interactions DESC
      LIMIT ${limit}
    `;
    
    const [rows] = await bigquery.query({ query });
    const trendingIds = rows.map((row: any) => row.eventId);
    
    if (trendingIds.length === 0) {
      // Fallback to upcoming events
      return getUpcomingEvents(cityId, limit);
    }
    
    // Fetch event details
    const events: Event[] = [];
    for (const eventId of trendingIds) {
      const doc = await db.collection("events").doc(eventId).get();
      if (doc.exists) {
        events.push({ id: doc.id, ...doc.data() } as Event);
      }
    }
    
    return events;
    
  } catch (error: any) {
    logger.error("Failed to get trending events", { error: error.message });
    return getUpcomingEvents(cityId, limit);
  }
}

/**
 * Get upcoming events as fallback
 */
async function getUpcomingEvents(cityId: string, limit: number): Promise<Event[]> {
  const snapshot = await db.collection("events")
    .where("status", "==", EventStatus.PUBLISHED)
    .where("cityId", "==", cityId)
    .where("startAt", ">", admin.firestore.Timestamp.now())
    .orderBy("startAt")
    .limit(limit)
    .get();
  
  return snapshot.docs.map(doc => ({
    id: doc.id,
    ...doc.data()
  })) as Event[];
}