import { BigQuery } from '@google-cloud/bigquery';
import { logger } from '../../shared/utils/logger';

export interface SearchAnalyticsEvent {
  userId: string;
  sessionId: string;
  timestamp: Date;
  query: string;
  location: {
    coordinates?: { lat: number; lng: number };
    placeName?: string;
  };
  dateRange: {
    checkIn: Date;
    checkOut: Date;
    nights: number;
  };
  guests: {
    adults: number;
    children: number;
    rooms: number;
  };
  filters?: any;
  resultCount: number;
  responseTimeMs: number;
  userAgent?: string;
  deviceType?: string;
}

export interface PropertyViewEvent {
  userId: string;
  sessionId: string;
  timestamp: Date;
  propertyId: string;
  propertyName: string;
  propertyType: string;
  location: {
    coordinates: { lat: number; lng: number };
    city: string;
    country: string;
  };
  priceRange?: {
    min: number;
    max: number;
    currency: string;
  };
  rating?: number;
  viewDurationSeconds?: number;
  clickSource: 'search_results' | 'recommendations' | 'saved' | 'direct';
  viewDepth: number; // How many properties viewed in this session
}

export interface BookingAnalyticsEvent {
  userId: string;
  sessionId: string;
  timestamp: Date;
  bookingId: string;
  propertyId: string;
  roomTypeId: string;
  ratePlanId: string;
  totalPrice: number;
  currency: string;
  nights: number;
  guests: {
    adults: number;
    children: number;
  };
  leadTime: number; // Days between booking and check-in
  bookingSource: 'organic' | 'recommendation' | 'saved';
  conversionFunnelStep: 'search' | 'view' | 'booking_form' | 'payment' | 'completed';
  paymentMethod: string;
  specialRequests?: string;
}

export interface UserPreferenceEvent {
  userId: string;
  timestamp: Date;
  action: 'favorite_add' | 'favorite_remove' | 'shortlist_create' | 'shortlist_add' | 'filter_change';
  propertyId?: string;
  propertyType?: string;
  priceRange?: { min: number; max: number };
  location?: { city: string; country: string };
  amenities?: string[];
  metadata?: any;
}

export class AccommodationsAnalyticsService {
  private bigQuery: BigQuery;
  private datasetId = 'accommodations_analytics';
  
  constructor() {
    this.bigQuery = new BigQuery();
  }

  async initialize(): Promise<void> {
    try {
      // Create dataset if it doesn't exist
      const [datasets] = await this.bigQuery.getDatasets();
      const datasetExists = datasets.some(dataset => dataset.id === this.datasetId);
      
      if (!datasetExists) {
        await this.bigQuery.createDataset(this.datasetId, {
          location: 'US',
          description: 'Analytics data for accommodations service',
        });
        logger.info(`Created BigQuery dataset: ${this.datasetId}`);
      }

      // Create tables if they don't exist
      await this.createTablesIfNeeded();
    } catch (error) {
      logger.error('Failed to initialize BigQuery analytics:', error);
      throw error;
    }
  }

  private async createTablesIfNeeded(): Promise<void> {
    const tables = [
      {
        name: 'search_events',
        schema: [
          { name: 'user_id', type: 'STRING', mode: 'REQUIRED' },
          { name: 'session_id', type: 'STRING', mode: 'REQUIRED' },
          { name: 'timestamp', type: 'TIMESTAMP', mode: 'REQUIRED' },
          { name: 'query', type: 'STRING', mode: 'NULLABLE' },
          { name: 'location_coordinates', type: 'GEOGRAPHY', mode: 'NULLABLE' },
          { name: 'location_place_name', type: 'STRING', mode: 'NULLABLE' },
          { name: 'check_in_date', type: 'DATE', mode: 'REQUIRED' },
          { name: 'check_out_date', type: 'DATE', mode: 'REQUIRED' },
          { name: 'nights', type: 'INTEGER', mode: 'REQUIRED' },
          { name: 'adults', type: 'INTEGER', mode: 'REQUIRED' },
          { name: 'children', type: 'INTEGER', mode: 'REQUIRED' },
          { name: 'rooms', type: 'INTEGER', mode: 'REQUIRED' },
          { name: 'filters', type: 'JSON', mode: 'NULLABLE' },
          { name: 'result_count', type: 'INTEGER', mode: 'REQUIRED' },
          { name: 'response_time_ms', type: 'INTEGER', mode: 'REQUIRED' },
          { name: 'user_agent', type: 'STRING', mode: 'NULLABLE' },
          { name: 'device_type', type: 'STRING', mode: 'NULLABLE' },
        ],
      },
      {
        name: 'property_view_events',
        schema: [
          { name: 'user_id', type: 'STRING', mode: 'REQUIRED' },
          { name: 'session_id', type: 'STRING', mode: 'REQUIRED' },
          { name: 'timestamp', type: 'TIMESTAMP', mode: 'REQUIRED' },
          { name: 'property_id', type: 'STRING', mode: 'REQUIRED' },
          { name: 'property_name', type: 'STRING', mode: 'REQUIRED' },
          { name: 'property_type', type: 'STRING', mode: 'REQUIRED' },
          { name: 'location_coordinates', type: 'GEOGRAPHY', mode: 'REQUIRED' },
          { name: 'city', type: 'STRING', mode: 'REQUIRED' },
          { name: 'country', type: 'STRING', mode: 'REQUIRED' },
          { name: 'price_min', type: 'NUMERIC', mode: 'NULLABLE' },
          { name: 'price_max', type: 'NUMERIC', mode: 'NULLABLE' },
          { name: 'currency', type: 'STRING', mode: 'NULLABLE' },
          { name: 'rating', type: 'NUMERIC', mode: 'NULLABLE' },
          { name: 'view_duration_seconds', type: 'INTEGER', mode: 'NULLABLE' },
          { name: 'click_source', type: 'STRING', mode: 'REQUIRED' },
          { name: 'view_depth', type: 'INTEGER', mode: 'REQUIRED' },
        ],
      },
      {
        name: 'booking_events',
        schema: [
          { name: 'user_id', type: 'STRING', mode: 'REQUIRED' },
          { name: 'session_id', type: 'STRING', mode: 'REQUIRED' },
          { name: 'timestamp', type: 'TIMESTAMP', mode: 'REQUIRED' },
          { name: 'booking_id', type: 'STRING', mode: 'REQUIRED' },
          { name: 'property_id', type: 'STRING', mode: 'REQUIRED' },
          { name: 'room_type_id', type: 'STRING', mode: 'REQUIRED' },
          { name: 'rate_plan_id', type: 'STRING', mode: 'REQUIRED' },
          { name: 'total_price', type: 'NUMERIC', mode: 'REQUIRED' },
          { name: 'currency', type: 'STRING', mode: 'REQUIRED' },
          { name: 'nights', type: 'INTEGER', mode: 'REQUIRED' },
          { name: 'adults', type: 'INTEGER', mode: 'REQUIRED' },
          { name: 'children', type: 'INTEGER', mode: 'REQUIRED' },
          { name: 'lead_time_days', type: 'INTEGER', mode: 'REQUIRED' },
          { name: 'booking_source', type: 'STRING', mode: 'REQUIRED' },
          { name: 'conversion_funnel_step', type: 'STRING', mode: 'REQUIRED' },
          { name: 'payment_method', type: 'STRING', mode: 'REQUIRED' },
          { name: 'special_requests', type: 'STRING', mode: 'NULLABLE' },
        ],
      },
      {
        name: 'user_preference_events',
        schema: [
          { name: 'user_id', type: 'STRING', mode: 'REQUIRED' },
          { name: 'timestamp', type: 'TIMESTAMP', mode: 'REQUIRED' },
          { name: 'action', type: 'STRING', mode: 'REQUIRED' },
          { name: 'property_id', type: 'STRING', mode: 'NULLABLE' },
          { name: 'property_type', type: 'STRING', mode: 'NULLABLE' },
          { name: 'price_min', type: 'NUMERIC', mode: 'NULLABLE' },
          { name: 'price_max', type: 'NUMERIC', mode: 'NULLABLE' },
          { name: 'city', type: 'STRING', mode: 'NULLABLE' },
          { name: 'country', type: 'STRING', mode: 'NULLABLE' },
          { name: 'amenities', type: 'STRING', mode: 'REPEATED' },
          { name: 'metadata', type: 'JSON', mode: 'NULLABLE' },
        ],
      },
    ];

    for (const tableConfig of tables) {
      try {
        const table = this.bigQuery.dataset(this.datasetId).table(tableConfig.name);
        const [exists] = await table.exists();
        
        if (!exists) {
          await table.create({
            schema: { fields: tableConfig.schema },
            timePartitioning: {
              type: 'DAY',
              field: 'timestamp',
            },
            clustering: {
              fields: ['user_id', 'session_id'],
            },
          });
          logger.info(`Created BigQuery table: ${this.datasetId}.${tableConfig.name}`);
        }
      } catch (error) {
        logger.error(`Failed to create table ${tableConfig.name}:`, error);
      }
    }
  }

  async trackSearchEvent(event: SearchAnalyticsEvent): Promise<void> {
    try {
      const table = this.bigQuery.dataset(this.datasetId).table('search_events');
      
      const row = {
        user_id: event.userId,
        session_id: event.sessionId,
        timestamp: event.timestamp.toISOString(),
        query: event.query,
        location_coordinates: event.location.coordinates 
          ? `POINT(${event.location.coordinates.lng} ${event.location.coordinates.lat})` 
          : null,
        location_place_name: event.location.placeName,
        check_in_date: event.dateRange.checkIn.toISOString().split('T')[0],
        check_out_date: event.dateRange.checkOut.toISOString().split('T')[0],
        nights: event.dateRange.nights,
        adults: event.guests.adults,
        children: event.guests.children,
        rooms: event.guests.rooms,
        filters: event.filters ? JSON.stringify(event.filters) : null,
        result_count: event.resultCount,
        response_time_ms: event.responseTimeMs,
        user_agent: event.userAgent,
        device_type: event.deviceType,
      };

      await table.insert([row]);
      logger.info('Tracked search event', { userId: event.userId, query: event.query });
    } catch (error) {
      logger.error('Failed to track search event:', error);
    }
  }

  async trackPropertyView(event: PropertyViewEvent): Promise<void> {
    try {
      const table = this.bigQuery.dataset(this.datasetId).table('property_view_events');
      
      const row = {
        user_id: event.userId,
        session_id: event.sessionId,
        timestamp: event.timestamp.toISOString(),
        property_id: event.propertyId,
        property_name: event.propertyName,
        property_type: event.propertyType,
        location_coordinates: `POINT(${event.location.coordinates.lng} ${event.location.coordinates.lat})`,
        city: event.location.city,
        country: event.location.country,
        price_min: event.priceRange?.min,
        price_max: event.priceRange?.max,
        currency: event.priceRange?.currency,
        rating: event.rating,
        view_duration_seconds: event.viewDurationSeconds,
        click_source: event.clickSource,
        view_depth: event.viewDepth,
      };

      await table.insert([row]);
      logger.info('Tracked property view', { userId: event.userId, propertyId: event.propertyId });
    } catch (error) {
      logger.error('Failed to track property view:', error);
    }
  }

  async trackBookingEvent(event: BookingAnalyticsEvent): Promise<void> {
    try {
      const table = this.bigQuery.dataset(this.datasetId).table('booking_events');
      
      const row = {
        user_id: event.userId,
        session_id: event.sessionId,
        timestamp: event.timestamp.toISOString(),
        booking_id: event.bookingId,
        property_id: event.propertyId,
        room_type_id: event.roomTypeId,
        rate_plan_id: event.ratePlanId,
        total_price: event.totalPrice,
        currency: event.currency,
        nights: event.nights,
        adults: event.guests.adults,
        children: event.guests.children,
        lead_time_days: event.leadTime,
        booking_source: event.bookingSource,
        conversion_funnel_step: event.conversionFunnelStep,
        payment_method: event.paymentMethod,
        special_requests: event.specialRequests,
      };

      await table.insert([row]);
      logger.info('Tracked booking event', { userId: event.userId, bookingId: event.bookingId });
    } catch (error) {
      logger.error('Failed to track booking event:', error);
    }
  }

  async trackUserPreference(event: UserPreferenceEvent): Promise<void> {
    try {
      const table = this.bigQuery.dataset(this.datasetId).table('user_preference_events');
      
      const row = {
        user_id: event.userId,
        timestamp: event.timestamp.toISOString(),
        action: event.action,
        property_id: event.propertyId,
        property_type: event.propertyType,
        price_min: event.priceRange?.min,
        price_max: event.priceRange?.max,
        city: event.location?.city,
        country: event.location?.country,
        amenities: event.amenities || [],
        metadata: event.metadata ? JSON.stringify(event.metadata) : null,
      };

      await table.insert([row]);
      logger.info('Tracked user preference', { userId: event.userId, action: event.action });
    } catch (error) {
      logger.error('Failed to track user preference:', error);
    }
  }

  // Analytics queries for ML recommendations
  async getUserSearchPatterns(userId: string, limit: number = 100): Promise<any[]> {
    const query = `
      SELECT 
        location_place_name,
        AVG(nights) as avg_nights,
        AVG(adults + children) as avg_guests,
        COUNT(*) as search_count,
        MAX(timestamp) as last_search
      FROM \`${this.bigQuery.projectId}.${this.datasetId}.search_events\`
      WHERE user_id = @userId
        AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
      GROUP BY location_place_name
      ORDER BY search_count DESC, last_search DESC
      LIMIT @limit
    `;

    const [rows] = await this.bigQuery.query({
      query,
      params: { userId, limit },
    });

    return rows;
  }

  async getUserPropertyPreferences(userId: string): Promise<any> {
    const query = `
      WITH user_views AS (
        SELECT 
          property_type,
          city,
          country,
          price_min,
          price_max,
          rating,
          COUNT(*) as view_count,
          AVG(view_duration_seconds) as avg_view_duration
        FROM \`${this.bigQuery.projectId}.${this.datasetId}.property_view_events\`
        WHERE user_id = @userId
          AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
        GROUP BY property_type, city, country, price_min, price_max, rating
      ),
      user_bookings AS (
        SELECT 
          property_id,
          total_price,
          currency,
          nights,
          adults + children as total_guests
        FROM \`${this.bigQuery.projectId}.${this.datasetId}.booking_events\`
        WHERE user_id = @userId
          AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 365 DAY)
      )
      SELECT 
        ARRAY_AGG(STRUCT(property_type, view_count, avg_view_duration) ORDER BY view_count DESC LIMIT 5) as preferred_types,
        ARRAY_AGG(DISTINCT city ORDER BY view_count DESC LIMIT 5) as preferred_cities,
        AVG(price_min) as avg_price_min,
        AVG(price_max) as avg_price_max,
        AVG(rating) as preferred_min_rating,
        (SELECT AVG(total_price) FROM user_bookings) as avg_booking_value,
        (SELECT AVG(nights) FROM user_bookings) as avg_stay_duration
      FROM user_views
    `;

    const [rows] = await this.bigQuery.query({
      query,
      params: { userId },
    });

    return rows[0] || null;
  }

  async getPopularDestinations(limit: number = 20): Promise<any[]> {
    const query = `
      SELECT 
        location_place_name as destination,
        COUNT(DISTINCT user_id) as unique_searchers,
        COUNT(*) as total_searches,
        AVG(result_count) as avg_results,
        MAX(timestamp) as last_search
      FROM \`${this.bigQuery.projectId}.${this.datasetId}.search_events\`
      WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
        AND location_place_name IS NOT NULL
      GROUP BY location_place_name
      HAVING unique_searchers >= 3
      ORDER BY unique_searchers DESC, total_searches DESC
      LIMIT @limit
    `;

    const [rows] = await this.bigQuery.query({
      query,
      params: { limit },
    });

    return rows;
  }

  async getPropertyPerformanceMetrics(propertyId: string): Promise<any> {
    const query = `
      WITH property_views AS (
        SELECT COUNT(*) as total_views,
               COUNT(DISTINCT user_id) as unique_viewers,
               AVG(view_duration_seconds) as avg_view_duration
        FROM \`${this.bigQuery.projectId}.${this.datasetId}.property_view_events\`
        WHERE property_id = @propertyId
          AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
      ),
      property_bookings AS (
        SELECT COUNT(*) as total_bookings,
               AVG(total_price) as avg_booking_value,
               AVG(nights) as avg_nights
        FROM \`${this.bigQuery.projectId}.${this.datasetId}.booking_events\`
        WHERE property_id = @propertyId
          AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
      )
      SELECT 
        pv.*,
        pb.*,
        SAFE_DIVIDE(pb.total_bookings, pv.total_views) as conversion_rate
      FROM property_views pv
      CROSS JOIN property_bookings pb
    `;

    const [rows] = await this.bigQuery.query({
      query,
      params: { propertyId },
    });

    return rows[0] || null;
  }
}

// Singleton instance
export const analyticsService = new AccommodationsAnalyticsService();