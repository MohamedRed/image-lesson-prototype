import { CloudTasksClient } from '@google-cloud/tasks';
import { logger } from 'firebase-functions/v2';
import { AccommodationSearchRequest } from '../types/search.js';
import { AccommodationProvider } from '../types/provider.js';

export interface TaskPayload {
  searchRequest: AccommodationSearchRequest;
  provider: AccommodationProvider;
  requestId: string;
  userId: string;
  retryCount?: number;
}

export interface TaskScheduleOptions {
  delaySeconds?: number;
  priority?: number;
  maxRetries?: number;
  retryBackoffSeconds?: number;
}

/**
 * Cloud Tasks service for managing provider API fan-out
 * Handles distributed search across multiple accommodation providers
 */
export class CloudTasksService {
  private client: CloudTasksClient;
  private projectId: string;
  private locationId: string;
  private queueName: string;
  private serviceUrl: string;

  constructor() {
    this.client = new CloudTasksClient();
    this.projectId = process.env.GCLOUD_PROJECT || 'liive-app';
    this.locationId = process.env.TASKS_LOCATION || 'us-central1';
    this.queueName = 'accommodations-provider-fanout';
    this.serviceUrl = process.env.FUNCTIONS_BASE_URL || 'https://us-central1-liive-app.cloudfunctions.net';
  }

  /**
   * Schedule provider search tasks for fan-out execution
   */
  async scheduleProviderSearchTasks(
    searchRequest: AccommodationSearchRequest,
    providers: AccommodationProvider[],
    requestId: string,
    userId: string,
    options: TaskScheduleOptions = {}
  ): Promise<void> {
    const {
      delaySeconds = 0,
      priority = 0,
      maxRetries = 3,
      retryBackoffSeconds = 60
    } = options;

    const tasks = providers.map(async (provider, index) => {
      const payload: TaskPayload = {
        searchRequest,
        provider,
        requestId,
        userId,
        retryCount: 0
      };

      // Stagger task execution to avoid thundering herd
      const taskDelaySeconds = delaySeconds + (index * 2);
      
      const parent = this.client.queuePath(this.projectId, this.locationId, this.queueName);
      const url = `${this.serviceUrl}/accommodations-provider-search`;

      const task = {
        httpRequest: {
          httpMethod: 'POST' as const,
          url,
          body: Buffer.from(JSON.stringify(payload)),
          headers: {
            'Content-Type': 'application/json',
            'X-Task-Source': 'cloud-tasks',
            'X-Request-ID': requestId,
            'X-User-ID': userId,
            'Authorization': `Bearer ${await this.generateServiceToken()}`
          }
        },
        scheduleTime: taskDelaySeconds > 0 ? {
          seconds: Math.floor(Date.now() / 1000) + taskDelaySeconds
        } : undefined,
        retryConfig: {
          maxAttempts: maxRetries + 1,
          maxRetryDuration: { seconds: 300 }, // 5 minutes max retry window
          minBackoff: { seconds: retryBackoffSeconds },
          maxBackoff: { seconds: retryBackoffSeconds * 4 },
          maxDoublings: 3
        },
        httpRequest: {
          ...task.httpRequest,
          // Add exponential backoff for failed requests
          oidcToken: process.env.CLOUD_TASKS_SERVICE_ACCOUNT_EMAIL ? {
            serviceAccountEmail: process.env.CLOUD_TASKS_SERVICE_ACCOUNT_EMAIL,
            audience: url
          } : undefined
        }
      };

      try {
        const [response] = await this.client.createTask({ parent, task });
        
        logger.info('Task scheduled successfully', {
          taskName: response.name,
          provider: provider.id,
          requestId,
          delaySeconds: taskDelaySeconds
        });

        return response;
      } catch (error) {
        logger.error('Failed to schedule task', {
          error: error instanceof Error ? error.message : String(error),
          provider: provider.id,
          requestId
        });
        throw error;
      }
    });

    await Promise.allSettled(tasks);
    
    logger.info('Provider search tasks scheduled', {
      requestId,
      providerCount: providers.length,
      totalTasks: tasks.length
    });
  }

  /**
   * Schedule retry task for failed provider request
   */
  async scheduleRetryTask(
    originalPayload: TaskPayload,
    delaySeconds: number = 60
  ): Promise<void> {
    const retryPayload: TaskPayload = {
      ...originalPayload,
      retryCount: (originalPayload.retryCount || 0) + 1
    };

    const parent = this.client.queuePath(this.projectId, this.locationId, this.queueName);
    const url = `${this.serviceUrl}/accommodations-provider-search`;

    const task = {
      httpRequest: {
        httpMethod: 'POST' as const,
        url,
        body: Buffer.from(JSON.stringify(retryPayload)),
        headers: {
          'Content-Type': 'application/json',
          'X-Task-Source': 'retry',
          'X-Request-ID': retryPayload.requestId,
          'X-Retry-Count': String(retryPayload.retryCount)
        }
      },
      scheduleTime: {
        seconds: Math.floor(Date.now() / 1000) + delaySeconds
      }
    };

    try {
      const [response] = await this.client.createTask({ parent, task });
      
      logger.info('Retry task scheduled', {
        taskName: response.name,
        provider: retryPayload.provider.id,
        requestId: retryPayload.requestId,
        retryCount: retryPayload.retryCount,
        delaySeconds
      });
    } catch (error) {
      logger.error('Failed to schedule retry task', {
        error: error instanceof Error ? error.message : String(error),
        provider: retryPayload.provider.id,
        requestId: retryPayload.requestId,
        retryCount: retryPayload.retryCount
      });
      throw error;
    }
  }

  /**
   * Schedule batch processing task for aggregating results
   */
  async scheduleBatchProcessingTask(
    requestId: string,
    userId: string,
    expectedProviderCount: number,
    delaySeconds: number = 30
  ): Promise<void> {
    const payload = {
      requestId,
      userId,
      expectedProviderCount,
      taskType: 'batch-processing'
    };

    const parent = this.client.queuePath(this.projectId, this.locationId, 'accommodations-batch-processing');
    const url = `${this.serviceUrl}/accommodations-batch-processing`;

    const task = {
      httpRequest: {
        httpMethod: 'POST' as const,
        url,
        body: Buffer.from(JSON.stringify(payload)),
        headers: {
          'Content-Type': 'application/json',
          'X-Task-Source': 'batch-processing',
          'X-Request-ID': requestId
        }
      },
      scheduleTime: {
        seconds: Math.floor(Date.now() / 1000) + delaySeconds
      }
    };

    try {
      const [response] = await this.client.createTask({ parent, task });
      
      logger.info('Batch processing task scheduled', {
        taskName: response.name,
        requestId,
        expectedProviderCount,
        delaySeconds
      });
    } catch (error) {
      logger.error('Failed to schedule batch processing task', {
        error: error instanceof Error ? error.message : String(error),
        requestId
      });
      throw error;
    }
  }

  /**
   * Cancel pending tasks for a request (e.g., user cancellation)
   */
  async cancelTasksForRequest(requestId: string): Promise<void> {
    try {
      const parent = this.client.queuePath(this.projectId, this.locationId, this.queueName);
      
      // List tasks and filter by request ID
      const [tasks] = await this.client.listTasks({ parent });
      
      const tasksToCancel = tasks.filter(task => 
        task.httpRequest?.headers && 
        task.httpRequest.headers['X-Request-ID'] === requestId
      );

      const cancelPromises = tasksToCancel.map(task => {
        if (task.name) {
          return this.client.deleteTask({ name: task.name });
        }
        return Promise.resolve();
      });

      await Promise.allSettled(cancelPromises);
      
      logger.info('Tasks cancelled for request', {
        requestId,
        cancelledCount: tasksToCancel.length
      });
    } catch (error) {
      logger.error('Failed to cancel tasks', {
        error: error instanceof Error ? error.message : String(error),
        requestId
      });
    }
  }

  /**
   * Get queue statistics for monitoring
   */
  async getQueueStats(): Promise<{
    pendingTasks: number;
    executingTasks: number;
    queueName: string;
  }> {
    try {
      const parent = this.client.queuePath(this.projectId, this.locationId, this.queueName);
      const [tasks] = await this.client.listTasks({ parent });
      
      const now = Date.now() / 1000;
      let pendingTasks = 0;
      let executingTasks = 0;
      
      tasks.forEach(task => {
        const scheduleTime = task.scheduleTime?.seconds;
        if (scheduleTime && Number(scheduleTime) > now) {
          pendingTasks++;
        } else {
          executingTasks++;
        }
      });

      return {
        pendingTasks,
        executingTasks,
        queueName: this.queueName
      };
    } catch (error) {
      logger.error('Failed to get queue stats', {
        error: error instanceof Error ? error.message : String(error)
      });
      
      return {
        pendingTasks: 0,
        executingTasks: 0,
        queueName: this.queueName
      };
    }
  }

  /**
   * Generate service account token for authenticated task execution
   */
  private async generateServiceToken(): Promise<string> {
    // In production, this would use service account impersonation
    // For development, return a placeholder
    if (process.env.NODE_ENV === 'development') {
      return 'dev-token';
    }
    
    // Use Google Auth Library to get token
    const { GoogleAuth } = await import('google-auth-library');
    const auth = new GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/cloud-platform']
    });
    
    const client = await auth.getClient();
    const token = await client.getAccessToken();
    
    return token.token || '';
  }
}

// Singleton instance
export const cloudTasksService = new CloudTasksService();