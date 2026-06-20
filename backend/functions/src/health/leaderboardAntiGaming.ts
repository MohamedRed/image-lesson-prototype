import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { Firestore, FieldValue, Timestamp } from '@google-cloud/firestore';
import { BigQuery } from '@google-cloud/bigquery';
import { logger } from 'firebase-functions';

const firestore = new Firestore();
const bigQuery = new BigQuery();

export interface SuspiciousActivity {
  userId: string;
  type: 'data_manipulation' | 'impossible_values' | 'rapid_changes' | 'pattern_gaming' | 'duplicate_submissions';
  description: string;
  severity: 'low' | 'medium' | 'high' | 'critical';
  detectionMethod: string;
  evidenceData: any;
  timestamp: Date;
  resolved: boolean;
  adminNotes?: string;
}

export interface UserTrustScore {
  userId: string;
  score: number; // 0-100, where 100 is fully trusted
  factors: {
    accountAge: number;
    consistentPatterns: number;
    deviceVerification: number;
    socialConnections: number;
    manualReviews: number;
  };
  flags: string[];
  lastUpdated: Date;
}

export interface LeaderboardValidation {
  userId: string;
  isValid: boolean;
  trustScore: number;
  restrictions: string[];
  validatedAt: Date;
}

/**
 * Real-time validation when health observations are created
 */
export const validateHealthObservation = onDocumentCreated(
  'users/{userId}/healthObservations/{observationId}',
  async (event) => {
    const observation = event.data?.data();
    const userId = event.params.userId;

    if (!observation) return;

    try {
      const violations = await detectDataViolations(userId, observation);
      
      if (violations.length > 0) {
        await recordSuspiciousActivity(userId, violations);
        await updateUserTrustScore(userId, violations);
      }
    } catch (error) {
      logger.error('Health observation validation failed:', error);
    }
  }
);

/**
 * Enhanced validation when health observations are updated
 */
export const validateHealthObservationUpdate = onDocumentUpdated(
  'users/{userId}/healthObservations/{observationId}',
  async (event) => {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();
    const userId = event.params.userId;

    if (!beforeData || !afterData) return;

    try {
      // Check for suspicious modifications
      const suspiciousChanges = await detectSuspiciousModifications(
        userId, 
        beforeData, 
        afterData
      );

      if (suspiciousChanges.length > 0) {
        await recordSuspiciousActivity(userId, suspiciousChanges);
        await updateUserTrustScore(userId, suspiciousChanges);
      }
    } catch (error) {
      logger.error('Health observation update validation failed:', error);
    }
  }
);

/**
 * Manual leaderboard validation endpoint for admins
 */
export const validateLeaderboardEntry = onCall<{
  userId: string;
  period: 'daily' | 'weekly' | 'monthly';
  date: string;
}, LeaderboardValidation>(async (request) => {
  const { userId, period, date } = request.data;

  // Verify admin permission
  if (!request.auth?.token?.admin) {
    throw new HttpsError('permission-denied', 'Admin access required');
  }

  try {
    const validation = await performLeaderboardValidation(userId, period, date);
    return validation;
  } catch (error) {
    logger.error('Leaderboard validation failed:', error);
    throw new HttpsError('internal', 'Validation failed');
  }
});

/**
 * Bulk validation for leaderboard integrity
 */
export const auditLeaderboard = onCall<{
  period: 'daily' | 'weekly' | 'monthly';
  date: string;
  topN?: number;
}, { validatedUsers: number; flaggedUsers: string[]; issues: string[] }>(async (request) => {
  const { period, date, topN = 100 } = request.data;

  if (!request.auth?.token?.admin) {
    throw new HttpsError('permission-denied', 'Admin access required');
  }

  try {
    const auditResults = await auditLeaderboardPeriod(period, date, topN);
    return auditResults;
  } catch (error) {
    logger.error('Leaderboard audit failed:', error);
    throw new HttpsError('internal', 'Audit failed');
  }
});

/**
 * Get user trust score and history
 */
export const getUserTrustScore = onCall<{
  userId: string;
}, UserTrustScore | null>(async (request) => {
  const { userId } = request.data;

  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  // Users can only see their own trust score, admins can see any
  if (request.auth.uid !== userId && !request.auth.token?.admin) {
    throw new HttpsError('permission-denied', 'Access denied');
  }

  try {
    const trustDoc = await firestore
      .collection('userTrustScores')
      .doc(userId)
      .get();

    return trustDoc.exists ? trustDoc.data() as UserTrustScore : null;
  } catch (error) {
    logger.error('Get trust score failed:', error);
    throw new HttpsError('internal', 'Failed to get trust score');
  }
});

/**
 * Detect various types of data violations in health observations
 */
async function detectDataViolations(userId: string, observation: any): Promise<SuspiciousActivity[]> {
  const violations: SuspiciousActivity[] = [];
  const now = new Date();

  // 1. Impossible physiological values
  const impossibleValues = detectImpossibleValues(observation);
  violations.push(...impossibleValues.map(violation => ({
    userId,
    type: 'impossible_values' as const,
    description: violation.description,
    severity: violation.severity,
    detectionMethod: 'physiological_limits',
    evidenceData: { observation, violation },
    timestamp: now,
    resolved: false
  })));

  // 2. Rapid value changes
  const rapidChanges = await detectRapidChanges(userId, observation);
  violations.push(...rapidChanges.map(violation => ({
    userId,
    type: 'rapid_changes' as const,
    description: violation.description,
    severity: violation.severity,
    detectionMethod: 'temporal_analysis',
    evidenceData: { observation, previousValues: violation.previousValues },
    timestamp: now,
    resolved: false
  })));

  // 3. Pattern gaming detection
  const patternGaming = await detectPatternGaming(userId, observation);
  violations.push(...patternGaming.map(violation => ({
    userId,
    type: 'pattern_gaming' as const,
    description: violation.description,
    severity: violation.severity,
    detectionMethod: 'statistical_analysis',
    evidenceData: { observation, patterns: violation.patterns },
    timestamp: now,
    resolved: false
  })));

  // 4. Duplicate detection
  const duplicates = await detectDuplicateSubmissions(userId, observation);
  violations.push(...duplicates.map(violation => ({
    userId,
    type: 'duplicate_submissions' as const,
    description: violation.description,
    severity: violation.severity,
    detectionMethod: 'duplicate_detection',
    evidenceData: { observation, duplicates: violation.duplicates },
    timestamp: now,
    resolved: false
  })));

  return violations;
}

/**
 * Detect impossible physiological values
 */
function detectImpossibleValues(observation: any): Array<{description: string, severity: 'low' | 'medium' | 'high' | 'critical'}> {
  const violations = [];

  switch (observation.type) {
    case 'steps':
      if (observation.value?.numeric > 100000) {
        violations.push({
          description: `Impossible steps count: ${observation.value.numeric}`,
          severity: 'high' as const
        });
      } else if (observation.value?.numeric > 50000) {
        violations.push({
          description: `Suspiciously high steps: ${observation.value.numeric}`,
          severity: 'medium' as const
        });
      }
      break;

    case 'heart_rate':
      const hr = observation.value?.numeric;
      if (hr > 220 || hr < 30) {
        violations.push({
          description: `Impossible heart rate: ${hr} bpm`,
          severity: 'critical' as const
        });
      } else if (hr > 200 || hr < 40) {
        violations.push({
          description: `Suspicious heart rate: ${hr} bpm`,
          severity: 'high' as const
        });
      }
      break;

    case 'sleep':
      const sleepHours = observation.value?.numeric / 3600; // Convert seconds to hours
      if (sleepHours > 18 || sleepHours < 0) {
        violations.push({
          description: `Impossible sleep duration: ${sleepHours.toFixed(1)} hours`,
          severity: 'high' as const
        });
      } else if (sleepHours > 14 || sleepHours < 2) {
        violations.push({
          description: `Suspicious sleep duration: ${sleepHours.toFixed(1)} hours`,
          severity: 'medium' as const
        });
      }
      break;

    case 'weight':
      const weight = observation.value?.numeric;
      if (weight > 300 || weight < 30) {
        violations.push({
          description: `Suspicious weight: ${weight} kg`,
          severity: 'medium' as const
        });
      }
      break;

    case 'calories':
      const calories = observation.value?.numeric;
      if (calories > 10000 || calories < 0) {
        violations.push({
          description: `Impossible calorie burn: ${calories}`,
          severity: 'high' as const
        });
      }
      break;
  }

  return violations;
}

/**
 * Detect rapid, unrealistic changes in health metrics
 */
async function detectRapidChanges(userId: string, observation: any): Promise<Array<{
  description: string, 
  severity: 'low' | 'medium' | 'high' | 'critical',
  previousValues: any[]
}>> {
  const violations = [];
  
  // Get recent observations of the same type
  const recentDocs = await firestore
    .collection('users')
    .doc(userId)
    .collection('healthObservations')
    .where('type', '==', observation.type)
    .where('effectiveDateTime', '>', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)) // Last 7 days
    .orderBy('effectiveDateTime', 'desc')
    .limit(10)
    .get();

  const recentValues = recentDocs.docs.map(doc => ({
    value: doc.data().value?.numeric,
    date: doc.data().effectiveDateTime.toDate()
  }));

  if (recentValues.length < 2) return violations;

  const currentValue = observation.value?.numeric;
  const avgRecentValue = recentValues.reduce((sum, item) => sum + (item.value || 0), 0) / recentValues.length;

  switch (observation.type) {
    case 'weight':
      // Weight changes > 5kg in a day are suspicious
      const latestWeight = recentValues[0]?.value;
      if (latestWeight && Math.abs(currentValue - latestWeight) > 5) {
        violations.push({
          description: `Rapid weight change: ${Math.abs(currentValue - latestWeight).toFixed(1)}kg in one day`,
          severity: 'high' as const,
          previousValues: recentValues
        });
      }
      break;

    case 'steps':
      // Sudden jump from low activity to extreme activity
      if (avgRecentValue < 5000 && currentValue > 25000) {
        violations.push({
          description: `Sudden activity spike: from avg ${Math.round(avgRecentValue)} to ${currentValue} steps`,
          severity: 'medium' as const,
          previousValues: recentValues
        });
      }
      break;

    case 'heart_rate':
      // Heart rate changes > 40 bpm from recent average are suspicious
      if (Math.abs(currentValue - avgRecentValue) > 40) {
        violations.push({
          description: `Rapid heart rate change: ${Math.abs(currentValue - avgRecentValue).toFixed(0)} bpm from average`,
          severity: 'medium' as const,
          previousValues: recentValues
        });
      }
      break;
  }

  return violations;
}

/**
 * Detect gaming patterns using statistical analysis
 */
async function detectPatternGaming(userId: string, observation: any): Promise<Array<{
  description: string,
  severity: 'low' | 'medium' | 'high' | 'critical',
  patterns: any
}>> {
  const violations = [];

  // Get user's historical data for pattern analysis
  const query = `
    SELECT type, value_numeric, DATE(effectiveDateTime) as date
    FROM \`health_analytics.health_observations\`
    WHERE userId = @userId 
    AND type = @type
    AND effectiveDateTime >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    ORDER BY effectiveDateTime DESC
  `;

  try {
    const [rows] = await bigQuery.query({
      query,
      params: { 
        userId: userId,
        type: observation.type
      }
    });

    if (rows.length < 10) return violations; // Need sufficient data for pattern analysis

    const values = rows.map((row: any) => row.value_numeric).filter((v: any) => v != null);
    
    // Statistical analysis
    const mean = values.reduce((sum: number, val: number) => sum + val, 0) / values.length;
    const variance = values.reduce((sum: number, val: number) => sum + Math.pow(val - mean, 2), 0) / values.length;
    const stdDev = Math.sqrt(variance);

    // Check for suspiciously consistent patterns
    if (stdDev < mean * 0.05 && values.length > 20) {
      violations.push({
        description: `Suspiciously consistent values (low variance: ${stdDev.toFixed(2)})`,
        severity: 'medium' as const,
        patterns: { mean, stdDev, variance, sampleSize: values.length }
      });
    }

    // Check for round number bias
    const roundNumbers = values.filter((v: number) => v % 100 === 0 || v % 1000 === 0).length;
    const roundNumberRatio = roundNumbers / values.length;
    
    if (roundNumberRatio > 0.3 && observation.type === 'steps') {
      violations.push({
        description: `High frequency of round numbers: ${(roundNumberRatio * 100).toFixed(1)}%`,
        severity: 'low' as const,
        patterns: { roundNumbers, total: values.length, ratio: roundNumberRatio }
      });
    }

    // Check for impossible consistency in steps
    if (observation.type === 'steps') {
      const dailySteps = rows.reduce((acc: any, row: any) => {
        const date = row.date;
        if (!acc[date]) acc[date] = 0;
        acc[date] += row.value_numeric;
        return acc;
      }, {});

      const dailyValues = Object.values(dailySteps) as number[];
      const dailyMean = dailyValues.reduce((sum, val) => sum + val, 0) / dailyValues.length;
      const dailyStdDev = Math.sqrt(
        dailyValues.reduce((sum, val) => sum + Math.pow(val - dailyMean, 2), 0) / dailyValues.length
      );

      if (dailyStdDev < dailyMean * 0.1 && dailyValues.length > 10) {
        violations.push({
          description: `Suspiciously consistent daily step counts (CV: ${(dailyStdDev/dailyMean * 100).toFixed(1)}%)`,
          severity: 'medium' as const,
          patterns: { dailyMean, dailyStdDev, coefficientOfVariation: dailyStdDev/dailyMean }
        });
      }
    }

  } catch (error) {
    logger.warn('Pattern gaming detection failed:', error);
  }

  return violations;
}

/**
 * Detect duplicate or near-duplicate submissions
 */
async function detectDuplicateSubmissions(userId: string, observation: any): Promise<Array<{
  description: string,
  severity: 'low' | 'medium' | 'high' | 'critical',
  duplicates: any[]
}>> {
  const violations = [];
  
  // Look for exact duplicates in the last hour
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
  
  const duplicatesQuery = await firestore
    .collection('users')
    .doc(userId)
    .collection('healthObservations')
    .where('type', '==', observation.type)
    .where('effectiveDateTime', '>', oneHourAgo)
    .get();

  const duplicates = duplicatesQuery.docs
    .map(doc => doc.data())
    .filter(obs => 
      obs.value?.numeric === observation.value?.numeric &&
      Math.abs(obs.effectiveDateTime.toDate().getTime() - observation.effectiveDateTime.getTime()) < 60000 // Within 1 minute
    );

  if (duplicates.length > 0) {
    violations.push({
      description: `${duplicates.length} near-duplicate submissions detected`,
      severity: 'medium' as const,
      duplicates
    });
  }

  return violations;
}

/**
 * Detect suspicious modifications to existing observations
 */
async function detectSuspiciousModifications(userId: string, beforeData: any, afterData: any): Promise<SuspiciousActivity[]> {
  const violations: SuspiciousActivity[] = [];
  const now = new Date();

  // Check if critical fields were modified
  if (beforeData.value?.numeric !== afterData.value?.numeric) {
    const change = Math.abs(afterData.value.numeric - beforeData.value.numeric);
    const changePercent = change / beforeData.value.numeric * 100;

    if (changePercent > 50) {
      violations.push({
        userId,
        type: 'data_manipulation',
        description: `Large value modification: ${beforeData.value.numeric} → ${afterData.value.numeric} (${changePercent.toFixed(1)}% change)`,
        severity: 'high',
        detectionMethod: 'modification_tracking',
        evidenceData: { before: beforeData, after: afterData, changePercent },
        timestamp: now,
        resolved: false
      });
    }
  }

  // Check for timestamp manipulation
  const timeDiff = Math.abs(afterData.effectiveDateTime.toDate().getTime() - beforeData.effectiveDateTime.toDate().getTime());
  if (timeDiff > 24 * 60 * 60 * 1000) { // More than 24 hours
    violations.push({
      userId,
      type: 'data_manipulation',
      description: `Significant timestamp modification: ${timeDiff / (60 * 60 * 1000)} hours difference`,
      severity: 'medium',
      detectionMethod: 'timestamp_tracking',
      evidenceData: { before: beforeData, after: afterData, timeDiff },
      timestamp: now,
      resolved: false
    });
  }

  return violations;
}

/**
 * Record suspicious activity in the database
 */
async function recordSuspiciousActivity(userId: string, violations: SuspiciousActivity[]): Promise<void> {
  if (violations.length === 0) return;

  const batch = firestore.batch();

  for (const violation of violations) {
    const activityRef = firestore.collection('suspiciousActivities').doc();
    batch.set(activityRef, violation);
  }

  await batch.commit();
  logger.warn(`Recorded ${violations.length} suspicious activities for user ${userId}`);
}

/**
 * Update user trust score based on violations
 */
async function updateUserTrustScore(userId: string, violations: SuspiciousActivity[]): Promise<void> {
  const trustRef = firestore.collection('userTrustScores').doc(userId);
  
  await firestore.runTransaction(async (transaction) => {
    const trustDoc = await transaction.get(trustRef);
    let trustScore: UserTrustScore;

    if (trustDoc.exists) {
      trustScore = trustDoc.data() as UserTrustScore;
    } else {
      // Initialize trust score for new user
      trustScore = {
        userId,
        score: 100,
        factors: {
          accountAge: 80,
          consistentPatterns: 100,
          deviceVerification: 80,
          socialConnections: 50,
          manualReviews: 100
        },
        flags: [],
        lastUpdated: new Date()
      };
    }

    // Reduce trust score based on violation severity
    let scoreReduction = 0;
    const newFlags = [...trustScore.flags];

    for (const violation of violations) {
      switch (violation.severity) {
        case 'critical':
          scoreReduction += 25;
          newFlags.push(`critical_${violation.type}`);
          break;
        case 'high':
          scoreReduction += 15;
          newFlags.push(`high_${violation.type}`);
          break;
        case 'medium':
          scoreReduction += 8;
          break;
        case 'low':
          scoreReduction += 3;
          break;
      }
    }

    trustScore.score = Math.max(0, trustScore.score - scoreReduction);
    trustScore.flags = [...new Set(newFlags)]; // Remove duplicates
    trustScore.lastUpdated = new Date();

    // Update specific factor scores
    if (violations.some(v => v.type === 'data_manipulation')) {
      trustScore.factors.consistentPatterns = Math.max(0, trustScore.factors.consistentPatterns - 20);
    }

    transaction.set(trustRef, trustScore);
  });
}

/**
 * Perform comprehensive leaderboard validation
 */
async function performLeaderboardValidation(userId: string, period: string, date: string): Promise<LeaderboardValidation> {
  // Get user's trust score
  const trustDoc = await firestore.collection('userTrustScores').doc(userId).get();
  const trustScore = trustDoc.exists ? (trustDoc.data() as UserTrustScore) : null;

  const validation: LeaderboardValidation = {
    userId,
    isValid: true,
    trustScore: trustScore?.score || 50,
    restrictions: [],
    validatedAt: new Date()
  };

  // Apply restrictions based on trust score
  if (!trustScore || trustScore.score < 30) {
    validation.isValid = false;
    validation.restrictions.push('low_trust_score');
  }

  if (trustScore && trustScore.flags.length > 0) {
    validation.restrictions.push(...trustScore.flags);
  }

  // Check for recent suspicious activities
  const recentActivities = await firestore
    .collection('suspiciousActivities')
    .where('userId', '==', userId)
    .where('timestamp', '>', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000))
    .where('resolved', '==', false)
    .get();

  if (!recentActivities.empty) {
    validation.restrictions.push('unresolved_violations');
    
    const criticalViolations = recentActivities.docs.filter(doc => 
      doc.data().severity === 'critical'
    );
    
    if (criticalViolations.length > 0) {
      validation.isValid = false;
    }
  }

  return validation;
}

/**
 * Audit an entire leaderboard period
 */
async function auditLeaderboardPeriod(period: string, date: string, topN: number): Promise<{
  validatedUsers: number;
  flaggedUsers: string[];
  issues: string[];
}> {
  const results = {
    validatedUsers: 0,
    flaggedUsers: [] as string[],
    issues: [] as string[]
  };

  // Get leaderboard entries
  const leaderboardDoc = await firestore
    .collection('leaderboards')
    .doc(`${period}_${date}`)
    .get();

  if (!leaderboardDoc.exists) {
    results.issues.push('Leaderboard not found');
    return results;
  }

  const leaderboard = leaderboardDoc.data();
  const topEntries = leaderboard?.entries?.slice(0, topN) || [];

  for (const entry of topEntries) {
    try {
      const validation = await performLeaderboardValidation(entry.userId, period, date);
      
      if (validation.isValid) {
        results.validatedUsers++;
      } else {
        results.flaggedUsers.push(entry.userId);
        results.issues.push(
          `User ${entry.userId}: ${validation.restrictions.join(', ')}`
        );
      }
    } catch (error) {
      results.issues.push(`Validation failed for user ${entry.userId}: ${error}`);
    }
  }

  return results;
}