import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { trace } from '../shared/trace';
import { analytics } from '../shared/analytics';
import { fcmService } from '../services/notifications/fcmService';
import { templates } from '../services/notifications/templates';

const db = getFirestore();

interface ReservationData {
  listingId: string;
  meetupLocation: {
    lat: number;
    lng: number;
    address: string;
    name?: string;
  };
  scheduledAt: Date;
  notes?: string;
  contactInfo?: {
    phone?: string;
    preferredContact: 'phone' | 'chat';
  };
}

interface MeetupUpdate {
  status: 'confirmed' | 'cancelled' | 'completed' | 'no_show';
  notes?: string;
  completionCode?: string;
}

/**
 * Create a reservation with meetup scheduling
 * Per Section 12 - Reservation & Meetup Scheduling
 */
export const createReservation = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.createReservation', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const data = request.data as ReservationData;
      const buyerId = request.auth.uid;

      if (!data.listingId || !data.meetupLocation || !data.scheduledAt) {
        throw new HttpsError('invalid-argument', 'Listing ID, meetup location, and scheduled time are required');
      }

      try {
        const result = await db.runTransaction(async (transaction) => {
          // Verify listing is reserved by this buyer
          const listingRef = db.collection('listings').doc(data.listingId);
          const listingDoc = await transaction.get(listingRef);

          if (!listingDoc.exists) {
            throw new HttpsError('not-found', 'Listing not found');
          }

          const listing = listingDoc.data();

          if (listing?.status !== 'reserved' || listing?.reservedBy !== buyerId) {
            throw new HttpsError('failed-precondition', 'Listing is not reserved by you');
          }

          // Check if reservation already exists
          const existingReservation = await db.collection('reservations')
            .where('listingId', '==', data.listingId)
            .where('buyerId', '==', buyerId)
            .where('status', 'in', ['pending', 'confirmed'])
            .get();

          if (!existingReservation.empty) {
            throw new HttpsError('already-exists', 'Reservation already exists for this listing');
          }

          // Validate scheduled time (must be in future, within 14 days)
          const scheduledTime = new Date(data.scheduledAt);
          const now = new Date();
          const maxTime = new Date(now.getTime() + 14 * 24 * 60 * 60 * 1000);

          if (scheduledTime <= now) {
            throw new HttpsError('invalid-argument', 'Scheduled time must be in the future');
          }

          if (scheduledTime > maxTime) {
            throw new HttpsError('invalid-argument', 'Scheduled time cannot be more than 14 days in advance');
          }

          // Generate completion code
          const completionCode = generateCompletionCode();

          // Create reservation
          const reservationRef = db.collection('reservations').doc();
          const reservation = {
            id: reservationRef.id,
            listingId: data.listingId,
            buyerId,
            sellerId: listing.sellerId,
            status: 'pending',
            meetupLocation: data.meetupLocation,
            scheduledAt: scheduledTime,
            notes: data.notes || '',
            contactInfo: data.contactInfo || null,
            completionCode,
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp()
          };

          transaction.set(reservationRef, reservation);

          // Update listing status
          transaction.update(listingRef, {
            status: 'meetup_scheduled',
            updatedAt: FieldValue.serverTimestamp()
          });

          return {
            reservationId: reservationRef.id,
            completionCode,
            scheduledAt: scheduledTime
          };
        });

        // Analytics
        await analytics.track('marketplace_reservation_created', {
          buyerId,
          listingId: data.listingId,
          scheduledAt: data.scheduledAt,
          hasNotes: !!data.notes,
          hasContactInfo: !!data.contactInfo
        });

        return { success: true, ...result };

      } catch (error) {
        logger.error('Error creating reservation', { buyerId, listingId: data.listingId, error });
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', 'Failed to create reservation');
      }
    });
  }
);

/**
 * Update meetup details or reschedule
 */
export const updateMeetup = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.updateMeetup', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const { reservationId, scheduledAt, meetupLocation, notes } = request.data;
      const userId = request.auth.uid;

      if (!reservationId) {
        throw new HttpsError('invalid-argument', 'Reservation ID is required');
      }

      try {
        const reservationRef = db.collection('reservations').doc(reservationId);
        const reservationDoc = await reservationRef.get();

        if (!reservationDoc.exists) {
          throw new HttpsError('not-found', 'Reservation not found');
        }

        const reservation = reservationDoc.data();

        // Verify user is participant
        if (reservation?.buyerId !== userId && reservation?.sellerId !== userId) {
          throw new HttpsError('permission-denied', 'You are not a participant in this reservation');
        }

        // Check if reservation can be updated
        if (!['pending', 'confirmed'].includes(reservation?.status)) {
          throw new HttpsError('failed-precondition', 'Reservation cannot be updated');
        }

        // Prepare updates
        const updateData: any = {
          updatedAt: FieldValue.serverTimestamp(),
          lastUpdatedBy: userId
        };

        if (scheduledAt) {
          const newTime = new Date(scheduledAt);
          const now = new Date();
          const maxTime = new Date(now.getTime() + 14 * 24 * 60 * 60 * 1000);

          if (newTime <= now || newTime > maxTime) {
            throw new HttpsError('invalid-argument', 'Invalid scheduled time');
          }

          updateData.scheduledAt = newTime;
          updateData.status = 'pending'; // Reset to pending if rescheduled
        }

        if (meetupLocation) {
          updateData.meetupLocation = meetupLocation;
        }

        if (notes !== undefined) {
          updateData.notes = notes;
        }

        await reservationRef.update(updateData);

        // Analytics
        await analytics.track('marketplace_meetup_updated', {
          userId,
          reservationId,
          hasReschedule: !!scheduledAt,
          hasLocationChange: !!meetupLocation
        });

        return { success: true };

      } catch (error) {
        logger.error('Error updating meetup', { userId, reservationId, error });
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', 'Failed to update meetup');
      }
    });
  }
);

/**
 * Confirm meetup attendance
 */
export const confirmMeetup = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.confirmMeetup', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const { reservationId, confirmed } = request.data;
      const userId = request.auth.uid;

      try {
        const reservationRef = db.collection('reservations').doc(reservationId);
        const reservationDoc = await reservationRef.get();

        if (!reservationDoc.exists) {
          throw new HttpsError('not-found', 'Reservation not found');
        }

        const reservation = reservationDoc.data();

        // Verify user is participant
        if (reservation?.buyerId !== userId && reservation?.sellerId !== userId) {
          throw new HttpsError('permission-denied', 'You are not a participant in this reservation');
        }

        // Update confirmation status
        const isBuyer = reservation?.buyerId === userId;
        const confirmationField = isBuyer ? 'buyerConfirmed' : 'sellerConfirmed';

        const updateData: any = {
          [confirmationField]: confirmed,
          [`${confirmationField}At`]: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp()
        };

        // If both parties confirmed, mark as confirmed
        const otherConfirmed = isBuyer ? reservation?.sellerConfirmed : reservation?.buyerConfirmed;
        if (confirmed && otherConfirmed) {
          updateData.status = 'confirmed';
          updateData.confirmedAt = FieldValue.serverTimestamp();
        }

        await reservationRef.update(updateData);

        // Analytics
        await analytics.track('marketplace_meetup_confirmed', {
          userId,
          reservationId,
          userType: isBuyer ? 'buyer' : 'seller',
          confirmed,
          bothConfirmed: confirmed && otherConfirmed
        });

        return { success: true, bothConfirmed: confirmed && otherConfirmed };

      } catch (error) {
        logger.error('Error confirming meetup', { userId, reservationId, error });
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', 'Failed to confirm meetup');
      }
    });
  }
);

/**
 * Complete meetup transaction
 */
export const completeMeetup = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.completeMeetup', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const { reservationId, completionCode, rating, review } = request.data;
      const userId = request.auth.uid;

      if (!completionCode) {
        throw new HttpsError('invalid-argument', 'Completion code is required');
      }

      try {
        const result = await db.runTransaction(async (transaction) => {
          const reservationRef = db.collection('reservations').doc(reservationId);
          const reservationDoc = await transaction.get(reservationRef);

          if (!reservationDoc.exists) {
            throw new HttpsError('not-found', 'Reservation not found');
          }

          const reservation = reservationDoc.data();

          // Verify user is participant
          if (reservation?.buyerId !== userId && reservation?.sellerId !== userId) {
            throw new HttpsError('permission-denied', 'You are not a participant in this reservation');
          }

          // Verify completion code
          if (reservation?.completionCode !== completionCode) {
            throw new HttpsError('invalid-argument', 'Invalid completion code');
          }

          // Check if already completed
          if (reservation?.status === 'completed') {
            throw new HttpsError('failed-precondition', 'Meetup already completed');
          }

          const isBuyer = reservation?.buyerId === userId;

          // Update reservation
          const updateData: any = {
            status: 'completed',
            completedAt: FieldValue.serverTimestamp(),
            completedBy: userId,
            updatedAt: FieldValue.serverTimestamp()
          };

          if (rating) {
            updateData[`${isBuyer ? 'buyerRating' : 'sellerRating'}`] = rating;
          }

          if (review) {
            updateData[`${isBuyer ? 'buyerReview' : 'sellerReview'}`] = review;
          }

          transaction.update(reservationRef, updateData);

          // Update listing status to sold
          const listingRef = db.collection('listings').doc(reservation.listingId);
          transaction.update(listingRef, {
            status: 'sold',
            soldAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp()
          });

          // Update user stats
          const buyerRef = db.collection('users').doc(reservation.buyerId);
          const sellerRef = db.collection('users').doc(reservation.sellerId);

          transaction.update(buyerRef, {
            'marketplace.stats.purchaseCount': FieldValue.increment(1),
            'marketplace.stats.lastPurchaseAt': FieldValue.serverTimestamp()
          });

          transaction.update(sellerRef, {
            'marketplace.stats.saleCount': FieldValue.increment(1),
            'marketplace.stats.lastSaleAt': FieldValue.serverTimestamp(),
            'marketplace.rating': updateSellerRating(reservation.sellerId, rating)
          });

          return { success: true };
        });

        // Analytics
        await analytics.track('marketplace_meetup_completed', {
          userId,
          reservationId,
          listingId: reservationId, // Would get from reservation
          userType: userId === reservationId ? 'buyer' : 'seller', // Would determine properly
          hasRating: !!rating,
          hasReview: !!review
        });

        return result;

      } catch (error) {
        logger.error('Error completing meetup', { userId, reservationId, error });
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', 'Failed to complete meetup');
      }
    });
  }
);

/**
 * Cancel reservation
 */
export const cancelReservation = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.cancelReservation', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const { reservationId, reason } = request.data;
      const userId = request.auth.uid;

      try {
        const result = await db.runTransaction(async (transaction) => {
          const reservationRef = db.collection('reservations').doc(reservationId);
          const reservationDoc = await transaction.get(reservationRef);

          if (!reservationDoc.exists) {
            throw new HttpsError('not-found', 'Reservation not found');
          }

          const reservation = reservationDoc.data();

          // Verify user is participant
          if (reservation?.buyerId !== userId && reservation?.sellerId !== userId) {
            throw new HttpsError('permission-denied', 'You are not a participant in this reservation');
          }

          // Check if can be cancelled
          if (!['pending', 'confirmed'].includes(reservation?.status)) {
            throw new HttpsError('failed-precondition', 'Reservation cannot be cancelled');
          }

          // Update reservation
          transaction.update(reservationRef, {
            status: 'cancelled',
            cancelledBy: userId,
            cancelledAt: FieldValue.serverTimestamp(),
            cancellationReason: reason || '',
            updatedAt: FieldValue.serverTimestamp()
          });

          // Return listing to active status
          const listingRef = db.collection('listings').doc(reservation.listingId);
          transaction.update(listingRef, {
            status: 'active',
            reservedBy: FieldValue.delete(),
            reservedAt: FieldValue.delete(),
            updatedAt: FieldValue.serverTimestamp()
          });

          return { success: true };
        });

        // Analytics
        await analytics.track('marketplace_reservation_cancelled', {
          userId,
          reservationId,
          cancelledBy: userId,
          reason: reason || 'not_specified'
        });

        return result;

      } catch (error) {
        logger.error('Error cancelling reservation', { userId, reservationId, error });
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', 'Failed to cancel reservation');
      }
    });
  }
);

/**
 * Report no-show
 */
export const reportNoShow = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.reportNoShow', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const { reservationId, evidence } = request.data;
      const reporterId = request.auth.uid;

      try {
        const reservationRef = db.collection('reservations').doc(reservationId);
        const reservationDoc = await reservationRef.get();

        if (!reservationDoc.exists) {
          throw new HttpsError('not-found', 'Reservation not found');
        }

        const reservation = reservationDoc.data();

        // Verify user is participant
        if (reservation?.buyerId !== reporterId && reservation?.sellerId !== reporterId) {
          throw new HttpsError('permission-denied', 'You are not a participant in this reservation');
        }

        // Check if meetup time has passed
        const scheduledTime = reservation?.scheduledAt?.toDate();
        const graceTime = new Date(scheduledTime.getTime() + 30 * 60 * 1000); // 30 min grace

        if (new Date() < graceTime) {
          throw new HttpsError('failed-precondition', 'Cannot report no-show before grace period');
        }

        // Create no-show report
        const reportRef = db.collection('reports').doc();
        await reportRef.set({
          id: reportRef.id,
          type: 'no_show',
          reservationId,
          reporterId,
          reportedUserId: reservation.buyerId === reporterId ? reservation.sellerId : reservation.buyerId,
          evidence: evidence || '',
          status: 'pending',
          createdAt: FieldValue.serverTimestamp()
        });

        // Update reservation
        await reservationRef.update({
          status: 'no_show',
          noShowReportedBy: reporterId,
          noShowReportedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp()
        });

        // Analytics
        await analytics.track('marketplace_no_show_reported', {
          reporterId,
          reservationId,
          reportedUserId: reservation.buyerId === reporterId ? reservation.sellerId : reservation.buyerId
        });

        return { success: true, reportId: reportRef.id };

      } catch (error) {
        logger.error('Error reporting no-show', { reporterId, reservationId, error });
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', 'Failed to report no-show');
      }
    });
  }
);

/**
 * Trigger: Send reservation notifications
 */
export const onReservationCreated = onDocumentCreated(
  'reservations/{reservationId}',
  async (event) => {
    const reservationData = event.data?.data();
    const reservationId = event.params.reservationId;

    if (!reservationData) return;

    try {
      // Get user details
      const sellerDoc = await db.collection('users').doc(reservationData.sellerId).get();
      const seller = sellerDoc.data();

      const buyerDoc = await db.collection('users').doc(reservationData.buyerId).get();
      const buyer = buyerDoc.data();

      const listingDoc = await db.collection('listings').doc(reservationData.listingId).get();
      const listing = listingDoc.data();

      // Notify seller
      if (seller?.notificationSettings?.reservations !== false) {
        const sellerNotification = templates.generateReservationCreatedNotification({
          buyerName: buyer?.displayName || 'A buyer',
          listingTitle: listing?.title || 'Your item',
          scheduledAt: reservationData.scheduledAt,
          meetupLocation: reservationData.meetupLocation,
          reservationId
        });

        await fcmService.sendToUser(reservationData.sellerId, sellerNotification);
      }

      // Notify buyer (confirmation)
      if (buyer?.notificationSettings?.reservations !== false) {
        const buyerNotification = templates.generateReservationConfirmationNotification({
          listingTitle: listing?.title || 'Item',
          scheduledAt: reservationData.scheduledAt,
          meetupLocation: reservationData.meetupLocation,
          completionCode: reservationData.completionCode,
          reservationId
        });

        await fcmService.sendToUser(reservationData.buyerId, buyerNotification);
      }

      // Analytics
      await analytics.track('marketplace_reservation_notifications_sent', {
        reservationId,
        buyerId: reservationData.buyerId,
        sellerId: reservationData.sellerId
      });

    } catch (error) {
      logger.error('Error sending reservation notifications', { reservationId, error });
    }
  }
);

// Helper functions

function generateCompletionCode(): string {
  return Math.random().toString(36).substring(2, 8).toUpperCase();
}

async function updateSellerRating(sellerId: string, newRating?: number): Promise<number> {
  if (!newRating) return 4.5; // Default rating
  
  // Simplified rating calculation
  // In production, would fetch all ratings and calculate average
  return Math.min(5.0, Math.max(1.0, newRating));
}

/**
 * Background task: Send meetup reminders
 */
export const sendMeetupReminders = onCall(
  { invoker: 'private' },
  async () => {
    return trace('marketplace.sendMeetupReminders', 'system', async () => {
      try {
        const now = new Date();
        const reminderTime = new Date(now.getTime() + 2 * 60 * 60 * 1000); // 2 hours ahead

        // Find reservations needing reminders
        const reservations = await db.collection('reservations')
          .where('status', '==', 'confirmed')
          .where('scheduledAt', '>=', now)
          .where('scheduledAt', '<=', reminderTime)
          .where('reminderSent', '==', false)
          .get();

        let reminderCount = 0;

        for (const doc of reservations.docs) {
          const reservation = doc.data();

          try {
            // Send reminders to both parties
            const buyerDoc = await db.collection('users').doc(reservation.buyerId).get();
            const sellerDoc = await db.collection('users').doc(reservation.sellerId).get();
            const listingDoc = await db.collection('listings').doc(reservation.listingId).get();

            const buyer = buyerDoc.data();
            const seller = sellerDoc.data();
            const listing = listingDoc.data();

            const reminderNotification = templates.generateMeetupReminderNotification({
              listingTitle: listing?.title || 'Item',
              scheduledAt: reservation.scheduledAt,
              meetupLocation: reservation.meetupLocation,
              completionCode: reservation.completionCode,
              reservationId: doc.id
            });

            // Send to both users
            await Promise.all([
              fcmService.sendToUser(reservation.buyerId, reminderNotification),
              fcmService.sendToUser(reservation.sellerId, reminderNotification)
            ]);

            // Mark reminder as sent
            await doc.ref.update({ reminderSent: true });

            reminderCount++;

          } catch (error) {
            logger.error('Error sending meetup reminder', { reservationId: doc.id, error });
          }
        }

        logger.info(`Sent ${reminderCount} meetup reminders`);
        return { reminderCount };

      } catch (error) {
        logger.error('Error in sendMeetupReminders', { error });
        throw new HttpsError('internal', 'Failed to send meetup reminders');
      }
    });
  }
);