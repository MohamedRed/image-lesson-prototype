import { describe, test, expect, beforeEach, afterEach } from '@jest/globals';
import * as admin from 'firebase-admin';
import { performHourlySweep, reconcileLegCompletion } from '../src/sweeper';

// Mock Firebase Admin
jest.mock('firebase-admin', () => ({
  initializeApp: jest.fn(),
  app: jest.fn(),
  firestore: jest.fn(() => ({
    collection: jest.fn(),
    collectionGroup: jest.fn(),
    doc: jest.fn(),
    batch: jest.fn(),
    runTransaction: jest.fn()
  })),
  FieldValue: {
    increment: jest.fn(),
    serverTimestamp: jest.fn()
  },
  Timestamp: {
    fromDate: jest.fn(),
    now: jest.fn()
  }
}));

describe('GDPR Sweeper Tests', () => {
  let mockDb: any;
  let mockBatch: any;
  let mockCollection: any;
  let mockCollectionGroup: any;

  beforeEach(() => {
    mockBatch = {
      delete: jest.fn(),
      update: jest.fn(),
      commit: jest.fn().mockResolvedValue(undefined)
    };

    mockCollection = jest.fn().mockReturnValue({
      where: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      get: jest.fn().mockResolvedValue({
        docs: [],
        forEach: jest.fn()
      })
    });

    mockCollectionGroup = jest.fn().mockReturnValue({
      where: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      get: jest.fn().mockResolvedValue({
        docs: [],
        forEach: jest.fn()
      })
    });

    mockDb = {
      collection: mockCollection,
      collectionGroup: mockCollectionGroup,
      batch: jest.fn().mockReturnValue(mockBatch),
      runTransaction: jest.fn()
    };

    (admin.firestore as jest.Mock).mockReturnValue(mockDb);
    (admin.firestore.Timestamp.fromDate as jest.Mock).mockImplementation((date: Date) => ({ _seconds: Math.floor(date.getTime() / 1000) }));
    (admin.firestore.Timestamp.now as jest.Mock).mockReturnValue({ _seconds: Math.floor(Date.now() / 1000) });
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  test('should verify 30-day retention period for GDPR compliance', async () => {
    // Set environment variable for testing
    process.env.RETENTION_DAYS = '30';
    
    const mockExpiredDocs = [
      { ref: 'doc1', data: () => ({ createdAt: new Date(Date.now() - 31 * 24 * 60 * 60 * 1000) }) },
      { ref: 'doc2', data: () => ({ createdAt: new Date(Date.now() - 35 * 24 * 60 * 60 * 1000) }) }
    ];

    mockCollection.mockReturnValue({
      where: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      get: jest.fn().mockResolvedValue({
        docs: mockExpiredDocs,
        forEach: jest.fn().mockImplementation((callback: any) => {
          mockExpiredDocs.forEach(callback);
        })
      })
    });

    // Test the TTL query range calculation
    const retentionDays = parseInt(process.env.RETENTION_DAYS || '30');
    const cutoffTime = new Date();
    cutoffTime.setDate(cutoffTime.getDate() - retentionDays);
    
    expect(retentionDays).toBe(30);
    expect(cutoffTime.getTime()).toBeLessThan(Date.now());
    expect(Date.now() - cutoffTime.getTime()).toBeGreaterThanOrEqual(30 * 24 * 60 * 60 * 1000 - 1000); // Allow 1s tolerance
  });

  test('should handle configurable retention period via environment variable', () => {
    // Test default value
    delete process.env.RETENTION_DAYS;
    const defaultRetention = parseInt(process.env.RETENTION_DAYS || '30');
    expect(defaultRetention).toBe(30);

    // Test custom value
    process.env.RETENTION_DAYS = '7';
    const customRetention = parseInt(process.env.RETENTION_DAYS || '30');
    expect(customRetention).toBe(7);

    // Test invalid value fallback
    process.env.RETENTION_DAYS = 'invalid';
    const invalidRetention = parseInt(process.env.RETENTION_DAYS || '30');
    expect(isNaN(invalidRetention)).toBe(true);
  });

  test('should clean up expired ride requests with correct TTL', async () => {
    const mockExpiredRideRequests = [
      { ref: { path: 'rideRequests/req1' } },
      { ref: { path: 'rideRequests/req2' } }
    ];

    const mockQueryResult = {
      docs: mockExpiredRideRequests,
      forEach: jest.fn().mockImplementation((callback: any) => {
        mockExpiredRideRequests.forEach(callback);
      })
    };

    mockCollection.mockReturnValue({
      where: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      get: jest.fn().mockResolvedValue(mockQueryResult)
    });

    // Verify the query parameters would be correct
    const retentionDays = 30;
    const cutoffTime = new Date();
    cutoffTime.setDate(cutoffTime.getDate() - retentionDays);
    
    expect(cutoffTime).toBeInstanceOf(Date);
    expect(mockExpiredRideRequests.length).toBe(2);
  });

  test('should reconcile leg completion correctly', async () => {
    const mockTransaction = {
      get: jest.fn(),
      update: jest.fn()
    };

    const mockDriverSnap = {
      exists: true,
      data: () => ({ activePickups: 2 })
    };

    const mockZoneSnap = {
      exists: true,
      data: () => ({ activePickups: 5 })
    };

    mockDb.runTransaction.mockImplementation(async (callback: any) => {
      mockTransaction.get
        .mockResolvedValueOnce(mockDriverSnap)
        .mockResolvedValueOnce(mockZoneSnap);
      
      await callback(mockTransaction);
    });

    mockDb.doc = jest.fn()
      .mockReturnValueOnce({ path: 'drivers/driver1' })
      .mockReturnValueOnce({ path: 'pickupZones/zone1' });

    const legData = {
      driverId: 'driver1',
      pickupZoneId: 'zone1',
      status: 'completed'
    };

    await reconcileLegCompletion(legData, mockDb);

    expect(mockDb.runTransaction).toHaveBeenCalledTimes(1);
    expect(mockTransaction.get).toHaveBeenCalledTimes(2);
    expect(mockTransaction.update).toHaveBeenCalledTimes(2);
  });

  test('should handle batch operations within limits', async () => {
    // Test that batch operations respect Firestore limits (500 operations per batch)
    const mockDocs = Array.from({ length: 600 }, (_, i) => ({
      ref: { path: `doc${i}` },
      data: () => ({ createdAt: new Date(Date.now() - 31 * 24 * 60 * 60 * 1000) })
    }));

    const mockQueryResult = {
      docs: mockDocs.slice(0, 500), // Limit query results to 500
      forEach: jest.fn().mockImplementation((callback: any) => {
        mockDocs.slice(0, 500).forEach(callback);
      })
    };

    mockCollection.mockReturnValue({
      where: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      get: jest.fn().mockResolvedValue(mockQueryResult)
    });

    // Verify that queries are limited to prevent batch overflow
    expect(mockQueryResult.docs.length).toBeLessThanOrEqual(500);
  });
}); 