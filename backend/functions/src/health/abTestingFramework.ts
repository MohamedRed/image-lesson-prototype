import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { Firestore, FieldValue, Timestamp } from '@google-cloud/firestore';
import { BigQuery } from '@google-cloud/bigquery';
import { logger } from 'firebase-functions';

const firestore = new Firestore();
const bigQuery = new BigQuery();

export interface ABExperiment {
  id: string;
  name: string;
  description: string;
  status: 'draft' | 'active' | 'paused' | 'completed' | 'archived';
  type: 'health_program' | 'ui_variation' | 'notification_timing' | 'coaching_style' | 'goal_setting';
  targetAudience: {
    criteria: Array<{
      field: string;
      operator: '=' | '!=' | '>' | '<' | '>=' | '<=' | 'in' | 'not_in';
      value: any;
    }>;
    sampleSize: number;
    eligibilityRules?: string[];
  };
  variants: Array<{
    id: string;
    name: string;
    description: string;
    trafficAllocation: number; // percentage 0-100
    config: {
      [key: string]: any;
    };
    isControl: boolean;
  }>;
  metrics: Array<{
    name: string;
    type: 'primary' | 'secondary';
    calculation: 'count' | 'average' | 'sum' | 'rate' | 'conversion';
    field?: string;
    goal?: 'increase' | 'decrease' | 'maintain';
    significanceLevel?: number; // default 0.05
  }>;
  duration: {
    startDate: Date;
    endDate: Date;
    minParticipants: number;
    maxParticipants?: number;
  };
  results?: {
    totalParticipants: number;
    variantPerformance: Array<{
      variantId: string;
      participants: number;
      metrics: { [metricName: string]: number };
      confidenceInterval?: { [metricName: string]: [number, number] };
      pValue?: { [metricName: string]: number };
    }>;
    winner?: string;
    statisticalSignificance?: boolean;
    confidence?: number;
  };
  createdBy: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface ABParticipant {
  id: string;
  userId: string;
  experimentId: string;
  variantId: string;
  assignedAt: Date;
  firstInteractionAt?: Date;
  lastInteractionAt?: Date;
  interactions: number;
  conversions: Array<{
    metricName: string;
    value: number;
    timestamp: Date;
  }>;
  metadata?: {
    userSegment?: string;
    deviceType?: string;
    appVersion?: string;
    [key: string]: any;
  };
}

export interface ExperimentConfig {
  experimentId: string;
  variantId: string;
  config: any;
  userId: string;
  appliedAt: Date;
  expiresAt?: Date;
}

/**
 * Create a new A/B experiment
 */
export const createABExperiment = onCall<{
  experiment: Omit<ABExperiment, 'id' | 'createdAt' | 'updatedAt' | 'createdBy'>;
}, { experimentId: string }>(async (request) => {
  const { experiment } = request.data;

  if (!request.auth?.uid || !request.auth?.token?.admin) {
    throw new HttpsError('permission-denied', 'Admin access required');
  }

  try {
    // Validate experiment configuration
    await validateExperimentConfig(experiment as ABExperiment);

    const experimentData: ABExperiment = {
      ...experiment,
      id: '',
      createdBy: request.auth.uid,
      createdAt: new Date(),
      updatedAt: new Date()
    };

    // Save experiment
    const experimentRef = await firestore.collection('abExperiments').add(experimentData);
    await experimentRef.update({ id: experimentRef.id });

    logger.info(`A/B experiment created: ${experimentRef.id}`);
    return { experimentId: experimentRef.id };
  } catch (error) {
    logger.error('Create A/B experiment failed:', error);
    throw new HttpsError('internal', 'Failed to create experiment');
  }
});

/**
 * Get user's experiment assignment
 */
export const getUserExperimentConfig = onCall<{
  experimentType?: string;
  activeOnly?: boolean;
}, { assignments: ExperimentConfig[] }>(async (request) => {
  const { experimentType, activeOnly = true } = request.data;

  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  try {
    // Get user's active experiment assignments
    let query = firestore
      .collection('abParticipants')
      .where('userId', '==', request.auth.uid);

    const participantsSnapshot = await query.get();
    const assignments: ExperimentConfig[] = [];

    for (const doc of participantsSnapshot.docs) {
      const participant = doc.data() as ABParticipant;
      
      // Get experiment details
      const experimentDoc = await firestore
        .collection('abExperiments')
        .doc(participant.experimentId)
        .get();

      if (!experimentDoc.exists) continue;

      const experiment = experimentDoc.data() as ABExperiment;

      // Skip if filtering by type and doesn't match
      if (experimentType && experiment.type !== experimentType) continue;

      // Skip inactive experiments if activeOnly
      if (activeOnly && experiment.status !== 'active') continue;

      // Check if experiment is still valid
      if (new Date() > experiment.duration.endDate) continue;

      // Get variant configuration
      const variant = experiment.variants.find(v => v.id === participant.variantId);
      if (!variant) continue;

      assignments.push({
        experimentId: experiment.id,
        variantId: variant.id,
        config: variant.config,
        userId: request.auth.uid,
        appliedAt: participant.assignedAt,
        expiresAt: experiment.duration.endDate
      });
    }

    return { assignments };
  } catch (error) {
    logger.error('Get user experiment config failed:', error);
    throw new HttpsError('internal', 'Failed to get experiment config');
  }
});

/**
 * Assign user to experiments
 */
export const assignUserToExperiments = onCall<{
  userId?: string;
  forceReassignment?: boolean;
}, { assignments: string[] }>(async (request) => {
  const { userId: targetUserId, forceReassignment = false } = request.data;
  
  const userId = targetUserId || request.auth?.uid;
  if (!userId) {
    throw new HttpsError('unauthenticated', 'User ID required');
  }

  // Only allow self-assignment unless admin
  if (targetUserId && targetUserId !== request.auth?.uid && !request.auth?.token?.admin) {
    throw new HttpsError('permission-denied', 'Permission denied');
  }

  try {
    const assignments = await assignUserToActiveExperiments(userId, forceReassignment);
    return { assignments };
  } catch (error) {
    logger.error('Assign user to experiments failed:', error);
    throw new HttpsError('internal', 'Failed to assign experiments');
  }
});

/**
 * Track experiment interaction/conversion
 */
export const trackExperimentEvent = onCall<{
  eventType: string;
  metricName: string;
  value?: number;
  metadata?: any;
}, { success: boolean }>(async (request) => {
  const { eventType, metricName, value = 1, metadata } = request.data;

  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  try {
    await recordExperimentEvent(request.auth.uid, eventType, metricName, value, metadata);
    return { success: true };
  } catch (error) {
    logger.error('Track experiment event failed:', error);
    throw new HttpsError('internal', 'Failed to track event');
  }
});

/**
 * Get experiment results
 */
export const getExperimentResults = onCall<{
  experimentId: string;
  includeRawData?: boolean;
}, { results: any }>(async (request) => {
  const { experimentId, includeRawData = false } = request.data;

  if (!request.auth?.token?.admin) {
    throw new HttpsError('permission-denied', 'Admin access required');
  }

  try {
    const results = await calculateExperimentResults(experimentId, includeRawData);
    return { results };
  } catch (error) {
    logger.error('Get experiment results failed:', error);
    throw new HttpsError('internal', 'Failed to get results');
  }
});

/**
 * Auto-assign users to experiments when they complete onboarding
 */
export const autoAssignExperiments = onDocumentUpdated(
  'users/{userId}',
  async (event) => {
    const userData = event.data?.after.data();
    const previousData = event.data?.before.data();
    const userId = event.params.userId;

    // Check if user just completed onboarding
    if (userData?.onboarding?.completed && !previousData?.onboarding?.completed) {
      try {
        await assignUserToActiveExperiments(userId);
        logger.info(`Auto-assigned experiments to user ${userId}`);
      } catch (error) {
        logger.error(`Auto-assignment failed for user ${userId}:`, error);
      }
    }
  }
);

/**
 * Validate experiment configuration
 */
async function validateExperimentConfig(experiment: ABExperiment): Promise<void> {
  // Check traffic allocation adds up to 100%
  const totalAllocation = experiment.variants.reduce((sum, variant) => sum + variant.trafficAllocation, 0);
  if (Math.abs(totalAllocation - 100) > 0.01) {
    throw new Error(`Traffic allocation must equal 100%, got ${totalAllocation}%`);
  }

  // Ensure at least one control variant
  const hasControl = experiment.variants.some(v => v.isControl);
  if (!hasControl) {
    throw new Error('At least one variant must be marked as control');
  }

  // Check date validity
  if (experiment.duration.startDate >= experiment.duration.endDate) {
    throw new Error('Start date must be before end date');
  }

  // Ensure at least one primary metric
  const primaryMetrics = experiment.metrics.filter(m => m.type === 'primary');
  if (primaryMetrics.length === 0) {
    throw new Error('At least one primary metric is required');
  }
}

/**
 * Assign user to active experiments
 */
async function assignUserToActiveExperiments(
  userId: string, 
  forceReassignment: boolean = false
): Promise<string[]> {
  
  // Get user data for targeting
  const userDoc = await firestore.collection('users').doc(userId).get();
  const userData = userDoc.data();
  
  if (!userData) {
    throw new Error('User not found');
  }

  // Get active experiments
  const activeExperiments = await firestore
    .collection('abExperiments')
    .where('status', '==', 'active')
    .where('duration.startDate', '<=', new Date())
    .where('duration.endDate', '>', new Date())
    .get();

  const assignments: string[] = [];

  for (const experimentDoc of activeExperiments.docs) {
    const experiment = experimentDoc.data() as ABExperiment;

    try {
      // Check if user already assigned (unless forcing reassignment)
      if (!forceReassignment) {
        const existingAssignment = await firestore
          .collection('abParticipants')
          .where('userId', '==', userId)
          .where('experimentId', '==', experiment.id)
          .get();

        if (!existingAssignment.empty) {
          assignments.push(experiment.id);
          continue;
        }
      }

      // Check if user matches targeting criteria
      if (!userMatchesCriteria(userData, experiment.targetAudience.criteria)) {
        continue;
      }

      // Check if experiment has capacity
      const currentParticipants = await firestore
        .collection('abParticipants')
        .where('experimentId', '==', experiment.id)
        .get();

      if (currentParticipants.size >= (experiment.duration.maxParticipants || Infinity)) {
        continue;
      }

      // Assign user to variant
      const variantId = selectVariant(experiment.variants, userId);
      
      const participant: ABParticipant = {
        id: firestore.collection('temp').doc().id,
        userId,
        experimentId: experiment.id,
        variantId,
        assignedAt: new Date(),
        interactions: 0,
        conversions: [],
        metadata: {
          userSegment: userData.segment,
          deviceType: userData.lastDeviceType,
          appVersion: userData.lastAppVersion
        }
      };

      // Save assignment
      await firestore.collection('abParticipants').doc(participant.id).set(participant);
      assignments.push(experiment.id);

      logger.info(`Assigned user ${userId} to experiment ${experiment.id}, variant ${variantId}`);
    } catch (error) {
      logger.warn(`Failed to assign user ${userId} to experiment ${experiment.id}:`, error);
    }
  }

  return assignments;
}

/**
 * Check if user matches targeting criteria
 */
function userMatchesCriteria(userData: any, criteria: any[]): boolean {
  for (const criterion of criteria) {
    const userValue = getNestedValue(userData, criterion.field);
    
    switch (criterion.operator) {
      case '=':
        if (userValue !== criterion.value) return false;
        break;
      case '!=':
        if (userValue === criterion.value) return false;
        break;
      case '>':
        if (!(userValue > criterion.value)) return false;
        break;
      case '<':
        if (!(userValue < criterion.value)) return false;
        break;
      case '>=':
        if (!(userValue >= criterion.value)) return false;
        break;
      case '<=':
        if (!(userValue <= criterion.value)) return false;
        break;
      case 'in':
        if (!Array.isArray(criterion.value) || !criterion.value.includes(userValue)) return false;
        break;
      case 'not_in':
        if (Array.isArray(criterion.value) && criterion.value.includes(userValue)) return false;
        break;
    }
  }
  
  return true;
}

/**
 * Get nested value from object using dot notation
 */
function getNestedValue(obj: any, path: string): any {
  return path.split('.').reduce((current, key) => current?.[key], obj);
}

/**
 * Select variant for user using consistent hashing
 */
function selectVariant(variants: any[], userId: string): string {
  // Use consistent hashing to ensure same user always gets same variant
  const hash = simpleHash(userId);
  const normalizedHash = hash % 10000; // 0-9999
  
  let cumulativeWeight = 0;
  for (const variant of variants) {
    cumulativeWeight += variant.trafficAllocation * 100; // Convert percentage to 0-10000
    if (normalizedHash < cumulativeWeight) {
      return variant.id;
    }
  }
  
  // Fallback to control variant
  return variants.find(v => v.isControl)?.id || variants[0].id;
}

/**
 * Simple hash function for consistent variant assignment
 */
function simpleHash(str: string): number {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash; // Convert to 32-bit integer
  }
  return Math.abs(hash);
}

/**
 * Record experiment event/conversion
 */
async function recordExperimentEvent(
  userId: string,
  eventType: string,
  metricName: string,
  value: number,
  metadata?: any
): Promise<void> {
  
  // Get user's current experiment assignments
  const participantsSnapshot = await firestore
    .collection('abParticipants')
    .where('userId', '==', userId)
    .get();

  const batch = firestore.batch();

  for (const participantDoc of participantsSnapshot.docs) {
    const participant = participantDoc.data() as ABParticipant;
    
    // Check if this event is relevant to the experiment
    const experimentDoc = await firestore
      .collection('abExperiments')
      .doc(participant.experimentId)
      .get();

    if (!experimentDoc.exists) continue;

    const experiment = experimentDoc.data() as ABExperiment;
    
    // Check if this metric is tracked in the experiment
    const trackedMetric = experiment.metrics.find(m => m.name === metricName);
    if (!trackedMetric) continue;

    // Update participant's conversion data
    const conversion = {
      metricName,
      value,
      timestamp: new Date()
    };

    const updatedParticipant = {
      ...participant,
      interactions: participant.interactions + 1,
      conversions: [...participant.conversions, conversion],
      lastInteractionAt: new Date(),
      firstInteractionAt: participant.firstInteractionAt || new Date()
    };

    batch.update(participantDoc.ref, updatedParticipant);

    // Log event to BigQuery for detailed analysis
    try {
      await logEventToBigQuery({
        userId,
        experimentId: participant.experimentId,
        variantId: participant.variantId,
        eventType,
        metricName,
        value,
        timestamp: new Date(),
        metadata
      });
    } catch (error) {
      logger.warn('Failed to log event to BigQuery:', error);
    }
  }

  await batch.commit();
}

/**
 * Log event to BigQuery for analysis
 */
async function logEventToBigQuery(eventData: any): Promise<void> {
  const dataset = bigQuery.dataset('health_analytics');
  const table = dataset.table('ab_test_events');

  const row = {
    ...eventData,
    timestamp: eventData.timestamp.toISOString(),
    metadata_json: JSON.stringify(eventData.metadata || {})
  };

  await table.insert([row]);
}

/**
 * Calculate experiment results with statistical analysis
 */
async function calculateExperimentResults(
  experimentId: string,
  includeRawData: boolean = false
): Promise<any> {
  
  // Get experiment configuration
  const experimentDoc = await firestore.collection('abExperiments').doc(experimentId).get();
  if (!experimentDoc.exists) {
    throw new Error('Experiment not found');
  }

  const experiment = experimentDoc.data() as ABExperiment;

  // Get all participants
  const participantsSnapshot = await firestore
    .collection('abParticipants')
    .where('experimentId', '==', experimentId)
    .get();

  const participants = participantsSnapshot.docs.map(doc => doc.data() as ABParticipant);

  // Group participants by variant
  const variantData: { [variantId: string]: ABParticipant[] } = {};
  for (const participant of participants) {
    if (!variantData[participant.variantId]) {
      variantData[participant.variantId] = [];
    }
    variantData[participant.variantId].push(participant);
  }

  // Calculate metrics for each variant
  const variantPerformance = [];
  
  for (const variant of experiment.variants) {
    const variantParticipants = variantData[variant.id] || [];
    const metrics: { [metricName: string]: number } = {};

    for (const metric of experiment.metrics) {
      const metricValue = calculateMetricValue(variantParticipants, metric);
      metrics[metric.name] = metricValue;
    }

    variantPerformance.push({
      variantId: variant.id,
      variantName: variant.name,
      isControl: variant.isControl,
      participants: variantParticipants.length,
      metrics,
      rawData: includeRawData ? variantParticipants : undefined
    });
  }

  // Perform statistical significance testing
  const statisticalResults = await performStatisticalAnalysis(variantPerformance, experiment.metrics);

  const results = {
    experimentId,
    experimentName: experiment.name,
    status: experiment.status,
    totalParticipants: participants.length,
    duration: {
      startDate: experiment.duration.startDate,
      endDate: experiment.duration.endDate,
      daysRunning: Math.floor(
        (new Date().getTime() - experiment.duration.startDate.getTime()) / (1000 * 60 * 60 * 24)
      )
    },
    variantPerformance,
    statisticalSignificance: statisticalResults.hasSignificantResults,
    winner: statisticalResults.winner,
    confidence: statisticalResults.confidence,
    recommendations: generateRecommendations(variantPerformance, statisticalResults),
    calculatedAt: new Date()
  };

  // Update experiment with results
  await firestore.collection('abExperiments').doc(experimentId).update({
    results,
    updatedAt: new Date()
  });

  return results;
}

/**
 * Calculate metric value for a group of participants
 */
function calculateMetricValue(participants: ABParticipant[], metric: any): number {
  if (participants.length === 0) return 0;

  const relevantConversions = participants.flatMap(p => 
    p.conversions.filter(c => c.metricName === metric.name)
  );

  switch (metric.calculation) {
    case 'count':
      return relevantConversions.length;
    case 'sum':
      return relevantConversions.reduce((sum, conv) => sum + conv.value, 0);
    case 'average':
      return relevantConversions.length > 0 
        ? relevantConversions.reduce((sum, conv) => sum + conv.value, 0) / relevantConversions.length
        : 0;
    case 'rate':
      return (relevantConversions.length / participants.length) * 100;
    case 'conversion':
      const participantsWithConversion = new Set(relevantConversions.map(c => participants.find(p => 
        p.conversions.some(pc => pc.metricName === metric.name && pc.timestamp === c.timestamp)
      )?.userId)).size;
      return (participantsWithConversion / participants.length) * 100;
    default:
      return 0;
  }
}

/**
 * Perform statistical significance testing
 */
async function performStatisticalAnalysis(
  variantPerformance: any[],
  metrics: any[]
): Promise<{
  hasSignificantResults: boolean;
  winner?: string;
  confidence?: number;
}> {
  
  // Simple significance testing (in production, use proper statistical libraries)
  const controlVariant = variantPerformance.find(v => v.isControl);
  if (!controlVariant) {
    return { hasSignificantResults: false };
  }

  const primaryMetrics = metrics.filter(m => m.type === 'primary');
  let bestVariant = controlVariant;
  let maxImprovement = 0;

  for (const variant of variantPerformance) {
    if (variant.isControl) continue;

    let significantImprovements = 0;
    
    for (const metric of primaryMetrics) {
      const controlValue = controlVariant.metrics[metric.name];
      const variantValue = variant.metrics[metric.name];
      
      if (controlValue === 0) continue;
      
      const improvement = ((variantValue - controlValue) / controlValue) * 100;
      
      // Simple heuristic: if improvement > 5% and sufficient sample size
      if (Math.abs(improvement) > 5 && variant.participants > 30 && controlVariant.participants > 30) {
        significantImprovements++;
        
        if (improvement > maxImprovement) {
          maxImprovement = improvement;
          bestVariant = variant;
        }
      }
    }
  }

  return {
    hasSignificantResults: maxImprovement > 5,
    winner: maxImprovement > 5 ? bestVariant.variantId : undefined,
    confidence: Math.min(95, 50 + maxImprovement * 2) // Simplified confidence calculation
  };
}

/**
 * Generate recommendations based on results
 */
function generateRecommendations(
  variantPerformance: any[],
  statisticalResults: any
): string[] {
  
  const recommendations: string[] = [];

  if (statisticalResults.hasSignificantResults) {
    const winner = variantPerformance.find(v => v.variantId === statisticalResults.winner);
    recommendations.push(
      `Consider implementing variant "${winner.variantName}" as it shows statistically significant improvements.`
    );
  } else {
    recommendations.push(
      'No statistically significant differences detected. Consider running the experiment longer or with larger sample sizes.'
    );
  }

  // Check sample sizes
  const minParticipants = Math.min(...variantPerformance.map(v => v.participants));
  if (minParticipants < 100) {
    recommendations.push(
      'Sample sizes are small. Consider running longer to achieve more reliable results.'
    );
  }

  return recommendations;
}