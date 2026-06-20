import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';

const db = getFirestore();

// Types for health observations
interface HealthObservation {
  id?: string;
  userId: string;
  type: 'steps' | 'heartRate' | 'weight' | 'bloodPressure' | 'bloodSugar' | 'mood' | 'sleep' | 'water' | 'temperature' | 'medication';
  value: ObservationValue;
  source: 'manual' | 'healthkit' | 'device' | 'provider';
  timestamp: string;
  notes?: string;
  metadata?: Record<string, any>;
  createdAt?: string;
  updatedAt?: string;
}

interface ObservationValue {
  numeric?: number;
  text?: string;
  bloodPressure?: {
    systolic: number;
    diastolic: number;
    unit: string;
  };
  categorical?: {
    value: string;
    numericValue: number;
  };
  unit?: string;
}

interface SaveObservationRequest {
  observation: HealthObservation;
}

interface GetObservationsRequest {
  type?: string;
  startDate?: string;
  endDate?: string;
  source?: string;
  limit?: number;
  pageToken?: string;
}

interface ObservationsResponse {
  observations: HealthObservation[];
  nextPageToken?: string;
  totalCount: number;
}

interface HealthKitImportRequest {
  observations: HealthKitObservation[];
  manifest: {
    startDate: string;
    endDate: string;
    dataTypes: string[];
    recordCount: number;
  };
}

interface HealthKitObservation {
  type: string;
  value: number;
  unit: string;
  startDate: string;
  endDate: string;
  source: string;
  metadata?: Record<string, any>;
}

interface ImportResult {
  processedCount: number;
  skippedCount: number;
  errorCount: number;
  warnings: string[];
}

// Save individual health observation
export const saveObservation = onCall<SaveObservationRequest, HealthObservation>(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request: CallableRequest<SaveObservationRequest>): Promise<HealthObservation> => {
    try {
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const userId = request.auth.uid;
      const { observation } = request.data;

      // Validate observation data
      if (!observation.type || !observation.value || !observation.timestamp) {
        throw new HttpsError('invalid-argument', 'Missing required observation fields');
      }

      // Ensure userId matches authenticated user
      observation.userId = userId;

      const now = new Date().toISOString();
      const observationToSave = {
        ...observation,
        createdAt: now,
        updatedAt: now,
        timestamp: new Date(observation.timestamp).toISOString()
      };

      // Save to Firestore
      const docRef = await db.collection('healthObservations').add(observationToSave);
      
      // Update daily metrics if applicable
      await updateDailyMetrics(userId, observation);

      // Generate insights if needed
      await triggerInsightGeneration(userId, observation);

      const savedObservation = {
        ...observationToSave,
        id: docRef.id
      };

      logger.info(`Saved health observation for user: ${userId}, type: ${observation.type}`);
      return savedObservation;

    } catch (error) {
      logger.error('Error saving observation:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to save observation');
    }
  }
);

// Get health observations with filtering and pagination
export const getObservations = onCall<GetObservationsRequest, ObservationsResponse>(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request: CallableRequest<GetObservationsRequest>): Promise<ObservationsResponse> => {
    try {
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const userId = request.auth.uid;
      const { 
        type, 
        startDate, 
        endDate, 
        source, 
        limit = 50, 
        pageToken 
      } = request.data;

      let query = db
        .collection('healthObservations')
        .where('userId', '==', userId);

      // Apply filters
      if (type) {
        query = query.where('type', '==', type);
      }

      if (source) {
        query = query.where('source', '==', source);
      }

      if (startDate) {
        query = query.where('timestamp', '>=', new Date(startDate).toISOString());
      }

      if (endDate) {
        query = query.where('timestamp', '<=', new Date(endDate).toISOString());
      }

      // Order by timestamp descending
      query = query.orderBy('timestamp', 'desc');

      // Handle pagination
      if (pageToken) {
        const lastDoc = await db.doc(pageToken).get();
        if (lastDoc.exists) {
          query = query.startAfter(lastDoc);
        }
      }

      // Apply limit
      query = query.limit(limit + 1); // Get one extra to check if there are more

      const querySnapshot = await query.get();
      
      const observations: HealthObservation[] = [];
      let hasMore = false;

      querySnapshot.docs.forEach((doc, index) => {
        if (index < limit) {
          const data = doc.data();
          observations.push({
            id: doc.id,
            userId: data.userId,
            type: data.type,
            value: data.value,
            source: data.source,
            timestamp: data.timestamp,
            notes: data.notes,
            metadata: data.metadata,
            createdAt: data.createdAt,
            updatedAt: data.updatedAt
          });
        } else {
          hasMore = true;
        }
      });

      // Get total count (this could be cached for better performance)
      const countQuery = await db
        .collection('healthObservations')
        .where('userId', '==', userId)
        .count()
        .get();

      const response: ObservationsResponse = {
        observations,
        totalCount: countQuery.data().count,
        nextPageToken: hasMore && observations.length > 0 ? 
          observations[observations.length - 1].id : undefined
      };

      return response;

    } catch (error) {
      logger.error('Error getting observations:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to get observations');
    }
  }
);

// Import HealthKit data in bulk
export const importHealthKitData = onCall<HealthKitImportRequest, ImportResult>(
  {
    enforceAppCheck: true,
    cors: true,
    timeoutSeconds: 300, // 5 minutes timeout for large imports
  },
  async (request: CallableRequest<HealthKitImportRequest>): Promise<ImportResult> => {
    try {
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const userId = request.auth.uid;
      const { observations, manifest } = request.data;

      logger.info(`Starting HealthKit import for user: ${userId}, records: ${observations.length}`);

      let processedCount = 0;
      let skippedCount = 0;
      let errorCount = 0;
      const warnings: string[] = [];

      // Process in batches to avoid Firestore limits
      const batchSize = 500;
      const batches = [];
      
      for (let i = 0; i < observations.length; i += batchSize) {
        batches.push(observations.slice(i, i + batchSize));
      }

      for (const batch of batches) {
        const firestoreBatch = db.batch();
        
        for (const healthKitObs of batch) {
          try {
            // Convert HealthKit observation to our format
            const observation: HealthObservation = {
              userId,
              type: mapHealthKitType(healthKitObs.type),
              value: {
                numeric: healthKitObs.value,
                unit: healthKitObs.unit
              },
              source: 'healthkit',
              timestamp: healthKitObs.startDate,
              metadata: {
                ...healthKitObs.metadata,
                healthKitSource: healthKitObs.source,
                endDate: healthKitObs.endDate
              },
              createdAt: new Date().toISOString(),
              updatedAt: new Date().toISOString()
            };

            // Check for duplicates (same user, type, timestamp)
            const existingQuery = await db
              .collection('healthObservations')
              .where('userId', '==', userId)
              .where('type', '==', observation.type)
              .where('timestamp', '==', observation.timestamp)
              .where('source', '==', 'healthkit')
              .limit(1)
              .get();

            if (!existingQuery.empty) {
              skippedCount++;
              continue;
            }

            // Add to batch
            const docRef = db.collection('healthObservations').doc();
            firestoreBatch.set(docRef, observation);
            processedCount++;

          } catch (error) {
            errorCount++;
            warnings.push(`Failed to process observation: ${error}`);
            logger.warn(`Error processing observation:`, error);
          }
        }

        // Commit batch
        if (processedCount > 0) {
          await firestoreBatch.commit();
        }
      }

      // Update daily metrics for imported data
      await updateDailyMetricsFromImport(userId, observations, manifest);

      // Record import in user's sync history
      await db.collection('healthSyncHistory').add({
        userId,
        type: 'healthkit_import',
        processedCount,
        skippedCount,
        errorCount,
        dataTypes: manifest.dataTypes,
        startDate: manifest.startDate,
        endDate: manifest.endDate,
        importedAt: FieldValue.serverTimestamp()
      });

      const result: ImportResult = {
        processedCount,
        skippedCount,
        errorCount,
        warnings
      };

      logger.info(`HealthKit import completed for user: ${userId}`, result);
      return result;

    } catch (error) {
      logger.error('Error importing HealthKit data:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to import HealthKit data');
    }
  }
);

// Helper function to map HealthKit types to our observation types
function mapHealthKitType(healthKitType: string): HealthObservation['type'] {
  const mapping: Record<string, HealthObservation['type']> = {
    'HKQuantityTypeIdentifierStepCount': 'steps',
    'HKQuantityTypeIdentifierHeartRate': 'heartRate',
    'HKQuantityTypeIdentifierBodyMass': 'weight',
    'HKQuantityTypeIdentifierBloodPressureSystolic': 'bloodPressure',
    'HKQuantityTypeIdentifierBloodPressureDiastolic': 'bloodPressure',
    'HKQuantityTypeIdentifierBloodGlucose': 'bloodSugar',
    'HKCategoryTypeIdentifierSleepAnalysis': 'sleep',
    'HKQuantityTypeIdentifierDistanceWalkingRunning': 'steps',
    'HKQuantityTypeIdentifierActiveEnergyBurned': 'steps',
    'HKQuantityTypeIdentifierBodyTemperature': 'temperature'
  };

  return mapping[healthKitType] || 'steps';
}

// Update daily metrics aggregation
async function updateDailyMetrics(userId: string, observation: HealthObservation) {
  const date = new Date(observation.timestamp).toISOString().split('T')[0];
  const dailyMetricsRef = db
    .collection('healthMetrics')
    .doc(userId)
    .collection('daily')
    .doc(date);

  const doc = await dailyMetricsRef.get();
  const existing = doc.exists ? doc.data() : {};

  const updates: any = {
    date,
    updatedAt: FieldValue.serverTimestamp()
  };

  // Update specific metrics based on observation type
  switch (observation.type) {
    case 'steps':
      if (observation.value.numeric) {
        updates.steps = Math.max(existing.steps || 0, observation.value.numeric);
      }
      break;
    
    case 'heartRate':
      if (observation.value.numeric) {
        const currentCount = existing.heartRateCount || 0;
        const currentSum = (existing.heartRateAvg || 0) * currentCount;
        updates.heartRateCount = currentCount + 1;
        updates.heartRateAvg = Math.round((currentSum + observation.value.numeric) / updates.heartRateCount);
      }
      break;
    
    case 'weight':
      if (observation.value.numeric) {
        updates.currentWeight = observation.value.numeric;
        updates.weightUnit = observation.value.unit || 'kg';
      }
      break;

    case 'sleep':
      if (observation.value.numeric) {
        updates.sleepHours = observation.value.numeric;
      }
      break;
  }

  if (Object.keys(updates).length > 2) { // More than just date and updatedAt
    await dailyMetricsRef.set(updates, { merge: true });
  }
}

// Update daily metrics from bulk import
async function updateDailyMetricsFromImport(
  userId: string, 
  observations: HealthKitObservation[], 
  manifest: HealthKitImportRequest['manifest']
) {
  // Group observations by date
  const observationsByDate: Record<string, HealthKitObservation[]> = {};
  
  observations.forEach(obs => {
    const date = new Date(obs.startDate).toISOString().split('T')[0];
    if (!observationsByDate[date]) {
      observationsByDate[date] = [];
    }
    observationsByDate[date].push(obs);
  });

  // Update each date's metrics
  const batch = db.batch();
  
  Object.entries(observationsByDate).forEach(([date, dayObservations]) => {
    const dailyMetricsRef = db
      .collection('healthMetrics')
      .doc(userId)
      .collection('daily')
      .doc(date);

    const metrics: any = {
      date,
      updatedAt: FieldValue.serverTimestamp()
    };

    // Aggregate metrics for the day
    let totalSteps = 0;
    let heartRateReadings: number[] = [];
    let sleepHours = 0;
    let latestWeight: number | undefined;

    dayObservations.forEach(obs => {
      const type = mapHealthKitType(obs.type);
      
      switch (type) {
        case 'steps':
          totalSteps = Math.max(totalSteps, obs.value);
          break;
        case 'heartRate':
          heartRateReadings.push(obs.value);
          break;
        case 'sleep':
          sleepHours = Math.max(sleepHours, obs.value);
          break;
        case 'weight':
          latestWeight = obs.value;
          break;
      }
    });

    // Set aggregated values
    if (totalSteps > 0) metrics.steps = totalSteps;
    if (heartRateReadings.length > 0) {
      metrics.heartRateAvg = Math.round(
        heartRateReadings.reduce((a, b) => a + b, 0) / heartRateReadings.length
      );
    }
    if (sleepHours > 0) metrics.sleepHours = sleepHours;
    if (latestWeight) metrics.currentWeight = latestWeight;

    batch.set(dailyMetricsRef, metrics, { merge: true });
  });

  await batch.commit();
}

// Trigger insight generation based on new observation
async function triggerInsightGeneration(userId: string, observation: HealthObservation) {
  // This would typically trigger a background task or analytics pipeline
  // For now, we'll just log the event
  logger.info(`Triggering insight generation for user: ${userId}, observation: ${observation.type}`);
  
  // In a production system, you might:
  // 1. Add to a Pub/Sub topic for ML processing
  // 2. Trigger Cloud Run job for insight analysis
  // 3. Update real-time analytics dashboard
}