import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { SearchService } from '../services/search-service';
import { RecommendationService } from '../services/recommendation-service';
import { BookingService } from '../services/booking-service';
import { ImportService } from '../services/import-service';
import { VoiceService } from '../services/voice-service';
import { validateSearchRequest, validateBookingRequest } from '../utils/validators';
import { rateLimiter } from '../../shared/middleware/rate-limiter';
import { authenticate } from '../../shared/middleware/auth';
import { advancedRateLimiter } from '../middleware/advanced-rate-limiter';
import { createProviderProtection, ProviderRetryHandler } from '../middleware/provider-protection';
import { logger } from '../../shared/utils/logger';
import { mapboxGeocodingService, searchDestinations, getLocationFromCoordinates } from '../services/geocoding-service';
import { analyticsService, SearchAnalyticsEvent, PropertyViewEvent, BookingAnalyticsEvent } from '../services/analytics-service';
import { cloudTasksService } from '../services/cloud-tasks-service';
import { providerService } from '../services/provider-service';
import { cacheService } from '../services/cache-service';
import { monitoringService } from '../services/monitoring-service';

// Initialize services
const searchService = new SearchService();
const recommendationService = new RecommendationService();
const bookingService = new BookingService();
const importService = new ImportService();
const voiceService = new VoiceService();

/**
 * Search for accommodations
 * GET /accommodations/search
 */
export const searchAccommodations = functions
  .runWith({
    timeoutSeconds: 30,
    memory: '1GB',
  })
  .https.onRequest(async (req, res) => {
    // Apply tiered rate limiting
    const tieredRateLimit = advancedRateLimiter.createTieredRateLimit({
      free: {
        windowMs: 60 * 1000, // 1 minute
        maxRequests: 30, // 30 searches per minute for free users
      },
      premium: {
        windowMs: 60 * 1000,
        maxRequests: 100, // 100 searches per minute for premium
      },
      enterprise: {
        windowMs: 60 * 1000,
        maxRequests: 500, // 500 searches per minute for enterprise
      },
    });

    // Apply adaptive rate limiting based on system load
    const adaptiveRateLimit = advancedRateLimiter.createAdaptiveRateLimit({
      windowMs: 60 * 1000,
      maxRequests: 200, // Base limit that adapts to system load
    });

    try {
      // CORS
      res.set('Access-Control-Allow-Origin', '*');
      if (req.method === 'OPTIONS') {
        res.set('Access-Control-Allow-Methods', 'GET, POST');
        res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
        res.status(204).send('');
        return;
      }
      
      // Apply both rate limiters
      await new Promise<void>((resolve, reject) => {
        tieredRateLimit(req, res, (err) => {
          if (err) reject(err);
          else resolve();
        });
      });

      await new Promise<void>((resolve, reject) => {
        adaptiveRateLimit(req, res, (err) => {
          if (err) reject(err);
          else resolve();
        });
      });
      
      // Parse and validate request
      const searchRequest = validateSearchRequest(req.query);
      
      // Get user ID if authenticated (optional for search)
      let userId: string | undefined;
      try {
        const authResult = await authenticate(req);
        userId = authResult.uid;
      } catch {
        // Continue without authentication
      }
      
      // Generate unique request ID for tracking
      const requestId = `search_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      
      // Check cache first for quick response
      const cacheKey = `search:aggregated:${JSON.stringify(searchRequest)}`;
      const cachedResults = await cacheService.get(cacheKey);
      
      if (cachedResults) {
        logger.info('Returning cached aggregated results', { requestId, cacheHit: true });
        res.set('X-Cache', 'HIT');
        res.set('Cache-Control', 'public, max-age=300, s-maxage=600');
        res.json(cachedResults);
        return;
      }
      
      // Get available providers for this region
      const availableProviders = await providerService.getAvailableProviders(
        searchRequest.location
      );
      
      // Start distributed search using Cloud Tasks
      const startTime = Date.now();
      await cloudTasksService.scheduleProviderSearchTasks(
        searchRequest,
        availableProviders,
        requestId,
        userId || 'anonymous',
        {
          delaySeconds: 0, // Start immediately
          maxRetries: 2
        }
      );
      
      // Schedule batch processing to aggregate results
      await cloudTasksService.scheduleBatchProcessingTask(
        requestId,
        userId || 'anonymous',
        availableProviders.length,
        30 // Wait 30 seconds for providers to complete
      );
      
      // For immediate response, try to get quick results from fastest providers
      const quickResults = await getQuickSearchResults(searchRequest, requestId);
      const responseTime = Date.now() - startTime;
      
      // Track analytics event
      if (userId) {
        const searchEvent: SearchAnalyticsEvent = {
          userId,
          sessionId: req.headers['x-session-id'] as string || `session_${Date.now()}`,
          timestamp: new Date(),
          query: searchRequest.location.toString(),
          location: {
            coordinates: searchRequest.location.type === 'coordinates' 
              ? { lat: searchRequest.location.lat, lng: searchRequest.location.lng }
              : undefined,
            placeName: searchRequest.location.type === 'address' ? searchRequest.location.address : undefined,
          },
          dateRange: {
            checkIn: searchRequest.dateRange.startDate,
            checkOut: searchRequest.dateRange.endDate,
            nights: Math.ceil((searchRequest.dateRange.endDate.getTime() - searchRequest.dateRange.startDate.getTime()) / (1000 * 60 * 60 * 24)),
          },
          guests: {
            adults: searchRequest.guests.adults,
            children: searchRequest.guests.children,
            rooms: searchRequest.guests.rooms,
          },
          filters: searchRequest.filters,
          resultCount: quickResults.properties?.length || 0,
          responseTimeMs: responseTime,
          userAgent: req.headers['user-agent'],
          deviceType: req.headers['user-agent']?.includes('Mobile') ? 'mobile' : 'desktop',
        };
        
        // Track asynchronously to avoid blocking response
        analyticsService.trackSearchEvent(searchEvent).catch(error => {
          logger.error('Failed to track search analytics:', error);
        });
      }
      
      // Record search performance metrics
      await monitoringService.recordSearchMetrics(
        responseTime,
        quickResults.properties?.length || 0,
        false, // Not cached since we checked cache earlier
        availableProviders?.length || 0,
        searchRequest.location.toString()
      ).catch(error => {
        logger.error('Failed to record search metrics:', error);
      });
      
      // Set cache headers and response metadata
      res.set('Cache-Control', 'public, max-age=300, s-maxage=600');
      res.set('X-Request-ID', requestId);
      res.set('X-Search-Status', quickResults.status);
      
      res.json(quickResults);
    } catch (error) {
      logger.error('Search error:', error);
      res.status(500).json({
        error: 'Search failed',
        message: (error as Error).message,
      });
    }
  });

/**
 * Get aggregated search results from Cloud Tasks
 * GET /accommodations/search/{requestId}/results
 */
export const getAggregatedSearchResults = functions
  .runWith({
    timeoutSeconds: 10,
    memory: '512MB',
  })
  .https.onRequest(async (req, res) => {
    try {
      res.set('Access-Control-Allow-Origin', '*');
      if (req.method === 'OPTIONS') {
        res.set('Access-Control-Allow-Methods', 'GET');
        res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
        res.status(204).send('');
        return;
      }

      const requestId = req.params[0]?.split('/')[0]; // Extract from path
      if (!requestId) {
        res.status(400).json({ error: 'Request ID required' });
        return;
      }

      // Check if final results are available
      const { getFirestore } = await import('firebase-admin/firestore');
      const db = getFirestore();

      const finalResultsDoc = await db
        .collection('accommodation-search-final')
        .doc(requestId)
        .get();

      if (finalResultsDoc.exists) {
        const finalData = finalResultsDoc.data();
        
        // Cache the final results
        const cacheKey = `search:aggregated:${requestId}`;
        await cacheService.set(cacheKey, finalData, 600); // Cache for 10 minutes
        
        res.set('X-Cache', 'MISS');
        res.set('X-Search-Status', 'completed');
        res.set('Cache-Control', 'public, max-age=600, s-maxage=1200');
        
        res.json({
          ...finalData,
          status: 'completed'
        });
      } else {
        // Check if results are still being processed
        const intermediateResults = await db
          .collection('accommodation-search-results')
          .where('requestId', '==', requestId)
          .get();

        const providerResults = intermediateResults.docs.map(doc => doc.data());
        
        res.status(202).json({
          requestId,
          status: 'processing',
          message: 'Search results are still being aggregated',
          completedProviders: providerResults.length,
          partialResults: providerResults.flatMap(r => r.results || []).slice(0, 20)
        });
      }
    } catch (error) {
      logger.error('Get aggregated results error:', error);
      res.status(500).json({
        error: 'Failed to get search results',
        message: (error as Error).message,
      });
    }
  });

/**
 * Get accommodation recommendations
 * GET /accommodations/recommendations
 */
export const getRecommendations = functions
  .runWith({
    timeoutSeconds: 30,
    memory: '1GB',
  })
  .https.onRequest(async (req, res) => {
    try {
      res.set('Access-Control-Allow-Origin', '*');
      if (req.method === 'OPTIONS') {
        res.set('Access-Control-Allow-Methods', 'GET');
        res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
        res.status(204).send('');
        return;
      }
      
      // Authenticate user (required for recommendations)
      const authResult = await authenticate(req);
      const userId = authResult.uid;
      
      // Parse request
      const context = req.body || {};
      
      // Get recommendations
      const recommendations = await recommendationService.getRecommendations(
        userId,
        context
      );
      
      res.json(recommendations);
    } catch (error) {
      logger.error('Recommendations error:', error);
      res.status(500).json({
        error: 'Failed to get recommendations',
        message: (error as Error).message,
      });
    }
  });

/**
 * Get property details
 * GET /accommodations/properties/{id}
 */
export const getPropertyDetails = functions
  .runWith({
    timeoutSeconds: 20,
    memory: '512MB',
  })
  .https.onRequest(async (req, res) => {
    try {
      res.set('Access-Control-Allow-Origin', '*');
      if (req.method === 'OPTIONS') {
        res.set('Access-Control-Allow-Methods', 'GET');
        res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
        res.status(204).send('');
        return;
      }
      
      // Extract property ID from path
      const pathParts = req.path.split('/');
      const propertyId = pathParts[pathParts.length - 1];
      
      if (!propertyId) {
        res.status(400).json({ error: 'Property ID is required' });
        return;
      }
      
      // Get property details
      const details = await searchService.getPropertyDetails(propertyId, req.query);
      
      // Cache for 15 minutes
      res.set('Cache-Control', 'public, max-age=900, s-maxage=1800');
      res.json(details);
    } catch (error) {
      logger.error('Property details error:', error);
      res.status(500).json({
        error: 'Failed to get property details',
        message: (error as Error).message,
      });
    }
  });

/**
 * Create a booking
 * POST /accommodations/book
 */
export const createBooking = functions
  .runWith({
    timeoutSeconds: 60,
    memory: '1GB',
  })
  .https.onRequest(async (req, res) => {
    try {
      res.set('Access-Control-Allow-Origin', '*');
      if (req.method === 'OPTIONS') {
        res.set('Access-Control-Allow-Methods', 'POST');
        res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
        res.status(204).send('');
        return;
      }
      
      // Authenticate user (required for booking)
      const authResult = await authenticate(req);
      const userId = authResult.uid;
      
      // Validate booking request
      const bookingRequest = validateBookingRequest(req.body);
      
      // Create booking
      const booking = await bookingService.createBooking(userId, bookingRequest);
      
      res.status(201).json(booking);
    } catch (error) {
      logger.error('Booking error:', error);
      res.status(500).json({
        error: 'Booking failed',
        message: (error as Error).message,
      });
    }
  });

/**
 * Import existing booking
 * POST /accommodations/import
 */
export const importBooking = functions
  .runWith({
    timeoutSeconds: 30,
    memory: '512MB',
  })
  .https.onRequest(async (req, res) => {
    try {
      res.set('Access-Control-Allow-Origin', '*');
      if (req.method === 'OPTIONS') {
        res.set('Access-Control-Allow-Methods', 'POST');
        res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
        res.status(204).send('');
        return;
      }
      
      // Authenticate user (required for import)
      const authResult = await authenticate(req);
      const userId = authResult.uid;
      
      // Import booking
      const importResult = await importService.importBooking(userId, req.body);
      
      res.json(importResult);
    } catch (error) {
      logger.error('Import error:', error);
      res.status(500).json({
        error: 'Import failed',
        message: (error as Error).message,
      });
    }
  });

/**
 * Voice search interpretation
 * POST /accommodations/voice/interpret
 */
export const interpretVoiceSearch = functions
  .runWith({
    timeoutSeconds: 20,
    memory: '1GB',
  })
  .https.onRequest(async (req, res) => {
    try {
      res.set('Access-Control-Allow-Origin', '*');
      if (req.method === 'OPTIONS') {
        res.set('Access-Control-Allow-Methods', 'POST');
        res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
        res.status(204).send('');
        return;
      }
      
      // Optional authentication
      let userId: string | undefined;
      try {
        const authResult = await authenticate(req);
        userId = authResult.uid;
      } catch {
        // Continue without authentication
      }
      
      // Interpret voice command
      const interpretation = await voiceService.interpret(req.body, userId);
      
      res.json(interpretation);
    } catch (error) {
      logger.error('Voice interpretation error:', error);
      res.status(500).json({
        error: 'Voice interpretation failed',
        message: (error as Error).message,
      });
    }
  });

/**
 * Get user's bookings
 * GET /accommodations/bookings
 */
export const getUserBookings = functions
  .runWith({
    timeoutSeconds: 20,
    memory: '512MB',
  })
  .https.onRequest(async (req, res) => {
    try {
      res.set('Access-Control-Allow-Origin', '*');
      if (req.method === 'OPTIONS') {
        res.set('Access-Control-Allow-Methods', 'GET');
        res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
        res.status(204).send('');
        return;
      }
      
      // Authenticate user
      const authResult = await authenticate(req);
      const userId = authResult.uid;
      
      // Get bookings
      const bookings = await bookingService.getUserBookings(userId);
      
      res.json(bookings);
    } catch (error) {
      logger.error('Get bookings error:', error);
      res.status(500).json({
        error: 'Failed to get bookings',
        message: (error as Error).message,
      });
    }
  });

/**
 * Cancel booking
 * POST /accommodations/bookings/{id}/cancel
 */
export const cancelBooking = functions
  .runWith({
    timeoutSeconds: 30,
    memory: '512MB',
  })
  .https.onRequest(async (req, res) => {
    try {
      res.set('Access-Control-Allow-Origin', '*');
      if (req.method === 'OPTIONS') {
        res.set('Access-Control-Allow-Methods', 'POST');
        res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
        res.status(204).send('');
        return;
      }
      
      // Authenticate user
      const authResult = await authenticate(req);
      const userId = authResult.uid;
      
      // Extract booking ID
      const pathParts = req.path.split('/');
      const bookingId = pathParts[pathParts.length - 2];
      
      if (!bookingId) {
        res.status(400).json({ error: 'Booking ID is required' });
        return;
      }
      
      // Cancel booking
      const result = await bookingService.cancelBooking(userId, bookingId, req.body.reason);
      
      res.json(result);
    } catch (error) {
      logger.error('Cancel booking error:', error);
      res.status(500).json({
        error: 'Failed to cancel booking',
        message: (error as Error).message,
      });
    }
  });

/**
 * Scheduled function to clean expired cache
 */
export const cleanExpiredCache = functions
  .pubsub
  .schedule('every 30 minutes')
  .onRun(async (context) => {
    try {
      logger.info('Starting cache cleanup');
      
      const db = admin.firestore();
      const now = Date.now();
      const batch = db.batch();
      let deletedCount = 0;
      
      const snapshot = await db
        .collection('accommodations_cache_availability')
        .where('timestamp', '<', now - (15 * 60 * 1000)) // Older than 15 minutes
        .limit(500)
        .get();
      
      snapshot.forEach(doc => {
        batch.delete(doc.ref);
        deletedCount++;
      });
      
      if (deletedCount > 0) {
        await batch.commit();
        logger.info(`Deleted ${deletedCount} expired cache entries`);
      }
    } catch (error) {
      logger.error('Cache cleanup error:', error);
    }
  });

/**
 * Scheduled function to warm cache with popular searches
 */
export const warmCache = functions
  .pubsub
  .schedule('every 60 minutes')
  .onRun(async (context) => {
    try {
      logger.info('Starting cache warming');
      
      // Get popular search patterns from analytics
      const popularSearches = await searchService.getPopularSearches();
      
      // Pre-fetch and cache results
      for (const search of popularSearches) {
        await searchService.search(search);
      }
      
      logger.info(`Warmed cache with ${popularSearches.length} searches`);
    } catch (error) {
      logger.error('Cache warming error:', error);
    }
  });

/**
 * Cleanup expired rate limit documents
 * Scheduled to run every hour
 */
export const cleanupRateLimits = functions
  .runWith({
    timeoutSeconds: 300,
    memory: '256MB',
  })
  .pubsub
  .schedule('0 * * * *') // Every hour
  .onRun(async (context) => {
    try {
      logger.info('Starting rate limit cleanup');
      await advancedRateLimiter.cleanupExpiredRateLimits();
      logger.info('Rate limit cleanup completed');
    } catch (error) {
      logger.error('Rate limit cleanup error:', error);
    }
  });

/**
 * Autocomplete destinations for search
 * GET /accommodations/places/autocomplete
 */
export const autocompleteDestinations = functions
  .runWith({
    timeoutSeconds: 10,
    memory: '256MB',
  })
  .https.onRequest(async (req, res) => {
    try {
      await rateLimiter(req, res, async () => {
        if (req.method !== 'GET') {
          res.status(405).json({ error: 'Method not allowed' });
          return;
        }

        const { query, lat, lng, country, language } = req.query;

        if (!query || typeof query !== 'string') {
          res.status(400).json({ error: 'Query parameter is required' });
          return;
        }

        const options: any = {};
        
        if (lat && lng && typeof lat === 'string' && typeof lng === 'string') {
          options.proximityBias = {
            latitude: parseFloat(lat),
            longitude: parseFloat(lng),
          };
        }

        if (country && typeof country === 'string') {
          options.countryBias = country.split(',');
        }

        if (language && typeof language === 'string') {
          options.language = language;
        }

        const results = await searchDestinations(query, options.proximityBias);

        logger.info('Autocomplete request', {
          query,
          resultsCount: results.length,
          userLocation: options.proximityBias,
        });

        res.json({
          query,
          results,
          metadata: {
            count: results.length,
            timestamp: new Date().toISOString(),
          },
        });
      });
    } catch (error) {
      logger.error('Autocomplete destinations error:', error);
      res.status(500).json({
        error: 'Internal server error',
        message: 'Failed to fetch destination suggestions',
      });
    }
  });

/**
 * Geocode address to coordinates
 * POST /accommodations/places/geocode
 */
export const geocodeAddress = functions
  .runWith({
    timeoutSeconds: 10,
    memory: '256MB',
  })
  .https.onRequest(async (req, res) => {
    try {
      await rateLimiter(req, res, async () => {
        if (req.method !== 'POST') {
          res.status(405).json({ error: 'Method not allowed' });
          return;
        }

        const { address, country, language, proximityBias } = req.body;

        if (!address || typeof address !== 'string') {
          res.status(400).json({ error: 'Address is required' });
          return;
        }

        const options: any = {};
        
        if (country) {
          options.countryBias = Array.isArray(country) ? country : [country];
        }

        if (language) {
          options.language = language;
        }

        if (proximityBias && proximityBias.latitude && proximityBias.longitude) {
          options.proximityBias = proximityBias;
        }

        const results = await mapboxGeocodingService.geocode(address, options);

        logger.info('Geocode request', {
          address,
          resultsCount: results.length,
        });

        res.json({
          address,
          results,
          metadata: {
            count: results.length,
            timestamp: new Date().toISOString(),
          },
        });
      });
    } catch (error) {
      logger.error('Geocode address error:', error);
      res.status(500).json({
        error: 'Internal server error',
        message: 'Failed to geocode address',
      });
    }
  });

/**
 * Reverse geocode coordinates to address
 * POST /accommodations/places/reverse-geocode
 */
export const reverseGeocode = functions
  .runWith({
    timeoutSeconds: 10,
    memory: '256MB',
  })
  .https.onRequest(async (req, res) => {
    try {
      await rateLimiter(req, res, async () => {
        if (req.method !== 'POST') {
          res.status(405).json({ error: 'Method not allowed' });
          return;
        }

        const { latitude, longitude, language } = req.body;

        if (typeof latitude !== 'number' || typeof longitude !== 'number') {
          res.status(400).json({ error: 'Latitude and longitude are required as numbers' });
          return;
        }

        const options: any = {};
        if (language) {
          options.language = language;
        }

        const results = await mapboxGeocodingService.reverseGeocode(latitude, longitude, options);

        logger.info('Reverse geocode request', {
          coordinates: { latitude, longitude },
          resultsCount: results.length,
        });

        res.json({
          coordinates: { latitude, longitude },
          results,
          metadata: {
            count: results.length,
            timestamp: new Date().toISOString(),
          },
        });
      });
    } catch (error) {
      logger.error('Reverse geocode error:', error);
      res.status(500).json({
        error: 'Internal server error',
        message: 'Failed to reverse geocode coordinates',
      });
    }
  });

/**
 * Track property view analytics
 * POST /accommodations/analytics/property-view
 */
export const trackPropertyView = functions
  .runWith({
    timeoutSeconds: 10,
    memory: '256MB',
  })
  .https.onRequest(async (req, res) => {
    try {
      await rateLimiter(req, res, async () => {
        if (req.method !== 'POST') {
          res.status(405).json({ error: 'Method not allowed' });
          return;
        }

        const { userId } = await authenticate(req, res);
        if (!userId) return;

        const {
          propertyId,
          propertyName,
          propertyType,
          location,
          priceRange,
          rating,
          viewDurationSeconds,
          clickSource,
          viewDepth,
        } = req.body;

        if (!propertyId || !propertyName || !propertyType || !location || !clickSource) {
          res.status(400).json({ error: 'Missing required fields' });
          return;
        }

        const propertyViewEvent: PropertyViewEvent = {
          userId,
          sessionId: req.headers['x-session-id'] as string || `session_${Date.now()}`,
          timestamp: new Date(),
          propertyId,
          propertyName,
          propertyType,
          location,
          priceRange,
          rating,
          viewDurationSeconds,
          clickSource,
          viewDepth: viewDepth || 1,
        };

        await analyticsService.trackPropertyView(propertyViewEvent);

        res.json({
          success: true,
          message: 'Property view tracked',
        });
      });
    } catch (error) {
      logger.error('Track property view error:', error);
      res.status(500).json({
        error: 'Internal server error',
        message: 'Failed to track property view',
      });
    }
  });

/**
 * Track booking analytics
 * POST /accommodations/analytics/booking
 */
export const trackBookingAnalytics = functions
  .runWith({
    timeoutSeconds: 10,
    memory: '256MB',
  })
  .https.onRequest(async (req, res) => {
    try {
      await rateLimiter(req, res, async () => {
        if (req.method !== 'POST') {
          res.status(405).json({ error: 'Method not allowed' });
          return;
        }

        const { userId } = await authenticate(req, res);
        if (!userId) return;

        const {
          bookingId,
          propertyId,
          roomTypeId,
          ratePlanId,
          totalPrice,
          currency,
          nights,
          guests,
          leadTime,
          bookingSource,
          conversionFunnelStep,
          paymentMethod,
          specialRequests,
        } = req.body;

        if (!bookingId || !propertyId || !roomTypeId || !ratePlanId || !totalPrice || !currency) {
          res.status(400).json({ error: 'Missing required fields' });
          return;
        }

        const bookingEvent: BookingAnalyticsEvent = {
          userId,
          sessionId: req.headers['x-session-id'] as string || `session_${Date.now()}`,
          timestamp: new Date(),
          bookingId,
          propertyId,
          roomTypeId,
          ratePlanId,
          totalPrice,
          currency,
          nights: nights || 1,
          guests: guests || { adults: 1, children: 0 },
          leadTime: leadTime || 0,
          bookingSource: bookingSource || 'organic',
          conversionFunnelStep: conversionFunnelStep || 'completed',
          paymentMethod: paymentMethod || 'unknown',
          specialRequests,
        };

        await analyticsService.trackBookingEvent(bookingEvent);

        res.json({
          success: true,
          message: 'Booking analytics tracked',
        });
      });
    } catch (error) {
      logger.error('Track booking analytics error:', error);
      res.status(500).json({
        error: 'Internal server error',
        message: 'Failed to track booking analytics',
      });
    }
  });

/**
 * Get user recommendations based on analytics
 * GET /accommodations/analytics/recommendations
 */
export const getAnalyticsRecommendations = functions
  .runWith({
    timeoutSeconds: 15,
    memory: '512MB',
  })
  .https.onRequest(async (req, res) => {
    try {
      await rateLimiter(req, res, async () => {
        if (req.method !== 'GET') {
          res.status(405).json({ error: 'Method not allowed' });
          return;
        }

        const { userId } = await authenticate(req, res);
        if (!userId) return;

        // Get user preferences and search patterns
        const [searchPatterns, preferences] = await Promise.all([
          analyticsService.getUserSearchPatterns(userId, 20),
          analyticsService.getUserPropertyPreferences(userId),
        ]);

        logger.info('Retrieved analytics recommendations', {
          userId,
          searchPatternsCount: searchPatterns.length,
          hasPreferences: !!preferences,
        });

        res.json({
          userId,
          searchPatterns,
          preferences,
          metadata: {
            generated: new Date().toISOString(),
          },
        });
      });
    } catch (error) {
      logger.error('Get analytics recommendations error:', error);
      res.status(500).json({
        error: 'Internal server error',
        message: 'Failed to get analytics recommendations',
      });
    }
  });

/**
 * Get property performance metrics
 * GET /accommodations/analytics/property/:propertyId/metrics
 */
export const getPropertyMetrics = functions
  .runWith({
    timeoutSeconds: 10,
    memory: '256MB',
  })
  .https.onRequest(async (req, res) => {
    try {
      await rateLimiter(req, res, async () => {
        if (req.method !== 'GET') {
          res.status(405).json({ error: 'Method not allowed' });
          return;
        }

        const propertyId = req.path.split('/').pop();
        if (!propertyId) {
          res.status(400).json({ error: 'Property ID is required' });
          return;
        }

        const metrics = await analyticsService.getPropertyPerformanceMetrics(propertyId);

        logger.info('Retrieved property metrics', {
          propertyId,
          hasMetrics: !!metrics,
        });

        res.json({
          propertyId,
          metrics,
          metadata: {
            generated: new Date().toISOString(),
          },
        });
      });
    } catch (error) {
      logger.error('Get property metrics error:', error);
      res.status(500).json({
        error: 'Internal server error',
        message: 'Failed to get property metrics',
      });
    }
  });

/**
 * Helper function to get quick search results from fastest providers
 * Returns immediate results while Cloud Tasks handle full provider fan-out
 */
async function getQuickSearchResults(searchRequest: any, requestId: string): Promise<any> {
  try {
    // Try to get results from the fastest/most reliable provider first
    const fastestProvider = await providerService.getFastestProvider(searchRequest.location);
    
    if (fastestProvider) {
      const quickResults = await providerService.searchProvider(fastestProvider, searchRequest);
      
      // Return partial results with indication that more are coming
      return {
        properties: quickResults.slice(0, 10), // Limit initial results
        requestId,
        status: 'partial',
        message: 'Initial results loaded, more properties are being fetched...',
        totalProviders: 1,
        completedProviders: 1,
        hasMore: true,
        aggregationStatus: 'pending'
      };
    }
    
    // Fallback to empty results if no quick provider available
    return {
      properties: [],
      requestId,
      status: 'pending',
      message: 'Searching across multiple providers...',
      totalProviders: 0,
      completedProviders: 0,
      hasMore: true,
      aggregationStatus: 'pending'
    };
    
  } catch (error) {
    logger.error('Quick search failed', { error, requestId });
    
    // Return empty results but don't fail the request
    return {
      properties: [],
      requestId,
      status: 'pending',
      message: 'Searching across multiple providers...',
      totalProviders: 0,
      completedProviders: 0,
      hasMore: true,
      aggregationStatus: 'pending'
    };
  }
}