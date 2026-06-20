import { describe, it, expect, jest, beforeEach } from '@jest/globals';
import { SearchService } from '../../src/accommodations/services/search-service';
import { SearchRequest, AccommodationType, SortOption } from '../../src/accommodations/models/types';

// Mock Firebase Admin
jest.mock('firebase-admin', () => ({
  firestore: jest.fn(() => ({
    collection: jest.fn(() => ({
      doc: jest.fn(() => ({
        set: jest.fn(),
        get: jest.fn(() => ({ exists: false })),
      })),
    })),
  })),
}));

// Mock provider registry
jest.mock('../../src/accommodations/providers/provider-interface');
jest.mock('../../src/accommodations/services/cache-service');

describe('SearchService', () => {
  let searchService: SearchService;
  
  beforeEach(() => {
    searchService = new SearchService();
    jest.clearAllMocks();
  });
  
  describe('search', () => {
    const mockSearchRequest: SearchRequest = {
      location: { type: 'coordinates', lat: 37.7749, lng: -122.4194 },
      dateRange: {
        startDate: new Date('2024-03-01'),
        endDate: new Date('2024-03-03'),
      },
      guests: {
        rooms: 1,
        adults: 2,
        children: 0,
        childrenAges: [],
      },
      filters: {
        budgetMin: 100,
        budgetMax: 300,
        types: [AccommodationType.HOTEL],
      },
      sortBy: SortOption.PRICE_ASC,
    };
    
    it('should return search results', async () => {
      const result = await searchService.search(mockSearchRequest);
      
      expect(result).toBeDefined();
      expect(result.properties).toBeDefined();
      expect(result.searchId).toBeDefined();
      expect(Array.isArray(result.properties)).toBe(true);
    });
    
    it('should handle location coordinates', async () => {
      const request = {
        ...mockSearchRequest,
        location: { type: 'coordinates' as const, lat: 40.7128, lng: -74.0060 },
      };
      
      const result = await searchService.search(request);
      expect(result).toBeDefined();
    });
    
    it('should handle date range validation', async () => {
      const invalidRequest = {
        ...mockSearchRequest,
        dateRange: {
          startDate: new Date('2024-03-03'),
          endDate: new Date('2024-03-01'), // End before start
        },
      };
      
      // Should either handle gracefully or throw appropriate error
      await expect(searchService.search(invalidRequest)).rejects.toThrow();
    });
  });
  
  describe('sorting', () => {
    it('should sort by price ascending', () => {
      const properties = [
        { id: '1', priceRange: { min: 200, max: 250, currency: 'USD' } },
        { id: '2', priceRange: { min: 100, max: 150, currency: 'USD' } },
        { id: '3', priceRange: { min: 300, max: 350, currency: 'USD' } },
      ] as any[];
      
      // Access private method via type assertion for testing
      const sortedProperties = (searchService as any).sortProperties(properties, SortOption.PRICE_ASC);
      
      expect(sortedProperties[0].priceRange.min).toBe(100);
      expect(sortedProperties[1].priceRange.min).toBe(200);
      expect(sortedProperties[2].priceRange.min).toBe(300);
    });
  });
  
  describe('cache key generation', () => {
    it('should generate consistent cache keys', () => {
      const request1: SearchRequest = {
        location: { type: 'coordinates', lat: 37.7749, lng: -122.4194 },
        dateRange: {
          startDate: new Date('2024-03-01'),
          endDate: new Date('2024-03-03'),
        },
        guests: {
          rooms: 1,
          adults: 2,
          children: 0,
          childrenAges: [],
        },
      };
      
      const request2: SearchRequest = { ...request1 };
      
      const key1 = (searchService as any).generateCacheKey(request1);
      const key2 = (searchService as any).generateCacheKey(request2);
      
      expect(key1).toBe(key2);
    });
    
    it('should generate different cache keys for different requests', () => {
      const request1: SearchRequest = {
        location: { type: 'coordinates', lat: 37.7749, lng: -122.4194 },
        dateRange: {
          startDate: new Date('2024-03-01'),
          endDate: new Date('2024-03-03'),
        },
        guests: {
          rooms: 1,
          adults: 2,
          children: 0,
          childrenAges: [],
        },
      };
      
      const request2: SearchRequest = {
        ...request1,
        guests: {
          ...request1.guests,
          adults: 3, // Different guest count
        },
      };
      
      const key1 = (searchService as any).generateCacheKey(request1);
      const key2 = (searchService as any).generateCacheKey(request2);
      
      expect(key1).not.toBe(key2);
    });
  });
});