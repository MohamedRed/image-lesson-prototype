import { BigQuery } from "@google-cloud/bigquery";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { Event, EventInteraction, InteractionType } from "./types";

const bigquery = new BigQuery();
const db = admin.firestore();

// Table names
const EVENTS_TABLE = "events.events_catalog";
const INTERACTIONS_TABLE = "events.user_interactions";
const EMBEDDINGS_TABLE = "events.event_embeddings";
const ANALYTICS_TABLE = "events.event_analytics";

/**
 * Enhanced search with vector similarity using BigQuery ML
 */
export async function vectorSearchEvents(
  query: string,
  filters: any = {},
  userId?: string,
  limit: number = 50
): Promise<{
  events: Event[];
  relevanceScores: number[];
  semanticMatches: boolean;
}> {
  try {
    // Generate query embedding using ML model
    const queryEmbedding = await generateTextEmbedding(query);
    
    // Build semantic search query
    const searchQuery = `
      WITH semantic_matches AS (
        SELECT 
          e.*,
          ML.DISTANCE(em.embedding, @queryEmbedding, 'COSINE') as semantic_distance,
          CASE 
            WHEN CONTAINS_SUBSTR(LOWER(e.title), LOWER(@query)) THEN 3.0
            WHEN CONTAINS_SUBSTR(LOWER(e.description), LOWER(@query)) THEN 2.0  
            WHEN ARRAY_LENGTH(ARRAY(SELECT tag FROM UNNEST(e.tags) as tag WHERE CONTAINS_SUBSTR(LOWER(tag), LOWER(@query)))) > 0 THEN 1.5
            ELSE 0.0
          END as text_score,
          ROW_NUMBER() OVER (ORDER BY ML.DISTANCE(em.embedding, @queryEmbedding, 'COSINE')) as semantic_rank
        FROM \`${EVENTS_TABLE}\` e
        JOIN \`${EMBEDDINGS_TABLE}\` em ON e.id = em.event_id
        WHERE e.status = 'published' 
          AND e.start_at > CURRENT_TIMESTAMP()
          ${buildFilterConditions(filters)}
      ),
      ranked_results AS (
        SELECT *,
          (4.0 - semantic_distance) * 0.6 + text_score * 0.4 as combined_score
        FROM semantic_matches
        ORDER BY combined_score DESC
        LIMIT @limit
      )
      SELECT * FROM ranked_results
    `;

    const options = {
      query: searchQuery,
      params: {
        queryEmbedding: queryEmbedding,
        query: query,
        limit: limit
      },
      types: {
        queryEmbedding: 'ARRAY<FLOAT64>',
        query: 'STRING',
        limit: 'INT64'
      }
    };

    const [rows] = await bigquery.query(options);
    
    // Convert to Event objects
    const events = rows.map((row: any) => convertBigQueryRowToEvent(row));
    const relevanceScores = rows.map((row: any) => row.combined_score);
    
    // Apply personalization if user provided
    let personalizedEvents = events;
    if (userId) {
      personalizedEvents = await applyPersonalizationRanking(events, userId);
    }

    logger.info("Vector search completed", {
      query: query.substring(0, 50),
      resultsCount: events.length,
      avgRelevanceScore: relevanceScores.reduce((a, b) => a + b, 0) / relevanceScores.length,
      semanticMatches: true
    });

    return {
      events: personalizedEvents,
      relevanceScores,
      semanticMatches: true
    };

  } catch (error: any) {
    logger.error("Vector search failed, falling back to text search", { error: error.message });
    
    // Fallback to basic text search
    return await basicTextSearch(query, filters, userId, limit);
  }
}

/**
 * Generate text embeddings using BigQuery ML
 */
async function generateTextEmbedding(text: string): Promise<number[]> {
  try {
    const query = `
      SELECT embedding
      FROM ML.GENERATE_TEXT_EMBEDDINGS(
        MODEL \`events.text_embedding_model\`,
        (SELECT @text as content)
      )
    `;

    const [rows] = await bigquery.query({
      query,
      params: { text },
      types: { text: 'STRING' }
    });

    return rows[0]?.embedding || [];
  } catch (error: any) {
    logger.error("Failed to generate embedding", { error: error.message });
    return [];
  }
}

/**
 * Advanced event analytics with ML predictions
 */
export async function getEventAnalytics(
  eventId?: string,
  timeRange?: { start: Date; end: Date }
): Promise<{
  popularEvents: Array<{ eventId: string; score: number; trend: string }>;
  userEngagement: { averageSessionTime: number; conversionRate: number };
  predictions: { expectedAttendance: number; recommendedPricing: number };
  cohortAnalysis: any;
}> {
  try {
    const timeFilter = timeRange ? 
      `AND timestamp BETWEEN @startTime AND @endTime` : 
      `AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)`;

    // Popular events with trend analysis
    const popularEventsQuery = `
      WITH event_metrics AS (
        SELECT 
          entity_id as event_id,
          COUNT(*) as total_interactions,
          COUNT(DISTINCT user_id) as unique_users,
          AVG(CASE WHEN type = 'view' THEN 1 ELSE 0 END) as view_rate,
          AVG(CASE WHEN type = 'save' THEN 1 ELSE 0 END) as save_rate,
          AVG(CASE WHEN type = 'rsvp' THEN 1 ELSE 0 END) as conversion_rate
        FROM \`${INTERACTIONS_TABLE}\`
        WHERE entity_type = 'event' ${timeFilter}
        GROUP BY entity_id
      ),
      trend_analysis AS (
        SELECT 
          event_id,
          total_interactions,
          unique_users,
          (conversion_rate * 0.5 + save_rate * 0.3 + view_rate * 0.2) as engagement_score,
          CASE 
            WHEN total_interactions > LAG(total_interactions, 1) OVER (PARTITION BY event_id ORDER BY total_interactions) THEN 'rising'
            WHEN total_interactions < LAG(total_interactions, 1) OVER (PARTITION BY event_id ORDER BY total_interactions) THEN 'declining'
            ELSE 'stable'
          END as trend
        FROM event_metrics
      )
      SELECT event_id, engagement_score as score, trend
      FROM trend_analysis
      ORDER BY engagement_score DESC
      LIMIT 20
    `;

    // User engagement metrics
    const engagementQuery = `
      SELECT 
        AVG(session_duration) as avg_session_time,
        SAFE_DIVIDE(
          COUNT(CASE WHEN type = 'order' THEN 1 END),
          COUNT(CASE WHEN type = 'view' THEN 1 END)
        ) as conversion_rate
      FROM \`${INTERACTIONS_TABLE}\`
      WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    `;

    // ML predictions for event performance
    const predictionQuery = eventId ? `
      SELECT 
        predicted_attendance,
        recommended_price
      FROM ML.PREDICT(
        MODEL \`events.attendance_prediction_model\`,
        (SELECT 
          @eventId as event_id,
          EXTRACT(DAYOFWEEK FROM start_at) as day_of_week,
          EXTRACT(HOUR FROM start_at) as hour_of_day,
          indoor,
          ARRAY_LENGTH(price_tiers) as price_tier_count,
          (SELECT MIN(price_mad) FROM UNNEST(price_tiers)) as min_price
         FROM \`${EVENTS_TABLE}\` WHERE id = @eventId)
      )
    ` : null;

    // Execute queries in parallel
    const queries = await Promise.all([
      bigquery.query({ 
        query: popularEventsQuery,
        params: timeRange ? { 
          startTime: timeRange.start.toISOString(),
          endTime: timeRange.end.toISOString()
        } : {}
      }),
      bigquery.query({ query: engagementQuery }),
      predictionQuery ? bigquery.query({ 
        query: predictionQuery,
        params: { eventId }
      }) : Promise.resolve([[]]),
    ]);

    const [popularEvents] = queries[0];
    const [engagementData] = queries[1];
    const [predictions] = queries[2];

    // Cohort analysis for user retention
    const cohortAnalysis = await getCohortAnalysis(timeRange);

    return {
      popularEvents: popularEvents.map((row: any) => ({
        eventId: row.event_id,
        score: row.score,
        trend: row.trend
      })),
      userEngagement: {
        averageSessionTime: engagementData[0]?.avg_session_time || 0,
        conversionRate: engagementData[0]?.conversion_rate || 0
      },
      predictions: {
        expectedAttendance: predictions[0]?.predicted_attendance || 0,
        recommendedPricing: predictions[0]?.recommended_price || 0
      },
      cohortAnalysis
    };

  } catch (error: any) {
    logger.error("Analytics query failed", { error: error.message });
    return {
      popularEvents: [],
      userEngagement: { averageSessionTime: 0, conversionRate: 0 },
      predictions: { expectedAttendance: 0, recommendedPricing: 0 },
      cohortAnalysis: {}
    };
  }
}

/**
 * Real-time event streaming analytics
 */
export async function processEventStream(interactions: EventInteraction[]): Promise<void> {
  try {
    // Prepare data for streaming insert
    const rows = interactions.map(interaction => ({
      insertId: `${interaction.userId}-${interaction.timestamp.getTime()}`,
      json: {
        user_id: interaction.userId,
        entity_id: interaction.entityId,
        entity_type: interaction.entityType,
        interaction_type: interaction.type,
        timestamp: interaction.timestamp.toISOString(),
        context: JSON.stringify(interaction.context || {})
      }
    }));

    // Stream to BigQuery
    const table = bigquery.dataset('events').table('user_interactions');
    await table.insert(rows);

    // Update real-time aggregates
    await updateRealTimeMetrics(interactions);

    logger.info("Event stream processed", { count: interactions.length });

  } catch (error: any) {
    logger.error("Failed to process event stream", { error: error.message });
  }
}

/**
 * Update event embeddings when events are created/modified
 */
export async function updateEventEmbeddings(events: Event[]): Promise<void> {
  try {
    const embeddingRows = [];

    for (const event of events) {
      // Create composite text for embedding
      const eventText = `${event.title} ${event.description} ${event.tags.join(' ')} ${event.category} ${event.venueName}`;
      
      // Generate embedding
      const embedding = await generateTextEmbedding(eventText);
      
      if (embedding.length > 0) {
        embeddingRows.push({
          insertId: event.id,
          json: {
            event_id: event.id,
            embedding: embedding,
            text_content: eventText,
            updated_at: new Date().toISOString()
          }
        });
      }
    }

    if (embeddingRows.length > 0) {
      const table = bigquery.dataset('events').table('event_embeddings');
      await table.insert(embeddingRows);
      
      logger.info("Event embeddings updated", { count: embeddingRows.length });
    }

  } catch (error: any) {
    logger.error("Failed to update embeddings", { error: error.message });
  }
}

// Helper functions
function buildFilterConditions(filters: any): string {
  const conditions = [];
  
  if (filters.categories?.length > 0) {
    conditions.push(`AND e.category IN UNNEST(@categories)`);
  }
  
  if (filters.priceRange) {
    conditions.push(`AND (SELECT MIN(price_mad) FROM UNNEST(e.price_tiers)) BETWEEN @minPrice AND @maxPrice`);
  }
  
  if (filters.dateRange) {
    conditions.push(`AND e.start_at BETWEEN @startDate AND @endDate`);
  }
  
  if (filters.indoor !== undefined) {
    conditions.push(`AND e.indoor = @indoor`);
  }
  
  return conditions.join(' ');
}

function convertBigQueryRowToEvent(row: any): Event {
  // Convert BigQuery row format to Event model
  return {
    id: row.id,
    promoterId: row.promoter_id,
    title: row.title,
    category: row.category,
    description: row.description,
    images: row.images || [],
    rules: row.rules || [],
    priceTiers: row.price_tiers || [],
    location: new admin.firestore.GeoPoint(row.location?.lat || 0, row.location?.lng || 0),
    venueName: row.venue_name,
    neighborhood: row.neighborhood,
    startAt: row.start_at,
    endAt: row.end_at,
    indoor: row.indoor,
    tags: row.tags || [],
    seating: row.seating || { hasSeatMap: false, generalAdmission: true },
    status: row.status
  } as Event;
}

async function basicTextSearch(query: string, filters: any, userId?: string, limit: number = 50): Promise<any> {
  // Fallback to Firestore text search
  const events: Event[] = [];
  // Implementation would go here
  return {
    events,
    relevanceScores: [],
    semanticMatches: false
  };
}

async function applyPersonalizationRanking(events: Event[], userId: string): Promise<Event[]> {
  // Apply user preference based re-ranking
  // This would use user traits and interaction history
  return events; // For now, return as-is
}

async function getCohortAnalysis(timeRange?: { start: Date; end: Date }): Promise<any> {
  // Implement cohort analysis query
  return {};
}

async function updateRealTimeMetrics(interactions: EventInteraction[]): Promise<void> {
  // Update real-time aggregate tables
  // This would update counters for trending calculations
}