import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { logger } from 'firebase-functions/v2';
import { trace } from '../shared/trace';
import { analytics } from '../shared/analytics';
import { audit } from '../shared/audit';
import { idempotency } from '../shared/idempotency';

const db = getFirestore();
const storage = getStorage();

// Types matching iOS models
interface ListingDraft {
  title: string;
  description: string;
  category: string;
  condition: string;
  price: {
    amount: number;
    currency: string;
  };
  images: string[]; // Storage URLs
  location: {
    lat: number;
    lng: number;
    addressLine?: string;
    arrondissement?: string;
  };
  deliveryOptions: {
    meetup: boolean;
    courier: boolean;
  };
  attributes: { [key: string]: string };
}

interface ListingUpdate {
  title?: string;
  description?: string;
  price?: {
    amount: number;
    currency: string;
  };
  status?: string;
  deliveryOptions?: {
    meetup: boolean;
    courier: boolean;
  };
}

/**
 * Create a new listing with AI assistance
 * Per Section 10 - Fast listing creation with AI
 */
export const createListing = onCall(
  { 
    cors: true,
    enforceAppCheck: true,
    secrets: ['OPENAI_API_KEY']
  },
  async (request) => {
    return trace('marketplace.createListing', request.auth?.uid || 'anonymous', async () => {
      // Validate authentication
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const { data } = request;
      const userId = request.auth.uid;

      // Validate input
      if (!data || !isValidListingDraft(data)) {
        throw new HttpsError('invalid-argument', 'Invalid listing data');
      }

      const draft = data as ListingDraft;

      try {
        // Generate unique listing ID
        const listingRef = db.collection('listings').doc();
        const listingId = listingRef.id;

        // Idempotency check
        const idempotencyKey = `create_listing_${userId}_${Date.now()}`;
        const existingResult = await idempotency.check(idempotencyKey);
        if (existingResult) {
          return existingResult;
        }

        // AI enhancements
        const enhancedData = await enhanceListingWithAI(draft);

        // Validate city and neighborhood
        const cityValidation = await validateLocation(draft.location);
        if (!cityValidation.isValid) {
          throw new HttpsError('invalid-argument', `Invalid location: ${cityValidation.reason}`);
        }

        // Create listing document
        const listing = {
          id: listingId,
          cityId: cityValidation.cityId,
          neighborhoodId: draft.location.arrondissement,
          title: enhancedData.title || draft.title,
          description: enhancedData.description || draft.description,
          category: draft.category,
          condition: draft.condition,
          price: draft.price,
          images: draft.images,
          thumbnails: await generateThumbnails(draft.images),
          sellerId: userId,
          status: 'active',
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          location: draft.location,
          deliveryOptions: draft.deliveryOptions,
          attributes: { ...draft.attributes, ...enhancedData.attributes },
          embedding: enhancedData.embedding,
          moderation: {
            status: 'pending',
            reasons: []
          }
        };

        // Write to Firestore
        await listingRef.set(listing);

        // Index for search
        await indexListingForSearch(listing);

        // Run content moderation
        moderateListingContent(listingId, listing).catch(error => {
          logger.error('Content moderation failed', { listingId, error });
        });

        // Analytics
        await analytics.track('listing_created', {
          userId,
          listingId,
          category: draft.category,
          cityId: cityValidation.cityId,
          priceAmount: draft.price.amount,
          hasImages: draft.images.length > 0
        });

        // Audit log
        await audit.log('listing_created', userId, {
          listingId,
          category: draft.category,
          price: draft.price
        });

        // Store result for idempotency
        const result = { ...listing, id: listingId };
        await idempotency.store(idempotencyKey, result);

        return result;

      } catch (error) {
        logger.error('Error creating listing', { userId, error });
        throw new HttpsError('internal', 'Failed to create listing');
      }
    });
  }
);

/**
 * Update an existing listing
 */
export const updateListing = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.updateListing', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const { listingId, ...updates } = request.data as { listingId: string } & ListingUpdate;
      const userId = request.auth.uid;

      if (!listingId) {
        throw new HttpsError('invalid-argument', 'Listing ID is required');
      }

      try {
        const listingRef = db.collection('listings').doc(listingId);
        const listingDoc = await listingRef.get();

        if (!listingDoc.exists) {
          throw new HttpsError('not-found', 'Listing not found');
        }

        const listing = listingDoc.data();
        
        // Verify ownership
        if (listing?.sellerId !== userId) {
          throw new HttpsError('permission-denied', 'You can only update your own listings');
        }

        // Prepare updates
        const updateData: any = {
          updatedAt: FieldValue.serverTimestamp()
        };

        if (updates.title) updateData.title = updates.title;
        if (updates.description) updateData.description = updates.description;
        if (updates.price) updateData.price = updates.price;
        if (updates.status) updateData.status = updates.status;
        if (updates.deliveryOptions) updateData.deliveryOptions = updates.deliveryOptions;

        // Update Firestore
        await listingRef.update(updateData);

        // Re-index if content changed
        if (updates.title || updates.description || updates.price) {
          const updatedListing = { ...listing, ...updateData };
          await indexListingForSearch(updatedListing);
        }

        // Analytics
        await analytics.track('listing_updated', {
          userId,
          listingId,
          updatedFields: Object.keys(updates)
        });

        return { success: true, listingId };

      } catch (error) {
        logger.error('Error updating listing', { userId, listingId, error });
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', 'Failed to update listing');
      }
    });
  }
);

/**
 * Mark listing as reserved
 */
export const markReserved = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.markReserved', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const { listingId, buyerId } = request.data;
      const userId = request.auth.uid;

      try {
        await db.runTransaction(async (transaction) => {
          const listingRef = db.collection('listings').doc(listingId);
          const listingDoc = await transaction.get(listingRef);

          if (!listingDoc.exists) {
            throw new HttpsError('not-found', 'Listing not found');
          }

          const listing = listingDoc.data();

          // Verify ownership
          if (listing?.sellerId !== userId) {
            throw new HttpsError('permission-denied', 'You can only update your own listings');
          }

          // Check current status
          if (listing?.status !== 'active') {
            throw new HttpsError('failed-precondition', 'Listing is not available for reservation');
          }

          // Update status
          transaction.update(listingRef, {
            status: 'reserved',
            reservedBy: buyerId,
            reservedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp()
          });
        });

        // Analytics
        await analytics.track('listing_reserved', {
          sellerId: userId,
          listingId,
          buyerId
        });

        return { success: true };

      } catch (error) {
        logger.error('Error reserving listing', { userId, listingId, error });
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', 'Failed to reserve listing');
      }
    });
  }
);

/**
 * Mark listing as sold
 */
export const markSold = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.markSold', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const { listingId } = request.data;
      const userId = request.auth.uid;

      try {
        await db.runTransaction(async (transaction) => {
          const listingRef = db.collection('listings').doc(listingId);
          const listingDoc = await transaction.get(listingRef);

          if (!listingDoc.exists) {
            throw new HttpsError('not-found', 'Listing not found');
          }

          const listing = listingDoc.data();

          // Verify ownership
          if (listing?.sellerId !== userId) {
            throw new HttpsError('permission-denied', 'You can only update your own listings');
          }

          // Update status
          transaction.update(listingRef, {
            status: 'sold',
            soldAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp()
          });

          // Update seller stats
          const userRef = db.collection('users').doc(userId);
          transaction.update(userRef, {
            'seller.stats.soldCount': FieldValue.increment(1),
            'seller.rating': calculateNewSellerRating(listing)
          });
        });

        // Analytics
        await analytics.track('listing_sold', {
          sellerId: userId,
          listingId,
          category: 'unknown', // Would be retrieved from listing
          finalPrice: 0 // Would be retrieved from reservation/payment
        });

        return { success: true };

      } catch (error) {
        logger.error('Error marking listing sold', { userId, listingId, error });
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', 'Failed to mark listing as sold');
      }
    });
  }
);

// Helper functions

function isValidListingDraft(data: any): data is ListingDraft {
  return (
    data &&
    typeof data.title === 'string' &&
    typeof data.description === 'string' &&
    typeof data.category === 'string' &&
    typeof data.condition === 'string' &&
    data.price &&
    typeof data.price.amount === 'number' &&
    typeof data.price.currency === 'string' &&
    Array.isArray(data.images) &&
    data.location &&
    typeof data.location.lat === 'number' &&
    typeof data.location.lng === 'number' &&
    data.deliveryOptions &&
    typeof data.deliveryOptions.meetup === 'boolean' &&
    typeof data.deliveryOptions.courier === 'boolean'
  );
}

async function enhanceListingWithAI(draft: ListingDraft) {
  // Simulate AI enhancement - would call actual AI service
  return {
    title: draft.title, // Enhanced by AI
    description: draft.description, // Enhanced by AI
    attributes: {
      ...draft.attributes,
      aiGenerated: 'true'
    },
    embedding: new Array(384).fill(0).map(() => Math.random()) // Mock embedding
  };
}

async function validateLocation(location: { lat: number; lng: number; arrondissement?: string }) {
  // Validate against supported cities
  const casablancaBounds = {
    north: 33.6532,
    south: 33.4928,
    east: -7.4671,
    west: -7.7059
  };

  const rabatBounds = {
    north: 34.0709,
    south: 33.9709,
    east: -6.7816,
    west: -6.9016
  };

  if (
    location.lat >= casablancaBounds.south &&
    location.lat <= casablancaBounds.north &&
    location.lng >= casablancaBounds.west &&
    location.lng <= casablancaBounds.east
  ) {
    return { isValid: true, cityId: 'casablanca' };
  }

  if (
    location.lat >= rabatBounds.south &&
    location.lat <= rabatBounds.north &&
    location.lng >= rabatBounds.west &&
    location.lng <= rabatBounds.east
  ) {
    return { isValid: true, cityId: 'rabat' };
  }

  return { isValid: false, reason: 'Location not in supported cities' };
}

async function generateThumbnails(imageUrls: string[]): Promise<string[]> {
  // Would generate actual thumbnails using image processing service
  return imageUrls.map(url => url.replace('.jpg', '_thumb.jpg'));
}

async function indexListingForSearch(listing: any) {
  // Would index to external search service (Algolia/Typesense/ES)
  logger.info('Indexing listing for search', { listingId: listing.id });
}

async function moderateListingContent(listingId: string, listing: any) {
  // Content moderation logic
  const forbiddenWords = ['counterfeit', 'replica', 'stolen'];
  const content = `${listing.title} ${listing.description}`.toLowerCase();
  
  const violations = forbiddenWords.filter(word => content.includes(word));
  
  if (violations.length > 0) {
    await db.collection('listings').doc(listingId).update({
      'moderation.status': 'flagged',
      'moderation.reasons': violations,
      status: 'removed'
    });
  } else {
    await db.collection('listings').doc(listingId).update({
      'moderation.status': 'approved'
    });
  }
}

function calculateNewSellerRating(listing: any): number {
  // Simplified rating calculation
  return 4.5; // Would calculate based on transaction history
}