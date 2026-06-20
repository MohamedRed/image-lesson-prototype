import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';

const db = getFirestore();

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

interface GetInsightsRequest {
  category?: string;
  limit?: number;
}

// Get health insights
export const getInsights = onCall<GetInsightsRequest, HealthInsight[]>(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request: CallableRequest<GetInsightsRequest>): Promise<HealthInsight[]> => {
    try {
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const userId = request.auth.uid;
      const { category, limit = 50 } = request.data;

      let query = db
        .collection('healthInsights')
        .where('userId', '==', userId)
        .where('isDismissed', '==', false);

      if (category) {
        query = query.where('category', '==', category);
      }

      query = query.orderBy('createdAt', 'desc').limit(limit);

      const querySnapshot = await query.get();
      
      const insights: HealthInsight[] = querySnapshot.docs.map(doc => {
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
          createdAt: data.createdAt?.toDate?.().toISOString() || new Date().toISOString()
        };
      });

      return insights;

    } catch (error) {
      logger.error('Error getting insights:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to get insights');
    }
  }
);

// Mark insight as read
export const markInsightRead = onCall<{insightId: string}, void>(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request: CallableRequest<{insightId: string}>): Promise<void> => {
    try {
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const userId = request.auth.uid;
      const { insightId } = request.data;

      const insightDoc = await db.collection('healthInsights').doc(insightId).get();
      
      if (!insightDoc.exists || insightDoc.data()!.userId !== userId) {
        throw new HttpsError('not-found', 'Insight not found');
      }

      await insightDoc.ref.update({
        isRead: true,
        readAt: FieldValue.serverTimestamp()
      });

    } catch (error) {
      logger.error('Error marking insight as read:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to mark insight as read');
    }
  }
);

// Dismiss insight
export const dismissInsight = onCall<{insightId: string}, void>(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request: CallableRequest<{insightId: string}>): Promise<void> => {
    try {
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const userId = request.auth.uid;
      const { insightId } = request.data;

      const insightDoc = await db.collection('healthInsights').doc(insightId).get();
      
      if (!insightDoc.exists || insightDoc.data()!.userId !== userId) {
        throw new HttpsError('not-found', 'Insight not found');
      }

      await insightDoc.ref.update({
        isDismissed: true,
        dismissedAt: FieldValue.serverTimestamp()
      });

    } catch (error) {
      logger.error('Error dismissing insight:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to dismiss insight');
    }
  }
);

// Generate insights (background function)
export const generateInsights = onCall<{userId?: string}, {generated: number}>(
  {
    cors: true,
  },
  async (request: CallableRequest<{userId?: string}>): Promise<{generated: number}> => {
    try {
      const { userId } = request.data;
      let usersToProcess: string[] = [];

      if (userId) {
        usersToProcess = [userId];
      } else {
        // Get active users who haven't had insights generated recently
        const activeUsersQuery = await db
          .collection('healthProfiles')
          .where('lastInsightGeneration', '<', new Date(Date.now() - 24 * 60 * 60 * 1000)) // 24 hours ago
          .limit(100)
          .get();

        usersToProcess = activeUsersQuery.docs.map(doc => doc.id);
      }

      let generatedCount = 0;

      for (const uid of usersToProcess) {
        try {
          const insights = await generateUserInsights(uid);
          generatedCount += insights.length;
          
          // Update last insight generation timestamp
          await db.collection('healthProfiles').doc(uid).update({
            lastInsightGeneration: FieldValue.serverTimestamp()
          });
          
        } catch (error) {
          logger.warn(`Failed to generate insights for user ${uid}:`, error);
        }
      }

      logger.info(`Generated ${generatedCount} insights for ${usersToProcess.length} users`);
      return { generated: generatedCount };

    } catch (error) {
      logger.error('Error in generateInsights:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to generate insights');
    }
  }
);

// Generate insights for a specific user
async function generateUserInsights(userId: string): Promise<HealthInsight[]> {
  const insights: HealthInsight[] = [];

  try {
    // Get user's recent health data
    const recentMetrics = await getRecentHealthMetrics(userId);
    const userGoals = await getUserGoals(userId);

    // Generate step count insights
    const stepInsights = await generateStepInsights(userId, recentMetrics);
    insights.push(...stepInsights);

    // Generate sleep insights
    const sleepInsights = await generateSleepInsights(userId, recentMetrics);
    insights.push(...sleepInsights);

    // Generate goal progress insights
    const goalInsights = await generateGoalInsights(userId, userGoals, recentMetrics);
    insights.push(...goalInsights);

    // Save generated insights
    if (insights.length > 0) {
      const batch = db.batch();
      
      insights.forEach(insight => {
        const insightRef = db.collection('healthInsights').doc();
        batch.set(insightRef, {
          ...insight,
          id: insightRef.id,
          createdAt: FieldValue.serverTimestamp()
        });
      });

      await batch.commit();
    }

    return insights;

  } catch (error) {
    logger.error(`Error generating insights for user ${userId}:`, error);
    return [];
  }
}

// Get recent health metrics for analysis
async function getRecentHealthMetrics(userId: string): Promise<any[]> {
  const sevenDaysAgo = new Date();
  sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

  const metricsQuery = await db
    .collection('healthMetrics')
    .doc(userId)
    .collection('daily')
    .where('date', '>=', sevenDaysAgo.toISOString().split('T')[0])
    .orderBy('date', 'desc')
    .get();

  return metricsQuery.docs.map(doc => ({ id: doc.id, ...doc.data() }));
}

// Get user goals
async function getUserGoals(userId: string): Promise<any[]> {
  const goalsQuery = await db
    .collection('healthGoals')
    .where('userId', '==', userId)
    .where('status', '==', 'active')
    .get();

  return goalsQuery.docs.map(doc => ({ id: doc.id, ...doc.data() }));
}

// Generate step-related insights
async function generateStepInsights(userId: string, metrics: any[]): Promise<HealthInsight[]> {
  const insights: HealthInsight[] = [];

  if (metrics.length < 3) return insights;

  const recentSteps = metrics.slice(0, 7).map(m => m.steps || 0);
  const avgSteps = recentSteps.reduce((a, b) => a + b, 0) / recentSteps.length;

  // Detect significant increase in activity
  if (avgSteps > 8000 && recentSteps[0] > avgSteps * 1.2) {
    insights.push({
      id: '',
      userId,
      type: 'trend',
      category: 'activity',
      title: 'Great Activity Boost!',
      description: `You've been more active lately, averaging ${Math.round(avgSteps)} steps per day. Keep up the great work!`,
      severity: 'low',
      trigger: 'Step count increase detected',
      recommendedActions: [
        'Maintain this activity level',
        'Consider setting a higher daily step goal',
        'Try new walking routes to stay motivated'
      ],
      evidenceLinks: [],
      isRead: false,
      isDismissed: false,
      createdAt: new Date().toISOString()
    });
  }

  // Detect low activity pattern
  if (avgSteps < 5000 && recentSteps.every(steps => steps < 6000)) {
    insights.push({
      id: '',
      userId,
      type: 'recommendation',
      category: 'activity',
      title: 'Time to Get Moving',
      description: 'Your activity levels have been below recommended guidelines. Small increases can make a big difference!',
      severity: 'medium',
      trigger: 'Consistently low step count',
      recommendedActions: [
        'Start with a 10-minute daily walk',
        'Take the stairs when possible',
        'Set hourly movement reminders',
        'Find an activity buddy for motivation'
      ],
      evidenceLinks: [
        'https://www.cdc.gov/physicalactivity/basics/adults/index.htm'
      ],
      isRead: false,
      isDismissed: false,
      createdAt: new Date().toISOString()
    });
  }

  return insights;
}

// Generate sleep-related insights
async function generateSleepInsights(userId: string, metrics: any[]): Promise<HealthInsight[]> {
  const insights: HealthInsight[] = [];

  const recentSleep = metrics
    .filter(m => m.sleepHours)
    .slice(0, 7)
    .map(m => m.sleepHours);

  if (recentSleep.length < 3) return insights;

  const avgSleep = recentSleep.reduce((a, b) => a + b, 0) / recentSleep.length;

  // Detect insufficient sleep pattern
  if (avgSleep < 7 && recentSleep.filter(h => h < 7).length >= recentSleep.length * 0.7) {
    insights.push({
      id: '',
      userId,
      type: 'alert',
      category: 'sleep',
      title: 'Sleep Improvement Needed',
      description: `You're averaging ${avgSleep.toFixed(1)} hours of sleep per night, which is below the recommended 7-9 hours.`,
      severity: 'medium',
      trigger: 'Consistently insufficient sleep duration',
      recommendedActions: [
        'Set a consistent bedtime routine',
        'Avoid screens 1 hour before bed',
        'Keep your bedroom cool and dark',
        'Limit caffeine after 2 PM'
      ],
      evidenceLinks: [
        'https://www.sleepfoundation.org/how-sleep-works/why-do-we-need-sleep'
      ],
      isRead: false,
      isDismissed: false,
      createdAt: new Date().toISOString()
    });
  }

  return insights;
}

// Generate goal progress insights
async function generateGoalInsights(userId: string, goals: any[], metrics: any[]): Promise<HealthInsight[]> {
  const insights: HealthInsight[] = [];

  for (const goal of goals) {
    // Check if user is on track to meet their goal
    const progress = goal.currentValue / goal.targetValue;
    const timeRemaining = new Date(goal.targetDate).getTime() - Date.now();
    const daysRemaining = Math.max(0, Math.ceil(timeRemaining / (1000 * 60 * 60 * 24)));

    if (progress < 0.5 && daysRemaining < 30) {
      insights.push({
        id: '',
        userId,
        type: 'alert',
        category: 'activity',
        title: 'Goal Deadline Approaching',
        description: `Your "${goal.title}" goal is ${Math.round(progress * 100)}% complete with ${daysRemaining} days remaining.`,
        severity: 'high',
        trigger: 'Goal progress behind schedule',
        recommendedActions: [
          'Review and adjust your daily targets',
          'Consider breaking the goal into smaller steps',
          'Seek support from friends or professionals',
          'Reassess if the goal timeline is realistic'
        ],
        evidenceLinks: [],
        isRead: false,
        isDismissed: false,
        createdAt: new Date().toISOString()
      });
    }
  }

  return insights;
}