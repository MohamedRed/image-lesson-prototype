import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { trace } from '../shared/trace';
import { analytics } from '../shared/analytics';
import { secretManager } from '../shared/secretManager';

const db = getFirestore();

interface AIQuery {
  query: string;
  context: {
    userId: string;
    cityId: string;
    currentLocation?: {
      latitude: number;
      longitude: number;
    };
    sessionHistory?: string[];
  };
}

interface AIResponse {
  answer: string;
  suggestedActions?: Array<{
    type: string;
    label: string;
    data: { [key: string]: string };
  }>;
  reasonCodes?: string[];
  searchResults?: any[];
}

interface AlertCriteria {
  query: string;
  cityId: string;
  neighborhoods: string[];
  categories: string[];
  priceRange?: {
    min: number;
    max: number;
  };
}

interface NegotiationRequest {
  listingId: string;
  targetPrice?: {
    amount: number;
    currency: string;
  };
}

/**
 * AI Assistant for natural language marketplace queries
 * Per Section 7 - AI Assistant (Concierge)
 */
export const aiAnswer = onCall(
  { 
    cors: true,
    enforceAppCheck: true,
    secrets: ['OPENAI_API_KEY']
  },
  async (request) => {
    return trace('marketplace.ai.answer', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const { query, context } = request.data as AIQuery;
      const userId = request.auth.uid;

      if (!query || !context?.cityId) {
        throw new HttpsError('invalid-argument', 'Query and city context are required');
      }

      try {
        // Parse intent from natural language query
        const intent = await parseQueryIntent(query, context);

        let response: AIResponse;

        switch (intent.type) {
          case 'search':
            response = await handleSearchIntent(intent, context);
            break;
          case 'create_alert':
            response = await handleCreateAlertIntent(intent, userId);
            break;
          case 'price_inquiry':
            response = await handlePriceInquiryIntent(intent, context);
            break;
          case 'location_help':
            response = await handleLocationHelpIntent(intent, context);
            break;
          default:
            response = await handleGeneralIntent(intent, context);
        }

        // Track AI usage
        await analytics.track('marketplace_ai_query', {
          userId,
          query: query.substring(0, 100), // Truncate for privacy
          intentType: intent.type,
          cityId: context.cityId,
          hasResults: (response.searchResults?.length || 0) > 0
        });

        return response;

      } catch (error) {
        logger.error('AI query error', { userId, query: query.substring(0, 50), error });
        
        // Fallback response
        return {
          answer: "I'm sorry, I couldn't process your request right now. Please try rephrasing your question or browse our marketplace directly.",
          reasonCodes: ['ai_error_fallback']
        };
      }
    });
  }
);

/**
 * Create AI-powered watcher/alert
 */
export const createWatcher = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.ai.createWatcher', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const criteria = request.data as AlertCriteria;
      const userId = request.auth.uid;

      if (!criteria.query || !criteria.cityId) {
        throw new HttpsError('invalid-argument', 'Query and city are required');
      }

      try {
        // Create alert document
        const alertRef = db.collection('alerts').doc();
        const alert = {
          id: alertRef.id,
          userId,
          queryDSL: criteria.query,
          cityId: criteria.cityId,
          neighborhoods: criteria.neighborhoods,
          categories: criteria.categories,
          priceRange: criteria.priceRange,
          createdAt: new Date(),
          isActive: true,
          matchCount: 0,
          lastNotified: null
        };

        await alertRef.set(alert);

        // Set up background monitoring
        await scheduleAlertMonitoring(alertRef.id);

        // Analytics
        await analytics.track('marketplace_alert_created', {
          userId,
          alertId: alertRef.id,
          cityId: criteria.cityId,
          hasCategories: criteria.categories.length > 0,
          hasPriceRange: !!criteria.priceRange
        });

        return alert;

      } catch (error) {
        logger.error('Create watcher error', { userId, criteria, error });
        throw new HttpsError('internal', 'Failed to create alert');
      }
    });
  }
);

/**
 * AI-powered negotiation suggestions
 */
export const suggestNegotiation = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.ai.suggestNegotiation', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const { listingId, targetPrice } = request.data as NegotiationRequest;
      const userId = request.auth.uid;

      if (!listingId) {
        throw new HttpsError('invalid-argument', 'Listing ID is required');
      }

      try {
        // Get listing details
        const listingDoc = await db.collection('listings').doc(listingId).get();
        if (!listingDoc.exists) {
          throw new HttpsError('not-found', 'Listing not found');
        }

        const listing = listingDoc.data();

        // Get comparable listings for pricing analysis
        const comparables = await getComparableListings(listing);

        // Get seller's pricing history
        const sellerHistory = await getSellerPricingHistory(listing.sellerId);

        // Generate negotiation strategy
        const suggestion = await generateNegotiationSuggestion(
          listing,
          targetPrice,
          comparables,
          sellerHistory
        );

        // Analytics
        await analytics.track('marketplace_negotiation_suggestion', {
          userId,
          listingId,
          targetPriceProvided: !!targetPrice,
          suggestedDiscount: suggestion.suggestedPrice.amount < listing.price.amount
        });

        return suggestion;

      } catch (error) {
        logger.error('Negotiation suggestion error', { userId, listingId, error });
        throw new HttpsError('internal', 'Failed to generate negotiation suggestion');
      }
    });
  }
);

/**
 * Invoke category-specific Try Lab plugins
 */
export const invokePlugin = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.ai.invokePlugin', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const { category, action, input } = request.data;
      const userId = request.auth.uid;

      if (!category || !action) {
        throw new HttpsError('invalid-argument', 'Category and action are required');
      }

      try {
        let result;

        switch (`${category}:${action}`) {
          case 'apparel:try_on':
            result = await handleApparelTryOn(input, userId);
            break;
          case 'car_parts:compatibility_check':
            result = await handleCarPartCompatibility(input, userId);
            break;
          case 'furniture:ar_placement':
            result = await handleFurnitureARPlacement(input, userId);
            break;
          default:
            throw new HttpsError('invalid-argument', `Plugin ${category}:${action} not supported`);
        }

        // Analytics
        await analytics.track('marketplace_plugin_invoked', {
          userId,
          category,
          action,
          success: result.success
        });

        return result;

      } catch (error) {
        logger.error('Plugin invocation error', { userId, category, action, error });
        throw new HttpsError('internal', 'Plugin invocation failed');
      }
    });
  }
);

// Helper functions

async function parseQueryIntent(query: string, context: any) {
  const lowerQuery = query.toLowerCase();

  // Simple intent classification - would use actual NLP in production
  if (lowerQuery.includes('find') || lowerQuery.includes('looking for') || lowerQuery.includes('search')) {
    return {
      type: 'search',
      entities: extractSearchEntities(query)
    };
  }

  if (lowerQuery.includes('alert') || lowerQuery.includes('notify') || lowerQuery.includes('watch')) {
    return {
      type: 'create_alert',
      entities: extractSearchEntities(query)
    };
  }

  if (lowerQuery.includes('price') || lowerQuery.includes('cost') || lowerQuery.includes('cheap')) {
    return {
      type: 'price_inquiry',
      entities: extractSearchEntities(query)
    };
  }

  if (lowerQuery.includes('where') || lowerQuery.includes('location') || lowerQuery.includes('near')) {
    return {
      type: 'location_help',
      entities: extractLocationEntities(query)
    };
  }

  return {
    type: 'general',
    entities: {}
  };
}

function extractSearchEntities(query: string) {
  // Simple entity extraction - would use NER in production
  const categories = ['electronics', 'furniture', 'apparel', 'car', 'book', 'sport'];
  const conditions = ['new', 'like new', 'good', 'fair'];
  const neighborhoods = ['maarif', 'gauthier', 'racine', 'bourgogne', 'ain diab'];

  const extractedCategory = categories.find(cat => 
    query.toLowerCase().includes(cat)
  );

  const extractedCondition = conditions.find(cond => 
    query.toLowerCase().includes(cond)
  );

  const extractedNeighborhood = neighborhoods.find(neigh => 
    query.toLowerCase().includes(neigh)
  );

  // Extract price range
  const priceMatch = query.match(/(\d+)\s*(mad|dh|dirham)/i);
  const maxPrice = priceMatch ? parseInt(priceMatch[1]) : null;

  return {
    category: extractedCategory,
    condition: extractedCondition,
    neighborhood: extractedNeighborhood,
    maxPrice: maxPrice ? maxPrice * 100 : null // Convert to cents
  };
}

function extractLocationEntities(query: string) {
  const neighborhoods = ['maarif', 'gauthier', 'racine', 'bourgogne', 'ain diab'];
  
  const extractedNeighborhood = neighborhoods.find(neigh => 
    query.toLowerCase().includes(neigh)
  );

  return {
    neighborhood: extractedNeighborhood
  };
}

async function handleSearchIntent(intent: any, context: any): Promise<AIResponse> {
  // Build search filters from intent
  const filters: any = {
    cityId: context.cityId
  };

  if (intent.entities.category) {
    filters.categories = [intent.entities.category];
  }

  if (intent.entities.neighborhood) {
    filters.neighborhoods = [intent.entities.neighborhood];
  }

  if (intent.entities.maxPrice) {
    filters.priceRange = { max: intent.entities.maxPrice };
  }

  if (intent.entities.condition) {
    filters.condition = intent.entities.condition;
  }

  // Perform search
  const searchQuery = intent.entities.category || '';
  
  // Simulate search call - would call actual search function
  const searchResults = []; // Would be actual search results

  const answer = generateSearchAnswer(intent, searchResults, context);

  return {
    answer,
    searchResults,
    suggestedActions: [
      {
        type: 'view_results',
        label: 'View All Results',
        data: { filters: JSON.stringify(filters) }
      }
    ],
    reasonCodes: ['ai_search_intent']
  };
}

async function handleCreateAlertIntent(intent: any, userId: string): Promise<AIResponse> {
  const answer = `I can set up an alert for you! Based on your request, I'll notify you when new items matching your criteria are listed. Would you like me to create this alert?`;

  return {
    answer,
    suggestedActions: [
      {
        type: 'create_alert',
        label: 'Create Alert',
        data: {
          category: intent.entities.category || '',
          neighborhood: intent.entities.neighborhood || '',
          maxPrice: intent.entities.maxPrice?.toString() || ''
        }
      }
    ],
    reasonCodes: ['ai_alert_intent']
  };
}

async function handlePriceInquiryIntent(intent: any, context: any): Promise<AIResponse> {
  const category = intent.entities.category;
  
  if (category) {
    // Get price statistics for category
    const priceStats = await getCategoryPriceStats(category, context.cityId);
    
    const answer = `In ${context.cityId}, ${category} items typically range from ${priceStats.min} MAD to ${priceStats.max} MAD, with an average of ${priceStats.average} MAD. Would you like to see current listings in this price range?`;

    return {
      answer,
      suggestedActions: [
        {
          type: 'search_price_range',
          label: 'View Items in Price Range',
          data: {
            category,
            minPrice: priceStats.min.toString(),
            maxPrice: priceStats.max.toString()
          }
        }
      ],
      reasonCodes: ['ai_price_inquiry']
    };
  }

  return {
    answer: "I can help you understand pricing for specific items. What type of item are you interested in?",
    reasonCodes: ['ai_price_inquiry_general']
  };
}

async function handleLocationHelpIntent(intent: any, context: any): Promise<AIResponse> {
  const neighborhood = intent.entities.neighborhood;
  
  if (neighborhood) {
    const neighborhoodInfo = getNeighborhoodInfo(neighborhood, context.cityId);
    
    const answer = `${neighborhoodInfo.name} is a ${neighborhoodInfo.description}. It's popular for ${neighborhoodInfo.popularCategories.join(', ')}. Would you like to see current listings in this area?`;

    return {
      answer,
      suggestedActions: [
        {
          type: 'search_neighborhood',
          label: `Browse ${neighborhoodInfo.name}`,
          data: { neighborhood }
        }
      ],
      reasonCodes: ['ai_location_help']
    };
  }

  return {
    answer: "I can help you find items in specific neighborhoods. Which area are you interested in?",
    reasonCodes: ['ai_location_help_general']
  };
}

async function handleGeneralIntent(intent: any, context: any): Promise<AIResponse> {
  return {
    answer: "I'm here to help you find items, set up alerts, get pricing information, and explore different neighborhoods. What can I help you with today?",
    suggestedActions: [
      {
        type: 'search',
        label: 'Browse Items',
        data: {}
      },
      {
        type: 'create_alert',
        label: 'Set Up Alert',
        data: {}
      }
    ],
    reasonCodes: ['ai_general_help']
  };
}

function generateSearchAnswer(intent: any, results: any[], context: any): string {
  const resultCount = results.length;
  const entities = intent.entities;
  
  let answer = `I found ${resultCount} items`;
  
  if (entities.category) {
    answer += ` in ${entities.category}`;
  }
  
  if (entities.neighborhood) {
    answer += ` in ${entities.neighborhood}`;
  }
  
  if (entities.maxPrice) {
    answer += ` under ${entities.maxPrice / 100} MAD`;
  }
  
  answer += ` in ${context.cityId}.`;
  
  if (resultCount > 0) {
    answer += ` The newest items were just posted today. Would you like me to show you the results?`;
  } else {
    answer += ` I can set up an alert to notify you when matching items are listed.`;
  }
  
  return answer;
}

async function getComparableListings(listing: any) {
  // Get similar listings for price comparison
  const snapshot = await db.collection('listings')
    .where('category', '==', listing.category)
    .where('condition', '==', listing.condition)
    .where('cityId', '==', listing.cityId)
    .where('status', 'in', ['sold', 'active'])
    .limit(10)
    .get();

  return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
}

async function getSellerPricingHistory(sellerId: string) {
  const snapshot = await db.collection('listings')
    .where('sellerId', '==', sellerId)
    .where('status', '==', 'sold')
    .limit(20)
    .get();

  return snapshot.docs.map(doc => doc.data());
}

async function generateNegotiationSuggestion(
  listing: any,
  targetPrice: any,
  comparables: any[],
  sellerHistory: any[]
) {
  const askingPrice = listing.price.amount;
  const target = targetPrice?.amount || (askingPrice * 0.85); // Default to 15% off

  // Analyze comparables
  const soldComparables = comparables.filter(c => c.status === 'sold');
  const avgSoldPrice = soldComparables.length > 0 
    ? soldComparables.reduce((sum, c) => sum + c.price.amount, 0) / soldComparables.length
    : askingPrice;

  // Analyze seller flexibility
  const sellerFlexibility = analyzeSellerFlexibility(sellerHistory);

  // Generate suggestion
  let suggestedPrice = target;
  let reasoning = '';

  if (target < avgSoldPrice * 0.7) {
    suggestedPrice = Math.floor(avgSoldPrice * 0.8);
    reasoning = 'Your offer might be too low. Similar items sold for more. I suggest starting higher.';
  } else if (target > askingPrice * 0.95) {
    reasoning = 'You\'re offering close to asking price. This should be accepted quickly.';
  } else {
    reasoning = 'This is a reasonable offer based on similar items and market conditions.';
  }

  const draftMessage = generateNegotiationMessage(listing, suggestedPrice, reasoning, sellerFlexibility);

  return {
    suggestedPrice: {
      amount: suggestedPrice,
      currency: listing.price.currency
    },
    reasoning,
    comparables: soldComparables.slice(0, 3).map(c => c.id),
    draftMessage
  };
}

function analyzeSellerFlexibility(sellerHistory: any[]) {
  // Analyze if seller typically accepts lower offers
  // Simplified analysis - would be more sophisticated in production
  return {
    isFlexible: Math.random() > 0.5, // Simulate
    averageDiscount: 0.1,
    responseTime: '2-4 hours'
  };
}

function generateNegotiationMessage(listing: any, suggestedPrice: number, reasoning: string, flexibility: any): string {
  const discount = ((listing.price.amount - suggestedPrice) / listing.price.amount * 100).toFixed(0);
  
  return `Hi! I'm very interested in your ${listing.title}. I've been looking for exactly this item. Would you consider ${(suggestedPrice / 100).toFixed(0)} MAD? I can arrange pickup this week. Thank you!`;
}

async function scheduleAlertMonitoring(alertId: string) {
  // Would set up background job to monitor for matches
  logger.info('Alert monitoring scheduled', { alertId });
}

async function getCategoryPriceStats(category: string, cityId: string) {
  // Get price statistics for category
  const snapshot = await db.collection('listings')
    .where('category', '==', category)
    .where('cityId', '==', cityId)
    .where('status', 'in', ['active', 'sold'])
    .limit(100)
    .get();

  const prices = snapshot.docs
    .map(doc => doc.data().price?.amount || 0)
    .filter(price => price > 0)
    .sort((a, b) => a - b);

  if (prices.length === 0) {
    return { min: 100, average: 500, max: 1000 };
  }

  return {
    min: Math.floor(prices[0] / 100),
    average: Math.floor(prices.reduce((sum, p) => sum + p, 0) / prices.length / 100),
    max: Math.floor(prices[prices.length - 1] / 100)
  };
}

function getNeighborhoodInfo(neighborhood: string, cityId: string) {
  // Static neighborhood information - would be in database
  const neighborhoods: any = {
    'maarif': {
      name: 'Maarif',
      description: 'modern business district',
      popularCategories: ['electronics', 'office furniture', 'books']
    },
    'gauthier': {
      name: 'Gauthier',
      description: 'upscale residential area',
      popularCategories: ['furniture', 'art', 'jewelry']
    }
  };

  return neighborhoods[neighborhood] || {
    name: neighborhood,
    description: 'neighborhood',
    popularCategories: ['various items']
  };
}

// Try Lab plugin handlers

async function handleApparelTryOn(input: any, userId: string) {
  // Simulate apparel try-on processing
  return {
    success: true,
    result: {
      fitScore: 85,
      sizeRecommendation: 'M',
      preview: 'generated_tryon_image_url'
    }
  };
}

async function handleCarPartCompatibility(input: any, userId: string) {
  // Simulate car part compatibility check
  return {
    success: true,
    result: {
      compatible: true,
      compatibilityScore: 95,
      installationDifficulty: 'moderate',
      requiredTools: ['socket wrench', 'screwdriver']
    }
  };
}

async function handleFurnitureARPlacement(input: any, userId: string) {
  // Simulate furniture AR placement
  return {
    success: true,
    result: {
      fitsInRoom: true,
      clearanceScore: 80,
      visualHarmonyScore: 90
    }
  };
}