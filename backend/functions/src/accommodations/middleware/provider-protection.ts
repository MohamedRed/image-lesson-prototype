import { Request, Response, NextFunction } from 'express';
import { advancedRateLimiter, CircuitBreakerConfig, RateLimitConfig } from './advanced-rate-limiter';
import { logger } from '../../shared/utils/logger';

// Provider-specific configurations
export const PROVIDER_CONFIGS = {
  amadeus: {
    rateLimit: {
      windowMs: 60 * 1000, // 1 minute
      maxRequests: 100, // 100 requests per minute
      tier: 'free' as const,
    } as RateLimitConfig,
    circuitBreaker: {
      failureThreshold: 10,
      recoveryTimeoutMs: 30 * 1000, // 30 seconds
      monitoringWindowMs: 60 * 1000, // 1 minute
      minimumRequests: 5,
    } as CircuitBreakerConfig,
    timeout: 15000, // 15 seconds
    retryConfig: {
      maxRetries: 3,
      backoffMultiplier: 1.5,
      baseDelay: 1000,
    },
  },
  
  bookingcom: {
    rateLimit: {
      windowMs: 60 * 1000,
      maxRequests: 200, // Higher limit
      tier: 'free' as const,
    } as RateLimitConfig,
    circuitBreaker: {
      failureThreshold: 15,
      recoveryTimeoutMs: 45 * 1000,
      monitoringWindowMs: 90 * 1000,
      minimumRequests: 10,
    } as CircuitBreakerConfig,
    timeout: 20000,
    retryConfig: {
      maxRetries: 2,
      backoffMultiplier: 2.0,
      baseDelay: 2000,
    },
  },
  
  expedia: {
    rateLimit: {
      windowMs: 60 * 1000,
      maxRequests: 150,
      tier: 'free' as const,
    } as RateLimitConfig,
    circuitBreaker: {
      failureThreshold: 12,
      recoveryTimeoutMs: 60 * 1000,
      monitoringWindowMs: 120 * 1000,
      minimumRequests: 8,
    } as CircuitBreakerConfig,
    timeout: 18000,
    retryConfig: {
      maxRetries: 3,
      backoffMultiplier: 1.8,
      baseDelay: 1500,
    },
  },
  
  airbnb: {
    rateLimit: {
      windowMs: 60 * 1000,
      maxRequests: 80, // More conservative for Airbnb
      tier: 'free' as const,
    } as RateLimitConfig,
    circuitBreaker: {
      failureThreshold: 8,
      recoveryTimeoutMs: 90 * 1000,
      monitoringWindowMs: 180 * 1000,
      minimumRequests: 5,
    } as CircuitBreakerConfig,
    timeout: 25000,
    retryConfig: {
      maxRetries: 2,
      backoffMultiplier: 2.5,
      baseDelay: 3000,
    },
  },
  
  hotelscom: {
    rateLimit: {
      windowMs: 60 * 1000,
      maxRequests: 120,
      tier: 'free' as const,
    } as RateLimitConfig,
    circuitBreaker: {
      failureThreshold: 10,
      recoveryTimeoutMs: 30 * 1000,
      monitoringWindowMs: 60 * 1000,
      minimumRequests: 6,
    } as CircuitBreakerConfig,
    timeout: 16000,
    retryConfig: {
      maxRetries: 3,
      backoffMultiplier: 1.6,
      baseDelay: 1200,
    },
  },
  
  agoda: {
    rateLimit: {
      windowMs: 60 * 1000,
      maxRequests: 90,
      tier: 'free' as const,
    } as RateLimitConfig,
    circuitBreaker: {
      failureThreshold: 8,
      recoveryTimeoutMs: 45 * 1000,
      monitoringWindowMs: 90 * 1000,
      minimumRequests: 4,
    } as CircuitBreakerConfig,
    timeout: 20000,
    retryConfig: {
      maxRetries: 2,
      backoffMultiplier: 2.2,
      baseDelay: 2500,
    },
  },
};

export type ProviderName = keyof typeof PROVIDER_CONFIGS;

// Provider protection middleware factory
export function createProviderProtection(providerName: ProviderName) {
  const config = PROVIDER_CONFIGS[providerName];
  
  return {
    // Rate limiting middleware
    rateLimit: advancedRateLimiter.createTieredRateLimit({
      free: config.rateLimit,
      premium: {
        ...config.rateLimit,
        maxRequests: config.rateLimit.maxRequests * 3,
      },
      enterprise: {
        ...config.rateLimit,
        maxRequests: config.rateLimit.maxRequests * 10,
      },
    }),
    
    // Circuit breaker middleware
    circuitBreaker: advancedRateLimiter.createCircuitBreaker(providerName, config.circuitBreaker),
    
    // Timeout protection
    timeout: (req: Request, res: Response, next: NextFunction) => {
      const timeoutId = setTimeout(() => {
        if (!res.headersSent) {
          res.status(504).json({
            error: 'Request timeout',
            message: `${providerName} request timed out`,
            provider: providerName,
            timeout: config.timeout,
          });
        }
      }, config.timeout);
      
      req.setTimeout = timeoutId;
      
      const originalEnd = res.end;
      res.end = function(...args: any[]) {
        clearTimeout(timeoutId);
        originalEnd.apply(res, args);
      };
      
      next();
    },
    
    config,
  };
}

// Enhanced retry mechanism with exponential backoff
export class ProviderRetryHandler {
  static async executeWithRetry<T>(
    operation: () => Promise<T>,
    providerName: ProviderName,
    operationName: string
  ): Promise<T> {
    const config = PROVIDER_CONFIGS[providerName];
    let lastError: Error;
    
    for (let attempt = 0; attempt <= config.retryConfig.maxRetries; attempt++) {
      try {
        const startTime = Date.now();
        const result = await operation();
        const responseTime = Date.now() - startTime;
        
        // Track successful operation
        await advancedRateLimiter.trackCircuitBreakerResult(
          `circuit_${providerName}`,
          config.circuitBreaker,
          true,
          responseTime
        );
        
        // Log retry success if it was a retry
        if (attempt > 0) {
          logger.info(`${providerName} ${operationName} succeeded on retry ${attempt}`, {
            provider: providerName,
            operation: operationName,
            attempt,
            responseTime,
          });
        }
        
        return result;
      } catch (error) {
        lastError = error as Error;
        const responseTime = Date.now() - startTime;
        
        // Track failed operation
        await advancedRateLimiter.trackCircuitBreakerResult(
          `circuit_${providerName}`,
          config.circuitBreaker,
          false,
          responseTime
        );
        
        // Don't retry on client errors (4xx) or circuit breaker open
        if (this.shouldNotRetry(error as Error, attempt, config.retryConfig.maxRetries)) {
          logger.error(`${providerName} ${operationName} failed (no retry)`, {
            provider: providerName,
            operation: operationName,
            attempt,
            error: (error as Error).message,
            responseTime,
          });
          throw error;
        }
        
        // Calculate backoff delay
        const delay = config.retryConfig.baseDelay * 
          Math.pow(config.retryConfig.backoffMultiplier, attempt);
        
        logger.warn(`${providerName} ${operationName} failed, retrying in ${delay}ms`, {
          provider: providerName,
          operation: operationName,
          attempt: attempt + 1,
          maxRetries: config.retryConfig.maxRetries,
          error: (error as Error).message,
          delay,
        });
        
        // Wait before retry
        await this.sleep(delay + Math.random() * 1000); // Add jitter
      }
    }
    
    throw lastError!;
  }
  
  private static shouldNotRetry(error: Error, attempt: number, maxRetries: number): boolean {
    // Don't retry if max attempts reached
    if (attempt >= maxRetries) {
      return true;
    }
    
    // Don't retry on client errors
    if (error.message.includes('400') || error.message.includes('401') || 
        error.message.includes('403') || error.message.includes('404')) {
      return true;
    }
    
    // Don't retry if circuit breaker is open
    if (error.message.includes('Circuit breaker')) {
      return true;
    }
    
    return false;
  }
  
  private static sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

// Request batching for efficiency
export class ProviderRequestBatcher {
  private batches: Map<string, {
    requests: Array<{
      resolve: (value: any) => void;
      reject: (error: any) => void;
      data: any;
    }>;
    timeout: NodeJS.Timeout;
  }> = new Map();
  
  constructor(
    private batchSize: number = 10,
    private batchTimeoutMs: number = 100
  ) {}
  
  async addToBatch<T>(
    batchKey: string,
    data: any,
    executor: (batchData: any[]) => Promise<T[]>
  ): Promise<T> {
    return new Promise((resolve, reject) => {
      let batch = this.batches.get(batchKey);
      
      if (!batch) {
        batch = {
          requests: [],
          timeout: setTimeout(() => this.executeBatch(batchKey, executor), this.batchTimeoutMs),
        };
        this.batches.set(batchKey, batch);
      }
      
      batch.requests.push({ resolve, reject, data });
      
      // Execute batch if it's full
      if (batch.requests.length >= this.batchSize) {
        clearTimeout(batch.timeout);
        this.executeBatch(batchKey, executor);
      }
    });
  }
  
  private async executeBatch<T>(
    batchKey: string,
    executor: (batchData: any[]) => Promise<T[]>
  ): Promise<void> {
    const batch = this.batches.get(batchKey);
    if (!batch) return;
    
    this.batches.delete(batchKey);
    
    try {
      const batchData = batch.requests.map(req => req.data);
      const results = await executor(batchData);
      
      batch.requests.forEach((req, index) => {
        req.resolve(results[index]);
      });
    } catch (error) {
      batch.requests.forEach(req => {
        req.reject(error);
      });
    }
  }
}

// Global request batcher instance
export const requestBatcher = new ProviderRequestBatcher();

// Provider health check
export async function checkProviderHealth(providerName: ProviderName): Promise<{
  healthy: boolean;
  responseTime?: number;
  error?: string;
  circuitState: string;
}> {
  try {
    const startTime = Date.now();
    
    // Simple health check - could be expanded per provider
    const response = await fetch(`https://api.${providerName}.com/health`, {
      method: 'HEAD',
      timeout: 5000,
    });
    
    const responseTime = Date.now() - startTime;
    const healthy = response.ok;
    
    return {
      healthy,
      responseTime,
      circuitState: 'CLOSED', // Would get actual state from circuit breaker
    };
  } catch (error) {
    return {
      healthy: false,
      error: (error as Error).message,
      circuitState: 'OPEN',
    };
  }
}

// Middleware to add provider context to requests
export function addProviderContext(providerName: ProviderName) {
  return (req: Request, res: Response, next: NextFunction) => {
    req.providerContext = {
      name: providerName,
      config: PROVIDER_CONFIGS[providerName],
      startTime: Date.now(),
    };
    next();
  };
}

// Extend Express Request interface
declare global {
  namespace Express {
    interface Request {
      setTimeout?: NodeJS.Timeout;
      providerContext?: {
        name: ProviderName;
        config: typeof PROVIDER_CONFIGS[ProviderName];
        startTime: number;
      };
    }
  }
}