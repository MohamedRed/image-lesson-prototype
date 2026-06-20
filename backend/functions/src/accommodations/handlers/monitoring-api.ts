import { onRequest } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { logger } from 'firebase-functions/v2';
import { Request, Response } from 'express';
import { monitoringService } from '../services/monitoring-service.js';
import { AppError } from '../../shared/utils/errors.js';
import { authenticate } from '../../shared/middleware/auth.js';

/**
 * Health check endpoint
 * GET /accommodations/health
 */
export const healthCheck = onRequest(
  {
    timeoutSeconds: 30,
    memory: '512MiB',
    concurrency: 50
  },
  async (req: Request, res: Response) => {
    try {
      res.set('Access-Control-Allow-Origin', '*');
      
      if (req.method === 'OPTIONS') {
        res.set('Access-Control-Allow-Methods', 'GET');
        res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
        res.status(204).send('');
        return;
      }

      const health = await monitoringService.performHealthCheck();
      
      // Set appropriate HTTP status based on health
      const statusCode = {
        'HEALTHY': 200,
        'DEGRADED': 200,
        'UNHEALTHY': 503,
        'DOWN': 503
      }[health.status] || 500;

      res.status(statusCode).json({
        ...health,
        timestamp: new Date().toISOString(),
        version: process.env.SERVICE_VERSION || '1.0.0'
      });

    } catch (error) {
      logger.error('Health check failed', {
        error: error instanceof Error ? error.message : String(error)
      });

      res.status(500).json({
        service: 'accommodations',
        status: 'DOWN',
        error: 'Health check failed',
        timestamp: new Date().toISOString()
      });
    }
  }
);

/**
 * Get service metrics dashboard
 * GET /accommodations/monitoring/dashboard
 */
export const getDashboard = onRequest(
  {
    timeoutSeconds: 30,
    memory: '1GiB',
    invoker: 'private' // Require authentication
  },
  async (req: Request, res: Response) => {
    try {
      res.set('Access-Control-Allow-Origin', '*');
      
      if (req.method === 'OPTIONS') {
        res.set('Access-Control-Allow-Methods', 'GET');
        res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
        res.status(204).send('');
        return;
      }

      // Authenticate admin user
      const authResult = await authenticate(req);
      if (!authResult.admin) {
        throw new AppError('Admin access required', 403, 'ADMIN_REQUIRED');
      }

      const timeRange = (req.query.timeRange as string) || '24h';
      
      if (!['1h', '24h', '7d', '30d'].includes(timeRange)) {
        throw new AppError('Invalid time range', 400, 'INVALID_TIME_RANGE');
      }

      const dashboardData = await monitoringService.getDashboardData(
        timeRange as '1h' | '24h' | '7d' | '30d'
      );

      res.set('Cache-Control', 'private, max-age=60'); // Cache for 1 minute
      res.json({
        timeRange,
        generatedAt: new Date().toISOString(),
        ...dashboardData
      });

    } catch (error) {
      logger.error('Dashboard API error', {
        error: error instanceof Error ? error.message : String(error)
      });

      if (error instanceof AppError) {
        res.status(error.statusCode).json({
          error: error.message,
          code: error.code
        });
      } else {
        res.status(500).json({
          error: 'Failed to generate dashboard',
          code: 'DASHBOARD_ERROR'
        });
      }
    }
  }
);

/**
 * Create or update alert condition
 * POST /accommodations/monitoring/alerts
 */
export const createAlert = onRequest(
  {
    timeoutSeconds: 15,
    memory: '512MiB',
    invoker: 'private'
  },
  async (req: Request, res: Response) => {
    try {
      res.set('Access-Control-Allow-Origin', '*');
      
      if (req.method === 'OPTIONS') {
        res.set('Access-Control-Allow-Methods', 'POST');
        res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
        res.status(204).send('');
        return;
      }

      if (req.method !== 'POST') {
        res.status(405).json({ error: 'Method not allowed' });
        return;
      }

      // Authenticate admin user
      const authResult = await authenticate(req);
      if (!authResult.admin) {
        throw new AppError('Admin access required', 403, 'ADMIN_REQUIRED');
      }

      const {
        name,
        description,
        metric,
        operator,
        threshold,
        duration,
        severity,
        enabled
      } = req.body;

      // Validate required fields
      if (!name || !metric || !operator || threshold === undefined || !severity) {
        throw new AppError('Missing required fields', 400, 'MISSING_FIELDS');
      }

      // Validate operator
      if (!['GREATER_THAN', 'LESS_THAN', 'EQUAL_TO'].includes(operator)) {
        throw new AppError('Invalid operator', 400, 'INVALID_OPERATOR');
      }

      // Validate severity
      if (!['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'].includes(severity)) {
        throw new AppError('Invalid severity', 400, 'INVALID_SEVERITY');
      }

      const alertId = await monitoringService.createAlertCondition({
        name,
        description: description || '',
        metric,
        operator,
        threshold: Number(threshold),
        duration: Number(duration) || 300, // Default 5 minutes
        severity,
        enabled: enabled !== false // Default to true
      });

      res.status(201).json({
        id: alertId,
        message: 'Alert condition created successfully'
      });

    } catch (error) {
      logger.error('Create alert error', {
        error: error instanceof Error ? error.message : String(error)
      });

      if (error instanceof AppError) {
        res.status(error.statusCode).json({
          error: error.message,
          code: error.code
        });
      } else {
        res.status(500).json({
          error: 'Failed to create alert',
          code: 'ALERT_CREATION_ERROR'
        });
      }
    }
  }
);

/**
 * Manual metrics recording endpoint (for testing)
 * POST /accommodations/monitoring/metrics
 */
export const recordMetrics = onRequest(
  {
    timeoutSeconds: 15,
    memory: '512MiB',
    invoker: 'private'
  },
  async (req: Request, res: Response) => {
    try {
      if (req.method !== 'POST') {
        res.status(405).json({ error: 'Method not allowed' });
        return;
      }

      // This is typically called internally, but allow for testing
      const { metrics } = req.body;
      
      if (!Array.isArray(metrics)) {
        throw new AppError('Metrics must be an array', 400, 'INVALID_METRICS');
      }

      const results = await Promise.allSettled(
        metrics.map(metric => monitoringService.recordMetric({
          ...metric,
          timestamp: new Date(metric.timestamp) || new Date()
        }))
      );

      const successful = results.filter(r => r.status === 'fulfilled').length;
      const failed = results.length - successful;

      res.json({
        total: results.length,
        successful,
        failed,
        message: `Recorded ${successful} metrics successfully`
      });

    } catch (error) {
      logger.error('Record metrics error', {
        error: error instanceof Error ? error.message : String(error)
      });

      if (error instanceof AppError) {
        res.status(error.statusCode).json({
          error: error.message,
          code: error.code
        });
      } else {
        res.status(500).json({
          error: 'Failed to record metrics',
          code: 'METRICS_ERROR'
        });
      }
    }
  }
);

/**
 * Scheduled health check function
 * Runs every 5 minutes to monitor service health
 */
export const scheduledHealthCheck = onSchedule(
  {
    schedule: 'every 5 minutes',
    timeZone: 'UTC',
    memory: '512MiB',
    retryConfig: {
      retryCount: 2,
      maxRetrySeconds: 60
    }
  },
  async (event) => {
    try {
      logger.info('Running scheduled health check');
      
      const health = await monitoringService.performHealthCheck();
      
      logger.info('Scheduled health check completed', {
        status: health.status,
        responseTime: health.responseTime,
        errorRate: health.errorRate,
        uptime: health.uptime,
        issues: health.issues?.length || 0
      });

      // If service is unhealthy or down, log as error for alerting
      if (health.status === 'UNHEALTHY' || health.status === 'DOWN') {
        logger.error('Service health critical', {
          status: health.status,
          issues: health.issues,
          responseTime: health.responseTime,
          errorRate: health.errorRate
        });
      } else if (health.status === 'DEGRADED') {
        logger.warn('Service health degraded', {
          status: health.status,
          issues: health.issues,
          responseTime: health.responseTime,
          errorRate: health.errorRate
        });
      }

    } catch (error) {
      logger.error('Scheduled health check failed', {
        error: error instanceof Error ? error.message : String(error),
        stack: error instanceof Error ? error.stack : undefined
      });
    }
  }
);

/**
 * Scheduled alert checking function
 * Runs every minute to evaluate alert conditions
 */
export const scheduledAlertCheck = onSchedule(
  {
    schedule: 'every 1 minutes',
    timeZone: 'UTC',
    memory: '512MiB',
    retryConfig: {
      retryCount: 1,
      maxRetrySeconds: 30
    }
  },
  async (event) => {
    try {
      logger.debug('Running scheduled alert check');
      
      await monitoringService.checkAlerts();
      
      logger.debug('Scheduled alert check completed');

    } catch (error) {
      logger.error('Scheduled alert check failed', {
        error: error instanceof Error ? error.message : String(error)
      });
    }
  }
);

/**
 * Get system metrics and logs for debugging
 * GET /accommodations/monitoring/debug
 */
export const getDebugInfo = onRequest(
  {
    timeoutSeconds: 20,
    memory: '512MiB',
    invoker: 'private'
  },
  async (req: Request, res: Response) => {
    try {
      if (req.method !== 'GET') {
        res.status(405).json({ error: 'Method not allowed' });
        return;
      }

      // Authenticate admin user
      const authResult = await authenticate(req);
      if (!authResult.admin) {
        throw new AppError('Admin access required', 403, 'ADMIN_REQUIRED');
      }

      const { getFirestore } = await import('firebase-admin/firestore');
      const db = getFirestore();

      // Get recent errors
      const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
      const errorsSnapshot = await db
        .collection('error-logs')
        .where('timestamp', '>=', fiveMinutesAgo)
        .orderBy('timestamp', 'desc')
        .limit(10)
        .get();

      const recentErrors = errorsSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));

      // Get recent alerts
      const alertsSnapshot = await db
        .collection('alerts')
        .where('triggeredAt', '>=', fiveMinutesAgo)
        .orderBy('triggeredAt', 'desc')
        .limit(10)
        .get();

      const recentAlerts = alertsSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));

      // Get provider metrics
      const providersSnapshot = await db
        .collection('provider-metrics')
        .get();

      const providerMetrics = Object.fromEntries(
        providersSnapshot.docs.map(doc => [doc.id, doc.data()])
      );

      // Get recent health checks
      const healthSnapshot = await db
        .collection('health-checks')
        .orderBy('lastCheck', 'desc')
        .limit(5)
        .get();

      const recentHealthChecks = healthSnapshot.docs.map(doc => doc.data());

      res.json({
        timestamp: new Date().toISOString(),
        systemInfo: {
          projectId: process.env.GCLOUD_PROJECT,
          region: process.env.FUNCTION_REGION,
          version: process.env.SERVICE_VERSION || '1.0.0',
          nodeVersion: process.version,
          memory: process.memoryUsage()
        },
        recentErrors,
        recentAlerts,
        providerMetrics,
        recentHealthChecks,
        debugNotes: [
          'This endpoint provides debugging information for service monitoring',
          'Check recentErrors for any critical issues',
          'Monitor providerMetrics for external API performance',
          'Use recentHealthChecks to see service status trends'
        ]
      });

    } catch (error) {
      logger.error('Debug info error', {
        error: error instanceof Error ? error.message : String(error)
      });

      res.status(500).json({
        error: 'Failed to get debug info',
        timestamp: new Date().toISOString()
      });
    }
  }
);