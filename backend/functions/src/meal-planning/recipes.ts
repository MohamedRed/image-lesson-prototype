import { onCall, onRequest, CallableRequest } from "firebase-functions/v2/https";
import { onTaskDispatched } from "firebase-functions/v2/tasks";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { PubSub } from "@google-cloud/pubsub";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";

const db = getFirestore();
const pubsub = new PubSub();

// Types
interface RecipeImportRequest {
  url: string;
}

interface Recipe {
  id?: string;
  title: string;
  description: string;
  images: string[];
  videoUrl?: string;
  sourcePlatform: 'instagram' | 'tiktok' | 'youtube' | 'web';
  sourceAuthor?: string;
  sourceAttribution?: string;
  tags: string[];
  cuisines: string[];
  steps: RecipeStep[];
  ingredients: Ingredient[];
  utensils: Utensil[];
  nutrition?: NutrientProfile;
  servings: number;
  prepTimeMinutes: number;
  cookTimeMinutes: number;
  totalTimeMinutes: number;
  difficultyLevel: 'beginner' | 'intermediate' | 'advanced';
  status: 'draft' | 'processing' | 'ready' | 'failed';
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
}

interface RecipeStep {
  id: string;
  stepNumber: number;
  startTime?: number;
  endTime?: number;
  instruction: string;
  shortInstruction?: string;
  utensilRefs: string[];
  timerSeconds?: number;
  videoClipUrl?: string;
  temperature?: {
    value: number;
    unit: 'celsius' | 'fahrenheit';
  };
  notes?: string;
}

interface Ingredient {
  id: string;
  name: string;
  quantity?: number;
  unit?: string;
  notes?: string;
  substitutions: string[];
  allergens: string[];
  category?: string;
  isOptional: boolean;
}

interface Utensil {
  id: string;
  name: string;
  category: string;
  isEssential: boolean;
  alternatives: string[];
}

interface NutrientProfile {
  calories: number;
  macros: {
    protein: number;
    carbs: number;
    fat: number;
    fiber: number;
    sugar: number;
  };
  micronutrients: Record<string, number>;
  perServing: boolean;
}

interface ImportProgress {
  recipeId: string;
  stage: 'fetching' | 'extracting' | 'transcribing' | 'segmenting' | 'analyzing' | 'completed' | 'failed';
  progress: number;
  message: string;
  error?: string;
}

// Recipe Import - Main entry point
export const importRecipe = onCall(
  {
    region: 'us-central1',
    timeoutSeconds: 60,
    memory: '512MiB'
  },
  async (request: CallableRequest<RecipeImportRequest>) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new Error('Authentication required');
    }

    const { url } = request.data;
    if (!url || !isValidUrl(url)) {
      throw new Error('Valid URL required');
    }

    try {
      // Create recipe document in draft state
      const recipeId = db.collection('users').doc(userId).collection('recipes').doc().id;
      
      const initialRecipe: Partial<Recipe> = {
        id: recipeId,
        title: 'Importing...',
        description: 'Recipe is being imported',
        images: [],
        videoUrl: url,
        sourcePlatform: detectPlatform(url),
        tags: ['importing'],
        cuisines: [],
        steps: [],
        ingredients: [],
        utensils: [],
        servings: 1,
        prepTimeMinutes: 0,
        cookTimeMinutes: 0,
        totalTimeMinutes: 0,
        difficultyLevel: 'beginner',
        status: 'processing',
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now()
      };

      await db.collection('users').doc(userId).collection('recipes').doc(recipeId).set(initialRecipe);

      // Trigger async import pipeline
      const task = {
        recipeId,
        userId,
        url,
        sourcePlatform: detectPlatform(url)
      };

      await pubsub.topic('recipe-import-pipeline').publishMessage({
        json: task
      });

      logger.info('Recipe import initiated', { recipeId, userId, url });
      return { recipeId };

    } catch (error) {
      logger.error('Recipe import failed', { error, userId, url });
      throw new Error('Failed to start recipe import');
    }
  }
);

// Get recipe by ID
export const getRecipe = onCall(
  {
    region: 'us-central1',
    timeoutSeconds: 30
  },
  async (request: CallableRequest<{ recipeId: string }>) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new Error('Authentication required');
    }

    const { recipeId } = request.data;
    if (!recipeId) {
      throw new Error('Recipe ID required');
    }

    try {
      const recipeDoc = await db
        .collection('users')
        .doc(userId)
        .collection('recipes')
        .doc(recipeId)
        .get();

      if (!recipeDoc.exists) {
        throw new Error('Recipe not found');
      }

      return recipeDoc.data();
    } catch (error) {
      logger.error('Failed to get recipe', { error, userId, recipeId });
      throw new Error('Failed to retrieve recipe');
    }
  }
);

// Search recipes
export const searchRecipes = onCall(
  {
    region: 'us-central1',
    timeoutSeconds: 30
  },
  async (request: CallableRequest<{ query: string; filters?: any }>) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new Error('Authentication required');
    }

    const { query, filters } = request.data;
    if (!query) {
      throw new Error('Search query required');
    }

    try {
      // Search in user's recipes
      let recipesQuery = db
        .collection('users')
        .doc(userId)
        .collection('recipes')
        .where('status', '==', 'ready')
        .limit(20);

      // Apply filters if provided
      if (filters?.cuisines && filters.cuisines.length > 0) {
        recipesQuery = recipesQuery.where('cuisines', 'array-contains-any', filters.cuisines);
      }

      if (filters?.maxPrepTime) {
        recipesQuery = recipesQuery.where('prepTimeMinutes', '<=', filters.maxPrepTime);
      }

      if (filters?.difficulty) {
        recipesQuery = recipesQuery.where('difficultyLevel', '==', filters.difficulty);
      }

      const recipesSnapshot = await recipesQuery.get();
      let results = recipesSnapshot.docs.map(doc => doc.data());

      // Client-side text search (in production, use Algolia or similar)
      const searchTerms = query.toLowerCase().split(' ');
      results = results.filter((recipe: any) => {
        const searchText = [
          recipe.title,
          recipe.description,
          ...(recipe.tags || []),
          ...(recipe.cuisines || [])
        ].join(' ').toLowerCase();

        return searchTerms.some(term => searchText.includes(term));
      });

      // Also search in global recipe index (curated recipes)
      const globalQuery = db
        .collection('recipeIndex')
        .where('status', '==', 'ready')
        .limit(10);

      const globalSnapshot = await globalQuery.get();
      const globalResults = globalSnapshot.docs
        .map(doc => doc.data())
        .filter((recipe: any) => {
          const searchText = [
            recipe.title,
            recipe.description,
            ...(recipe.tags || []),
            ...(recipe.cuisines || [])
          ].join(' ').toLowerCase();

          return searchTerms.some(term => searchText.includes(term));
        });

      return {
        userRecipes: results,
        globalRecipes: globalResults
      };

    } catch (error) {
      logger.error('Recipe search failed', { error, userId, query });
      throw new Error('Search failed');
    }
  }
);

// Get user's recipes
export const getMyRecipes = onCall(
  {
    region: 'us-central1',
    timeoutSeconds: 30
  },
  async (request: CallableRequest<{ limit?: number }>) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new Error('Authentication required');
    }

    const { limit = 50 } = request.data;

    try {
      const recipesSnapshot = await db
        .collection('users')
        .doc(userId)
        .collection('recipes')
        .where('status', '==', 'ready')
        .orderBy('updatedAt', 'desc')
        .limit(limit)
        .get();

      return recipesSnapshot.docs.map(doc => doc.data());
    } catch (error) {
      logger.error('Failed to get user recipes', { error, userId });
      throw new Error('Failed to retrieve recipes');
    }
  }
);

// Save recipe
export const saveRecipe = onCall(
  {
    region: 'us-central1',
    timeoutSeconds: 30
  },
  async (request: CallableRequest<{ recipe: Recipe }>) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new Error('Authentication required');
    }

    const { recipe } = request.data;
    if (!recipe) {
      throw new Error('Recipe data required');
    }

    try {
      const recipeId = recipe.id || db.collection('users').doc(userId).collection('recipes').doc().id;
      
      const recipeData = {
        ...recipe,
        id: recipeId,
        updatedAt: admin.firestore.Timestamp.now(),
        ...(recipe.id ? {} : { createdAt: admin.firestore.Timestamp.now() })
      };

      await db
        .collection('users')
        .doc(userId)
        .collection('recipes')
        .doc(recipeId)
        .set(recipeData, { merge: true });

      return { recipeId };
    } catch (error) {
      logger.error('Failed to save recipe', { error, userId });
      throw new Error('Failed to save recipe');
    }
  }
);

// Delete recipe
export const deleteRecipe = onCall(
  {
    region: 'us-central1',
    timeoutSeconds: 30
  },
  async (request: CallableRequest<{ recipeId: string }>) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new Error('Authentication required');
    }

    const { recipeId } = request.data;
    if (!recipeId) {
      throw new Error('Recipe ID required');
    }

    try {
      await db
        .collection('users')
        .doc(userId)
        .collection('recipes')
        .doc(recipeId)
        .delete();

      return { success: true };
    } catch (error) {
      logger.error('Failed to delete recipe', { error, userId, recipeId });
      throw new Error('Failed to delete recipe');
    }
  }
);

// Recipe suggestions
export const getRecipeSuggestions = onCall(
  {
    region: 'us-central1',
    timeoutSeconds: 30
  },
  async (request: CallableRequest<{
    mealSlot?: 'breakfast' | 'lunch' | 'dinner' | 'snack';
    dietary: string[];
    allergies: string[];
    cuisines: string[];
    maxTimeMinutes?: number;
    nutritionFocus: string[];
    excludeRecipeIds: string[];
  }>) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new Error('Authentication required');
    }

    const { 
      mealSlot, 
      dietary, 
      allergies, 
      cuisines, 
      maxTimeMinutes, 
      nutritionFocus,
      excludeRecipeIds 
    } = request.data;

    try {
      // Build query for user's recipes
      let query = db
        .collection('users')
        .doc(userId)
        .collection('recipes')
        .where('status', '==', 'ready');

      // Apply filters
      if (cuisines.length > 0) {
        query = query.where('cuisines', 'array-contains-any', cuisines);
      }

      if (maxTimeMinutes) {
        query = query.where('totalTimeMinutes', '<=', maxTimeMinutes);
      }

      const recipesSnapshot = await query.limit(20).get();
      let suggestions = recipesSnapshot.docs.map(doc => doc.data());

      // Filter out excluded recipes
      if (excludeRecipeIds.length > 0) {
        suggestions = suggestions.filter((recipe: any) => 
          !excludeRecipeIds.includes(recipe.id)
        );
      }

      // Apply dietary restrictions and allergy filters
      suggestions = suggestions.filter((recipe: any) => {
        // Check dietary restrictions
        if (dietary.includes('vegetarian') && recipe.tags.some((tag: string) => 
          ['meat', 'chicken', 'beef', 'pork', 'fish'].includes(tag.toLowerCase())
        )) {
          return false;
        }

        if (dietary.includes('vegan') && recipe.tags.some((tag: string) => 
          ['meat', 'chicken', 'beef', 'pork', 'fish', 'dairy', 'eggs'].includes(tag.toLowerCase())
        )) {
          return false;
        }

        // Check allergies
        if (allergies.length > 0) {
          const recipeAllergens = recipe.ingredients?.flatMap((ing: any) => ing.allergens || []) || [];
          if (allergies.some(allergy => recipeAllergens.includes(allergy))) {
            return false;
          }
        }

        return true;
      });

      // Score and sort by relevance
      suggestions = suggestions.map((recipe: any) => {
        let score = 0;

        // Meal slot preference
        if (mealSlot) {
          if (recipe.tags.includes(mealSlot)) score += 2;
          
          // Time-based scoring for meal slots
          if (mealSlot === 'breakfast' && recipe.totalTimeMinutes <= 20) score += 1;
          if (mealSlot === 'lunch' && recipe.totalTimeMinutes <= 30) score += 1;
          if (mealSlot === 'snack' && recipe.totalTimeMinutes <= 15) score += 1;
        }

        // Nutrition focus scoring
        if (nutritionFocus.length > 0 && recipe.nutrition) {
          if (nutritionFocus.includes('high_protein') && recipe.nutrition.macros.protein > 20) score += 1;
          if (nutritionFocus.includes('low_carb') && recipe.nutrition.macros.carbs < 20) score += 1;
          if (nutritionFocus.includes('high_fiber') && recipe.nutrition.macros.fiber > 5) score += 1;
        }

        // Cuisine preference
        if (cuisines.length > 0) {
          const matchingCuisines = recipe.cuisines.filter((c: string) => cuisines.includes(c));
          score += matchingCuisines.length;
        }

        return { ...recipe, relevanceScore: score };
      });

      // Sort by relevance score and return top suggestions
      suggestions.sort((a: any, b: any) => b.relevanceScore - a.relevanceScore);

      return suggestions.slice(0, 10);

    } catch (error) {
      logger.error('Failed to get recipe suggestions', { error, userId });
      throw new Error('Failed to get suggestions');
    }
  }
);

// Recipe import progress webhook (for progress updates)
export const recipeImportProgress = onRequest(
  {
    region: 'us-central1',
    timeoutSeconds: 60
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('Method not allowed');
      return;
    }

    try {
      const progress: ImportProgress = req.body;
      
      // Broadcast progress to client via Firestore document update
      await db
        .collection('recipeImportProgress')
        .doc(progress.recipeId)
        .set({
          ...progress,
          updatedAt: admin.firestore.Timestamp.now()
        });

      // If completed or failed, update the recipe status
      if (progress.stage === 'completed' || progress.stage === 'failed') {
        // Extract userId from recipe path
        const recipeDoc = await db.collectionGroup('recipes').where('id', '==', progress.recipeId).get();
        
        if (!recipeDoc.empty) {
          const recipeRef = recipeDoc.docs[0].ref;
          await recipeRef.update({
            status: progress.stage === 'completed' ? 'ready' : 'failed',
            updatedAt: admin.firestore.Timestamp.now()
          });
        }
      }

      res.status(200).send('OK');
    } catch (error) {
      logger.error('Failed to update import progress', { error, body: req.body });
      res.status(500).send('Internal server error');
    }
  }
);

// Process recipe import pipeline (Cloud Task)
export const processRecipeImport = onTaskDispatched(
  {
    region: 'us-central1',
    retryConfig: {
      maxAttempts: 3,
      maxRetrySeconds: 300
    },
    rateLimits: {
      maxConcurrentDispatches: 10
    }
  },
  async (req) => {
    const { recipeId, userId, url, sourcePlatform } = req.data;

    try {
      logger.info('Processing recipe import', { recipeId, userId, url });

      // Step 1: Fetch metadata
      await updateProgress(recipeId, 'fetching', 0.1, 'Fetching recipe metadata...');
      
      const metadata = await fetchRecipeMetadata(url, sourcePlatform);
      
      // Step 2: Extract content
      await updateProgress(recipeId, 'extracting', 0.3, 'Extracting recipe content...');
      
      const content = await extractRecipeContent(url, metadata);
      
      // Step 3: Process with AI (if available)
      await updateProgress(recipeId, 'analyzing', 0.6, 'Analyzing recipe with AI...');
      
      const processedRecipe = await processRecipeWithAI(content, metadata);
      
      // Step 4: Save final recipe
      await updateProgress(recipeId, 'completed', 1.0, 'Recipe import completed!');
      
      const finalRecipe: Partial<Recipe> = {
        ...processedRecipe,
        id: recipeId,
        status: 'ready',
        updatedAt: admin.firestore.Timestamp.now()
      };

      await db
        .collection('users')
        .doc(userId)
        .collection('recipes')
        .doc(recipeId)
        .update(finalRecipe);

      logger.info('Recipe import completed successfully', { recipeId, userId });

    } catch (error) {
      logger.error('Recipe import failed', { error, recipeId, userId, url });
      
      await updateProgress(
        recipeId, 
        'failed', 
        0, 
        'Import failed', 
        error instanceof Error ? error.message : 'Unknown error'
      );

      await db
        .collection('users')
        .doc(userId)
        .collection('recipes')
        .doc(recipeId)
        .update({
          status: 'failed',
          updatedAt: admin.firestore.Timestamp.now()
        });
    }
  }
);

// Helper functions
function isValidUrl(string: string): boolean {
  try {
    new URL(string);
    return true;
  } catch (_) {
    return false;
  }
}

function detectPlatform(url: string): Recipe['sourcePlatform'] {
  if (url.includes('instagram.com')) return 'instagram';
  if (url.includes('tiktok.com')) return 'tiktok';
  if (url.includes('youtube.com') || url.includes('youtu.be')) return 'youtube';
  return 'web';
}

async function updateProgress(
  recipeId: string,
  stage: ImportProgress['stage'],
  progress: number,
  message: string,
  error?: string
) {
  const progressData: ImportProgress = {
    recipeId,
    stage,
    progress,
    message,
    ...(error && { error })
  };

  await db
    .collection('recipeImportProgress')
    .doc(recipeId)
    .set({
      ...progressData,
      updatedAt: admin.firestore.Timestamp.now()
    });
}

async function fetchRecipeMetadata(url: string, platform: string) {
  // Implementation would use platform-specific APIs or web scraping
  // For now, returning mock data
  return {
    title: 'Imported Recipe',
    description: 'A delicious recipe imported from social media',
    author: 'Chef Unknown',
    images: [],
    videoUrl: url
  };
}

async function extractRecipeContent(url: string, metadata: any) {
  // Implementation would:
  // 1. Download video/content if needed
  // 2. Extract transcript using speech-to-text
  // 3. Parse HTML content for structured data
  // 4. Extract images and thumbnails
  
  return {
    transcript: 'Recipe transcript would be here...',
    ingredients: [],
    steps: [],
    images: metadata.images || []
  };
}

async function processRecipeWithAI(content: any, metadata: any): Promise<Partial<Recipe>> {
  // Implementation would use OpenAI/PaLM API to:
  // 1. Parse transcript into structured steps
  // 2. Extract ingredients with quantities
  // 3. Identify cooking techniques and utensils
  // 4. Estimate nutrition information
  // 5. Classify difficulty and cuisines
  
  return {
    title: metadata.title,
    description: metadata.description,
    images: content.images,
    videoUrl: metadata.videoUrl,
    sourceAuthor: metadata.author,
    tags: ['imported'],
    cuisines: ['International'],
    steps: [
      {
        id: '1',
        stepNumber: 1,
        instruction: 'Follow the video instructions',
        shortInstruction: 'Follow video',
        utensilRefs: [],
        timerSeconds: undefined,
        videoClipUrl: undefined,
        temperature: undefined,
        notes: undefined
      }
    ],
    ingredients: [
      {
        id: '1',
        name: 'Main ingredient',
        quantity: 1,
        unit: 'piece',
        notes: undefined,
        substitutions: [],
        allergens: [],
        category: 'produce',
        isOptional: false
      }
    ],
    utensils: [
      {
        id: '1',
        name: 'Basic cooking utensils',
        category: 'cookware',
        isEssential: true,
        alternatives: []
      }
    ],
    nutrition: {
      calories: 300,
      macros: {
        protein: 15,
        carbs: 30,
        fat: 15,
        fiber: 5,
        sugar: 10
      },
      micronutrients: {},
      perServing: true
    },
    servings: 2,
    prepTimeMinutes: 10,
    cookTimeMinutes: 20,
    totalTimeMinutes: 30,
    difficultyLevel: 'intermediate'
  };
}