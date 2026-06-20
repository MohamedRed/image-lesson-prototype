import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import { logger } from 'firebase-functions';

const db = getFirestore();

interface HealthOverviewRequest {}

interface HealthMetrics {
  steps: number;
  activeMinutes: number;
  sleepHours?: number;
  heartRateAvg?: number;
  caloriesBurned?: number;
  distanceKm?: number;
}

interface DaySummary extends HealthMetrics {
  date: string;
}

interface ProgramStep {
  id: string;
  programId: string;
  title: string;
  description: string;
  isCompleted: boolean;
  estimatedDuration?: number;
  category: 'exercise' | 'nutrition' | 'mindfulness' | 'sleep' | 'medical';
  completedAt?: string;
}

interface HealthInsight {
  id: string;
  userId: string;
  type: 'trend' | 'anomaly' | 'recommendation' | 'alert';
  category: 'activity' | 'nutrition' | 'sleep' | 'mental' | 'medical' | 'social';
  title: string;
  description: string;
  severity: 'low' | 'medium' | 'high' | 'critical';
  trigger: string;
  recommendedActions: string[];
  evidenceLinks: string[];
  isRead: boolean;
  isDismissed: boolean;
  createdAt: string;
}

interface LeaderboardPosition {
  rank: number;
  score: number;
  bucket: string;
  percentile: number;
  trend: 'up' | 'down' | 'stable';
}

interface HealthProfile {
  userId: string;
  demographics?: {
    age?: number;
    height?: number;
    biologicalSex?: 'male' | 'female' | 'other' | 'notSet';
    bloodType?: string;
  };
  goals: Array<{
    id: string;
    title: string;
    type: string;
    targetValue: number;
    currentValue: number;
    status: 'active' | 'paused' | 'completed' | 'archived';
  }>;
  measurementPreferences: {
    weightUnit: 'kg' | 'lbs';
    heightUnit: 'cm' | 'ft';
    temperatureUnit: 'celsius' | 'fahrenheit';
    distanceUnit: 'km' | 'miles';
  };
}

interface HealthOverviewResponse {
  profile: HealthProfile;
  todaySummary: DaySummary;
  weekSummary: HealthMetrics;
  monthSummary: HealthMetrics;
  activeProgramSteps: ProgramStep[];
  insights: HealthInsight[];
  leaderboardPosition?: LeaderboardPosition;
}

export const getHealthOverview = onCall<HealthOverviewRequest, HealthOverviewResponse>(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request: CallableRequest<HealthOverviewRequest>): Promise<HealthOverviewResponse> => {
    try {
      // Verify authentication
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const userId = request.auth.uid;
      logger.info(`Getting health overview for user: ${userId}`);

      // Get user profile
      const profileDoc = await db.collection('healthProfiles').doc(userId).get();
      
      let profile: HealthProfile;
      if (!profileDoc.exists) {
        // Create default profile
        profile = {
          userId,
          goals: [],
          measurementPreferences: {
            weightUnit: 'kg',
            heightUnit: 'cm',
            temperatureUnit: 'celsius',
            distanceUnit: 'km'
          }
        };
        
        // Save default profile
        await db.collection('healthProfiles').doc(userId).set({
          ...profile,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp()
        });
      } else {
        profile = profileDoc.data() as HealthProfile;
      }

      // Get today's metrics
      const today = new Date().toISOString().split('T')[0];
      const todayMetricsDoc = await db
        .collection('healthMetrics')
        .doc(userId)
        .collection('daily')
        .doc(today)
        .get();

      const todaySummary: DaySummary = todayMetricsDoc.exists ? 
        { date: today, ...todayMetricsDoc.data() } as DaySummary :
        {
          date: today,
          steps: 0,
          activeMinutes: 0,
          sleepHours: 0,
          heartRateAvg: 0,
          caloriesBurned: 0,
          distanceKm: 0
        };

      // Get week summary
      const weekAgo = new Date();
      weekAgo.setDate(weekAgo.getDate() - 7);
      const weekSummary = await calculatePeriodSummary(userId, weekAgo, new Date());

      // Get month summary
      const monthAgo = new Date();
      monthAgo.setMonth(monthAgo.getMonth() - 1);
      const monthSummary = await calculatePeriodSummary(userId, monthAgo, new Date());

      // Get active program steps
      const activeProgramSteps = await getActiveProgramSteps(userId);

      // Get recent insights
      const insights = await getRecentInsights(userId, 5);

      // Get leaderboard position (if user opted in)
      const leaderboardPosition = await getLeaderboardPosition(userId);

      const response: HealthOverviewResponse = {
        profile,
        todaySummary,
        weekSummary,
        monthSummary,
        activeProgramSteps,
        insights,
        leaderboardPosition
      };

      logger.info(`Successfully retrieved health overview for user: ${userId}`);
      return response;

    } catch (error) {
      logger.error('Error getting health overview:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to get health overview');
    }
  }
);

async function calculatePeriodSummary(
  userId: string, 
  startDate: Date, 
  endDate: Date
): Promise<HealthMetrics> {
  const startDateStr = startDate.toISOString().split('T')[0];
  const endDateStr = endDate.toISOString().split('T')[0];

  const metricsQuery = await db
    .collection('healthMetrics')
    .doc(userId)
    .collection('daily')
    .where('date', '>=', startDateStr)
    .where('date', '<=', endDateStr)
    .get();

  if (metricsQuery.empty) {
    return {
      steps: 0,
      activeMinutes: 0,
      sleepHours: 0,
      heartRateAvg: 0,
      caloriesBurned: 0,
      distanceKm: 0
    };
  }

  let totalSteps = 0;
  let totalActiveMinutes = 0;
  let totalSleepHours = 0;
  let totalHeartRate = 0;
  let totalCalories = 0;
  let totalDistance = 0;
  let heartRateCount = 0;
  let sleepCount = 0;

  metricsQuery.docs.forEach(doc => {
    const data = doc.data();
    totalSteps += data.steps || 0;
    totalActiveMinutes += data.activeMinutes || 0;
    totalCalories += data.caloriesBurned || 0;
    totalDistance += data.distanceKm || 0;
    
    if (data.sleepHours) {
      totalSleepHours += data.sleepHours;
      sleepCount++;
    }
    
    if (data.heartRateAvg) {
      totalHeartRate += data.heartRateAvg;
      heartRateCount++;
    }
  });

  return {
    steps: totalSteps,
    activeMinutes: totalActiveMinutes,
    sleepHours: sleepCount > 0 ? totalSleepHours / sleepCount : undefined,
    heartRateAvg: heartRateCount > 0 ? Math.round(totalHeartRate / heartRateCount) : undefined,
    caloriesBurned: totalCalories,
    distanceKm: Number(totalDistance.toFixed(2))
  };
}

async function getActiveProgramSteps(userId: string): Promise<ProgramStep[]> {
  // Get active programs for user
  const programsQuery = await db
    .collection('healthPrograms')
    .where('userId', '==', userId)
    .where('status', '==', 'active')
    .limit(3)
    .get();

  if (programsQuery.empty) {
    return [];
  }

  const steps: ProgramStep[] = [];
  
  for (const programDoc of programsQuery.docs) {
    const programData = programDoc.data();
    
    // Get today's incomplete steps for this program
    const stepsQuery = await db
      .collection('programSteps')
      .where('programId', '==', programDoc.id)
      .where('isCompleted', '==', false)
      .where('scheduledDate', '==', new Date().toISOString().split('T')[0])
      .limit(3)
      .get();

    stepsQuery.docs.forEach(stepDoc => {
      const stepData = stepDoc.data();
      steps.push({
        id: stepDoc.id,
        programId: programDoc.id,
        title: stepData.title,
        description: stepData.description,
        isCompleted: stepData.isCompleted,
        estimatedDuration: stepData.estimatedDuration,
        category: stepData.category,
        completedAt: stepData.completedAt
      });
    });
  }

  return steps.slice(0, 5); // Return max 5 steps
}

async function getRecentInsights(userId: string, limit: number): Promise<HealthInsight[]> {
  const insightsQuery = await db
    .collection('healthInsights')
    .where('userId', '==', userId)
    .where('isDismissed', '==', false)
    .orderBy('createdAt', 'desc')
    .limit(limit)
    .get();

  return insightsQuery.docs.map(doc => {
    const data = doc.data();
    return {
      id: doc.id,
      userId: data.userId,
      type: data.type,
      category: data.category,
      title: data.title,
      description: data.description,
      severity: data.severity,
      trigger: data.trigger,
      recommendedActions: data.recommendedActions || [],
      evidenceLinks: data.evidenceLinks || [],
      isRead: data.isRead || false,
      isDismissed: data.isDismissed || false,
      createdAt: data.createdAt.toDate().toISOString()
    };
  });
}

async function getLeaderboardPosition(userId: string): Promise<LeaderboardPosition | undefined> {
  try {
    // Check if user opted into leaderboards
    const preferencesDoc = await db.collection('userPreferences').doc(userId).get();
    
    if (!preferencesDoc.exists || !preferencesDoc.data()?.leaderboard?.participate) {
      return undefined;
    }

    // Get user's leaderboard entry
    const leaderboardDoc = await db
      .collection('leaderboards')
      .doc('global')
      .collection('entries')
      .doc(userId)
      .get();

    if (!leaderboardDoc.exists) {
      return undefined;
    }

    const data = leaderboardDoc.data()!;
    
    return {
      rank: data.rank,
      score: data.score,
      bucket: data.bucket,
      percentile: data.percentile,
      trend: data.trend || 'stable'
    };
    
  } catch (error) {
    logger.warn('Could not get leaderboard position:', error);
    return undefined;
  }
}