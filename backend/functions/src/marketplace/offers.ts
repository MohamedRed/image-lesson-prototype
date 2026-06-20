import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { trace } from '../shared/trace';
import { analytics } from '../shared/analytics';
import { fcmService } from '../services/notifications/fcmService';
import { templates } from '../services/notifications/templates';

const db = getFirestore();

interface OfferData {
  listingId: string;
  amount: {
    amount: number;
    currency: string;
  };
  message?: string;
  expiresAt?: Date;
}

interface OfferResponse {
  response: 'accept' | 'decline' | 'counter';
  counterOffer?: {
    amount: number;
    currency: string;
  };
  message?: string;
}

/**
 * Create an offer on a listing
 * Per Section 11 - Offers & Negotiations
 */
export const makeOffer = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.makeOffer', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const { listingId, amount, message } = request.data as OfferData;
      const buyerId = request.auth.uid;

      if (!listingId || !amount || amount.amount <= 0) {
        throw new HttpsError('invalid-argument', 'Valid listing ID and amount are required');
      }

      try {
        // Check if listing exists and is available
        const listingDoc = await db.collection('listings').doc(listingId).get();
        if (!listingDoc.exists) {
          throw new HttpsError('not-found', 'Listing not found');
        }

        const listing = listingDoc.data();
        if (listing?.status !== 'active') {
          throw new HttpsError('failed-precondition', 'Listing is not available for offers');
        }

        if (listing?.sellerId === buyerId) {
          throw new HttpsError('invalid-argument', 'Cannot make offer on your own listing');
        }

        // Check for existing offers from this buyer
        const existingOffers = await db.collection('offers')
          .where('listingId', '==', listingId)
          .where('buyerId', '==', buyerId)
          .where('status', 'in', ['pending', 'counter_offered'])
          .get();

        if (!existingOffers.empty) {
          throw new HttpsError('already-exists', 'You already have a pending offer on this listing');
        }

        // Validate offer amount (max 120% of asking price)
        const maxOffer = listing?.price.amount * 1.2;
        if (amount.amount > maxOffer) {
          throw new HttpsError('invalid-argument', 'Offer exceeds maximum allowed amount');
        }

        // Rate limiting - max 5 offers per day per user
        const todayStart = new Date();
        todayStart.setHours(0, 0, 0, 0);
        
        const todayOffers = await db.collection('offers')
          .where('buyerId', '==', buyerId)
          .where('createdAt', '>=', todayStart)
          .get();

        if (todayOffers.size >= 5) {
          throw new HttpsError('resource-exhausted', 'Daily offer limit exceeded');
        }

        // Create offer
        const offerRef = db.collection('offers').doc();
        const expiresAt = new Date(Date.now() + 72 * 60 * 60 * 1000); // 72 hours

        const offer = {
          id: offerRef.id,
          listingId,
          buyerId,
          sellerId: listing.sellerId,
          amount,
          message: message || '',
          status: 'pending',
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          expiresAt
        };

        await offerRef.set(offer);

        // Analytics
        await analytics.track('marketplace_offer_made', {
          buyerId,
          sellerId: listing.sellerId,
          listingId,
          offerAmount: amount.amount,
          askingPrice: listing.price.amount,
          offerPercentage: (amount.amount / listing.price.amount) * 100
        });

        return {
          success: true,
          offerId: offerRef.id,
          expiresAt
        };

      } catch (error) {
        logger.error('Error making offer', { buyerId, listingId, error });
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', 'Failed to make offer');
      }
    });
  }
);

/**
 * Respond to an offer (accept, decline, counter)
 */
export const respondToOffer = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.respondToOffer', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const { offerId, response, counterOffer, message } = request.data as { offerId: string } & OfferResponse;
      const sellerId = request.auth.uid;

      if (!offerId || !response) {
        throw new HttpsError('invalid-argument', 'Offer ID and response are required');
      }

      try {
        const result = await db.runTransaction(async (transaction) => {
          const offerRef = db.collection('offers').doc(offerId);
          const offerDoc = await transaction.get(offerRef);

          if (!offerDoc.exists) {
            throw new HttpsError('not-found', 'Offer not found');
          }

          const offer = offerDoc.data();

          // Verify seller permission
          if (offer?.sellerId !== sellerId) {
            throw new HttpsError('permission-denied', 'You can only respond to offers on your listings');
          }

          // Check offer status
          if (offer?.status !== 'pending' && offer?.status !== 'counter_offered') {
            throw new HttpsError('failed-precondition', 'Offer is no longer pending');
          }

          // Check expiration
          if (offer?.expiresAt && new Date() > offer.expiresAt.toDate()) {
            transaction.update(offerRef, { status: 'expired' });
            throw new HttpsError('failed-precondition', 'Offer has expired');
          }

          let updateData: any = {
            status: response === 'accept' ? 'accepted' : response === 'decline' ? 'declined' : 'counter_offered',
            respondedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp()
          };

          if (message) {
            updateData.sellerMessage = message;
          }

          if (response === 'counter' && counterOffer) {
            updateData.counterOffer = counterOffer;
            updateData.expiresAt = new Date(Date.now() + 48 * 60 * 60 * 1000); // 48 hours for counter
          }

          // If accepted, mark listing as reserved
          if (response === 'accept') {
            const listingRef = db.collection('listings').doc(offer.listingId);
            transaction.update(listingRef, {
              status: 'reserved',
              reservedBy: offer.buyerId,
              reservedAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp()
            });

            // Decline all other pending offers on this listing
            const otherOffers = await db.collection('offers')
              .where('listingId', '==', offer.listingId)
              .where('status', 'in', ['pending', 'counter_offered'])
              .get();

            otherOffers.docs.forEach(doc => {
              if (doc.id !== offerId) {
                transaction.update(doc.ref, {
                  status: 'declined',
                  declineReason: 'listing_reserved',
                  updatedAt: FieldValue.serverTimestamp()
                });
              }
            });
          }

          transaction.update(offerRef, updateData);

          return { response, offerId };
        });

        // Analytics
        await analytics.track('marketplace_offer_responded', {
          sellerId,
          offerId,
          response,
          hasCounterOffer: !!counterOffer
        });

        return { success: true, ...result };

      } catch (error) {
        logger.error('Error responding to offer', { sellerId, offerId, error });
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', 'Failed to respond to offer');
      }
    });
  }
);

/**
 * Withdraw an offer
 */
export const withdrawOffer = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.withdrawOffer', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const { offerId } = request.data;
      const buyerId = request.auth.uid;

      try {
        const offerRef = db.collection('offers').doc(offerId);
        const offerDoc = await offerRef.get();

        if (!offerDoc.exists) {
          throw new HttpsError('not-found', 'Offer not found');
        }

        const offer = offerDoc.data();

        // Verify buyer permission
        if (offer?.buyerId !== buyerId) {
          throw new HttpsError('permission-denied', 'You can only withdraw your own offers');
        }

        // Check if offer can be withdrawn
        if (!['pending', 'counter_offered'].includes(offer?.status)) {
          throw new HttpsError('failed-precondition', 'Offer cannot be withdrawn');
        }

        await offerRef.update({
          status: 'withdrawn',
          withdrawnAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp()
        });

        // Analytics
        await analytics.track('marketplace_offer_withdrawn', {
          buyerId,
          offerId,
          listingId: offer.listingId
        });

        return { success: true };

      } catch (error) {
        logger.error('Error withdrawing offer', { buyerId, offerId, error });
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', 'Failed to withdraw offer');
      }
    });
  }
);

/**
 * Accept a counter offer
 */
export const acceptCounterOffer = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.acceptCounterOffer', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const { offerId } = request.data;
      const buyerId = request.auth.uid;

      try {
        const result = await db.runTransaction(async (transaction) => {
          const offerRef = db.collection('offers').doc(offerId);
          const offerDoc = await transaction.get(offerRef);

          if (!offerDoc.exists) {
            throw new HttpsError('not-found', 'Offer not found');
          }

          const offer = offerDoc.data();

          // Verify buyer permission
          if (offer?.buyerId !== buyerId) {
            throw new HttpsError('permission-denied', 'You can only accept your own counter offers');
          }

          // Check offer status
          if (offer?.status !== 'counter_offered') {
            throw new HttpsError('failed-precondition', 'No counter offer to accept');
          }

          // Check expiration
          if (offer?.expiresAt && new Date() > offer.expiresAt.toDate()) {
            transaction.update(offerRef, { status: 'expired' });
            throw new HttpsError('failed-precondition', 'Counter offer has expired');
          }

          // Accept the counter offer
          transaction.update(offerRef, {
            status: 'accepted',
            counterAcceptedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
            finalAmount: offer.counterOffer
          });

          // Reserve the listing
          const listingRef = db.collection('listings').doc(offer.listingId);
          transaction.update(listingRef, {
            status: 'reserved',
            reservedBy: buyerId,
            reservedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp()
          });

          return { success: true };
        });

        // Analytics
        await analytics.track('marketplace_counter_offer_accepted', {
          buyerId,
          offerId
        });

        return result;

      } catch (error) {
        logger.error('Error accepting counter offer', { buyerId, offerId, error });
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', 'Failed to accept counter offer');
      }
    });
  }
);

/**
 * Trigger: Send notification when offer is created
 */
export const onOfferCreated = onDocumentCreated(
  'offers/{offerId}',
  async (event) => {
    const offerData = event.data?.data();
    const offerId = event.params.offerId;

    if (!offerData) return;

    try {
      // Get listing and seller details
      const listingDoc = await db.collection('listings').doc(offerData.listingId).get();
      const listing = listingDoc.data();

      const sellerDoc = await db.collection('users').doc(offerData.sellerId).get();
      const seller = sellerDoc.data();

      const buyerDoc = await db.collection('users').doc(offerData.buyerId).get();
      const buyer = buyerDoc.data();

      // Skip if notifications disabled
      if (seller?.notificationSettings?.offers === false) return;

      // Generate notification
      const notification = templates.generateOfferReceivedNotification({
        buyerName: buyer?.displayName || 'Someone',
        listingTitle: listing?.title || 'Your item',
        offerAmount: offerData.amount.amount,
        currency: offerData.amount.currency,
        message: offerData.message,
        offerId,
        listingId: offerData.listingId
      });

      // Send push notification
      await fcmService.sendToUser(offerData.sellerId, notification);

      // Track notification sent
      await analytics.track('marketplace_offer_notification_sent', {
        sellerId: offerData.sellerId,
        buyerId: offerData.buyerId,
        offerId,
        listingId: offerData.listingId
      });

    } catch (error) {
      logger.error('Error sending offer notification', { offerId, error });
    }
  }
);

/**
 * Trigger: Send notification when offer status changes
 */
export const onOfferUpdated = onDocumentUpdated(
  'offers/{offerId}',
  async (event) => {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();
    const offerId = event.params.offerId;

    if (!beforeData || !afterData) return;

    // Only notify on status changes
    if (beforeData.status === afterData.status) return;

    try {
      const buyerDoc = await db.collection('users').doc(afterData.buyerId).get();
      const buyer = buyerDoc.data();

      if (buyer?.notificationSettings?.offers === false) return;

      let notification;

      switch (afterData.status) {
        case 'accepted':
          const listingDoc = await db.collection('listings').doc(afterData.listingId).get();
          const listing = listingDoc.data();

          notification = templates.generateOfferAcceptedNotification({
            listingTitle: listing?.title || 'Item',
            finalAmount: afterData.finalAmount?.amount || afterData.amount.amount,
            currency: afterData.amount.currency,
            offerId,
            listingId: afterData.listingId
          });
          break;

        case 'declined':
          notification = templates.generateOfferDeclinedNotification({
            offerId,
            sellerMessage: afterData.sellerMessage
          });
          break;

        case 'counter_offered':
          notification = templates.generateCounterOfferNotification({
            counterAmount: afterData.counterOffer.amount,
            currency: afterData.counterOffer.currency,
            sellerMessage: afterData.sellerMessage,
            offerId,
            expiresAt: afterData.expiresAt
          });
          break;

        default:
          return;
      }

      if (notification) {
        await fcmService.sendToUser(afterData.buyerId, notification);

        await analytics.track('marketplace_offer_status_notification_sent', {
          buyerId: afterData.buyerId,
          offerId,
          newStatus: afterData.status
        });
      }

    } catch (error) {
      logger.error('Error sending offer status notification', { offerId, error });
    }
  }
);

/**
 * Background task: Expire old offers
 */
export const expireOffers = onCall(
  { invoker: 'private' },
  async () => {
    return trace('marketplace.expireOffers', 'system', async () => {
      try {
        const now = new Date();
        
        // Find expired offers
        const expiredOffers = await db.collection('offers')
          .where('status', 'in', ['pending', 'counter_offered'])
          .where('expiresAt', '<=', now)
          .get();

        const batch = db.batch();
        let expiredCount = 0;

        expiredOffers.docs.forEach(doc => {
          batch.update(doc.ref, {
            status: 'expired',
            expiredAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp()
          });
          expiredCount++;
        });

        if (expiredCount > 0) {
          await batch.commit();
          logger.info(`Expired ${expiredCount} offers`);
        }

        return { expiredCount };

      } catch (error) {
        logger.error('Error expiring offers', { error });
        throw new HttpsError('internal', 'Failed to expire offers');
      }
    });
  }
);