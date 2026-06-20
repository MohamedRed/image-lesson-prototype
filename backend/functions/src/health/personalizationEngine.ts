import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { Firestore, FieldValue, Timestamp } from '@google-cloud/firestore';
import { BigQuery } from '@google-cloud/bigquery';
import { VertexAI } from '@google-cloud/vertexai';
import { logger } from 'firebase-functions';

const firestore = new Firestore();
const bigQuery = new BigQuery();
const vertexAI = new VertexAI({
  project: process.env.GOOGLE_CLOUD_PROJECT!,
  location: 'us-central1'
});

export interface PersonalizationProfile {
  userId: string;
  preferences: {
    workoutTypes: string[];
    workoutIntensity: 'low' | 'moderate' | 'high';
    preferredTimes: {
      workout?: string;
      sleep?: string;
      meals?: string[];
    };
    motivationStyle: 'achievement' | 'social' | 'self_improvement' | 'competition';
    communicationFrequency: 'minimal' | 'moderate' | 'frequent';
    contentTypes: string[];
  };
  behaviorPatterns: {
    engagementScore: number; // 0-100
    consistencyScore: number; // 0-100
    responsiveness: number; // 0-100
    preferredInteractionTimes: number[]; // hours of day
    typicalSessionDuration: number; // minutes
    dropoffIndicators: string[];
  };
  adaptations: {
    successfulInterventions: Array<{
      type: string;
      context: string;
      outcome: string;
      effectiveness: number; // 0-100
    }>;
    failedInterventions: Array<{
      type: string;
      context: string;
      reason: string;
    }>;
    learnings: Array<{
      insight: string;
      confidence: number; // 0-100
      evidence: string[];
    }>;
  };
  segments: string[];
  riskFactors: string[];
  lastUpdated: Date;
}

export interface RecommendationEngine {
  userId: string;
  recommendations: Array<{
    id: string;
    type: 'exercise' | 'nutrition' | 'sleep' | 'mindfulness' | 'medical' | 'behavioral';
    priority: 'low' | 'medium' | 'high' | 'urgent';
    title: string;
    description: string;
    actionItems: string[];
    reasoning: string;
    personalizedFor: string[];
    confidence: number; // 0-100
    expectedOutcome: string;
    timeframe: string;
    metrics: string[];
    createdAt: Date;
    expiresAt?: Date;
    category: string;
  }>;
  nextReviewDate: Date;
  lastGeneratedAt: Date;
}

export interface FeedbackLoop {
  userId: string;
  recommendationId: string;
  action: 'viewed' | 'started' | 'completed' | 'dismissed' | 'postponed';
  outcome?: {
    metric: string;
    before: number;
    after: number;
    improvement: number;
    timeframe: number; // days
  };
  feedback?: {
    rating: number; // 1-5
    helpful: boolean;
    comments?: string;
    difficulty?: 'too_easy' | 'just_right' | 'too_hard';
  };
  context: {
    timeOfDay: number;
    dayOfWeek: number;
    userState: string; // energy level, mood, etc.
    environmentalFactors: string[];
  };
  timestamp: Date;
}

export interface MLPersonalizationModel {
  userId: string;
  modelVersion: string;
  features: {
    demographic: any;
    behavioral: any;
    health: any;
    temporal: any;
    contextual: any;
  };
  predictions: {
    engagementProbability: number;
    successProbability: number;
    optimalTiming: number[];
    preferredContentTypes: string[];
    riskScore: number;
  };
  confidence: number;
  lastTrainingDate: Date;
  performanceMetrics: {
    accuracy: number;
    precision: number;
    recall: number;
    f1Score: number;
  };
}

/**
 * Generate personalized recommendations for a user
 */
export const generatePersonalizedRecommendations = onCall<{
  userId?: string;
  forceRefresh?: boolean;
  recommendationType?: string[];
}, { recommendations: any[]; confidence: number }>(async (request) => {
  const { userId: targetUserId, forceRefresh = false, recommendationType } = request.data;
  
  const userId = targetUserId || request.auth?.uid;
  if (!userId) {
    throw new HttpsError('unauthenticated', 'User ID required');
  }

  // Only allow self-recommendations unless admin
  if (targetUserId && targetUserId !== request.auth?.uid && !request.auth?.token?.admin) {
    throw new HttpsError('permission-denied', 'Permission denied');
  }

  try {
    // Check if we have recent recommendations and don't need to refresh
    if (!forceRefresh) {
      const existingEngine = await firestore
        .collection('recommendationEngines')
        .doc(userId)
        .get();

      if (existingEngine.exists) {
        const engine = existingEngine.data() as RecommendationEngine;
        const hoursSinceGeneration = (Date.now() - engine.lastGeneratedAt.getTime()) / (1000 * 60 * 60);
        
        if (hoursSinceGeneration < 12) { // Use cached recommendations if less than 12 hours old
          const filteredRecommendations = recommendationType 
            ? engine.recommendations.filter(r => recommendationType.includes(r.type))
            : engine.recommendations;
            
          return {
            recommendations: filteredRecommendations.slice(0, 10), // Top 10
            confidence: 85 // Cached recommendations have good confidence
          };
        }
      }
    }

    // Generate fresh recommendations
    const recommendations = await generateFreshRecommendations(userId, recommendationType);
    
    return {
      recommendations: recommendations.recommendations.slice(0, 10),
      confidence: recommendations.confidence
    };
  } catch (error) {
    logger.error('Generate personalized recommendations failed:', error);
    throw new HttpsError('internal', 'Failed to generate recommendations');
  }
});

/**
 * Update personalization profile based on user behavior
 */
export const updatePersonalizationProfile = onCall<{
  behaviorData: any;
  context?: any;
}, { success: boolean; profileUpdated: boolean }>(async (request) => {
  const { behaviorData, context } = request.data;

  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  try {
    const profileUpdated = await updateUserPersonalizationProfile(
      request.auth.uid,
      behaviorData,
      context
    );

    return {
      success: true,
      profileUpdated
    };
  } catch (error) {
    logger.error('Update personalization profile failed:', error);
    throw new HttpsError('internal', 'Failed to update profile');
  }
});

/**
 * Record feedback on recommendations
 */
export const recordRecommendationFeedback = onCall<{
  recommendationId: string;
  action: string;
  outcome?: any;
  feedback?: any;
  context?: any;
}, { success: boolean; learningsUpdated: boolean }>(async (request) => {
  const { recommendationId, action, outcome, feedback, context } = request.data;

  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  try {
    const learningsUpdated = await processFeedbackLoop({
      userId: request.auth.uid,
      recommendationId,
      action: action as any,
      outcome,
      feedback,
      context: {
        timeOfDay: new Date().getHours(),
        dayOfWeek: new Date().getDay(),
        userState: context?.userState || 'unknown',
        environmentalFactors: context?.environmentalFactors || []
      },
      timestamp: new Date()
    });

    return {
      success: true,
      learningsUpdated
    };
  } catch (error) {
    logger.error('Record recommendation feedback failed:', error);
    throw new HttpsError('internal', 'Failed to record feedback');
  }
});

/**
 * Get user's personalization insights
 */
export const getPersonalizationInsights = onCall<{}, { 
  profile: PersonalizationProfile;
  recentLearnings: any[];
  performanceMetrics: any;
}>(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  try {
    // Get personalization profile
    const profileDoc = await firestore
      .collection('personalizationProfiles')
      .doc(request.auth.uid)
      .get();

    const profile = profileDoc.exists 
      ? profileDoc.data() as PersonalizationProfile
      : await createInitialPersonalizationProfile(request.auth.uid);

    // Get recent learnings
    const recentLearnings = profile.adaptations.learnings
      .sort((a, b) => b.confidence - a.confidence)
      .slice(0, 5);

    // Get performance metrics
    const performanceMetrics = await calculatePersonalizationPerformance(request.auth.uid);

    return {
      profile,
      recentLearnings,
      performanceMetrics
    };
  } catch (error) {
    logger.error('Get personalization insights failed:', error);
    throw new HttpsError('internal', 'Failed to get insights');
  }
});

/**
 * Auto-update personalization when health data changes
 */
export const autoUpdatePersonalization = onDocumentCreated(
  'users/{userId}/healthObservations/{observationId}',
  async (event) => {
    const observation = event.data?.data();
    const userId = event.params.userId;

    if (!observation) return;

    try {
      // Update behavior patterns based on new health data
      await updateBehaviorPatternsFromHealthData(userId, observation);
      
      // Check if we need to regenerate recommendations
      const shouldRegenerate = await shouldRegenerateRecommendations(userId, observation);
      
      if (shouldRegenerate) {
        await generateFreshRecommendations(userId);
        logger.info(`Regenerated recommendations for user ${userId} due to health data change`);
      }
    } catch (error) {
      logger.error('Auto-update personalization failed:', error);
    }
  }
);

/**
 * Generate fresh personalized recommendations
 */
async function generateFreshRecommendations(
  userId: string,
  recommendationType?: string[]
): Promise<{ recommendations: any[]; confidence: number }> {
  
  // Get user's personalization profile
  let profile = await getOrCreatePersonalizationProfile(userId);
  
  // Get user's health data and context
  const userContext = await buildUserContext(userId);
  
  // Get ML predictions
  const mlPredictions = await getMLPersonalizationPredictions(userId, userContext);
  
  // Generate recommendations using multiple strategies
  const recommendations = [];
  
  // 1. Evidence-based recommendations
  const evidenceBasedRecs = await generateEvidenceBasedRecommendations(userContext, profile);
  recommendations.push(...evidenceBasedRecs);
  
  // 2. Behavior-driven recommendations  
  const behaviorDrivenRecs = await generateBehaviorDrivenRecommendations(userContext, profile);
  recommendations.push(...behaviorDrivenRecs);
  
  // 3. AI-generated recommendations
  const aiGeneratedRecs = await generateAIRecommendations(userContext, profile, mlPredictions);
  recommendations.push(...aiGeneratedRecs);
  
  // 4. Temporal recommendations (time-sensitive)
  const temporalRecs = await generateTemporalRecommendations(userContext, profile);
  recommendations.push(...temporalRecs);

  // Filter by type if specified
  let filteredRecommendations = recommendationType
    ? recommendations.filter(r => recommendationType.includes(r.type))
    : recommendations;

  // Rank and personalize recommendations
  const rankedRecommendations = await rankRecommendations(
    filteredRecommendations,
    profile,
    mlPredictions
  );

  // Save to recommendation engine
  const engine: RecommendationEngine = {
    userId,
    recommendations: rankedRecommendations,
    nextReviewDate: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours
    lastGeneratedAt: new Date()
  };

  await firestore.collection('recommendationEngines').doc(userId).set(engine);

  const confidence = calculateRecommendationConfidence(rankedRecommendations, profile, mlPredictions);
  
  return {
    recommendations: rankedRecommendations,
    confidence
  };
}

/**
 * Get or create personalization profile
 */
async function getOrCreatePersonalizationProfile(userId: string): Promise<PersonalizationProfile> {
  const profileDoc = await firestore.collection('personalizationProfiles').doc(userId).get();
  
  if (profileDoc.exists) {
    return profileDoc.data() as PersonalizationProfile;
  }
  
  return await createInitialPersonalizationProfile(userId);
}

/**
 * Create initial personalization profile
 */
async function createInitialPersonalizationProfile(userId: string): Promise<PersonalizationProfile> {
  // Get user data for initial profile
  const userDoc = await firestore.collection('users').doc(userId).get();
  const userData = userDoc.data() || {};

  const profile: PersonalizationProfile = {
    userId,
    preferences: {
      workoutTypes: userData.preferences?.workoutTypes || ['walking', 'general'],
      workoutIntensity: userData.preferences?.workoutIntensity || 'moderate',
      preferredTimes: userData.preferences?.preferredTimes || {},
      motivationStyle: userData.preferences?.motivationStyle || 'self_improvement',
      communicationFrequency: userData.preferences?.communicationFrequency || 'moderate',
      contentTypes: userData.preferences?.contentTypes || ['tips', 'challenges']
    },
    behaviorPatterns: {
      engagementScore: 50, // Start neutral
      consistencyScore: 50,
      responsiveness: 50,
      preferredInteractionTimes: [9, 12, 18], // Default: morning, noon, evening
      typicalSessionDuration: 5, // 5 minutes default
      dropoffIndicators: []
    },
    adaptations: {
      successfulInterventions: [],
      failedInterventions: [],
      learnings: []
    },
    segments: ['new_user'],
    riskFactors: [],
    lastUpdated: new Date()
  };

  await firestore.collection('personalizationProfiles').doc(userId).set(profile);
  return profile;
}

/**
 * Build comprehensive user context
 */
async function buildUserContext(userId: string): Promise<any> {
  // Get user profile
  const userDoc = await firestore.collection('users').doc(userId).get();
  const userData = userDoc.data() || {};

  // Get recent health data (last 30 days)
  const healthDataSnapshot = await firestore
    .collection('users')
    .doc(userId)
    .collection('healthObservations')
    .where('effectiveDateTime', '>=', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000))
    .orderBy('effectiveDateTime', 'desc')
    .limit(100)
    .get();

  const healthData = healthDataSnapshot.docs.map(doc => doc.data());

  // Get current programs
  const programsSnapshot = await firestore
    .collection('users')
    .doc(userId)
    .collection('healthPrograms')
    .where('status', '==', 'active')
    .get();

  const activePrograms = programsSnapshot.docs.map(doc => doc.data());

  // Get recent feedback
  const feedbackSnapshot = await firestore
    .collection('feedbackLoops')
    .where('userId', '==', userId)
    .orderBy('timestamp', 'desc')
    .limit(20)
    .get();

  const recentFeedback = feedbackSnapshot.docs.map(doc => doc.data());

  return {
    profile: userData.profile || {},
    health: userData.health || {},
    preferences: userData.preferences || {},
    healthData,
    activePrograms,
    recentFeedback,
    demographics: {
      age: userData.profile?.age,
      gender: userData.profile?.gender,
      location: userData.profile?.location
    },
    activity: {
      lastActiveAt: userData.lastActiveAt,
      totalSessions: userData.stats?.totalSessions || 0,
      averageSessionDuration: userData.stats?.averageSessionDuration || 0
    }
  };
}

/**
 * Get ML personalization predictions
 */
async function getMLPersonalizationPredictions(userId: string, userContext: any): Promise<any> {
  try {
    // In a real implementation, this would call a trained ML model
    // For now, return heuristic-based predictions
    
    const avgEngagement = userContext.recentFeedback
      .filter((f: any) => f.feedback?.rating)
      .reduce((sum: number, f: any) => sum + f.feedback.rating, 0) / 
      Math.max(1, userContext.recentFeedback.length);

    const engagementProbability = Math.min(100, Math.max(20, avgEngagement * 20));
    
    // Analyze health data patterns
    const recentSteps = userContext.healthData
      .filter((h: any) => h.type === 'steps')
      .slice(0, 7);
    
    const stepConsistency = recentSteps.length >= 5 ? 80 : 50;
    
    const predictions = {
      engagementProbability,
      successProbability: (engagementProbability + stepConsistency) / 2,
      optimalTiming: [9, 18], // Morning and evening based on engagement patterns
      preferredContentTypes: ['tips', 'challenges', 'progress_updates'],
      riskScore: userContext.health.riskFactors?.length * 20 || 10
    };

    return predictions;
  } catch (error) {
    logger.warn('ML predictions failed, using defaults:', error);
    return {
      engagementProbability: 50,
      successProbability: 50,
      optimalTiming: [9, 18],
      preferredContentTypes: ['tips'],
      riskScore: 20
    };
  }
}

/**
 * Generate evidence-based recommendations
 */
async function generateEvidenceBasedRecommendations(
  userContext: any, 
  profile: PersonalizationProfile
): Promise<any[]> {
  
  const recommendations = [];
  
  // Analyze recent health data for evidence-based recommendations
  const recentSteps = userContext.healthData
    .filter((h: any) => h.type === 'steps')
    .slice(0, 7);
  
  if (recentSteps.length > 0) {
    const avgSteps = recentSteps.reduce((sum: any, h: any) => sum + (h.value?.numeric || 0), 0) / recentSteps.length;
    
    if (avgSteps < 5000) {
      recommendations.push({
        id: `evidence_${Date.now()}_1`,
        type: 'exercise',
        priority: 'high',
        title: 'Increase Daily Walking',
        description: 'Your recent activity levels are below recommended levels. Let\'s work on increasing your daily steps.',
        actionItems: [
          'Take a 10-minute walk after meals',
          'Use stairs instead of elevators',
          'Set hourly walking reminders'
        ],
        reasoning: `Your average daily steps (${Math.round(avgSteps)}) are below the recommended 7,500 steps for health benefits.`,
        personalizedFor: ['low_activity_pattern'],
        confidence: 85,
        expectedOutcome: 'Improved cardiovascular health and energy levels',
        timeframe: '2-3 weeks',
        metrics: ['steps', 'active_minutes'],
        createdAt: new Date(),
        category: 'physical_activity'
      });
    }
  }

  // Sleep recommendations
  const recentSleep = userContext.healthData
    .filter((h: any) => h.type === 'sleep')
    .slice(0, 7);
  
  if (recentSleep.length > 0) {
    const avgSleepHours = recentSleep.reduce((sum: any, h: any) => sum + ((h.value?.numeric || 0) / 3600), 0) / recentSleep.length;
    
    if (avgSleepHours < 7) {
      recommendations.push({
        id: `evidence_${Date.now()}_2`,
        type: 'sleep',
        priority: 'high',
        title: 'Optimize Sleep Duration',
        description: 'Your sleep duration is below the recommended 7-9 hours. Better sleep will improve your overall health.',
        actionItems: [
          'Set a consistent bedtime routine',
          'Avoid screens 1 hour before bed',
          'Keep bedroom temperature cool (65-68°F)'
        ],
        reasoning: `Your average sleep duration (${avgSleepHours.toFixed(1)} hours) is below recommended levels.`,
        personalizedFor: ['sleep_optimization'],
        confidence: 90,
        expectedOutcome: 'Better energy, mood, and cognitive function',
        timeframe: '1-2 weeks',
        metrics: ['sleep_duration', 'sleep_quality'],
        createdAt: new Date(),
        category: 'sleep_health'
      });
    }
  }

  return recommendations;
}

/**
 * Generate behavior-driven recommendations
 */
async function generateBehaviorDrivenRecommendations(
  userContext: any,
  profile: PersonalizationProfile
): Promise<any[]> {
  
  const recommendations = [];

  // Analyze successful interventions
  const successfulInterventions = profile.adaptations.successfulInterventions;
  
  if (successfulInterventions.length > 0) {
    // Find most effective intervention type
    const interventionEffectiveness = successfulInterventions.reduce((acc: any, intervention) => {
      if (!acc[intervention.type]) {
        acc[intervention.type] = { count: 0, totalEffectiveness: 0 };
      }
      acc[intervention.type].count++;
      acc[intervention.type].totalEffectiveness += intervention.effectiveness;
      return acc;
    }, {});

    const bestIntervention = Object.entries(interventionEffectiveness)
      .map(([type, data]: [string, any]) => ({
        type,
        avgEffectiveness: data.totalEffectiveness / data.count,
        count: data.count
      }))
      .sort((a, b) => b.avgEffectiveness - a.avgEffectiveness)[0];

    if (bestIntervention && bestIntervention.avgEffectiveness > 70) {
      recommendations.push({
        id: `behavior_${Date.now()}_1`,
        type: bestIntervention.type,
        priority: 'medium',
        title: `More ${bestIntervention.type.replace('_', ' ').toUpperCase()} Activities`,
        description: `You've had great success with ${bestIntervention.type} activities. Let's continue building on this strength.`,
        actionItems: [
          `Continue your ${bestIntervention.type} routine`,
          'Try slight variations to maintain interest',
          'Track your progress to stay motivated'
        ],
        reasoning: `Your ${bestIntervention.type} interventions have ${bestIntervention.avgEffectiveness.toFixed(0)}% average effectiveness.`,
        personalizedFor: ['successful_pattern_repetition'],
        confidence: 75,
        expectedOutcome: 'Continued progress based on past success',
        timeframe: 'Ongoing',
        metrics: ['engagement', 'consistency'],
        createdAt: new Date(),
        category: 'behavioral_reinforcement'
      });
    }
  }

  // Motivation style-based recommendations
  switch (profile.preferences.motivationStyle) {
    case 'competition':
      recommendations.push({
        id: `behavior_${Date.now()}_2`,
        type: 'behavioral',
        priority: 'medium',
        title: 'Join Health Challenges',
        description: 'Based on your competitive motivation style, participating in challenges could boost your engagement.',
        actionItems: [
          'Join weekly step challenges',
          'Compete with friends',
          'Set personal records to beat'
        ],
        reasoning: 'Your motivation style indicates you respond well to competitive elements.',
        personalizedFor: ['competitive_motivation'],
        confidence: 70,
        expectedOutcome: 'Increased motivation and consistency',
        timeframe: '1 week',
        metrics: ['challenge_participation', 'consistency_score'],
        createdAt: new Date(),
        category: 'motivation_optimization'
      });
      break;
    case 'social':
      recommendations.push({
        id: `behavior_${Date.now()}_3`,
        type: 'behavioral',
        priority: 'medium',
        title: 'Connect with Health Community',
        description: 'Your social motivation style suggests you\'ll benefit from community interactions.',
        actionItems: [
          'Share your progress with friends',
          'Join health-focused groups',
          'Find a workout buddy'
        ],
        reasoning: 'Social motivation styles show better results with community engagement.',
        personalizedFor: ['social_motivation'],
        confidence: 70,
        expectedOutcome: 'Enhanced motivation through social support',
        timeframe: '1-2 weeks',
        metrics: ['social_engagement', 'consistency_score'],
        createdAt: new Date(),
        category: 'social_engagement'
      });
      break;
  }

  return recommendations;
}

/**
 * Generate AI-powered recommendations using Vertex AI
 */
async function generateAIRecommendations(
  userContext: any,
  profile: PersonalizationProfile,
  mlPredictions: any
): Promise<any[]> {
  
  try {
    const model = vertexAI.getGenerativeModel({
      model: 'gemini-1.5-pro'
    });

    const prompt = `You are an expert health coach creating personalized recommendations. 

User Profile:
- Age: ${userContext.demographics.age}
- Activity Level: ${userContext.healthData.filter((h: any) => h.type === 'steps').length > 0 ? 'Active' : 'Inactive'}
- Goals: ${userContext.health.goals?.join(', ') || 'General health'}
- Motivation Style: ${profile.preferences.motivationStyle}
- Previous Success: ${profile.adaptations.successfulInterventions.slice(0, 3).map((i: any) => i.type).join(', ')}

Recent Health Data:
${userContext.healthData.slice(0, 10).map((h: any) => `${h.type}: ${h.value?.numeric || 'N/A'}`).join('\n')}

ML Predictions:
- Engagement Probability: ${mlPredictions.engagementProbability}%
- Success Probability: ${mlPredictions.successProbability}%
- Optimal Timing: ${mlPredictions.optimalTiming.join(', ')}

Generate 2 personalized health recommendations in this exact JSON format:
{
  "recommendations": [
    {
      "type": "exercise|nutrition|mindfulness|sleep|medical",
      "priority": "low|medium|high",
      "title": "Short, actionable title",
      "description": "1-2 sentence description",
      "actionItems": ["Specific action 1", "Specific action 2", "Specific action 3"],
      "reasoning": "Why this is personalized for this user",
      "expectedOutcome": "What improvement to expect",
      "timeframe": "How long to see results",
      "category": "descriptive_category"
    }
  ]
}`;

    const result = await model.generateContent(prompt);
    const response = result.response.text();

    try {
      const parsedResponse = JSON.parse(response);
      return parsedResponse.recommendations.map((rec: any, index: number) => ({
        ...rec,
        id: `ai_${Date.now()}_${index}`,
        personalizedFor: ['ai_generated'],
        confidence: mlPredictions.successProbability,
        metrics: ['user_satisfaction', 'goal_progress'],
        createdAt: new Date()
      }));
    } catch (parseError) {
      logger.warn('Failed to parse AI recommendations:', parseError);
      return [];
    }
  } catch (error) {
    logger.warn('AI recommendation generation failed:', error);
    return [];
  }
}

/**
 * Generate temporal (time-sensitive) recommendations
 */
async function generateTemporalRecommendations(
  userContext: any,
  profile: PersonalizationProfile
): Promise<any[]> {
  
  const recommendations = [];
  const now = new Date();
  const hour = now.getHours();
  const dayOfWeek = now.getDay();

  // Time-based recommendations
  if (hour >= 6 && hour <= 10) {
    // Morning recommendations
    recommendations.push({
      id: `temporal_${Date.now()}_1`,
      type: 'mindfulness',
      priority: 'low',
      title: 'Start Your Day Mindfully',
      description: 'A quick morning meditation can set a positive tone for your entire day.',
      actionItems: [
        'Take 5 deep breaths',
        'Set a positive intention',
        'Practice gratitude for 2 minutes'
      ],
      reasoning: 'Morning is an optimal time for mindfulness practices.',
      personalizedFor: ['morning_routine'],
      confidence: 60,
      expectedOutcome: 'Reduced stress and better focus',
      timeframe: 'Immediate',
      metrics: ['mindfulness_minutes', 'mood_score'],
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 4 * 60 * 60 * 1000), // Expires in 4 hours
      category: 'temporal_optimization'
    });
  }

  if (hour >= 17 && hour <= 20) {
    // Evening recommendations
    recommendations.push({
      id: `temporal_${Date.now()}_2`,
      type: 'exercise',
      priority: 'medium',
      title: 'Evening Movement',
      description: 'Light evening exercise can help you unwind and prepare for better sleep.',
      actionItems: [
        'Take a 15-minute walk',
        'Do gentle stretching',
        'Try light yoga poses'
      ],
      reasoning: 'Evening is a good time for moderate activity before winding down.',
      personalizedFor: ['evening_routine'],
      confidence: 65,
      expectedOutcome: 'Better sleep quality and stress relief',
      timeframe: 'Same evening',
      metrics: ['activity_minutes', 'sleep_quality'],
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 3 * 60 * 60 * 1000), // Expires in 3 hours
      category: 'temporal_optimization'
    });
  }

  // Weekend-specific recommendations
  if (dayOfWeek === 0 || dayOfWeek === 6) {
    recommendations.push({
      id: `temporal_${Date.now()}_3`,
      type: 'exercise',
      priority: 'medium',
      title: 'Weekend Adventure',
      description: 'Weekends are perfect for trying new activities or longer workouts.',
      actionItems: [
        'Try a new hiking trail',
        'Join a recreational sports game',
        'Take a longer bike ride'
      ],
      reasoning: 'Weekends provide more time for recreational activities.',
      personalizedFor: ['weekend_opportunities'],
      confidence: 70,
      expectedOutcome: 'Increased activity variety and enjoyment',
      timeframe: 'This weekend',
      metrics: ['activity_variety', 'enjoyment_score'],
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 48 * 60 * 60 * 1000), // Expires in 48 hours
      category: 'weekend_optimization'
    });
  }

  return recommendations;
}

/**
 * Rank recommendations based on personalization factors
 */
async function rankRecommendations(
  recommendations: any[],
  profile: PersonalizationProfile,
  mlPredictions: any
): Promise<any[]> {
  
  return recommendations
    .map(rec => ({
      ...rec,
      personalizedScore: calculatePersonalizationScore(rec, profile, mlPredictions)
    }))
    .sort((a, b) => {
      // Sort by priority first, then personalized score
      const priorityOrder = { 'urgent': 4, 'high': 3, 'medium': 2, 'low': 1 };
      const priorityDiff = priorityOrder[b.priority as keyof typeof priorityOrder] - priorityOrder[a.priority as keyof typeof priorityOrder];
      
      if (priorityDiff !== 0) return priorityDiff;
      
      return b.personalizedScore - a.personalizedScore;
    });
}

/**
 * Calculate personalization score for a recommendation
 */
function calculatePersonalizationScore(
  recommendation: any,
  profile: PersonalizationProfile,
  mlPredictions: any
): number {
  
  let score = recommendation.confidence || 50;

  // Boost score for preferred content types
  if (profile.preferences.contentTypes.includes(recommendation.category)) {
    score += 10;
  }

  // Boost score for historically successful intervention types
  const successfulTypes = profile.adaptations.successfulInterventions
    .map(i => i.type)
    .filter(type => type === recommendation.type);
  
  if (successfulTypes.length > 0) {
    const avgEffectiveness = profile.adaptations.successfulInterventions
      .filter(i => i.type === recommendation.type)
      .reduce((sum, i) => sum + i.effectiveness, 0) / successfulTypes.length;
    
    score += (avgEffectiveness - 50) / 5; // Scale to reasonable boost
  }

  // Adjust based on ML predictions
  score = score * (mlPredictions.successProbability / 100);

  // Penalize if similar interventions failed recently
  const recentFailures = profile.adaptations.failedInterventions
    .filter(i => i.type === recommendation.type)
    .length;
  
  score -= recentFailures * 5;

  return Math.max(0, Math.min(100, score));
}

/**
 * Calculate overall recommendation confidence
 */
function calculateRecommendationConfidence(
  recommendations: any[],
  profile: PersonalizationProfile,
  mlPredictions: any
): number {
  
  if (recommendations.length === 0) return 0;

  const avgConfidence = recommendations.reduce((sum, rec) => sum + rec.confidence, 0) / recommendations.length;
  const dataQuality = Math.min(100, profile.adaptations.successfulInterventions.length * 10 + 30);
  const mlConfidence = mlPredictions.successProbability;

  return Math.round((avgConfidence + dataQuality + mlConfidence) / 3);
}

/**
 * Update user personalization profile based on behavior
 */
async function updateUserPersonalizationProfile(
  userId: string,
  behaviorData: any,
  context?: any
): Promise<boolean> {
  
  const profileRef = firestore.collection('personalizationProfiles').doc(userId);
  
  try {
    await firestore.runTransaction(async (transaction) => {
      const profileDoc = await transaction.get(profileRef);
      let profile: PersonalizationProfile;

      if (profileDoc.exists) {
        profile = profileDoc.data() as PersonalizationProfile;
      } else {
        profile = await createInitialPersonalizationProfile(userId);
      }

      // Update behavior patterns
      if (behaviorData.sessionDuration) {
        profile.behaviorPatterns.typicalSessionDuration = 
          (profile.behaviorPatterns.typicalSessionDuration + behaviorData.sessionDuration) / 2;
      }

      if (behaviorData.interactionTime) {
        const hour = new Date(behaviorData.interactionTime).getHours();
        if (!profile.behaviorPatterns.preferredInteractionTimes.includes(hour)) {
          profile.behaviorPatterns.preferredInteractionTimes.push(hour);
          profile.behaviorPatterns.preferredInteractionTimes = 
            profile.behaviorPatterns.preferredInteractionTimes.slice(-10); // Keep last 10
        }
      }

      if (behaviorData.engagement !== undefined) {
        profile.behaviorPatterns.engagementScore = 
          Math.round((profile.behaviorPatterns.engagementScore * 0.8) + (behaviorData.engagement * 0.2));
      }

      if (behaviorData.consistency !== undefined) {
        profile.behaviorPatterns.consistencyScore = 
          Math.round((profile.behaviorPatterns.consistencyScore * 0.8) + (behaviorData.consistency * 0.2));
      }

      profile.lastUpdated = new Date();

      transaction.set(profileRef, profile);
    });

    return true;
  } catch (error) {
    logger.error('Update personalization profile failed:', error);
    return false;
  }
}

/**
 * Process feedback loop and extract learnings
 */
async function processFeedbackLoop(feedbackLoop: FeedbackLoop): Promise<boolean> {
  try {
    // Save feedback loop
    await firestore.collection('feedbackLoops').add(feedbackLoop);

    // Update personalization profile with learnings
    const profileRef = firestore.collection('personalizationProfiles').doc(feedbackLoop.userId);
    
    await firestore.runTransaction(async (transaction) => {
      const profileDoc = await transaction.get(profileRef);
      if (!profileDoc.exists) return;

      const profile = profileDoc.data() as PersonalizationProfile;

      // Analyze feedback for learnings
      if (feedbackLoop.outcome && feedbackLoop.outcome.improvement > 0) {
        // Successful intervention
        profile.adaptations.successfulInterventions.push({
          type: 'recommendation_type', // Would be extracted from recommendation
          context: JSON.stringify(feedbackLoop.context),
          outcome: JSON.stringify(feedbackLoop.outcome),
          effectiveness: Math.min(100, feedbackLoop.outcome.improvement * 20)
        });

        // Extract learning
        if (feedbackLoop.feedback?.helpful) {
          profile.adaptations.learnings.push({
            insight: `Recommendations at ${feedbackLoop.context.timeOfDay}h are effective`,
            confidence: 70,
            evidence: [`Improvement: ${feedbackLoop.outcome.improvement}`, `User rating: ${feedbackLoop.feedback.rating}`]
          });
        }
      } else if (feedbackLoop.feedback && !feedbackLoop.feedback.helpful) {
        // Failed intervention
        profile.adaptations.failedInterventions.push({
          type: 'recommendation_type',
          context: JSON.stringify(feedbackLoop.context),
          reason: feedbackLoop.feedback.comments || 'User marked as not helpful'
        });
      }

      // Update responsiveness score
      if (feedbackLoop.action === 'completed') {
        profile.behaviorPatterns.responsiveness = Math.min(100, profile.behaviorPatterns.responsiveness + 2);
      } else if (feedbackLoop.action === 'dismissed') {
        profile.behaviorPatterns.responsiveness = Math.max(0, profile.behaviorPatterns.responsiveness - 1);
      }

      profile.lastUpdated = new Date();
      transaction.set(profileRef, profile);
    });

    return true;
  } catch (error) {
    logger.error('Process feedback loop failed:', error);
    return false;
  }
}

/**
 * Update behavior patterns from health data
 */
async function updateBehaviorPatternsFromHealthData(userId: string, observation: any): Promise<void> {
  try {
    const profileRef = firestore.collection('personalizationProfiles').doc(userId);
    
    await firestore.runTransaction(async (transaction) => {
      const profileDoc = await transaction.get(profileRef);
      if (!profileDoc.exists) return;

      const profile = profileDoc.data() as PersonalizationProfile;
      
      // Update consistency score based on data frequency
      const hour = new Date(observation.effectiveDateTime.toDate()).getHours();
      const recentObservations = await firestore
        .collection('users')
        .doc(userId)
        .collection('healthObservations')
        .where('type', '==', observation.type)
        .where('effectiveDateTime', '>=', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000))
        .get();

      const consistency = Math.min(100, (recentObservations.size / 7) * 20); // Up to 5 observations per day
      profile.behaviorPatterns.consistencyScore = 
        Math.round((profile.behaviorPatterns.consistencyScore * 0.9) + (consistency * 0.1));

      profile.lastUpdated = new Date();
      transaction.set(profileRef, profile);
    });
  } catch (error) {
    logger.warn('Update behavior patterns from health data failed:', error);
  }
}

/**
 * Determine if recommendations should be regenerated
 */
async function shouldRegenerateRecommendations(userId: string, observation: any): Promise<boolean> {
  // Check if this is a significant health data change
  const significantTypes = ['sleep', 'heart_rate', 'weight', 'blood_pressure'];
  
  if (!significantTypes.includes(observation.type)) {
    return false;
  }

  // Check if the value is significantly different from recent values
  const recentObservations = await firestore
    .collection('users')
    .doc(userId)
    .collection('healthObservations')
    .where('type', '==', observation.type)
    .where('effectiveDateTime', '>=', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000))
    .orderBy('effectiveDateTime', 'desc')
    .limit(5)
    .get();

  if (recentObservations.size < 3) return false;

  const recentValues = recentObservations.docs
    .map(doc => doc.data().value?.numeric)
    .filter(val => val != null);

  if (recentValues.length < 3) return false;

  const avgRecent = recentValues.reduce((sum, val) => sum + val, 0) / recentValues.length;
  const currentValue = observation.value?.numeric;

  // If current value is >20% different from recent average, regenerate
  const percentageChange = Math.abs((currentValue - avgRecent) / avgRecent) * 100;
  
  return percentageChange > 20;
}

/**
 * Calculate personalization performance metrics
 */
async function calculatePersonalizationPerformance(userId: string): Promise<any> {
  try {
    // Get recent feedback
    const feedbackSnapshot = await firestore
      .collection('feedbackLoops')
      .where('userId', '==', userId)
      .where('timestamp', '>=', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000))
      .get();

    const feedback = feedbackSnapshot.docs.map(doc => doc.data());
    
    if (feedback.length === 0) {
      return {
        engagementRate: 0,
        completionRate: 0,
        satisfactionScore: 0,
        improvementRate: 0
      };
    }

    const engagementRate = (feedback.filter(f => f.action !== 'dismissed').length / feedback.length) * 100;
    const completionRate = (feedback.filter(f => f.action === 'completed').length / feedback.length) * 100;
    const satisfactionScore = feedback
      .filter(f => f.feedback?.rating)
      .reduce((sum, f) => sum + f.feedback.rating, 0) / 
      Math.max(1, feedback.filter(f => f.feedback?.rating).length);
    const improvementRate = (feedback.filter(f => f.outcome?.improvement > 0).length / feedback.length) * 100;

    return {
      engagementRate: Math.round(engagementRate),
      completionRate: Math.round(completionRate),
      satisfactionScore: Math.round(satisfactionScore * 20), // Convert 1-5 to 0-100
      improvementRate: Math.round(improvementRate),
      totalInteractions: feedback.length
    };
  } catch (error) {
    logger.warn('Calculate personalization performance failed:', error);
    return {
      engagementRate: 0,
      completionRate: 0,
      satisfactionScore: 0,
      improvementRate: 0,
      totalInteractions: 0
    };
  }
}