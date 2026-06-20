import * as admin from 'firebase-admin';
import { CloudTasksClient } from '@google-cloud/tasks';
import {
  SearchRequest,
  SearchResponse,
  AccommodationProperty,
  AvailabilitySummary,
  SearchLocation,
  CacheMetadata,
} from '../models/types';
import { ProviderRegistry, AccommodationProvider } from '../providers/provider-interface';
import { AmadeusProvider } from '../providers/amadeus-provider';
import { CacheService } from './cache-service';
import { logger } from '../../shared/utils/logger';
import { v4 as uuidv4 } from 'uuid';
import * as crypto from 'crypto';

export class SearchService {
  private db: admin.firestore.Firestore;
  private providerRegistry: ProviderRegistry;
  private cacheService: CacheService;
  private tasksClient: CloudTasksClient;
  
  constructor() {
    this.db = admin.firestore();
    this.providerRegistry = new ProviderRegistry();
    this.cacheService = new CacheService();
    this.tasksClient = new CloudTasksClient();
    
    // Initialize providers
    this.initializeProviders();
  }
  
  private initializeProviders(): void {
    // Register available providers
    const amadeusProvider = new AmadeusProvider({
      apiKey: process.env.AMADEUS_API_KEY,
      apiSecret: process.env.AMADEUS_API_SECRET,
    });
    
    if (amadeusProvider.isEnabled) {
      this.providerRegistry.register(amadeusProvider);
    }
    
    // Add more providers as needed
    // this.providerRegistry.register(new BookingComProvider(...));
    // this.providerRegistry.register(new ExpediaProvider(...));
  }
  
  async search(request: SearchRequest, userId?: string): Promise<SearchResponse> {
    const searchId = uuidv4();
    const cacheKey = this.generateCacheKey(request);
    
    try {
      // Check cache first
      const cachedResult = await this.cacheService.get(cacheKey);
      if (cachedResult) {
        logger.info(`Cache hit for search ${searchId}`);
        return {
          ...cachedResult,
          searchId,
          cacheMetadata: {
            cached: true,
            cacheAge: Date.now() - cachedResult.timestamp,
            ttl: this.cacheService.getTTL(cacheKey),
          },
        };
      }
      
      // Log search request for analytics
      await this.logSearch(searchId, request, userId);
      
      // Resolve location if needed
      const coordinates = await this.resolveLocation(request.location);
      
      // Fan out to providers
      const providers = this.providerRegistry.getEnabled();
      const searchPromises = providers.map(provider => 
        this.searchProvider(provider, request, coordinates)
          .catch(error => {
            logger.error(`Provider ${provider.name} search failed:`, error);
            return null;
          })
      );
      
      const results = await Promise.all(searchPromises);
      
      // Merge and deduplicate results
      const mergedProperties = this.mergeResults(results.filter(r => r !== null));
      
      // Apply sorting
      const sortedProperties = this.sortProperties(mergedProperties, request.sortBy);
      
      // Apply pagination
      const { paginatedProperties, nextPageToken } = this.paginate(
        sortedProperties,
        request.pageToken
      );
      
      // Fetch availability summaries
      const availability = await this.getAvailabilitySummaries(
        paginatedProperties,
        request
      );
      
      const response: SearchResponse = {
        properties: paginatedProperties,
        availability,
        totalResults: sortedProperties.length,
        pageToken: nextPageToken,
        searchId,
      };
      
      // Cache the result
      await this.cacheService.set(cacheKey, response, 300); // 5 minute TTL
      
      return response;
    } catch (error) {
      logger.error(`Search failed for ${searchId}:`, error);
      throw error;
    }
  }
  
  private async searchProvider(
    provider: AccommodationProvider,
    request: SearchRequest,
    coordinates: { lat: number; lng: number }
  ): Promise<AccommodationProperty[]> {
    const providerRequest = {
      location: {
        latitude: coordinates.lat,
        longitude: coordinates.lng,
        radius: 10, // Default 10km radius
      },
      checkIn: request.dateRange.startDate,
      checkOut: request.dateRange.endDate,
      guests: {
        adults: request.guests.adults,
        children: request.guests.children,
        childrenAges: request.guests.childrenAges,
      },
      rooms: request.guests.rooms,
      filters: request.filters ? {
        priceMin: request.filters.budgetMin,
        priceMax: request.filters.budgetMax,
        rating: request.filters.rating,
        amenities: request.filters.amenities,
        propertyTypes: request.filters.types?.map(t => t.toString()),
      } : undefined,
    };
    
    const response = await provider.search(providerRequest);
    return response.properties;
  }
  
  private async resolveLocation(location: SearchLocation): Promise<{ lat: number; lng: number }> {
    switch (location.type) {
      case 'coordinates':
        return { lat: location.lat, lng: location.lng };
      
      case 'placeId':
        // Use geocoding service to resolve place ID
        return await this.geocodePlaceId(location.placeId);
      
      case 'address':
        // Use geocoding service to resolve address
        return await this.geocodeAddress(location.address);
      
      default:
        throw new Error('Invalid location type');
    }
  }
  
  private async geocodePlaceId(placeId: string): Promise<{ lat: number; lng: number }> {
    // Implement Mapbox or Google Maps geocoding
    // This is a placeholder
    return { lat: 0, lng: 0 };
  }
  
  private async geocodeAddress(address: string): Promise<{ lat: number; lng: number }> {
    // Implement Mapbox or Google Maps geocoding
    // This is a placeholder
    return { lat: 0, lng: 0 };
  }
  
  private mergeResults(results: (AccommodationProperty[] | null)[]): AccommodationProperty[] {
    const propertyMap = new Map<string, AccommodationProperty>();
    
    results.forEach(properties => {
      if (!properties) return;
      
      properties.forEach(property => {
        const existingProperty = propertyMap.get(property.id);
        
        if (existingProperty) {
          // Merge provider references
          property.providerRefs = [
            ...existingProperty.providerRefs,
            ...property.providerRefs,
          ];
        }
        
        propertyMap.set(property.id, property);
      });
    });
    
    return Array.from(propertyMap.values());
  }
  
  private sortProperties(
    properties: AccommodationProperty[],
    sortBy?: string
  ): AccommodationProperty[] {
    if (!sortBy || sortBy === 'RELEVANCE') {
      // Default relevance sorting
      return properties.sort((a, b) => {
        const scoreA = this.calculateRelevanceScore(a);
        const scoreB = this.calculateRelevanceScore(b);
        return scoreB - scoreA;
      });
    }
    
    switch (sortBy) {
      case 'PRICE_ASC':
        return properties.sort((a, b) => 
          (a.priceRange?.min || 0) - (b.priceRange?.min || 0)
        );
      
      case 'PRICE_DESC':
        return properties.sort((a, b) => 
          (b.priceRange?.max || 0) - (a.priceRange?.max || 0)
        );
      
      case 'RATING':
        return properties.sort((a, b) => 
          (b.rating || 0) - (a.rating || 0)
        );
      
      case 'DISTANCE':
        // Distance sorting would require user location
        return properties;
      
      case 'POPULARITY':
        return properties.sort((a, b) => 
          b.reviewsCount - a.reviewsCount
        );
      
      default:
        return properties;
    }
  }
  
  private calculateRelevanceScore(property: AccommodationProperty): number {
    let score = 0;
    
    // Rating contributes to score
    if (property.rating) {
      score += property.rating * 20;
    }
    
    // Review count contributes
    score += Math.min(property.reviewsCount / 10, 10);
    
    // Number of photos
    score += Math.min(property.photos.length * 2, 10);
    
    // Number of amenities
    score += Math.min(property.amenities.length, 10);
    
    return score;
  }
  
  private paginate(
    properties: AccommodationProperty[],
    pageToken?: string
  ): { paginatedProperties: AccommodationProperty[]; nextPageToken?: string } {
    const pageSize = 20;
    const startIndex = pageToken ? parseInt(pageToken, 10) : 0;
    const endIndex = startIndex + pageSize;
    
    const paginatedProperties = properties.slice(startIndex, endIndex);
    const nextPageToken = endIndex < properties.length ? endIndex.toString() : undefined;
    
    return { paginatedProperties, nextPageToken };
  }
  
  private async getAvailabilitySummaries(
    properties: AccommodationProperty[],
    request: SearchRequest
  ): Promise<Record<string, AvailabilitySummary>> {
    const availability: Record<string, AvailabilitySummary> = {};
    
    // Queue availability checks as background tasks
    const queueName = 'accommodations-availability';
    const project = process.env.GCLOUD_PROJECT;
    const location = 'us-central1';
    const parent = this.tasksClient.queuePath(project!, location, queueName);
    
    for (const property of properties) {
      // For now, return basic availability
      // In production, this would query real-time availability
      availability[property.id] = {
        propertyId: property.id,
        isAvailable: true,
        lowestPrice: property.priceRange?.min,
        currency: property.priceRange?.currency || 'USD',
        roomsAvailable: request.guests.rooms,
      };
    }
    
    return availability;
  }
  
  private generateCacheKey(request: SearchRequest): string {
    const keyData = {
      location: request.location,
      dateRange: {
        start: request.dateRange.startDate.toISOString(),
        end: request.dateRange.endDate.toISOString(),
      },
      guests: request.guests,
      filters: request.filters,
      sortBy: request.sortBy,
    };
    
    const hash = crypto
      .createHash('sha256')
      .update(JSON.stringify(keyData))
      .digest('hex');
    
    return `search:${hash}`;
  }
  
  private async logSearch(
    searchId: string,
    request: SearchRequest,
    userId?: string
  ): Promise<void> {
    const searchDoc = {
      searchId,
      userId: userId || null,
      request,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    await this.db
      .collection('accommodations_searches')
      .doc(searchId)
      .set(searchDoc);
  }
}