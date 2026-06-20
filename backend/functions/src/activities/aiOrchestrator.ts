import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { logger } from 'firebase-functions';
import { 
  Activity,
  ActivityGroup,
  UserTraits,
  ActivitiesError,
  ErrorCodes,
  ActivityCategory,
  SkillLevel
} from './models';
import { incrementCounter } from '../shared/metrics';

const db = admin.firestore();

// Generate AI perspectives for activities
export const getActivityPerspectives = functions.https.onCall(async (data, context) => {
  const { activityId } = data;

  if (!activityId) {
    throw new functions.https.HttpsError('invalid-argument', 'Activity ID required');
  }

  try {
    // Get activity details
    const activityDoc = await db.collection('activities').doc(activityId).get();
    if (!activityDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Activity not found');
    }

    const activity = activityDoc.data() as Activity;

    // Generate AI perspectives based on activity details
    const perspectives = await generateActivityPerspectives(activity);

    await incrementCounter('activities_ai_perspectives_generated', 1);

    return perspectives;

  } catch (error) {
    logger.error('Error generating activity perspectives:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to generate perspectives');
  }
});

// Generate group activity suggestions using AI
export const generateGroupSuggestions = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { groupId } = data;

  if (!groupId) {
    throw new functions.https.HttpsError('invalid-argument', 'Group ID required');
  }

  try {
    // Get group details
    const groupDoc = await db.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Group not found');
    }

    const group = groupDoc.data() as ActivityGroup;

    // Check authorization
    if (!group.participantUserIds.includes(context.auth.uid)) {
      throw new functions.https.HttpsError('permission-denied', 'Not a group member');
    }

    // Generate suggestions based on group preferences and member traits
    const suggestions = await generateGroupActivitySuggestions(group);

    await incrementCounter('activities_ai_suggestions_generated', 1);

    return { suggestions };

  } catch (error) {
    logger.error('Error generating group suggestions:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to generate suggestions');
  }
});

// Analyze user behavior and update traits
export const updateUserTraits = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { interactions, preferences } = data;

  try {
    // Analyze recent interactions to infer user traits
    const updatedTraits = await analyzeUserTraits(context.auth.uid, interactions, preferences);

    // Update user traits in database
    await db.collection('userTraits').doc(context.auth.uid).set(updatedTraits, { merge: true });

    await incrementCounter('activities_user_traits_updated', 1);

    return { success: true };

  } catch (error) {
    logger.error('Error updating user traits:', error);
    throw new functions.https.HttpsError('internal', 'Failed to update user traits');
  }
});

// Enrich activity descriptions with AI insights
export const enrichActivityDescription = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { activityId } = data;

  if (!activityId) {
    throw new functions.https.HttpsError('invalid-argument', 'Activity ID required');
  }

  try {
    const activityDoc = await db.collection('activities').doc(activityId).get();
    if (!activityDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Activity not found');
    }

    const activity = activityDoc.data() as Activity;

    // Generate enriched description with AI insights
    const enrichedContent = await enrichActivityContent(activity);

    // Update activity with enriched content
    await db.collection('activities').doc(activityId).update({
      enrichedDescription: enrichedContent.description,
      aiInsights: enrichedContent.insights,
      tags: admin.firestore.FieldValue.arrayUnion(...enrichedContent.suggestedTags),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await incrementCounter('activities_enriched', 1);

    return enrichedContent;

  } catch (error) {
    logger.error('Error enriching activity:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to enrich activity');
  }
});

// AI-powered activity matching for users
export const getPersonalizedRecommendations = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { cityId, limit = 10 } = data;

  if (!cityId) {
    throw new functions.https.HttpsError('invalid-argument', 'City ID required');
  }

  try {
    // Get user traits and interaction history
    const userTraits = await getUserTraits(context.auth.uid);
    const userInteractions = await getUserRecentInteractions(context.auth.uid);

    // Get available activities in the city
    const activitiesQuery = await db.collection('activities')
      .where('location.cityId', '==', cityId)
      .where('isActive', '==', true)
      .limit(100) // Get more than needed for better filtering
      .get();

    const activities = activitiesQuery.docs.map(doc => ({ id: doc.id, ...doc.data() }) as Activity);

    // Generate personalized recommendations using AI
    const recommendations = await generatePersonalizedRecommendations(
      activities,
      userTraits,
      userInteractions,
      limit
    );

    await incrementCounter('activities_personalized_recommendations', 1);

    return { activities: recommendations };

  } catch (error) {
    logger.error('Error generating personalized recommendations:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to generate recommendations');
  }
});

// Helper function to generate activity perspectives
async function generateActivityPerspectives(activity: Activity) {
  // In a real implementation, this would call an AI service like OpenAI GPT
  // For now, we'll generate rule-based perspectives

  const perspectives = {
    beginnerTips: generateBeginnerTips(activity),
    expertInsights: generateExpertInsights(activity),
    safetyNotes: generateSafetyNotes(activity),
    culturalContext: generateCulturalContext(activity),
  };

  return perspectives;
}

// Helper function to generate group activity suggestions
async function generateGroupActivitySuggestions(group: ActivityGroup) {
  try {
    // Get member traits
    const memberTraits = await Promise.all(
      group.participantUserIds.map(userId => getUserTraits(userId))
    );

    // Get activities matching group preferences
    let query = db.collection('activities')
      .where('location.cityId', '==', group.cityId)
      .where('isActive', '==', true);

    if (group.preferences.categories.length > 0) {
      query = query.where('category', 'in', group.preferences.categories);
    }

    const activitiesSnapshot = await query.limit(50).get();
    const activities = activitiesSnapshot.docs.map(doc => 
      ({ id: doc.id, ...doc.data() }) as Activity
    );

    // Score and rank activities based on group compatibility
    const suggestions = activities
      .map(activity => {
        const matchScore = calculateGroupActivityMatch(activity, group, memberTraits);
        return {
          activityId: activity.id,
          title: activity.title,
          reason: generateMatchReason(activity, group, matchScore),
          matchScore: Math.round(matchScore),
        };
      })
      .filter(suggestion => suggestion.matchScore > 50)
      .sort((a, b) => b.matchScore - a.matchScore)
      .slice(0, 10);

    return suggestions;

  } catch (error) {
    logger.error('Error generating group suggestions:', error);
    return [];
  }
}

// Helper function to analyze and update user traits
async function analyzeUserTraits(userId: string, interactions: any[], preferences: any) {
  // Get existing traits
  const existingTraitsDoc = await db.collection('userTraits').doc(userId).get();
  const existingTraits = existingTraitsDoc.exists ? existingTraitsDoc.data() as UserTraits : null;

  // Analyze interaction patterns
  const categoryInteractions = new Map<string, number>();
  const skillLevelPreferences = new Map<string, number>();

  interactions.forEach(interaction => {
    if (interaction.entityType === 'activity' && interaction.context?.category) {
      const category = interaction.context.category;
      categoryInteractions.set(category, (categoryInteractions.get(category) || 0) + 1);
    }
  });

  // Determine favorite categories
  const favoriteSports = Array.from(categoryInteractions.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([category]) => category as ActivityCategory);

  // Update traits
  const updatedTraits: UserTraits = {
    userId,
    traits: {
      favoriteSports,
      skillLevels: existingTraits?.traits.skillLevels || {},
      preferredDays: preferences?.preferredDays || existingTraits?.traits.preferredDays,
      priceRange: preferences?.priceRange || existingTraits?.traits.priceRange,
      socialPreference: inferSocialPreference(interactions),
      activityFrequency: inferActivityFrequency(interactions),
    },
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    version: 1,
  };

  return updatedTraits;
}

// Helper function to enrich activity content
async function enrichActivityContent(activity: Activity) {
  // In a real implementation, this would use AI to generate content
  // For now, we'll use rule-based enrichment

  const insights = generateActivityInsights(activity);
  const suggestedTags = generateSuggestedTags(activity);
  const enhancedDescription = enhanceDescription(activity);

  return {
    description: enhancedDescription,
    insights,
    suggestedTags,
  };
}

// Helper function to generate personalized recommendations
async function generatePersonalizedRecommendations(
  activities: Activity[],
  userTraits: UserTraits | null,
  interactions: any[],
  limit: number
) {
  if (!userTraits) {
    // Return popular activities if no traits available
    return activities
      .sort((a, b) => (b.rating || 0) * (b.reviewCount || 0) - (a.rating || 0) * (a.reviewCount || 0))
      .slice(0, limit);
  }

  // Score activities based on user preferences
  const scoredActivities = activities.map(activity => {
    let score = 0;

    // Category preference
    if (userTraits.traits.favoriteSports?.includes(activity.category)) {
      score += 30;
    }

    // Skill level match
    const userSkillLevel = userTraits.traits.skillLevels?.[activity.category];
    if (userSkillLevel && activity.skillLevels.includes(userSkillLevel)) {
      score += 20;
    }

    // Price preference
    if (userTraits.traits.priceRange && activity.priceRange) {
      const priceMatch = calculatePriceMatch(userTraits.traits.priceRange, activity.priceRange);
      score += priceMatch * 15;
    }

    // Popularity boost
    score += Math.min((activity.rating || 0) * 2, 10);
    score += Math.min(Math.log10((activity.reviewCount || 0) + 1) * 5, 10);

    // Diversity penalty for recently viewed
    const recentViews = interactions.filter(i => 
      i.entityId === activity.id && 
      i.type === 'view'
    ).length;
    score -= recentViews * 5;

    return { ...activity, score };
  });

  // Return top recommendations
  return scoredActivities
    .sort((a, b) => b.score - a.score)
    .slice(0, limit)
    .map(({ score, ...activity }) => activity);
}

// Utility functions
async function getUserTraits(userId: string): Promise<UserTraits | null> {
  try {
    const traitsDoc = await db.collection('userTraits').doc(userId).get();
    return traitsDoc.exists ? traitsDoc.data() as UserTraits : null;
  } catch (error) {
    logger.warn(`Failed to get user traits for ${userId}:`, error);
    return null;
  }
}

async function getUserRecentInteractions(userId: string, limit = 50) {
  try {
    const interactionsSnapshot = await db.collection('interactions')
      .where('userId', '==', userId)
      .orderBy('timestamp', 'desc')
      .limit(limit)
      .get();

    return interactionsSnapshot.docs.map(doc => doc.data());
  } catch (error) {
    logger.warn(`Failed to get user interactions for ${userId}:`, error);
    return [];
  }
}

function generateBeginnerTips(activity: Activity): string[] {
  const tips = [
    "Start with basic techniques and don't rush the learning process",
    "Ask your instructor questions - they're there to help you succeed",
    "Arrive early to familiarize yourself with the environment",
  ];

  // Category-specific tips
  switch (activity.category) {
    case 'sports':
      tips.push("Focus on proper form before worrying about speed or power");
      break;
    case 'fitness':
      tips.push("Listen to your body and take breaks when needed");
      break;
    case 'arts':
      tips.push("Don't worry about perfection - enjoy the creative process");
      break;
    case 'adventure':
      tips.push("Safety first - follow all instructions and guidelines");
      break;
  }

  return tips;
}

function generateExpertInsights(activity: Activity): string[] {
  const insights = [
    "Focus on technique refinement and consistency",
    "Challenge yourself with progressive difficulty increases",
    "Share your knowledge with beginners to reinforce your own learning",
  ];

  // Add activity-specific expert insights
  if (activity.category === 'sports') {
    insights.push("Analyze your performance metrics to identify improvement areas");
  }

  return insights;
}

function generateSafetyNotes(activity: Activity): string[] {
  const notes = [
    "Follow all instructor guidelines and venue rules",
    "Inform staff of any medical conditions or injuries",
    "Stay hydrated and take breaks as needed",
  ];

  if (activity.category === 'adventure') {
    notes.push("Weather conditions can change quickly - be prepared");
    notes.push("Never participate beyond your skill level");
  }

  return notes;
}

function generateCulturalContext(activity: Activity): string | null {
  // Add cultural context for activities in Morocco
  if (activity.location.cityId === 'casablanca') {
    switch (activity.category) {
      case 'food':
        return "Moroccan cuisine emphasizes fresh ingredients and traditional spices. Many cooking classes include a market visit to source ingredients locally.";
      case 'arts':
        return "Casablanca has a rich artistic heritage blending traditional Moroccan crafts with modern influences from its cosmopolitan history.";
      default:
        return null;
    }
  }
  return null;
}

function calculateGroupActivityMatch(
  activity: Activity, 
  group: ActivityGroup, 
  memberTraits: (UserTraits | null)[]
): number {
  let score = 50; // Base score

  // Category match
  if (group.preferences.categories.includes(activity.category)) {
    score += 25;
  }

  // Skill level compatibility
  if (group.preferences.skillLevel && activity.skillLevels.includes(group.preferences.skillLevel)) {
    score += 15;
  }

  // Member interest analysis
  const interestedMembers = memberTraits.filter(traits => 
    traits?.traits.favoriteSports?.includes(activity.category)
  ).length;
  
  const interestRatio = interestedMembers / memberTraits.length;
  score += interestRatio * 20;

  // Price range compatibility
  if (group.preferences.priceRange && activity.priceRange) {
    const priceMatch = calculatePriceMatch(group.preferences.priceRange, activity.priceRange);
    score += priceMatch * 10;
  }

  return Math.min(score, 100);
}

function generateMatchReason(activity: Activity, group: ActivityGroup, matchScore: number): string {
  const reasons = [];

  if (group.preferences.categories.includes(activity.category)) {
    reasons.push(`matches your group's interest in ${activity.category}`);
  }

  if (matchScore > 80) {
    reasons.push("highly compatible with your group preferences");
  } else if (matchScore > 60) {
    reasons.push("good fit for your group");
  }

  if (activity.rating && activity.rating > 4.0) {
    reasons.push(`highly rated (${activity.rating.toFixed(1)} stars)`);
  }

  return reasons.join(", ") || "recommended for your group";
}

function calculatePriceMatch(userRange: any, activityRange: any): number {
  const userMin = userRange.min || 0;
  const userMax = userRange.max || Infinity;
  const activityMin = activityRange.min || 0;
  const activityMax = activityRange.max || 0;

  // Calculate overlap
  const overlapMin = Math.max(userMin, activityMin);
  const overlapMax = Math.min(userMax, activityMax);

  if (overlapMax <= overlapMin) {
    return 0; // No overlap
  }

  const userSpan = userMax - userMin;
  const overlapSpan = overlapMax - overlapMin;
  
  return userSpan > 0 ? overlapSpan / userSpan : 1;
}

function inferSocialPreference(interactions: any[]): 'solo' | 'small_group' | 'large_group' {
  // Analyze group size preferences from interactions
  const groupInteractions = interactions.filter(i => i.entityType === 'group').length;
  const soloInteractions = interactions.filter(i => i.entityType === 'activity' && !i.groupId).length;

  if (groupInteractions > soloInteractions * 2) {
    return 'large_group';
  } else if (groupInteractions > soloInteractions) {
    return 'small_group';
  } else {
    return 'solo';
  }
}

function inferActivityFrequency(interactions: any[]): 'low' | 'medium' | 'high' {
  const recentBookings = interactions.filter(i => 
    i.type === 'book' && 
    new Date(i.timestamp.toDate()).getTime() > Date.now() - 30 * 24 * 60 * 60 * 1000 // Last 30 days
  ).length;

  if (recentBookings >= 8) return 'high';
  if (recentBookings >= 3) return 'medium';
  return 'low';
}

function generateActivityInsights(activity: Activity): string[] {
  const insights = [];

  if (activity.rating && activity.rating > 4.5) {
    insights.push("This activity receives consistently excellent reviews");
  }

  if (activity.reviewCount && activity.reviewCount > 100) {
    insights.push("Popular activity with extensive participant feedback");
  }

  return insights;
}

function generateSuggestedTags(activity: Activity): string[] {
  const tags = [];

  if (activity.weatherDependency) {
    tags.push(`${activity.weatherDependency}-dependent`);
  }

  if (activity.skillLevels.includes('beginner' as SkillLevel)) {
    tags.push('beginner-friendly');
  }

  if (activity.maxParticipants && activity.maxParticipants <= 6) {
    tags.push('small-group');
  }

  return tags;
}

function enhanceDescription(activity: Activity): string {
  let enhanced = activity.description;

  // Add contextual information
  if (activity.duration) {
    const hours = Math.floor(activity.duration / 3600);
    const minutes = Math.floor((activity.duration % 3600) / 60);
    enhanced += ` This ${hours}h ${minutes}m experience`;
  }

  if (activity.skillLevels.length > 0) {
    enhanced += ` is suitable for ${activity.skillLevels.join(', ')} levels`;
  }

  return enhanced + ".";
}