import { onRequest } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';
import { Request, Response } from 'express';
import { TaskPayload, cloudTasksService } from '../services/cloud-tasks-service.js';
import { providerService } from '../services/provider-service.js';
import { cacheService } from '../services/cache-service.js';
import { rateLimiterService } from '../middleware/advanced-rate-limiter.js';
import { monitoringService } from '../services/monitoring-service.js';
import { AppError } from '../../shared/utils/errors.js';

/**
 * Cloud Task handler for individual provider searches
 * Processes single provider API calls as part of distributed search
 */
export const providerSearchTask = onRequest(
  {
    timeoutSeconds: 60,
    memory: '1GiB',
    concurrency: 100,
    invoker: 'private' // Only accessible via Cloud Tasks
  },
  async (req: Request, res: Response) => {
    const startTime = Date.now();
    
    try {
      // Validate request source
      if (!req.headers['x-task-source']) {
        throw new AppError('Unauthorized task execution', 401, 'UNAUTHORIZED_TASK');
      }

      const payload = req.body as TaskPayload;
      const { searchRequest, provider, requestId, userId, retryCount = 0 } = payload;

      // Validate payload
      if (!searchRequest || !provider || !requestId || !userId) {
        throw new AppError('Invalid task payload', 400, 'INVALID_PAYLOAD');
      }

      logger.info('Processing provider search task', {
        requestId,
        provider: provider.id,
        userId,
        retryCount,
        location: searchRequest.location.name
      });

      // Check rate limits for this provider
      const rateLimitKey = `provider:${provider.id}:${userId}`;
      const isAllowed = await rateLimiterService.checkRateLimit(
        rateLimitKey,
        provider.rateLimit || { requests: 100, windowMs: 60000 }
      );

      if (!isAllowed.allowed) {
        logger.warn('Provider rate limit exceeded, scheduling retry', {
          requestId,
          provider: provider.id,
          retryAfter: isAllowed.retryAfter
        });

        // Schedule retry after rate limit reset
        if (retryCount < 3) {
          await cloudTasksService.scheduleRetryTask(payload, isAllowed.retryAfter || 60);
        }

        res.status(429).json({
          error: 'Rate limit exceeded',
          retryAfter: isAllowed.retryAfter
        });
        return;
      }

      // Check if results already exist in cache
      const cacheKey = `search:${provider.id}:${JSON.stringify(searchRequest)}`;
      const cachedResults = await cacheService.get(cacheKey);
      
      if (cachedResults) {
        logger.info('Using cached results for provider', {
          requestId,
          provider: provider.id,
          cacheHit: true
        });

        await storeProviderResults(requestId, provider.id, cachedResults, true);
        res.status(200).json({ status: 'completed', cached: true });
        return;
      }

      // Execute provider search with circuit breaker protection
      const results = await executeProviderSearchWithCircuitBreaker(
        provider,
        searchRequest,
        retryCount
      );

      // Cache successful results
      await cacheService.set(
        cacheKey,
        results,
        provider.cacheTTL || 300 // 5 minutes default
      );

      // Store results in the aggregation collection
      await storeProviderResults(requestId, provider.id, results, false);

      // Update provider success metrics
      await updateProviderMetrics(provider.id, true, Date.now() - startTime);
      
      // Record provider performance metrics
      await monitoringService.recordProviderMetrics(
        provider.id,
        Date.now() - startTime,
        true,
        results.length,
        'CLOSED'
      ).catch(error => {
        logger.error('Failed to record provider metrics:', error);
      });

      logger.info('Provider search task completed successfully', {
        requestId,
        provider: provider.id,
        resultCount: results.length,
        duration: Date.now() - startTime,
        cached: false
      });

      res.status(200).json({
        status: 'completed',
        resultCount: results.length,
        duration: Date.now() - startTime,
        cached: false
      });

    } catch (error) {
      await handleTaskError(error, req.body as TaskPayload, startTime);
      
      if (error instanceof AppError) {
        res.status(error.statusCode).json({
          error: error.message,
          code: error.code,
          retryCount: (req.body as TaskPayload)?.retryCount || 0
        });
      } else {
        res.status(500).json({
          error: 'Internal server error',
          code: 'INTERNAL_ERROR'
        });
      }
    }
  }
);

/**
 * Execute provider search with circuit breaker protection
 */
async function executeProviderSearchWithCircuitBreaker(
  provider: any,
  searchRequest: any,
  retryCount: number
): Promise<any[]> {
  const circuitBreakerKey = `provider:${provider.id}`;
  
  try {
    // Check circuit breaker state
    const circuitState = await rateLimiterService.getCircuitBreakerState(circuitBreakerKey);
    
    if (circuitState === 'OPEN') {
      throw new AppError(
        `Circuit breaker open for provider ${provider.id}`,
        503,
        'CIRCUIT_BREAKER_OPEN'
      );
    }

    // Execute the actual provider search
    const results = await providerService.searchProvider(provider, searchRequest);
    
    // Record success for circuit breaker
    await rateLimiterService.recordCircuitBreakerSuccess(circuitBreakerKey);
    
    return results;

  } catch (error) {
    // Record failure for circuit breaker
    await rateLimiterService.recordCircuitBreakerFailure(circuitBreakerKey);
    
    logger.error('Provider search failed', {
      provider: provider.id,
      error: error instanceof Error ? error.message : String(error),
      retryCount
    });
    
    throw error;
  }
}

/**
 * Store provider results in aggregation collection
 */
async function storeProviderResults(
  requestId: string,
  providerId: string,
  results: any[],
  fromCache: boolean
): Promise<void> {
  const { getFirestore } = await import('firebase-admin/firestore');
  const db = getFirestore();

  const doc = {
    requestId,
    providerId,
    results,
    fromCache,
    timestamp: new Date(),
    resultCount: results.length,
    processingTime: Date.now()
  };

  await db
    .collection('accommodation-search-results')
    .doc(`${requestId}-${providerId}`)
    .set(doc);
}

/**
 * Update provider performance metrics
 */
async function updateProviderMetrics(
  providerId: string,
  success: boolean,
  responseTime: number
): Promise<void> {
  const { getFirestore } = await import('firebase-admin/firestore');
  const db = getFirestore();

  const metricsRef = db.collection('provider-metrics').doc(providerId);
  
  await db.runTransaction(async (transaction) => {
    const doc = await transaction.get(metricsRef);
    const currentData = doc.data() || {
      totalRequests: 0,
      successfulRequests: 0,
      failedRequests: 0,
      averageResponseTime: 0,
      lastUpdated: new Date()
    };

    const newTotalRequests = currentData.totalRequests + 1;
    const newSuccessfulRequests = success 
      ? currentData.successfulRequests + 1 
      : currentData.successfulRequests;
    const newFailedRequests = success 
      ? currentData.failedRequests 
      : currentData.failedRequests + 1;

    // Calculate rolling average response time
    const newAverageResponseTime = (
      (currentData.averageResponseTime * currentData.totalRequests) + responseTime
    ) / newTotalRequests;

    transaction.set(metricsRef, {
      totalRequests: newTotalRequests,
      successfulRequests: newSuccessfulRequests,
      failedRequests: newFailedRequests,
      averageResponseTime: Math.round(newAverageResponseTime),
      successRate: (newSuccessfulRequests / newTotalRequests) * 100,
      lastUpdated: new Date()
    });
  });
}

/**
 * Handle task execution errors with retry logic
 */
async function handleTaskError(
  error: unknown,
  payload: TaskPayload,
  startTime: number
): Promise<void> {
  const { provider, requestId, retryCount = 0 } = payload;
  
  // Update provider failure metrics
  await updateProviderMetrics(provider.id, false, Date.now() - startTime);

  // Log error details
  logger.error('Provider search task failed', {
    requestId,
    provider: provider.id,
    error: error instanceof Error ? error.message : String(error),
    stack: error instanceof Error ? error.stack : undefined,
    retryCount,
    duration: Date.now() - startTime
  });

  // Determine if we should retry
  const shouldRetry = (
    retryCount < 3 && 
    !(error instanceof AppError && error.code === 'CIRCUIT_BREAKER_OPEN') &&
    !(error instanceof AppError && error.statusCode === 401)
  );

  if (shouldRetry) {
    // Calculate exponential backoff delay
    const baseDelay = 30; // 30 seconds
    const backoffDelay = baseDelay * Math.pow(2, retryCount);
    const jitterDelay = backoffDelay + (Math.random() * 10); // Add jitter

    await cloudTasksService.scheduleRetryTask(payload, Math.min(jitterDelay, 300));
    
    logger.info('Retry task scheduled', {
      requestId,
      provider: provider.id,
      retryCount: retryCount + 1,
      delaySeconds: jitterDelay
    });
  } else {
    logger.error('Maximum retries exceeded, giving up', {
      requestId,
      provider: provider.id,
      finalRetryCount: retryCount
    });

    // Store failure result to prevent hanging aggregation
    await storeProviderResults(requestId, provider.id, [], false);
  }
}

/**
 * Batch processing handler for aggregating results from all providers
 */
export const batchProcessingTask = onRequest(
  {
    timeoutSeconds: 120,
    memory: '2GiB',
    concurrency: 10,
    invoker: 'private'
  },
  async (req: Request, res: Response) => {
    try {
      const { requestId, userId, expectedProviderCount } = req.body;

      if (!requestId || !userId || !expectedProviderCount) {
        throw new AppError('Invalid batch processing payload', 400, 'INVALID_PAYLOAD');
      }

      logger.info('Processing batch aggregation', {
        requestId,
        userId,
        expectedProviderCount
      });

      // Collect all provider results
      const { getFirestore } = await import('firebase-admin/firestore');
      const db = getFirestore();

      const resultsSnapshot = await db
        .collection('accommodation-search-results')
        .where('requestId', '==', requestId)
        .get();

      const providerResults = resultsSnapshot.docs.map(doc => doc.data());

      // Check if we have results from all expected providers or enough time has passed
      const hasAllResults = providerResults.length >= expectedProviderCount;
      const oldestResult = Math.min(...providerResults.map(r => r.processingTime));
      const hasTimedOut = (Date.now() - oldestResult) > 45000; // 45 seconds timeout

      if (!hasAllResults && !hasTimedOut) {
        // Reschedule for later check
        await cloudTasksService.scheduleBatchProcessingTask(
          requestId,
          userId,
          expectedProviderCount,
          15 // Check again in 15 seconds
        );

        res.status(202).json({ status: 'rescheduled' });
        return;
      }

      // Aggregate and deduplicate results
      const aggregatedResults = await aggregateProviderResults(providerResults);

      // Store final aggregated results
      await db.collection('accommodation-search-final').doc(requestId).set({
        requestId,
        userId,
        results: aggregatedResults,
        providerCount: providerResults.length,
        totalResults: aggregatedResults.length,
        completedAt: new Date(),
        processingTimeMs: Date.now() - oldestResult
      });

      // Clean up intermediate results
      const batch = db.batch();
      resultsSnapshot.docs.forEach(doc => batch.delete(doc.ref));
      await batch.commit();

      logger.info('Batch processing completed', {
        requestId,
        providerCount: providerResults.length,
        finalResultCount: aggregatedResults.length
      });

      res.status(200).json({
        status: 'completed',
        resultCount: aggregatedResults.length,
        providerCount: providerResults.length
      });

    } catch (error) {
      logger.error('Batch processing failed', {
        error: error instanceof Error ? error.message : String(error),
        requestId: req.body?.requestId
      });

      res.status(500).json({ error: 'Batch processing failed' });
    }
  }
);

/**
 * Aggregate and deduplicate results from multiple providers
 */
async function aggregateProviderResults(providerResults: any[]): Promise<any[]> {
  const allResults = providerResults.flatMap(pr => pr.results || []);
  
  // Deduplicate based on property ID and provider combination
  const seenProperties = new Set<string>();
  const deduplicatedResults = [];

  for (const result of allResults) {
    const uniqueKey = `${result.id}-${result.provider?.id || 'unknown'}`;
    
    if (!seenProperties.has(uniqueKey)) {
      seenProperties.add(uniqueKey);
      deduplicatedResults.push(result);
    }
  }

  // Sort by relevance score (if available) or rating
  deduplicatedResults.sort((a, b) => {
    if (a.relevanceScore && b.relevanceScore) {
      return b.relevanceScore - a.relevanceScore;
    }
    if (a.rating && b.rating) {
      return b.rating - a.rating;
    }
    return 0;
  });

  return deduplicatedResults;
}