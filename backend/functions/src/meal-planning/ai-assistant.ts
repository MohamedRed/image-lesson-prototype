import { onCall, CallableRequest } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";

const db = getFirestore();

// Types
interface AIMessage {
  id: string;
  content: string;
  isUser: boolean;
  timestamp: admin.firestore.Timestamp;
  context?: Record<string, any>;
  suggestedActions: AIAction[];
}

interface AIAction {
  type: 'replace_meal' | 'add_recipe' | 'adjust_serving' | 'suggest_alternative' | 
        'update_preferences' | 'regenerate_plan' | 'price_compare' | 'schedule_reminder';
  title: string;
  description?: string;
  parameters: Record<string, any>;
}

interface AIReply {
  content: string;
  suggestedRecipes: any[];
  suggestedEdits: MealPlanEdit[];
  followUpQuestions: string[];
  confidence: number;
  sources: string[];
}

interface MealPlanEdit {
  type: 'replace' | 'remove' | 'adjustServing' | 'reschedule';
  day: number;
  mealSlot: 'breakfast' | 'lunch' | 'dinner' | 'snack';
  newRecipeId?: string;
  newServingSize?: number;
  reason: string;
}

interface HealthProfile {
  userId: string;
  trackedNutrients: string[];
  goals: HealthGoal[];
  bodyRegionConcerns: BodyRegion[];
  symptoms: string[];
  flaggedConditions: string[];
  medicalDisclaimer: boolean;
  updatedAt: admin.firestore.Timestamp;
}

interface HealthGoal {
  type: 'weightLoss' | 'weightGain' | 'muscleGain' | 'energyBoost' | 
        'immuneSupport' | 'heartHealth' | 'brainHealth' | 'digestiveHealth' | 'customNutrient';
  target: number;
  unit: string;
  timeframe: 'daily' | 'weekly' | 'monthly';
  priority: 'low' | 'medium' | 'high';
}

interface BodyRegion {
  name: string;
  anatomicalId: string;
  concernLevel: 'low' | 'medium' | 'high';
  relatedNutrients: string[];
  notes?: string;
}

interface NutritionAdvice {
  bodyRegions: BodyRegion[];
  recommendedNutrients: string[];
  avoidedIngredients: string[];
  suggestedRecipes: any[];
  planCriteria: any;
  disclaimer: string;
}

// AI Chat Assistant
export const aiChat = onCall(
  {
    region: 'us-central1',
    timeoutSeconds: 60,
    memory: '1GiB'
  },
  async (request: CallableRequest<{
    messages: AIMessage[];
    context: Record<string, any>;
  }>) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new Error('Authentication required');
    }

    const { messages, context } = request.data;
    if (!messages || messages.length === 0) {
      throw new Error('Messages required');
    }

    try {
      const lastMessage = messages[messages.length - 1];
      if (!lastMessage.isUser) {
        throw new Error('Last message must be from user');
      }

      // Analyze user intent
      const intent = await analyzeUserIntent(lastMessage.content, context, userId);
      
      // Generate appropriate response
      const response = await generateAIResponse(intent, lastMessage.content, context, userId);

      // Store conversation for learning (optional)
      await storeConversation(userId, messages, response);

      return response;

    } catch (error) {
      logger.error('AI chat failed', { error, userId });
      
      // Fallback response
      return {
        content: "I'm sorry, I'm having trouble processing your request right now. Could you try rephrasing or asking something else?",
        suggestedRecipes: [],
        suggestedEdits: [],
        followUpQuestions: [
          "Would you like me to suggest some popular recipes?",
          "Do you need help with meal planning?"
        ],
        confidence: 0.1,
        sources: []
      } as AIReply;
    }
  }
);

// Get nutrition advice based on body regions and symptoms
export const getNutritionAdvice = onCall(
  {
    region: 'us-central1',
    timeoutSeconds: 60
  },
  async (request: CallableRequest<{
    bodyRegions: BodyRegion[];
    symptoms: string[];
    preferences: any;
  }>) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new Error('Authentication required');
    }

    const { bodyRegions, symptoms, preferences } = request.data;
    if (!bodyRegions || bodyRegions.length === 0) {
      throw new Error('Body regions required');
    }

    try {
      // Generate nutrition advice based on selected body regions
      const advice = await generateNutritionAdvice(bodyRegions, symptoms, preferences, userId);
      
      return advice;

    } catch (error) {
      logger.error('Failed to get nutrition advice', { error, userId });
      throw new Error('Failed to generate nutrition advice');
    }
  }
);

// Get/update user's health profile
export const getHealthProfile = onCall(
  {
    region: 'us-central1',
    timeoutSeconds: 30
  },
  async (request: CallableRequest<{}>) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new Error('Authentication required');
    }

    try {
      const profileDoc = await db
        .collection('users')
        .doc(userId)
        .collection('health')
        .doc('profile')
        .get();

      return profileDoc.exists ? profileDoc.data() : null;

    } catch (error) {
      logger.error('Failed to get health profile', { error, userId });
      throw new Error('Failed to retrieve health profile');
    }
  }
);

export const updateHealthProfile = onCall(
  {
    region: 'us-central1',
    timeoutSeconds: 30
  },
  async (request: CallableRequest<{ profile: HealthProfile }>) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new Error('Authentication required');
    }

    const { profile } = request.data;
    if (!profile) {
      throw new Error('Health profile required');
    }

    try {
      const updatedProfile = {
        ...profile,
        userId,
        updatedAt: admin.firestore.Timestamp.now()
      };

      await db
        .collection('users')
        .doc(userId)
        .collection('health')
        .doc('profile')
        .set(updatedProfile);

      return { success: true };

    } catch (error) {
      logger.error('Failed to update health profile', { error, userId });
      throw new Error('Failed to update health profile');
    }
  }
);

// Sync nutrition data to health tracking
export const syncNutritionToHealth = onCall(
  {
    region: 'us-central1',
    timeoutSeconds: 30
  },
  async (request: CallableRequest<{ planId: string }>) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new Error('Authentication required');
    }

    const { planId } = request.data;
    if (!planId) {
      throw new Error('Plan ID required');
    }

    try {
      // Get meal plan
      const planDoc = await db
        .collection('users')
        .doc(userId)
        .collection('mealPlans')
        .doc(planId)
        .get();

      if (!planDoc.exists) {
        throw new Error('Meal plan not found');
      }

      const plan = planDoc.data();
      
      // Aggregate nutrition data
      const nutritionData = await aggregateNutritionData(plan, userId);
      
      // Store in health tracking collection
      const syncId = `meal_plan_${planId}`;
      await db
        .collection('users')
        .doc(userId)
        .collection('health')
        .doc('nutrition')
        .collection('entries')
        .doc(syncId)
        .set({
          sourceType: 'meal_plan',
          sourcePlanId: planId,
          weekStartDate: plan.weekStartDate,
          dailyNutrition: nutritionData.dailyBreakdown,
          weeklyTotals: nutritionData.weeklyTotals,
          syncedAt: admin.firestore.Timestamp.now()
        });

      // Optionally integrate with external health services (Apple Health, etc.)
      // This would require additional API integrations

      return { success: true };

    } catch (error) {
      logger.error('Failed to sync nutrition to health', { error, userId, planId });
      throw new Error('Failed to sync nutrition data');
    }
  }
);

// Helper functions
async function analyzeUserIntent(message: string, context: Record<string, any>, userId: string) {
  const lowerMessage = message.toLowerCase();
  
  // Simple intent classification (in production, use NLP/ML models)
  if (lowerMessage.includes('swap') || lowerMessage.includes('replace') || lowerMessage.includes('change')) {
    return {
      type: 'meal_replacement',
      confidence: 0.8,
      extractedParams: extractMealReplacementParams(message, context)
    };
  }
  
  if (lowerMessage.includes('recipe') || lowerMessage.includes('suggest') || lowerMessage.includes('recommend')) {
    return {
      type: 'recipe_suggestion',
      confidence: 0.9,
      extractedParams: extractRecipeSuggestionParams(message, context)
    };
  }
  
  if (lowerMessage.includes('price') || lowerMessage.includes('cost') || lowerMessage.includes('expensive')) {
    return {
      type: 'price_inquiry',
      confidence: 0.7,
      extractedParams: {}
    };
  }
  
  if (lowerMessage.includes('nutrition') || lowerMessage.includes('healthy') || lowerMessage.includes('diet')) {
    return {
      type: 'nutrition_advice',
      confidence: 0.8,
      extractedParams: extractNutritionParams(message)
    };
  }
  
  if (lowerMessage.includes('plan') || lowerMessage.includes('week') || lowerMessage.includes('menu')) {
    return {
      type: 'meal_planning',
      confidence: 0.8,
      extractedParams: extractPlanningParams(message, context)
    };
  }
  
  return {
    type: 'general_inquiry',
    confidence: 0.5,
    extractedParams: {}
  };
}

async function generateAIResponse(
  intent: any, 
  message: string, 
  context: Record<string, any>, 
  userId: string
): Promise<AIReply> {
  
  switch (intent.type) {
    case 'meal_replacement':
      return await handleMealReplacement(intent, message, context, userId);
    
    case 'recipe_suggestion':
      return await handleRecipeSuggestion(intent, message, context, userId);
    
    case 'price_inquiry':
      return await handlePriceInquiry(intent, message, context, userId);
    
    case 'nutrition_advice':
      return await handleNutritionAdvice(intent, message, context, userId);
    
    case 'meal_planning':
      return await handleMealPlanning(intent, message, context, userId);
    
    default:
      return await handleGeneralInquiry(intent, message, context, userId);
  }
}

async function handleMealReplacement(intent: any, message: string, context: any, userId: string): Promise<AIReply> {
  const day = intent.extractedParams.day || 0;
  const mealSlot = intent.extractedParams.mealSlot || 'dinner';
  
  // Get suitable replacement recipes
  const replacements = await findReplacementRecipes(day, mealSlot, context, userId);
  
  return {
    content: `I can help you replace the ${mealSlot} for day ${day + 1}. Here are some suitable alternatives:`,
    suggestedRecipes: replacements.slice(0, 3),
    suggestedEdits: [{
      type: 'replace',
      day,
      mealSlot: mealSlot as any,
      reason: 'User requested replacement'
    }],
    followUpQuestions: [
      "Would you like me to show more options?",
      "Do you have any specific dietary preferences for this meal?"
    ],
    confidence: 0.8,
    sources: ['user_recipes', 'global_index']
  };
}

async function handleRecipeSuggestion(intent: any, message: string, context: any, userId: string): Promise<AIReply> {
  const mealType = intent.extractedParams.mealType;
  const cuisineType = intent.extractedParams.cuisineType;
  const timeLimit = intent.extractedParams.timeLimit;
  
  // Find suitable recipes based on parameters
  const suggestions = await findSuggestedRecipes({
    mealType,
    cuisineType,
    timeLimit,
    dietary: context.preferences?.dietary || [],
    allergies: context.preferences?.allergies || []
  }, userId);
  
  return {
    content: `Here are some ${mealType || ''} recipe suggestions${cuisineType ? ` for ${cuisineType} cuisine` : ''}:`,
    suggestedRecipes: suggestions.slice(0, 5),
    suggestedEdits: [],
    followUpQuestions: [
      "Would you like to add any of these to your meal plan?",
      "Do you need the shopping list for these recipes?"
    ],
    confidence: 0.9,
    sources: ['user_recipes', 'curated_recipes']
  };
}

async function handlePriceInquiry(intent: any, message: string, context: any, userId: string): Promise<AIReply> {
  return {
    content: "I can help you compare prices across different stores. Would you like me to check current prices for your shopping list?",
    suggestedRecipes: [],
    suggestedEdits: [],
    followUpQuestions: [
      "Should I compare prices at Marjane, Carrefour, and Atacadão?",
      "Would you like to see the cheapest store for each item?"
    ],
    confidence: 0.7,
    sources: ['price_database']
  };
}

async function handleNutritionAdvice(intent: any, message: string, context: any, userId: string): Promise<AIReply> {
  const nutritionFocus = intent.extractedParams.nutritionFocus || [];
  
  // Get nutrition-focused recipes
  const nutritionRecipes = await findNutritionFocusedRecipes(nutritionFocus, userId);
  
  return {
    content: `Based on your nutrition interests, here are some healthy recipe recommendations:`,
    suggestedRecipes: nutritionRecipes.slice(0, 3),
    suggestedEdits: [],
    followUpQuestions: [
      "Would you like me to create a nutrition-focused meal plan?",
      "Do you want to track specific nutrients?"
    ],
    confidence: 0.8,
    sources: ['nutrition_database', 'health_profile']
  };
}

async function handleMealPlanning(intent: any, message: string, context: any, userId: string): Promise<AIReply> {
  return {
    content: "I can help you create a personalized meal plan. What type of plan are you looking for?",
    suggestedRecipes: [],
    suggestedEdits: [],
    followUpQuestions: [
      "Would you like a balanced weekly plan?",
      "Do you prefer quick weekday meals?",
      "Should I focus on a specific cuisine?"
    ],
    confidence: 0.8,
    sources: []
  };
}

async function handleGeneralInquiry(intent: any, message: string, context: any, userId: string): Promise<AIReply> {
  return {
    content: "I'm here to help with your meal planning! I can suggest recipes, create meal plans, compare grocery prices, and provide nutrition advice. What would you like to explore?",
    suggestedRecipes: [],
    suggestedEdits: [],
    followUpQuestions: [
      "Would you like recipe suggestions?",
      "Should I help create a meal plan?",
      "Do you need nutrition advice?"
    ],
    confidence: 0.6,
    sources: []
  };
}

// Nutrition advice generation
async function generateNutritionAdvice(
  bodyRegions: BodyRegion[], 
  symptoms: string[], 
  preferences: any, 
  userId: string
): Promise<NutritionAdvice> {
  
  // Aggregate related nutrients from all body regions
  const allRelatedNutrients = bodyRegions.flatMap(region => region.relatedNutrients);
  const uniqueNutrients = [...new Set(allRelatedNutrients)];
  
  // Generate specific recommendations based on regions
  const recommendedNutrients = uniqueNutrients.slice(0, 6); // Top 6 nutrients
  
  // Identify ingredients to avoid (simplified logic)
  const avoidedIngredients = [];
  if (bodyRegions.some(r => r.anatomicalId === 'digestive')) {
    avoidedIngredients.push('processed_foods', 'high_fat', 'spicy');
  }
  if (bodyRegions.some(r => r.anatomicalId === 'heart')) {
    avoidedIngredients.push('high_sodium', 'trans_fat');
  }
  
  // Find recipes that support the recommended nutrients
  const supportiveRecipes = await findNutritionSupportiveRecipes(recommendedNutrients, avoidedIngredients, userId);
  
  // Generate modified meal plan criteria
  const planCriteria = {
    preferences: {
      ...preferences,
      nutritionFocus: recommendedNutrients,
      avoidIngredients: [...(preferences.dislikedIngredients || []), ...avoidedIngredients]
    },
    prioritizeNutrition: true,
    healthGoals: bodyRegions.map(region => ({
      region: region.name,
      focus: region.relatedNutrients
    }))
  };
  
  return {
    bodyRegions,
    recommendedNutrients,
    avoidedIngredients,
    suggestedRecipes: supportiveRecipes.slice(0, 5),
    planCriteria,
    disclaimer: "This advice is for wellness purposes only and not a substitute for professional medical advice. Always consult with a healthcare provider for medical concerns."
  };
}

// Recipe finding helpers
async function findReplacementRecipes(day: number, mealSlot: string, context: any, userId: string) {
  const recipesSnapshot = await db
    .collection('users')
    .doc(userId)
    .collection('recipes')
    .where('status', '==', 'ready')
    .limit(10)
    .get();

  return recipesSnapshot.docs
    .map(doc => doc.data())
    .filter((recipe: any) => {
      // Simple filtering logic
      if (mealSlot === 'breakfast' && recipe.totalTimeMinutes > 20) return false;
      if (mealSlot === 'lunch' && recipe.totalTimeMinutes > 30) return false;
      return true;
    });
}

async function findSuggestedRecipes(params: any, userId: string) {
  let query = db
    .collection('users')
    .doc(userId)
    .collection('recipes')
    .where('status', '==', 'ready');

  if (params.cuisineType) {
    query = query.where('cuisines', 'array-contains', params.cuisineType);
  }

  if (params.timeLimit) {
    query = query.where('totalTimeMinutes', '<=', params.timeLimit);
  }

  const recipesSnapshot = await query.limit(10).get();
  return recipesSnapshot.docs.map(doc => doc.data());
}

async function findNutritionFocusedRecipes(nutritionFocus: string[], userId: string) {
  const recipesSnapshot = await db
    .collection('users')
    .doc(userId)
    .collection('recipes')
    .where('status', '==', 'ready')
    .limit(15)
    .get();

  return recipesSnapshot.docs
    .map(doc => doc.data())
    .filter((recipe: any) => {
      if (!recipe.nutrition) return false;
      
      // Check if recipe meets nutrition focus
      if (nutritionFocus.includes('high_protein') && recipe.nutrition.macros.protein < 15) return false;
      if (nutritionFocus.includes('low_carb') && recipe.nutrition.macros.carbs > 20) return false;
      if (nutritionFocus.includes('high_fiber') && recipe.nutrition.macros.fiber < 5) return false;
      
      return true;
    });
}

async function findNutritionSupportiveRecipes(nutrients: string[], avoided: string[], userId: string) {
  const recipesSnapshot = await db
    .collection('users')
    .doc(userId)
    .collection('recipes')
    .where('status', '==', 'ready')
    .limit(20)
    .get();

  return recipesSnapshot.docs
    .map(doc => doc.data())
    .filter((recipe: any) => {
      // Check if recipe contains avoided ingredients
      const hasAvoided = avoided.some(avoidedIng => 
        recipe.ingredients?.some((ing: any) => 
          ing.name.toLowerCase().includes(avoidedIng)
        )
      );
      
      return !hasAvoided;
    });
}

// Parameter extraction helpers (simplified)
function extractMealReplacementParams(message: string, context: any) {
  const dayMatch = message.match(/day (\d+)/i);
  const day = dayMatch ? parseInt(dayMatch[1]) - 1 : 0;
  
  let mealSlot = 'dinner';
  if (message.toLowerCase().includes('breakfast')) mealSlot = 'breakfast';
  else if (message.toLowerCase().includes('lunch')) mealSlot = 'lunch';
  else if (message.toLowerCase().includes('snack')) mealSlot = 'snack';
  
  return { day, mealSlot };
}

function extractRecipeSuggestionParams(message: string, context: any) {
  const lowerMessage = message.toLowerCase();
  
  let mealType = '';
  if (lowerMessage.includes('breakfast')) mealType = 'breakfast';
  else if (lowerMessage.includes('lunch')) mealType = 'lunch';
  else if (lowerMessage.includes('dinner')) mealType = 'dinner';
  
  let cuisineType = '';
  if (lowerMessage.includes('mediterranean')) cuisineType = 'Mediterranean';
  else if (lowerMessage.includes('moroccan')) cuisineType = 'Moroccan';
  else if (lowerMessage.includes('italian')) cuisineType = 'Italian';
  
  const timeMatch = message.match(/(\d+)\s*(min|minute)/i);
  const timeLimit = timeMatch ? parseInt(timeMatch[1]) : undefined;
  
  return { mealType, cuisineType, timeLimit };
}

function extractNutritionParams(message: string) {
  const lowerMessage = message.toLowerCase();
  const nutritionFocus = [];
  
  if (lowerMessage.includes('protein')) nutritionFocus.push('high_protein');
  if (lowerMessage.includes('low carb')) nutritionFocus.push('low_carb');
  if (lowerMessage.includes('fiber')) nutritionFocus.push('high_fiber');
  if (lowerMessage.includes('heart')) nutritionFocus.push('heart_healthy');
  
  return { nutritionFocus };
}

function extractPlanningParams(message: string, context: any) {
  const lowerMessage = message.toLowerCase();
  
  let theme = '';
  if (lowerMessage.includes('mediterranean')) theme = 'Mediterranean';
  else if (lowerMessage.includes('healthy')) theme = 'Healthy';
  else if (lowerMessage.includes('quick')) theme = 'Quick & Easy';
  
  return { theme };
}

// Conversation storage
async function storeConversation(userId: string, messages: AIMessage[], response: AIReply) {
  try {
    await db
      .collection('users')
      .doc(userId)
      .collection('aiConversations')
      .add({
        messages: messages.map(m => ({
          ...m,
          timestamp: admin.firestore.Timestamp.now()
        })),
        response,
        createdAt: admin.firestore.Timestamp.now()
      });
  } catch (error) {
    logger.warn('Failed to store conversation', { error, userId });
  }
}

// Nutrition data aggregation
async function aggregateNutritionData(plan: any, userId: string) {
  const dailyBreakdown: any[] = [];
  const weeklyTotals = {
    calories: 0,
    protein: 0,
    carbs: 0,
    fat: 0,
    fiber: 0
  };

  for (const day of plan.days) {
    if (day.dailyNutrition) {
      dailyBreakdown.push({
        date: day.date,
        dayOfWeek: day.dayOfWeek,
        nutrition: day.dailyNutrition
      });

      weeklyTotals.calories += day.dailyNutrition.calories;
      weeklyTotals.protein += day.dailyNutrition.macros.protein;
      weeklyTotals.carbs += day.dailyNutrition.macros.carbs;
      weeklyTotals.fat += day.dailyNutrition.macros.fat;
      weeklyTotals.fiber += day.dailyNutrition.macros.fiber;
    }
  }

  return {
    dailyBreakdown,
    weeklyTotals: {
      ...weeklyTotals,
      averageDaily: {
        calories: weeklyTotals.calories / 7,
        protein: weeklyTotals.protein / 7,
        carbs: weeklyTotals.carbs / 7,
        fat: weeklyTotals.fat / 7,
        fiber: weeklyTotals.fiber / 7
      }
    }
  };
}