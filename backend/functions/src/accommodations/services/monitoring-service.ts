import { logger } from 'firebase-functions/v2';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { CloudMonitoringServiceClient } from '@google-cloud/monitoring';

export interface ServiceMetric {
  name: string;
  value: number;
  unit: string;
  timestamp: Date;
  labels: Record<string, string>;
  resourceType: string;
}

export interface AlertCondition {
  id: string;
  name: string;
  description: string;
  metric: string;
  operator: 'GREATER_THAN' | 'LESS_THAN' | 'EQUAL_TO';
  threshold: number;
  duration: number; // seconds
  severity: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
  enabled: boolean;
}

export interface ServiceHealth {
  service: string;
  status: 'HEALTHY' | 'DEGRADED' | 'UNHEALTHY' | 'DOWN';
  uptime: number;
  responseTime: number;
  errorRate: number;
  throughput: number;
  lastCheck: Date;
  issues?: string[];
}

/**
 * Comprehensive monitoring and alerting service for accommodations
 * Provides metrics collection, health checks, and alerting capabilities
 */
export class MonitoringService {
  private metricsClient: CloudMonitoringServiceClient;
  private projectId: string;
  private db: ReturnType<typeof getFirestore>;

  constructor() {
    this.metricsClient = new CloudMonitoringServiceClient();
    this.projectId = process.env.GCLOUD_PROJECT || 'liive-app';
    this.db = getFirestore();
  }

  /**
   * Record custom metrics to Cloud Monitoring
   */
  async recordMetric(metric: ServiceMetric): Promise<void> {
    try {
      const projectPath = this.metricsClient.projectPath(this.projectId);
      
      const dataPoint = {
        interval: {
          endTime: {
            seconds: Math.floor(metric.timestamp.getTime() / 1000),
          },
        },
        value: {
          doubleValue: metric.value,
        },
      };

      const timeSeries = [{
        metric: {
          type: `custom.googleapis.com/accommodations/${metric.name}`,
          labels: metric.labels,
        },
        resource: {
          type: metric.resourceType || 'cloud_function',
          labels: {
            function_name: 'accommodations',
            region: process.env.FUNCTION_REGION || 'us-central1',
            project_id: this.projectId,
          },
        },
        points: [dataPoint],
      }];

      await this.metricsClient.createTimeSeries({
        name: projectPath,
        timeSeries,
      });

      logger.debug('Metric recorded successfully', {
        metric: metric.name,
        value: metric.value,
        unit: metric.unit,
        labels: metric.labels
      });

    } catch (error) {
      logger.error('Failed to record metric', {
        metric: metric.name,
        error: error instanceof Error ? error.message : String(error)
      });
    }
  }

  /**
   * Record search performance metrics
   */
  async recordSearchMetrics(
    responseTime: number,
    resultCount: number,
    cacheHit: boolean,
    providersUsed: number,
    location: string
  ): Promise<void> {
    const timestamp = new Date();
    const baseLabels = {
      location_region: this.extractRegion(location),
      cache_hit: String(cacheHit),
      provider_count: String(providersUsed)
    };

    await Promise.allSettled([
      this.recordMetric({
        name: 'search_response_time_ms',
        value: responseTime,
        unit: 'ms',
        timestamp,
        labels: baseLabels,
        resourceType: 'cloud_function'
      }),
      this.recordMetric({
        name: 'search_result_count',
        value: resultCount,
        unit: 'count',
        timestamp,
        labels: baseLabels,
        resourceType: 'cloud_function'
      }),
      this.recordMetric({
        name: 'search_cache_hit_rate',
        value: cacheHit ? 1 : 0,
        unit: 'ratio',
        timestamp,
        labels: baseLabels,
        resourceType: 'cloud_function'
      })
    ]);
  }

  /**
   * Record provider performance metrics
   */
  async recordProviderMetrics(
    providerId: string,
    responseTime: number,
    success: boolean,
    resultCount: number,
    circuitBreakerState: string
  ): Promise<void> {
    const timestamp = new Date();
    const labels = {
      provider_id: providerId,
      success: String(success),
      circuit_breaker_state: circuitBreakerState
    };

    await Promise.allSettled([
      this.recordMetric({
        name: 'provider_response_time_ms',
        value: responseTime,
        unit: 'ms',
        timestamp,
        labels,
        resourceType: 'external_api'
      }),
      this.recordMetric({
        name: 'provider_success_rate',
        value: success ? 1 : 0,
        unit: 'ratio',
        timestamp,
        labels,
        resourceType: 'external_api'
      }),
      this.recordMetric({
        name: 'provider_result_count',
        value: resultCount,
        unit: 'count',
        timestamp,
        labels,
        resourceType: 'external_api'
      })
    ]);
  }

  /**
   * Record booking conversion metrics
   */
  async recordBookingMetrics(
    stage: 'started' | 'payment_initiated' | 'completed' | 'failed',
    amount: number,
    currency: string,
    providerId: string,
    conversionTime?: number
  ): Promise<void> {
    const timestamp = new Date();
    const labels = {
      stage,
      currency,
      provider_id: providerId
    };

    await Promise.allSettled([
      this.recordMetric({
        name: 'booking_conversion_funnel',
        value: 1,
        unit: 'count',
        timestamp,
        labels,
        resourceType: 'cloud_function'
      }),
      amount > 0 ? this.recordMetric({
        name: 'booking_revenue',
        value: amount,
        unit: currency.toLowerCase(),
        timestamp,
        labels,
        resourceType: 'cloud_function'
      }) : Promise.resolve(),
      conversionTime ? this.recordMetric({
        name: 'booking_conversion_time_ms',
        value: conversionTime,
        unit: 'ms',
        timestamp,
        labels,
        resourceType: 'cloud_function'
      }) : Promise.resolve()
    ]);
  }

  /**
   * Perform comprehensive health check
   */
  async performHealthCheck(): Promise<ServiceHealth> {
    const startTime = Date.now();
    const issues: string[] = [];
    let status: ServiceHealth['status'] = 'HEALTHY';

    try {
      // Check Firestore connectivity
      const testDoc = await this.db.collection('health-check').doc('test').get();
      const firestoreLatency = Date.now() - startTime;
      
      if (firestoreLatency > 1000) {
        issues.push(`Firestore latency high: ${firestoreLatency}ms`);
        status = 'DEGRADED';
      }

      // Check recent error rates
      const recentErrors = await this.getRecentErrorRate();
      if (recentErrors > 0.05) { // 5% error rate threshold
        issues.push(`High error rate: ${(recentErrors * 100).toFixed(1)}%`);
        status = recentErrors > 0.1 ? 'UNHEALTHY' : 'DEGRADED';
      }

      // Check provider circuit breaker states
      const circuitBreakerIssues = await this.checkCircuitBreakerStates();
      if (circuitBreakerIssues.length > 0) {
        issues.push(...circuitBreakerIssues);
        if (circuitBreakerIssues.length > 2) {
          status = 'DEGRADED';
        }
      }

      // Check Cloud Tasks queue health
      const queueHealth = await this.checkTaskQueueHealth();
      if (!queueHealth.healthy) {
        issues.push(`Task queue issues: ${queueHealth.issue}`);
        status = 'DEGRADED';
      }

      const totalResponseTime = Date.now() - startTime;

      const health: ServiceHealth = {
        service: 'accommodations',
        status,
        uptime: await this.calculateUptime(),
        responseTime: totalResponseTime,
        errorRate: recentErrors,
        throughput: await this.calculateThroughput(),
        lastCheck: new Date(),
        issues: issues.length > 0 ? issues : undefined
      };

      // Store health check result
      await this.storeHealthCheck(health);
      
      // Record health metrics
      await this.recordHealthMetrics(health);

      return health;

    } catch (error) {
      const errorHealth: ServiceHealth = {
        service: 'accommodations',
        status: 'DOWN',
        uptime: 0,
        responseTime: Date.now() - startTime,
        errorRate: 1,
        throughput: 0,
        lastCheck: new Date(),
        issues: [`Health check failed: ${error instanceof Error ? error.message : String(error)}`]
      };

      await this.storeHealthCheck(errorHealth);
      return errorHealth;
    }
  }

  /**
   * Check and trigger alerts based on current metrics
   */
  async checkAlerts(): Promise<void> {
    try {
      // Get active alert conditions
      const alertsSnapshot = await this.db
        .collection('alert-conditions')
        .where('enabled', '==', true)
        .get();

      const alertConditions = alertsSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      } as AlertCondition));

      for (const condition of alertConditions) {
        await this.evaluateAlertCondition(condition);
      }

    } catch (error) {
      logger.error('Alert checking failed', {
        error: error instanceof Error ? error.message : String(error)
      });
    }
  }

  /**
   * Create or update alert condition
   */
  async createAlertCondition(condition: Omit<AlertCondition, 'id'>): Promise<string> {
    const docRef = await this.db.collection('alert-conditions').add({
      ...condition,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now()
    });

    logger.info('Alert condition created', {
      id: docRef.id,
      name: condition.name,
      metric: condition.metric,
      severity: condition.severity
    });

    return docRef.id;
  }

  /**
   * Get service performance dashboard data
   */
  async getDashboardData(timeRange: '1h' | '24h' | '7d' | '30d'): Promise<{
    responseTime: { timestamp: Date; value: number }[];
    throughput: { timestamp: Date; value: number }[];
    errorRate: { timestamp: Date; value: number }[];
    providerMetrics: Record<string, {
      responseTime: number;
      successRate: number;
      resultCount: number;
    }>;
    alerts: { severity: string; count: number }[];
  }> {
    const endTime = new Date();
    const startTime = new Date(endTime.getTime() - this.getTimeRangeMs(timeRange));

    // This would typically query Cloud Monitoring API for actual metrics
    // For now, returning sample structure
    
    return {
      responseTime: await this.getMetricTimeSeries('search_response_time_ms', startTime, endTime),
      throughput: await this.getMetricTimeSeries('search_throughput', startTime, endTime),
      errorRate: await this.getMetricTimeSeries('error_rate', startTime, endTime),
      providerMetrics: await this.getProviderMetricsSummary(startTime, endTime),
      alerts: await this.getAlertsSummary(startTime, endTime)
    };
  }

  // Private helper methods

  private extractRegion(location: string): string {
    // Extract region from location string for metrics labeling
    const regions = ['us', 'europe', 'asia', 'oceania', 'africa', 'south_america'];
    const locationLower = location.toLowerCase();
    
    for (const region of regions) {
      if (locationLower.includes(region)) {
        return region;
      }
    }
    
    return 'unknown';
  }

  private async getRecentErrorRate(): Promise<number> {
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
    
    const errorsSnapshot = await this.db
      .collection('error-logs')
      .where('timestamp', '>=', Timestamp.fromDate(fiveMinutesAgo))
      .get();

    const requestsSnapshot = await this.db
      .collection('request-logs')
      .where('timestamp', '>=', Timestamp.fromDate(fiveMinutesAgo))
      .get();

    const errorCount = errorsSnapshot.size;
    const totalRequests = requestsSnapshot.size;

    return totalRequests > 0 ? errorCount / totalRequests : 0;
  }

  private async checkCircuitBreakerStates(): Promise<string[]> {
    const issues: string[] = [];
    
    try {
      // Check each provider's circuit breaker state
      const providersSnapshot = await this.db.collection('provider-metrics').get();
      
      for (const doc of providersSnapshot.docs) {
        const data = doc.data();
        if (data.circuitBreakerState === 'OPEN') {
          issues.push(`Provider ${doc.id} circuit breaker is open`);
        } else if (data.successRate < 0.8) { // 80% success rate threshold
          issues.push(`Provider ${doc.id} has low success rate: ${(data.successRate * 100).toFixed(1)}%`);
        }
      }
    } catch (error) {
      issues.push('Unable to check circuit breaker states');
    }

    return issues;
  }

  private async checkTaskQueueHealth(): Promise<{ healthy: boolean; issue?: string }> {
    try {
      // Check if there are too many pending tasks (indicates processing issues)
      const pendingTasksSnapshot = await this.db
        .collection('accommodation-search-results')
        .where('timestamp', '<', new Date(Date.now() - 10 * 60 * 1000)) // Older than 10 minutes
        .limit(10)
        .get();

      if (pendingTasksSnapshot.size > 5) {
        return { 
          healthy: false, 
          issue: 'Too many pending tasks, queue processing may be slow' 
        };
      }

      return { healthy: true };
    } catch (error) {
      return { 
        healthy: false, 
        issue: 'Unable to check task queue status' 
      };
    }
  }

  private async calculateUptime(): Promise<number> {
    // Calculate uptime based on successful health checks in the last 24 hours
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    
    const healthChecksSnapshot = await this.db
      .collection('health-checks')
      .where('lastCheck', '>=', Timestamp.fromDate(oneDayAgo))
      .orderBy('lastCheck', 'desc')
      .get();

    if (healthChecksSnapshot.empty) return 1.0;

    const totalChecks = healthChecksSnapshot.size;
    const successfulChecks = healthChecksSnapshot.docs.filter(
      doc => doc.data().status === 'HEALTHY' || doc.data().status === 'DEGRADED'
    ).length;

    return totalChecks > 0 ? successfulChecks / totalChecks : 1.0;
  }

  private async calculateThroughput(): Promise<number> {
    // Calculate requests per minute in the last 5 minutes
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
    
    const requestsSnapshot = await this.db
      .collection('request-logs')
      .where('timestamp', '>=', Timestamp.fromDate(fiveMinutesAgo))
      .get();

    return requestsSnapshot.size / 5; // requests per minute
  }

  private async storeHealthCheck(health: ServiceHealth): Promise<void> {
    await this.db.collection('health-checks').add({
      ...health,
      lastCheck: Timestamp.fromDate(health.lastCheck)
    });
  }

  private async recordHealthMetrics(health: ServiceHealth): Promise<void> {
    const timestamp = new Date();
    const statusValue = this.statusToNumeric(health.status);

    await Promise.allSettled([
      this.recordMetric({
        name: 'service_health_status',
        value: statusValue,
        unit: 'status',
        timestamp,
        labels: { service: health.service },
        resourceType: 'cloud_function'
      }),
      this.recordMetric({
        name: 'service_response_time_ms',
        value: health.responseTime,
        unit: 'ms',
        timestamp,
        labels: { service: health.service },
        resourceType: 'cloud_function'
      }),
      this.recordMetric({
        name: 'service_error_rate',
        value: health.errorRate,
        unit: 'ratio',
        timestamp,
        labels: { service: health.service },
        resourceType: 'cloud_function'
      })
    ]);
  }

  private async evaluateAlertCondition(condition: AlertCondition): Promise<void> {
    try {
      // Get recent metric values for evaluation
      const currentValue = await this.getCurrentMetricValue(condition.metric);
      const shouldTrigger = this.evaluateThreshold(
        currentValue,
        condition.operator,
        condition.threshold
      );

      if (shouldTrigger) {
        await this.triggerAlert(condition, currentValue);
      }

    } catch (error) {
      logger.error('Failed to evaluate alert condition', {
        conditionId: condition.id,
        error: error instanceof Error ? error.message : String(error)
      });
    }
  }

  private async getCurrentMetricValue(metricName: string): Promise<number> {
    // In a real implementation, this would query Cloud Monitoring API
    // For now, return a sample value
    return Math.random() * 1000;
  }

  private evaluateThreshold(value: number, operator: string, threshold: number): boolean {
    switch (operator) {
      case 'GREATER_THAN':
        return value > threshold;
      case 'LESS_THAN':
        return value < threshold;
      case 'EQUAL_TO':
        return Math.abs(value - threshold) < 0.001;
      default:
        return false;
    }
  }

  private async triggerAlert(condition: AlertCondition, currentValue: number): Promise<void> {
    const alert = {
      conditionId: condition.id,
      conditionName: condition.name,
      severity: condition.severity,
      metric: condition.metric,
      currentValue,
      threshold: condition.threshold,
      triggeredAt: Timestamp.now(),
      status: 'TRIGGERED'
    };

    await this.db.collection('alerts').add(alert);

    logger.warn('Alert triggered', {
      conditionName: condition.name,
      severity: condition.severity,
      metric: condition.metric,
      currentValue,
      threshold: condition.threshold
    });

    // In production, this would also send notifications via email, Slack, PagerDuty, etc.
  }

  private statusToNumeric(status: ServiceHealth['status']): number {
    switch (status) {
      case 'HEALTHY': return 1;
      case 'DEGRADED': return 0.5;
      case 'UNHEALTHY': return 0.25;
      case 'DOWN': return 0;
      default: return 0;
    }
  }

  private getTimeRangeMs(timeRange: '1h' | '24h' | '7d' | '30d'): number {
    switch (timeRange) {
      case '1h': return 60 * 60 * 1000;
      case '24h': return 24 * 60 * 60 * 1000;
      case '7d': return 7 * 24 * 60 * 60 * 1000;
      case '30d': return 30 * 24 * 60 * 60 * 1000;
      default: return 60 * 60 * 1000;
    }
  }

  private async getMetricTimeSeries(
    metricName: string,
    startTime: Date,
    endTime: Date
  ): Promise<{ timestamp: Date; value: number }[]> {
    // In production, this would query actual metrics from Cloud Monitoring
    // For now, return sample data
    const points: { timestamp: Date; value: number }[] = [];
    const interval = (endTime.getTime() - startTime.getTime()) / 20;
    
    for (let i = 0; i < 20; i++) {
      points.push({
        timestamp: new Date(startTime.getTime() + i * interval),
        value: Math.random() * 1000
      });
    }
    
    return points;
  }

  private async getProviderMetricsSummary(
    startTime: Date,
    endTime: Date
  ): Promise<Record<string, { responseTime: number; successRate: number; resultCount: number }>> {
    const providersSnapshot = await this.db.collection('provider-metrics').get();
    const summary: Record<string, any> = {};
    
    providersSnapshot.docs.forEach(doc => {
      const data = doc.data();
      summary[doc.id] = {
        responseTime: data.averageResponseTime || 0,
        successRate: data.successRate || 0,
        resultCount: data.totalResults || 0
      };
    });
    
    return summary;
  }

  private async getAlertsSummary(
    startTime: Date,
    endTime: Date
  ): Promise<{ severity: string; count: number }[]> {
    const alertsSnapshot = await this.db
      .collection('alerts')
      .where('triggeredAt', '>=', Timestamp.fromDate(startTime))
      .where('triggeredAt', '<=', Timestamp.fromDate(endTime))
      .get();

    const severityCounts: Record<string, number> = {};
    
    alertsSnapshot.docs.forEach(doc => {
      const severity = doc.data().severity;
      severityCounts[severity] = (severityCounts[severity] || 0) + 1;
    });

    return Object.entries(severityCounts).map(([severity, count]) => ({
      severity,
      count
    }));
  }
}

// Singleton instance
export const monitoringService = new MonitoringService();