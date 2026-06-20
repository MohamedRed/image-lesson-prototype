import { onRequest } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';
import { getFirestore } from 'firebase-admin/firestore';
import axios from 'axios';

const db = getFirestore();

// USDA FDC API configuration
const USDA_FDC_BASE_URL = 'https://api.nal.usda.gov/fdc/v1';
const USDA_API_KEY = process.env.USDA_FDC_API_KEY; // Set in Firebase config

interface USDAFood {
  fdcId: number;
  description: string;
  brandName?: string;
  brandOwner?: string;
  foodNutrients: USDANutrient[];
  foodCategory?: {
    description: string;
  };
}

interface USDANutrient {
  nutrient: {
    id: number;
    number: string;
    name: string;
    unitName: string;
  };
  amount: number;
}

interface NutritionData {
  fdcId: number;
  description: string;
  brandName?: string;
  category?: string;
  nutrients: {
    calories?: number;
    protein?: number; // grams
    carbs?: number; // grams
    totalFat?: number; // grams
    saturatedFat?: number; // grams
    fiber?: number; // grams
    sugars?: number; // grams
    sodium?: number; // milligrams
    calcium?: number; // milligrams
    iron?: number; // milligrams
    vitaminC?: number; // milligrams
    vitaminA?: number; // IU
    potassium?: number; // milligrams
  };
  servingSize?: number;
  servingUnit?: string;
}

// MARK: - Search Foods

export const searchFoods = onRequest(async (req, res) => {
  try {
    if (req.method !== 'POST') {
      res.status(405).send('Method not allowed');
      return;
    }

    const { query, pageSize = 25, pageNumber = 1 } = req.body;

    if (!query || typeof query !== 'string') {
      res.status(400).send('Query parameter is required');
      return;
    }

    logger.info(`Searching USDA FDC for: ${query}`);

    // Search USDA database
    const searchResults = await searchUSDAFoods(query, pageSize, pageNumber);

    // Cache results in Firestore for faster future access
    await cacheSearchResults(query, searchResults);

    res.json({
      foods: searchResults,
      totalResults: searchResults.length
    });

  } catch (error) {
    logger.error('Error searching foods:', error);
    res.status(500).json({ 
      error: 'Failed to search foods',
      message: error.message 
    });
  }
});

async function searchUSDAFoods(query: string, pageSize: number, pageNumber: number): Promise<NutritionData[]> {
  if (!USDA_API_KEY) {
    throw new Error('USDA FDC API key not configured');
  }

  try {
    const response = await axios.post(
      `${USDA_FDC_BASE_URL}/foods/search`,
      {
        query,
        pageSize,
        pageNumber,
        dataType: ['Foundation', 'SR Legacy', 'Branded'], // Include multiple data types
        sortBy: 'relevance'
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': USDA_API_KEY
        }
      }
    );

    const foods = response.data.foods || [];
    return foods.map(mapUSDAFoodToNutritionData);

  } catch (error) {
    if (error.response?.status === 429) {
      logger.warn('USDA API rate limit exceeded, returning cached results');
      return getCachedSearchResults(query);
    }
    throw error;
  }
}

function mapUSDAFoodToNutritionData(usdaFood: USDAFood): NutritionData {
  const nutrients: any = {};

  // Map USDA nutrients to our standard format
  for (const foodNutrient of usdaFood.foodNutrients) {
    const nutrient = foodNutrient.nutrient;
    const amount = foodNutrient.amount;

    switch (nutrient.number) {
      case '208': // Energy (calories)
        nutrients.calories = Math.round(amount);
        break;
      case '203': // Protein
        nutrients.protein = Math.round(amount * 100) / 100;
        break;
      case '205': // Carbohydrates
        nutrients.carbs = Math.round(amount * 100) / 100;
        break;
      case '204': // Total Fat
        nutrients.totalFat = Math.round(amount * 100) / 100;
        break;
      case '606': // Saturated Fat
        nutrients.saturatedFat = Math.round(amount * 100) / 100;
        break;
      case '291': // Dietary Fiber
        nutrients.fiber = Math.round(amount * 100) / 100;
        break;
      case '269': // Sugars
        nutrients.sugars = Math.round(amount * 100) / 100;
        break;
      case '307': // Sodium
        nutrients.sodium = Math.round(amount);
        break;
      case '301': // Calcium
        nutrients.calcium = Math.round(amount);
        break;
      case '303': // Iron
        nutrients.iron = Math.round(amount * 100) / 100;
        break;
      case '401': // Vitamin C
        nutrients.vitaminC = Math.round(amount * 100) / 100;
        break;
      case '318': // Vitamin A
        nutrients.vitaminA = Math.round(amount);
        break;
      case '306': // Potassium
        nutrients.potassium = Math.round(amount);
        break;
    }
  }

  return {
    fdcId: usdaFood.fdcId,
    description: usdaFood.description,
    brandName: usdaFood.brandName,
    category: usdaFood.foodCategory?.description,
    nutrients,
    servingSize: 100, // USDA data is typically per 100g
    servingUnit: 'g'
  };
}

async function cacheSearchResults(query: string, results: NutritionData[]): Promise<void> {
  try {
    await db.collection('nutritionCache').doc(query.toLowerCase()).set({
      query: query.toLowerCase(),
      results,
      cachedAt: new Date(),
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) // Cache for 7 days
    });
  } catch (error) {
    logger.warn('Failed to cache search results:', error);
  }
}

async function getCachedSearchResults(query: string): Promise<NutritionData[]> {
  try {
    const cacheDoc = await db.collection('nutritionCache').doc(query.toLowerCase()).get();
    
    if (cacheDoc.exists) {
      const data = cacheDoc.data()!;
      
      // Check if cache is still valid
      if (data.expiresAt.toDate() > new Date()) {
        return data.results || [];
      } else {
        // Clean up expired cache
        await cacheDoc.ref.delete();
      }
    }
    
    return [];
  } catch (error) {
    logger.warn('Failed to get cached search results:', error);
    return [];
  }
}

// MARK: - Get Food Details

export const getFoodDetails = onRequest(async (req, res) => {
  try {
    if (req.method !== 'GET') {
      res.status(405).send('Method not allowed');
      return;
    }

    const fdcId = req.query.fdcId as string;

    if (!fdcId) {
      res.status(400).send('fdcId parameter is required');
      return;
    }

    logger.info(`Getting food details for FDC ID: ${fdcId}`);

    // Check cache first
    const cachedFood = await getCachedFoodDetails(fdcId);
    if (cachedFood) {
      res.json(cachedFood);
      return;
    }

    // Fetch from USDA API
    const foodDetails = await getUSDAFoodDetails(fdcId);

    // Cache the result
    await cacheFoodDetails(fdcId, foodDetails);

    res.json(foodDetails);

  } catch (error) {
    logger.error('Error getting food details:', error);
    res.status(500).json({ 
      error: 'Failed to get food details',
      message: error.message 
    });
  }
});

async function getUSDAFoodDetails(fdcId: string): Promise<NutritionData> {
  if (!USDA_API_KEY) {
    throw new Error('USDA FDC API key not configured');
  }

  try {
    const response = await axios.get(
      `${USDA_FDC_BASE_URL}/food/${fdcId}`,
      {
        headers: {
          'X-API-Key': USDA_API_KEY
        }
      }
    );

    return mapUSDAFoodToNutritionData(response.data);

  } catch (error) {
    if (error.response?.status === 404) {
      throw new Error(`Food with FDC ID ${fdcId} not found`);
    }
    throw error;
  }
}

async function getCachedFoodDetails(fdcId: string): Promise<NutritionData | null> {
  try {
    const cacheDoc = await db.collection('nutritionDetails').doc(fdcId).get();
    
    if (cacheDoc.exists) {
      const data = cacheDoc.data()!;
      
      // Check if cache is still valid (30 days)
      if (data.expiresAt.toDate() > new Date()) {
        return data.details;
      } else {
        // Clean up expired cache
        await cacheDoc.ref.delete();
      }
    }
    
    return null;
  } catch (error) {
    logger.warn('Failed to get cached food details:', error);
    return null;
  }
}

async function cacheFoodDetails(fdcId: string, details: NutritionData): Promise<void> {
  try {
    await db.collection('nutritionDetails').doc(fdcId).set({
      fdcId,
      details,
      cachedAt: new Date(),
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // Cache for 30 days
    });
  } catch (error) {
    logger.warn('Failed to cache food details:', error);
  }
}

// MARK: - Ingredient Matching

export const matchIngredients = onRequest(async (req, res) => {
  try {
    if (req.method !== 'POST') {
      res.status(405).send('Method not allowed');
      return;
    }

    const { ingredients } = req.body;

    if (!Array.isArray(ingredients)) {
      res.status(400).send('ingredients must be an array');
      return;
    }

    logger.info(`Matching ${ingredients.length} ingredients to USDA database`);

    const matches = await Promise.all(
      ingredients.map(async (ingredient: any) => {
        const match = await findBestNutritionMatch(ingredient.name);
        return {
          originalName: ingredient.name,
          quantity: ingredient.quantity,
          unit: ingredient.unit,
          match: match
        };
      })
    );

    res.json({ matches });

  } catch (error) {
    logger.error('Error matching ingredients:', error);
    res.status(500).json({ 
      error: 'Failed to match ingredients',
      message: error.message 
    });
  }
});

async function findBestNutritionMatch(ingredientName: string): Promise<NutritionData | null> {
  // Clean up the ingredient name for better matching
  const cleanName = cleanIngredientName(ingredientName);
  
  // Try exact match first from cache
  const cachedMatch = await getCachedIngredientMatch(cleanName);
  if (cachedMatch) {
    return cachedMatch;
  }

  // Search USDA database
  try {
    const searchResults = await searchUSDAFoods(cleanName, 5, 1);
    
    if (searchResults.length > 0) {
      const bestMatch = searchResults[0]; // Take the most relevant result
      
      // Cache the match
      await cacheIngredientMatch(cleanName, bestMatch);
      
      return bestMatch;
    }
    
    return null;
  } catch (error) {
    logger.warn(`Failed to find nutrition match for ${ingredientName}:`, error);
    return null;
  }
}

function cleanIngredientName(name: string): string {
  return name
    .toLowerCase()
    .replace(/\(.*\)/g, '') // Remove parentheses content
    .replace(/[,\-]/g, ' ') // Replace commas and dashes with spaces
    .replace(/\s+/g, ' ') // Normalize whitespace
    .trim();
}

async function getCachedIngredientMatch(ingredientName: string): Promise<NutritionData | null> {
  try {
    const cacheDoc = await db.collection('ingredientMatches').doc(ingredientName).get();
    
    if (cacheDoc.exists) {
      const data = cacheDoc.data()!;
      
      // Check if cache is still valid (14 days)
      if (data.expiresAt.toDate() > new Date()) {
        return data.match;
      } else {
        // Clean up expired cache
        await cacheDoc.ref.delete();
      }
    }
    
    return null;
  } catch (error) {
    logger.warn('Failed to get cached ingredient match:', error);
    return null;
  }
}

async function cacheIngredientMatch(ingredientName: string, match: NutritionData): Promise<void> {
  try {
    await db.collection('ingredientMatches').doc(ingredientName).set({
      ingredientName,
      match,
      cachedAt: new Date(),
      expiresAt: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000) // Cache for 14 days
    });
  } catch (error) {
    logger.warn('Failed to cache ingredient match:', error);
  }
}

// MARK: - Recipe Nutrition Calculation

export const calculateRecipeNutrition = onRequest(async (req, res) => {
  try {
    if (req.method !== 'POST') {
      res.status(405).send('Method not allowed');
      return;
    }

    const { recipeId, ingredients, servings = 1 } = req.body;

    if (!Array.isArray(ingredients)) {
      res.status(400).send('ingredients must be an array');
      return;
    }

    logger.info(`Calculating nutrition for recipe ${recipeId} with ${ingredients.length} ingredients`);

    // Match ingredients to nutrition database
    const nutritionMatches = await Promise.all(
      ingredients.map(async (ingredient: any) => {
        const match = await findBestNutritionMatch(ingredient.name);
        return {
          ingredient,
          nutritionData: match
        };
      })
    );

    // Calculate total nutrition
    const totalNutrition = calculateTotalNutrition(nutritionMatches, servings);

    // Cache the calculated nutrition
    if (recipeId) {
      await cacheRecipeNutrition(recipeId, totalNutrition);
    }

    res.json({
      recipeId,
      servings,
      nutrition: totalNutrition,
      ingredientMatches: nutritionMatches.map(m => ({
        ingredient: m.ingredient.name,
        matched: !!m.nutritionData,
        fdcId: m.nutritionData?.fdcId
      }))
    });

  } catch (error) {
    logger.error('Error calculating recipe nutrition:', error);
    res.status(500).json({ 
      error: 'Failed to calculate recipe nutrition',
      message: error.message 
    });
  }
});

function calculateTotalNutrition(matches: any[], servings: number): any {
  const total = {
    calories: 0,
    protein: 0,
    carbs: 0,
    totalFat: 0,
    saturatedFat: 0,
    fiber: 0,
    sugars: 0,
    sodium: 0,
    calcium: 0,
    iron: 0,
    vitaminC: 0,
    vitaminA: 0,
    potassium: 0
  };

  for (const match of matches) {
    if (!match.nutritionData) continue;

    const ingredient = match.ingredient;
    const nutrition = match.nutritionData.nutrients;
    
    // Convert ingredient quantity to grams for calculation
    const gramsMultiplier = convertToGrams(ingredient.quantity, ingredient.unit);
    
    // Scale nutrition data (USDA is per 100g)
    const scale = gramsMultiplier / 100;

    // Add to totals
    Object.keys(total).forEach(key => {
      if (nutrition[key]) {
        total[key] += nutrition[key] * scale;
      }
    });
  }

  // Divide by servings to get per-serving values
  Object.keys(total).forEach(key => {
    total[key] = Math.round((total[key] / servings) * 100) / 100;
  });

  return total;
}

function convertToGrams(quantity: number, unit: string): number {
  // Simplified conversion - in production, this would be more comprehensive
  const conversions: { [key: string]: number } = {
    'g': 1,
    'gram': 1,
    'grams': 1,
    'kg': 1000,
    'kilogram': 1000,
    'lb': 453.592,
    'pound': 453.592,
    'oz': 28.3495,
    'ounce': 28.3495,
    'cup': 240, // Approximate for liquids
    'tbsp': 15,
    'tablespoon': 15,
    'tsp': 5,
    'teaspoon': 5,
    'ml': 1, // Assuming 1ml ≈ 1g for liquids
    'liter': 1000,
    'l': 1000
  };

  const normalizedUnit = unit.toLowerCase().trim();
  const multiplier = conversions[normalizedUnit] || 100; // Default to 100g if unknown
  
  return quantity * multiplier;
}

async function cacheRecipeNutrition(recipeId: string, nutrition: any): Promise<void> {
  try {
    await db.collection('recipeNutrition').doc(recipeId).set({
      recipeId,
      nutrition,
      calculatedAt: new Date(),
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) // Cache for 7 days
    });
  } catch (error) {
    logger.warn('Failed to cache recipe nutrition:', error);
  }
}