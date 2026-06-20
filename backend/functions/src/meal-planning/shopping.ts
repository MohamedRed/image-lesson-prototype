import { onCall, CallableRequest } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";

const db = getFirestore();

// Types
interface ShoppingList {
  id?: string;
  mealPlanId: string;
  userId: string;
  normalizedItems: GroceryItem[];
  estimatedTotal?: { amount: number; currency: string };
  stores: StoreInfo[];
  status: 'draft' | 'ready' | 'inProgress' | 'completed';
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
}

interface GroceryItem {
  id: string;
  ingredientKey: string;
  displayName: string;
  totalQuantity: number;
  unit: string;
  category: string;
  preferredBrands: string[];
  substitutions: string[];
  storeMappings: Record<string, StoreSKU>;
  priceEstimates: StorePrice[];
  recipeReferences: RecipeReference[];
  isPurchased: boolean;
  notes?: string;
}

interface StoreSKU {
  sku: string;
  productName: string;
  brand?: string;
  packageSize?: string;
  unitPrice: { amount: number; currency: string };
}

interface StorePrice {
  storeId: string;
  storeName: string;
  price: { amount: number; currency: string };
  availability: 'available' | 'lowStock' | 'outOfStock' | 'unknown';
  lastUpdated: admin.firestore.Timestamp;
  promotionText?: string;
}

interface StoreInfo {
  id: string;
  name: string;
  address: string;
  coordinates?: { latitude: number; longitude: number };
  pickupAvailable: boolean;
  deliveryAvailable: boolean;
  estimatedTotal?: { amount: number; currency: string };
  estimatedPickupTime?: string;
  estimatedDeliveryTime?: string;
}

interface RecipeReference {
  recipeId: string;
  recipeName: string;
  quantity: number;
  unit: string;
}

interface ShoppingOrder {
  id?: string;
  shoppingListId: string;
  storeId: string;
  items: OrderItem[];
  total: { amount: number; currency: string };
  fulfillmentType: 'pickup' | 'delivery' | 'curbside';
  status: 'pending' | 'confirmed' | 'preparing' | 'ready' | 'completed' | 'cancelled';
  estimatedReadyAt?: admin.firestore.Timestamp;
  trackingInfo?: string;
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
}

interface OrderItem {
  id: string;
  sku: string;
  productName: string;
  quantity: number;
  unitPrice: { amount: number; currency: string };
  totalPrice: { amount: number; currency: string };
}

// Get shopping list for meal plan
export const getShoppingList = onCall(
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
      // Check if shopping list already exists
      const existingListSnapshot = await db
        .collection('users')
        .doc(userId)
        .collection('shoppingLists')
        .where('mealPlanId', '==', planId)
        .limit(1)
        .get();

      if (!existingListSnapshot.empty) {
        return existingListSnapshot.docs[0].data();
      }

      // Generate new shopping list from meal plan
      const mealPlan = await getMealPlanData(userId, planId);
      if (!mealPlan) {
        throw new Error('Meal plan not found');
      }

      const shoppingList = await generateShoppingList(mealPlan, userId);
      return shoppingList;

    } catch (error) {
      logger.error('Failed to get shopping list', { error, userId, planId });
      throw new Error('Failed to generate shopping list');
    }
  }
);

// Compare prices across stores
export const priceCompare = onCall(
  {
    region: 'us-central1',
    timeoutSeconds: 60
  },
  async (request: CallableRequest<{ listId: string; stores: string[] }>) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new Error('Authentication required');
    }

    const { listId, stores } = request.data;
    if (!listId || !stores || stores.length === 0) {
      throw new Error('List ID and stores required');
    }

    try {
      const listRef = db.collection('users').doc(userId).collection('shoppingLists').doc(listId);
      const listDoc = await listRef.get();

      if (!listDoc.exists) {
        throw new Error('Shopping list not found');
      }

      const shoppingList = listDoc.data() as ShoppingList;

      // Update prices for each item across all stores
      const updatedItems = await Promise.all(
        shoppingList.normalizedItems.map(async (item) => {
          const updatedPrices = await fetchPricesForItem(item, stores);
          return {
            ...item,
            priceEstimates: updatedPrices,
            storeMappings: await updateStoreMappings(item, stores)
          };
        })
      );

      // Calculate totals for each store
      const storeInfos = stores.map(storeId => {
        const storeTotal = updatedItems.reduce((total, item) => {
          const storePrice = item.priceEstimates.find(p => p.storeId === storeId);
          return total + (storePrice ? storePrice.price.amount * item.totalQuantity : 0);
        }, 0);

        return {
          id: storeId,
          name: getStoreName(storeId),
          address: getStoreAddress(storeId),
          coordinates: getStoreCoordinates(storeId),
          pickupAvailable: true,
          deliveryAvailable: isDeliveryAvailable(storeId),
          estimatedTotal: { amount: Math.round(storeTotal), currency: 'MAD' },
          estimatedPickupTime: getEstimatedPickupTime(storeId),
          estimatedDeliveryTime: getEstimatedDeliveryTime(storeId)
        };
      });

      // Update shopping list
      const updatedList = {
        ...shoppingList,
        normalizedItems: updatedItems,
        stores: storeInfos,
        estimatedTotal: { 
          amount: Math.min(...storeInfos.map(s => s.estimatedTotal?.amount || 0)), 
          currency: 'MAD' 
        },
        updatedAt: admin.firestore.Timestamp.now()
      };

      await listRef.set(updatedList);

      return updatedList;

    } catch (error) {
      logger.error('Price comparison failed', { error, userId, listId, stores });
      throw new Error('Failed to compare prices');
    }
  }
);

// Update item purchased status
export const updateItemPurchased = onCall(
  {
    region: 'us-central1',
    timeoutSeconds: 30
  },
  async (request: CallableRequest<{ listId: string; itemId: string; purchased: boolean }>) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new Error('Authentication required');
    }

    const { listId, itemId, purchased } = request.data;
    if (!listId || !itemId || purchased === undefined) {
      throw new Error('Missing required parameters');
    }

    try {
      const listRef = db.collection('users').doc(userId).collection('shoppingLists').doc(listId);
      const listDoc = await listRef.get();

      if (!listDoc.exists) {
        throw new Error('Shopping list not found');
      }

      const shoppingList = listDoc.data() as ShoppingList;
      
      // Update the specific item
      const updatedItems = shoppingList.normalizedItems.map(item => 
        item.id === itemId ? { ...item, isPurchased: purchased } : item
      );

      // Check if all items are purchased to update status
      const allPurchased = updatedItems.every(item => item.isPurchased);
      const newStatus = allPurchased ? 'completed' : 
                       updatedItems.some(item => item.isPurchased) ? 'inProgress' : 'ready';

      await listRef.update({
        normalizedItems: updatedItems,
        status: newStatus,
        updatedAt: admin.firestore.Timestamp.now()
      });

      return { success: true };

    } catch (error) {
      logger.error('Failed to update item status', { error, userId, listId, itemId });
      throw new Error('Failed to update item');
    }
  }
);

// Create shopping order
export const createShoppingOrder = onCall(
  {
    region: 'us-central1',
    timeoutSeconds: 30
  },
  async (request: CallableRequest<{
    listId: string;
    storeId: string;
    fulfillmentType: 'pickup' | 'delivery' | 'curbside';
  }>) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new Error('Authentication required');
    }

    const { listId, storeId, fulfillmentType } = request.data;
    if (!listId || !storeId || !fulfillmentType) {
      throw new Error('Missing required parameters');
    }

    try {
      const listDoc = await db
        .collection('users')
        .doc(userId)
        .collection('shoppingLists')
        .doc(listId)
        .get();

      if (!listDoc.exists) {
        throw new Error('Shopping list not found');
      }

      const shoppingList = listDoc.data() as ShoppingList;
      const store = shoppingList.stores.find(s => s.id === storeId);

      if (!store) {
        throw new Error('Store not found in shopping list');
      }

      // Create order items
      const orderItems: OrderItem[] = shoppingList.normalizedItems.map(item => {
        const storeMapping = item.storeMappings[storeId];
        const storePrice = item.priceEstimates.find(p => p.storeId === storeId);
        
        return {
          id: item.id,
          sku: storeMapping?.sku || `generic_${item.id}`,
          productName: storeMapping?.productName || item.displayName,
          quantity: Math.ceil(item.totalQuantity),
          unitPrice: storePrice?.price || { amount: 10.0, currency: 'MAD' },
          totalPrice: { 
            amount: (storePrice?.price.amount || 10.0) * Math.ceil(item.totalQuantity), 
            currency: 'MAD' 
          }
        };
      });

      // Calculate total
      const total = {
        amount: orderItems.reduce((sum, item) => sum + item.totalPrice.amount, 0),
        currency: 'MAD'
      };

      // Create order
      const orderId = db.collection('users').doc(userId).collection('shoppingOrders').doc().id;
      const estimatedReadyTime = new Date();
      
      if (fulfillmentType === 'pickup') {
        estimatedReadyTime.setHours(estimatedReadyTime.getHours() + 2);
      } else if (fulfillmentType === 'delivery') {
        estimatedReadyTime.setHours(estimatedReadyTime.getHours() + 4);
      }

      const order: ShoppingOrder = {
        id: orderId,
        shoppingListId: listId,
        storeId,
        items: orderItems,
        total,
        fulfillmentType,
        status: 'confirmed',
        estimatedReadyAt: admin.firestore.Timestamp.fromDate(estimatedReadyTime),
        trackingInfo: `Order #${orderId.slice(-6).toUpperCase()}`,
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now()
      };

      await db.collection('users').doc(userId).collection('shoppingOrders').doc(orderId).set(order);

      // In a real implementation, this would integrate with the store's ordering system
      // and potentially with MarketplaceService for payment processing

      return order;

    } catch (error) {
      logger.error('Failed to create shopping order', { error, userId, listId, storeId });
      throw new Error('Failed to create order');
    }
  }
);

// Get shopping order
export const getShoppingOrder = onCall(
  {
    region: 'us-central1',
    timeoutSeconds: 30
  },
  async (request: CallableRequest<{ orderId: string }>) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new Error('Authentication required');
    }

    const { orderId } = request.data;
    if (!orderId) {
      throw new Error('Order ID required');
    }

    try {
      const orderDoc = await db
        .collection('users')
        .doc(userId)
        .collection('shoppingOrders')
        .doc(orderId)
        .get();

      if (!orderDoc.exists) {
        throw new Error('Order not found');
      }

      return orderDoc.data();

    } catch (error) {
      logger.error('Failed to get shopping order', { error, userId, orderId });
      throw new Error('Failed to retrieve order');
    }
  }
);

// Helper functions
async function getMealPlanData(userId: string, planId: string) {
  const planDoc = await db
    .collection('users')
    .doc(userId)
    .collection('mealPlans')
    .doc(planId)
    .get();

  return planDoc.exists ? planDoc.data() : null;
}

async function generateShoppingList(mealPlan: any, userId: string): Promise<ShoppingList> {
  // Collect all ingredients from all meals in the plan
  const allIngredients: Array<{ ingredient: any; recipeId: string; recipeName: string; servingSize: number }> = [];

  for (const day of mealPlan.days) {
    for (const meal of day.meals) {
      if (meal.recipeId) {
        const recipeDoc = await db
          .collection('users')
          .doc(userId)
          .collection('recipes')
          .doc(meal.recipeId)
          .get();

        if (recipeDoc.exists) {
          const recipe = recipeDoc.data();
          recipe.ingredients?.forEach((ingredient: any) => {
            allIngredients.push({
              ingredient,
              recipeId: meal.recipeId,
              recipeName: recipe.title,
              servingSize: meal.servingSize || 1.0
            });
          });
        }
      }
    }
  }

  // Normalize and consolidate ingredients
  const normalizedItems = consolidateIngredients(allIngredients);

  // Get initial price estimates
  const itemsWithPrices = await Promise.all(
    normalizedItems.map(async (item) => ({
      ...item,
      priceEstimates: await fetchPricesForItem(item, ['marjane', 'carrefour', 'atacadao'])
    }))
  );

  // Create shopping list
  const listId = db.collection('users').doc(userId).collection('shoppingLists').doc().id;
  
  const shoppingList: ShoppingList = {
    id: listId,
    mealPlanId: mealPlan.id,
    userId,
    normalizedItems: itemsWithPrices,
    stores: [
      {
        id: 'marjane',
        name: 'Marjane',
        address: 'Hay Riad, Rabat',
        coordinates: { latitude: 34.0105, longitude: -6.8326 },
        pickupAvailable: true,
        deliveryAvailable: true,
        estimatedPickupTime: '2 hours',
        estimatedDeliveryTime: '3-5 hours'
      },
      {
        id: 'carrefour',
        name: 'Carrefour',
        address: 'Agdal, Rabat',
        coordinates: { latitude: 34.0081, longitude: -6.8498 },
        pickupAvailable: true,
        deliveryAvailable: false,
        estimatedPickupTime: '1.5 hours'
      },
      {
        id: 'atacadao',
        name: 'Atacadão',
        address: 'Salé, Near Bouregreg',
        coordinates: { latitude: 34.0209, longitude: -6.7834 },
        pickupAvailable: true,
        deliveryAvailable: true,
        estimatedPickupTime: '2.5 hours',
        estimatedDeliveryTime: '4-6 hours'
      }
    ],
    status: 'ready',
    createdAt: admin.firestore.Timestamp.now(),
    updatedAt: admin.firestore.Timestamp.now()
  };

  // Save to Firestore
  await db.collection('users').doc(userId).collection('shoppingLists').doc(listId).set(shoppingList);

  return shoppingList;
}

function consolidateIngredients(
  allIngredients: Array<{ ingredient: any; recipeId: string; recipeName: string; servingSize: number }>
): GroceryItem[] {
  const ingredientMap = new Map<string, {
    totalQuantity: number;
    unit: string;
    references: RecipeReference[];
    ingredient: any;
  }>();

  // Group ingredients by normalized name
  for (const { ingredient, recipeId, recipeName, servingSize } of allIngredients) {
    const key = normalizeIngredientName(ingredient.name);
    const adjustedQuantity = (ingredient.quantity || 1) * servingSize;

    if (ingredientMap.has(key)) {
      const existing = ingredientMap.get(key)!;
      
      // Convert units if necessary and sum quantities
      const convertedQuantity = convertUnits(adjustedQuantity, ingredient.unit, existing.unit);
      existing.totalQuantity += convertedQuantity;
      existing.references.push({
        recipeId,
        recipeName,
        quantity: adjustedQuantity,
        unit: ingredient.unit || 'piece'
      });
    } else {
      ingredientMap.set(key, {
        totalQuantity: adjustedQuantity,
        unit: ingredient.unit || 'piece',
        references: [{
          recipeId,
          recipeName,
          quantity: adjustedQuantity,
          unit: ingredient.unit || 'piece'
        }],
        ingredient
      });
    }
  }

  // Convert to GroceryItem array
  return Array.from(ingredientMap.entries()).map(([key, data]) => ({
    id: key,
    ingredientKey: key,
    displayName: data.ingredient.name,
    totalQuantity: Math.round(data.totalQuantity * 100) / 100, // Round to 2 decimals
    unit: data.unit,
    category: data.ingredient.category || 'pantry',
    preferredBrands: [],
    substitutions: data.ingredient.substitutions || [],
    storeMappings: {},
    priceEstimates: [],
    recipeReferences: data.references,
    isPurchased: false
  }));
}

function normalizeIngredientName(name: string): string {
  return name
    .toLowerCase()
    .trim()
    .replace(/\s+/g, '_')
    .replace(/[^a-z0-9_]/g, '');
}

function convertUnits(quantity: number, fromUnit: string, toUnit: string): number {
  // Simplified unit conversion - in a real app, this would be more comprehensive
  const unitMap: Record<string, number> = {
    'tsp': 1,
    'tbsp': 3,
    'cup': 48,
    'ml': 0.2,
    'l': 200,
    'g': 1,
    'kg': 1000,
    'piece': 1,
    'pieces': 1
  };

  if (fromUnit === toUnit) return quantity;
  
  const fromValue = unitMap[fromUnit] || 1;
  const toValue = unitMap[toUnit] || 1;
  
  return (quantity * fromValue) / toValue;
}

async function fetchPricesForItem(item: GroceryItem, stores: string[]): Promise<StorePrice[]> {
  // In a real implementation, this would call external APIs or databases
  // For now, return mock prices with some variation
  
  const basePrices: Record<string, number> = {
    'marjane': Math.random() * 20 + 5,
    'carrefour': Math.random() * 18 + 6,
    'atacadao': Math.random() * 22 + 4
  };

  return stores.map(storeId => ({
    storeId,
    storeName: getStoreName(storeId),
    price: {
      amount: Math.round((basePrices[storeId] || 10) * 100) / 100,
      currency: 'MAD'
    },
    availability: 'available' as const,
    lastUpdated: admin.firestore.Timestamp.now(),
    promotionText: Math.random() > 0.7 ? '10% off this week' : undefined
  }));
}

async function updateStoreMappings(item: GroceryItem, stores: string[]): Promise<Record<string, StoreSKU>> {
  // In a real implementation, this would map ingredients to store SKUs
  const mappings: Record<string, StoreSKU> = {};

  for (const storeId of stores) {
    mappings[storeId] = {
      sku: `${storeId}_${item.ingredientKey}`,
      productName: item.displayName,
      brand: 'Generic',
      packageSize: `${item.totalQuantity} ${item.unit}`,
      unitPrice: {
        amount: Math.round(Math.random() * 15 + 5),
        currency: 'MAD'
      }
    };
  }

  return mappings;
}

// Store helper functions
function getStoreName(storeId: string): string {
  const storeNames: Record<string, string> = {
    'marjane': 'Marjane',
    'carrefour': 'Carrefour',
    'atacadao': 'Atacadão'
  };
  return storeNames[storeId] || storeId;
}

function getStoreAddress(storeId: string): string {
  const addresses: Record<string, string> = {
    'marjane': 'Hay Riad, Rabat',
    'carrefour': 'Agdal, Rabat',
    'atacadao': 'Salé, Near Bouregreg'
  };
  return addresses[storeId] || 'Unknown address';
}

function getStoreCoordinates(storeId: string): { latitude: number; longitude: number } | undefined {
  const coordinates: Record<string, { latitude: number; longitude: number }> = {
    'marjane': { latitude: 34.0105, longitude: -6.8326 },
    'carrefour': { latitude: 34.0081, longitude: -6.8498 },
    'atacadao': { latitude: 34.0209, longitude: -6.7834 }
  };
  return coordinates[storeId];
}

function isDeliveryAvailable(storeId: string): boolean {
  return storeId !== 'carrefour'; // Carrefour pickup only in this mock
}

function getEstimatedPickupTime(storeId: string): string {
  const times: Record<string, string> = {
    'marjane': '2 hours',
    'carrefour': '1.5 hours',
    'atacadao': '2.5 hours'
  };
  return times[storeId] || '2 hours';
}

function getEstimatedDeliveryTime(storeId: string): string | undefined {
  const times: Record<string, string> = {
    'marjane': '3-5 hours',
    'atacadao': '4-6 hours'
  };
  return times[storeId];
}