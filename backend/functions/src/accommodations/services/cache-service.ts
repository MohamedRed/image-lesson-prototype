import * as admin from 'firebase-admin';
import { logger } from '../../shared/utils/logger';

interface CacheEntry {
  data: any;
  timestamp: number;
  ttl: number;
  key: string;
}

/**
 * Cache service for accommodations
 * Uses Firestore for distributed caching with TTL support
 * In production, this could be replaced with Redis for better performance
 */
export class CacheService {
  private db: admin.firestore.Firestore;
  private collection: admin.firestore.CollectionReference;
  private defaultTTL: number = 300; // 5 minutes default
  
  constructor() {
    this.db = admin.firestore();
    this.collection = this.db.collection('accommodations_cache_availability');
    
    // Start background cleaner
    this.startCacheCleaner();
  }
  
  async get(key: string): Promise<any> {
    try {
      const doc = await this.collection.doc(key).get();
      
      if (!doc.exists) {
        return null;
      }
      
      const entry = doc.data() as CacheEntry;
      
      // Check if cache entry has expired
      if (this.isExpired(entry)) {
        await this.delete(key);
        return null;
      }
      
      return entry.data;
    } catch (error) {
      logger.error('Cache get error:', error);
      return null;
    }
  }
  
  async set(key: string, data: any, ttl?: number): Promise<void> {
    try {
      const entry: CacheEntry = {
        data,
        timestamp: Date.now(),
        ttl: ttl || this.defaultTTL,
        key,
      };
      
      await this.collection.doc(key).set(entry);
    } catch (error) {
      logger.error('Cache set error:', error);
    }
  }
  
  async delete(key: string): Promise<void> {
    try {
      await this.collection.doc(key).delete();
    } catch (error) {
      logger.error('Cache delete error:', error);
    }
  }
  
  async clear(): Promise<void> {
    try {
      const batch = this.db.batch();
      const docs = await this.collection.limit(500).get();
      
      docs.forEach(doc => {
        batch.delete(doc.ref);
      });
      
      await batch.commit();
    } catch (error) {
      logger.error('Cache clear error:', error);
    }
  }
  
  getTTL(key: string): number {
    // Return remaining TTL for a cache key
    // This is a simplified implementation
    return this.defaultTTL;
  }
  
  private isExpired(entry: CacheEntry): boolean {
    const expiryTime = entry.timestamp + (entry.ttl * 1000);
    return Date.now() > expiryTime;
  }
  
  /**
   * Background process to clean expired cache entries
   */
  private startCacheCleaner(): void {
    // Run every 5 minutes
    setInterval(async () => {
      try {
        const now = Date.now();
        const batch = this.db.batch();
        let deletedCount = 0;
        
        const snapshot = await this.collection
          .where('timestamp', '<', now - (this.defaultTTL * 1000))
          .limit(100)
          .get();
        
        snapshot.forEach(doc => {
          const entry = doc.data() as CacheEntry;
          if (this.isExpired(entry)) {
            batch.delete(doc.ref);
            deletedCount++;
          }
        });
        
        if (deletedCount > 0) {
          await batch.commit();
          logger.info(`Cleaned ${deletedCount} expired cache entries`);
        }
      } catch (error) {
        logger.error('Cache cleaner error:', error);
      }
    }, 5 * 60 * 1000);
  }
  
  /**
   * Generate cache key for availability data
   */
  static generateAvailabilityCacheKey(
    propertyId: string,
    checkIn: Date,
    checkOut: Date,
    guests: number
  ): string {
    const checkInStr = checkIn.toISOString().split('T')[0];
    const checkOutStr = checkOut.toISOString().split('T')[0];
    return `availability:${propertyId}:${checkInStr}:${checkOutStr}:${guests}`;
  }
  
  /**
   * Cache warming for popular searches
   */
  async warmCache(popularSearches: any[]): Promise<void> {
    // This would be called by a scheduled function to pre-cache popular searches
    logger.info(`Warming cache with ${popularSearches.length} popular searches`);
    
    for (const search of popularSearches) {
      // Implement cache warming logic
    }
  }
}