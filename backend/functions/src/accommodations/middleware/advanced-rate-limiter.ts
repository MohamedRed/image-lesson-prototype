import * as admin from 'firebase-admin';
import { Request, Response, NextFunction } from 'express';
import { logger } from '../../shared/utils/logger';

export interface RateLimitConfig {
  windowMs: number; // Time window in milliseconds
  maxRequests: number; // Maximum requests per window
  keyGenerator?: (req: Request) => string;
  skipSuccessfulRequests?: boolean;
  skipFailedRequests?: boolean;
  onLimitReached?: (req: Request, res: Response) => void;
  tier?: 'free' | 'premium' | 'enterprise';
}

export interface CircuitBreakerConfig {
  failureThreshold: number; // Number of failures before opening circuit
  recoveryTimeoutMs: number; // Time before attempting to close circuit
  monitoringWindowMs: number; // Time window for monitoring failures
  minimumRequests: number; // Minimum requests needed before circuit can open
}

export enum CircuitState {
  CLOSED = 'CLOSED',
  OPEN = 'OPEN',
  HALF_OPEN = 'HALF_OPEN',
}

export interface CircuitBreakerStatus {
  state: CircuitState;
  failureCount: number;
  lastFailureTime: number;
  nextAttemptTime: number;
  successCount: number;
  requestCount: number;
}

export class AdvancedRateLimiter {
  private db: admin.firestore.Firestore;
  private circuitBreakers: Map<string, CircuitBreakerStatus> = new Map();

  constructor() {
    this.db = admin.firestore();
  }

  // Tiered rate limiting based on user subscription
  createTieredRateLimit(configs: Record<string, RateLimitConfig>) {
    return async (req: Request, res: Response, next: NextFunction) => {
      try {
        const userTier = await this.getUserTier(req);
        const config = configs[userTier] || configs['free'];
        
        const isAllowed = await this.checkRateLimit(req, config);
        
        if (!isAllowed) {
          const upgradeMessage = userTier === 'free' 
            ? 'Upgrade to Premium for higher rate limits' 
            : '';
            
          res.status(429).json({
            error: 'Rate limit exceeded',
            message: 'Too many requests. Please try again later.',
            retryAfter: Math.ceil(config.windowMs / 1000),
            upgrade: upgradeMessage,
            tier: userTier,
          });
          return;
        }

        next();
      } catch (error) {
        logger.error('Rate limiter error:', error);
        next(); // Allow request to proceed on error
      }
    };
  }

  // Adaptive rate limiting based on system load
  createAdaptiveRateLimit(baseConfig: RateLimitConfig) {
    return async (req: Request, res: Response, next: NextFunction) => {
      try {
        const systemLoad = await this.getSystemLoad();
        const adaptedConfig = this.adaptConfigToLoad(baseConfig, systemLoad);
        
        const isAllowed = await this.checkRateLimit(req, adaptedConfig);
        
        if (!isAllowed) {
          res.status(429).json({
            error: 'Rate limit exceeded',
            message: 'System is experiencing high load. Please try again later.',
            retryAfter: Math.ceil(adaptedConfig.windowMs / 1000),
            systemLoad: systemLoad > 0.8 ? 'high' : 'normal',
          });
          return;
        }

        next();
      } catch (error) {
        logger.error('Adaptive rate limiter error:', error);
        next();
      }
    };
  }

  // Circuit breaker for external provider APIs
  createCircuitBreaker(providerName: string, config: CircuitBreakerConfig) {
    return async (req: Request, res: Response, next: NextFunction) => {
      try {
        const circuitKey = `circuit_${providerName}`;
        const circuitStatus = this.getCircuitStatus(circuitKey, config);

        // Check circuit state
        if (circuitStatus.state === CircuitState.OPEN) {
          if (Date.now() < circuitStatus.nextAttemptTime) {
            res.status(503).json({
              error: 'Service temporarily unavailable',
              message: `${providerName} service is temporarily unavailable. Circuit breaker is open.`,
              retryAfter: Math.ceil((circuitStatus.nextAttemptTime - Date.now()) / 1000),
              provider: providerName,
              circuitState: circuitStatus.state,
            });
            return;
          } else {
            // Transition to HALF_OPEN
            circuitStatus.state = CircuitState.HALF_OPEN;
            this.circuitBreakers.set(circuitKey, circuitStatus);
          }
        }

        // Add circuit breaker tracking
        req.circuitBreaker = {
          key: circuitKey,
          config,
          status: circuitStatus,
        };

        next();
      } catch (error) {
        logger.error('Circuit breaker error:', error);
        next();
      }
    };
  }

  // Track circuit breaker results
  async trackCircuitBreakerResult(
    circuitKey: string,
    config: CircuitBreakerConfig,
    success: boolean,
    responseTime?: number
  ): Promise<void> {
    const status = this.getCircuitStatus(circuitKey, config);
    
    status.requestCount++;
    
    if (success) {
      status.successCount++;
      
      if (status.state === CircuitState.HALF_OPEN) {
        // Close circuit after successful request in HALF_OPEN state
        status.state = CircuitState.CLOSED;
        status.failureCount = 0;
        status.successCount = 0;
        status.requestCount = 0;
      }
    } else {
      status.failureCount++;
      status.lastFailureTime = Date.now();
      
      // Check if circuit should open
      if (
        status.requestCount >= config.minimumRequests &&
        status.failureCount >= config.failureThreshold &&
        status.state === CircuitState.CLOSED
      ) {
        status.state = CircuitState.OPEN;
        status.nextAttemptTime = Date.now() + config.recoveryTimeoutMs;
        
        logger.warn(`Circuit breaker opened for ${circuitKey}`, {
          failureCount: status.failureCount,
          requestCount: status.requestCount,
          failureThreshold: config.failureThreshold,
        });
      }
    }

    this.circuitBreakers.set(circuitKey, status);
    
    // Log metrics for monitoring
    await this.logCircuitBreakerMetrics(circuitKey, status, responseTime);
  }

  // Distributed rate limiting using Firestore
  private async checkRateLimit(req: Request, config: RateLimitConfig): Promise<boolean> {
    const key = config.keyGenerator ? config.keyGenerator(req) : this.getDefaultKey(req);
    const windowStart = Math.floor(Date.now() / config.windowMs) * config.windowMs;
    const docPath = `rate_limits/${key}_${windowStart}`;
    
    const doc = this.db.doc(docPath);
    
    try {
      const result = await this.db.runTransaction(async (transaction) => {
        const docSnapshot = await transaction.get(doc);
        
        let currentCount = 0;
        if (docSnapshot.exists) {
          currentCount = docSnapshot.data()?.count || 0;
        }
        
        if (currentCount >= config.maxRequests) {
          return false; // Rate limit exceeded
        }
        
        // Increment counter
        transaction.set(doc, {
          count: currentCount + 1,
          windowStart,
          key,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        
        return true; // Request allowed
      });
      
      // Set TTL for cleanup
      if (result) {
        await doc.update({
          ttl: new Date(windowStart + config.windowMs * 2), // Double window for safety
        });
      }
      
      return result;
    } catch (error) {
      logger.error('Rate limit check error:', error);
      return true; // Allow request on error
    }
  }

  private getCircuitStatus(circuitKey: string, config: CircuitBreakerConfig): CircuitBreakerStatus {
    let status = this.circuitBreakers.get(circuitKey);
    
    if (!status) {
      status = {
        state: CircuitState.CLOSED,
        failureCount: 0,
        lastFailureTime: 0,
        nextAttemptTime: 0,
        successCount: 0,
        requestCount: 0,
      };
    }

    // Reset counters if monitoring window has passed
    const now = Date.now();
    if (now - status.lastFailureTime > config.monitoringWindowMs) {
      status.failureCount = 0;
      status.successCount = 0;
      status.requestCount = 0;
    }

    return status;
  }

  private async getUserTier(req: Request): Promise<string> {
    try {
      const userId = req.user?.uid;
      if (!userId) return 'free';

      const userDoc = await this.db.doc(`users/${userId}`).get();
      const userData = userDoc.data();
      
      return userData?.subscription?.tier || 'free';
    } catch (error) {
      logger.error('Error getting user tier:', error);
      return 'free';
    }
  }

  private async getSystemLoad(): Promise<number> {
    try {
      // Get system metrics from monitoring
      const metricsDoc = await this.db.doc('system/metrics').get();
      const metrics = metricsDoc.data();
      
      // Simplified load calculation
      const cpuUsage = metrics?.cpuUsage || 0.5;
      const memoryUsage = metrics?.memoryUsage || 0.5;
      const requestRate = metrics?.requestRate || 0.5;
      
      return Math.max(cpuUsage, memoryUsage, requestRate);
    } catch (error) {
      logger.error('Error getting system load:', error);
      return 0.5; // Default moderate load
    }
  }

  private adaptConfigToLoad(baseConfig: RateLimitConfig, systemLoad: number): RateLimitConfig {
    const loadFactor = Math.max(0.2, 1 - systemLoad); // Reduce limits as load increases
    
    return {
      ...baseConfig,
      maxRequests: Math.floor(baseConfig.maxRequests * loadFactor),
      windowMs: baseConfig.windowMs, // Keep window same
    };
  }

  private getDefaultKey(req: Request): string {
    const userId = req.user?.uid;
    const ip = req.ip || req.connection.remoteAddress;
    const userAgent = req.headers['user-agent'];
    
    // Prefer user ID, fallback to IP + User Agent hash
    if (userId) {
      return `user:${userId}`;
    }
    
    return `ip:${ip}:${this.hashString(userAgent || 'unknown')}`;
  }

  private hashString(str: string): string {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32-bit integer
    }
    return Math.abs(hash).toString(36);
  }

  private async logCircuitBreakerMetrics(
    circuitKey: string,
    status: CircuitBreakerStatus,
    responseTime?: number
  ): Promise<void> {
    try {
      await this.db.collection('circuit_breaker_metrics').add({
        circuitKey,
        state: status.state,
        failureCount: status.failureCount,
        successCount: status.successCount,
        requestCount: status.requestCount,
        responseTime,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      logger.error('Error logging circuit breaker metrics:', error);
    }
  }

  // Cleanup expired rate limit documents
  async cleanupExpiredRateLimits(): Promise<void> {
    try {
      const cutoffTime = new Date(Date.now() - 24 * 60 * 60 * 1000); // 24 hours ago
      
      const expiredDocs = await this.db
        .collection('rate_limits')
        .where('ttl', '<', cutoffTime)
        .limit(500)
        .get();

      const batch = this.db.batch();
      expiredDocs.docs.forEach(doc => {
        batch.delete(doc.ref);
      });

      await batch.commit();
      
      if (expiredDocs.docs.length > 0) {
        logger.info(`Cleaned up ${expiredDocs.docs.length} expired rate limit documents`);
      }
    } catch (error) {
      logger.error('Error cleaning up expired rate limits:', error);
    }
  }
}

// Export singleton instance
export const advancedRateLimiter = new AdvancedRateLimiter();

// Extend Express Request interface
declare global {
  namespace Express {
    interface Request {
      circuitBreaker?: {
        key: string;
        config: CircuitBreakerConfig;
        status: CircuitBreakerStatus;
      };
    }
  }
}