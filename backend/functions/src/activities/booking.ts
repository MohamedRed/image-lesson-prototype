import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { logger } from 'firebase-functions';
import { 
  Booking,
  BookingRequest,
  BookingStatus,
  BookingParticipant,
  ActivitySession,
  ActivitiesError,
  ErrorCodes
} from './models';
import { incrementCounter } from '../shared/metrics';
import { updateSessionStatus } from './catalog';
import { sendNotification } from '../services/notifications/fcmService';

const db = admin.firestore();

// Create a booking
export const createBooking = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const request: BookingRequest = data;
  const { groupId, activityId, sessionId, participants } = request;

  if (!groupId || !activityId || !sessionId || !participants?.length) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }

  try {
    const bookingResult = await db.runTransaction(async (transaction) => {
      // Get and validate group
      const groupDoc = await transaction.get(db.collection('groups').doc(groupId));
      if (!groupDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Group not found');
      }

      const groupData = groupDoc.data()!;
      
      // Only organizer can create booking
      if (groupData.organizerId !== context.auth!.uid) {
        throw new functions.https.HttpsError('permission-denied', 'Only group organizer can create bookings');
      }

      // Get and validate activity
      const activityDoc = await transaction.get(db.collection('activities').doc(activityId));
      if (!activityDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Activity not found');
      }

      const activityData = activityDoc.data()!;

      // Get and validate session
      const sessionDoc = await transaction.get(db.collection('activitySessions').doc(sessionId));
      if (!sessionDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Session not found');
      }

      const sessionData = sessionDoc.data() as ActivitySession;

      // Check session capacity
      if (sessionData.bookedCount + participants.length > sessionData.capacity) {
        throw new functions.https.HttpsError('failed-precondition', 'Insufficient capacity');
      }

      // Check booking window
      const now = admin.firestore.Timestamp.now();
      if (now < sessionData.bookingWindow.opensAt || now > sessionData.bookingWindow.closesAt) {
        throw new functions.https.HttpsError('failed-precondition', 'Booking window closed');
      }

      // Check session status
      if (!['open', 'limited'].includes(sessionData.status)) {
        throw new functions.https.HttpsError('failed-precondition', 'Session not available');
      }

      // Validate participants are in group
      const invalidParticipants = participants.filter(id => 
        !groupData.participantUserIds.includes(id)
      );
      
      if (invalidParticipants.length > 0) {
        throw new functions.https.HttpsError('invalid-argument', 'Some participants not in group');
      }

      // Calculate pricing
      const pricePerUnit = sessionData.priceOverride || activityData.pricePerUnit;
      let totalAmount = 0;

      if (activityData.unit === 'person') {
        totalAmount = pricePerUnit * participants.length;
      } else if (activityData.unit === 'team' || activityData.unit === 'slot') {
        totalAmount = pricePerUnit; // Flat rate
      } else if (activityData.unit === 'hour') {
        const durationHours = activityData.durationMinutes / 60;
        totalAmount = pricePerUnit * durationHours;
      }

      // Get participant details
      const participantDetails: BookingParticipant[] = await Promise.all(
        participants.map(async (userId) => {
          try {
            const userRecord = await admin.auth().getUser(userId);
            return {
              userId,
              userName: userRecord.displayName || 'User',
              role: userId === context.auth!.uid ? 'organizer' : 'participant',
              status: 'accepted' // They're in the group already
            };
          } catch (error) {
            return {
              userId,
              userName: 'Unknown User',
              role: userId === context.auth!.uid ? 'organizer' : 'participant',
              status: 'accepted'
            };
          }
        })
      );

      // Create booking
      const booking: Omit<Booking, 'id'> = {
        groupId,
        activityId,
        sessionId,
        providerId: activityData.providerId,
        organizerId: context.auth!.uid,
        participants: participantDetails,
        totalAmount,
        currency: 'MAD',
        status: 'pending',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      const bookingRef = db.collection('bookings').doc();
      transaction.set(bookingRef, booking);

      // Reserve capacity in session
      transaction.update(db.collection('activitySessions').doc(sessionId), {
        bookedCount: admin.firestore.FieldValue.increment(participants.length),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update group status
      transaction.update(db.collection('groups').doc(groupId), {
        status: 'booking',
        sessionId: sessionId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { bookingId: bookingRef.id, totalAmount };
    });

    // Update session status after transaction
    await updateSessionStatus(sessionId);

    // Track metrics
    await incrementCounter('activities_bookings_created', 1);
    await incrementCounter('activities_revenue', bookingResult.totalAmount);

    logger.info(`Booking created: ${bookingResult.bookingId}`, {
      bookingId: bookingResult.bookingId,
      groupId,
      activityId,
      sessionId,
      totalAmount: bookingResult.totalAmount,
      participantCount: participants.length
    });

    return bookingResult;

  } catch (error) {
    logger.error('Error creating booking:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to create booking');
  }
});

// Confirm booking (after payment)
export const confirmBooking = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { bookingId } = data;

  if (!bookingId) {
    throw new functions.https.HttpsError('invalid-argument', 'Booking ID required');
  }

  try {
    await db.runTransaction(async (transaction) => {
      const bookingRef = db.collection('bookings').doc(bookingId);
      const bookingDoc = await transaction.get(bookingRef);

      if (!bookingDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Booking not found');
      }

      const bookingData = bookingDoc.data() as Booking;

      // Check authorization
      if (bookingData.organizerId !== context.auth!.uid) {
        throw new functions.https.HttpsError('permission-denied', 'Not authorized');
      }

      // Can only confirm pending bookings
      if (bookingData.status !== 'awaiting_split' && bookingData.status !== 'pending') {
        throw new functions.https.HttpsError('failed-precondition', 'Booking cannot be confirmed');
      }

      // Update booking status
      transaction.update(bookingRef, {
        status: 'confirmed',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update group status
      transaction.update(db.collection('groups').doc(bookingData.groupId), {
        status: 'confirmed',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    // Get booking details for notifications
    const bookingDoc = await db.collection('bookings').doc(bookingId).get();
    const bookingData = bookingDoc.data() as Booking;

    // Send confirmation notifications
    await sendBookingConfirmationNotifications(bookingData);

    await incrementCounter('activities_bookings_confirmed', 1);

    logger.info(`Booking confirmed: ${bookingId}`);

    return { success: true };

  } catch (error) {
    logger.error('Error confirming booking:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to confirm booking');
  }
});

// Cancel booking
export const cancelBooking = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { bookingId, reason } = data;

  if (!bookingId || !reason) {
    throw new functions.https.HttpsError('invalid-argument', 'Booking ID and reason required');
  }

  try {
    await db.runTransaction(async (transaction) => {
      const bookingRef = db.collection('bookings').doc(bookingId);
      const bookingDoc = await transaction.get(bookingRef);

      if (!bookingDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Booking not found');
      }

      const bookingData = bookingDoc.data() as Booking;

      // Check authorization (organizer or participants can cancel)
      const canCancel = bookingData.organizerId === context.auth!.uid ||
                       bookingData.participants.some(p => p.userId === context.auth!.uid);

      if (!canCancel) {
        throw new functions.https.HttpsError('permission-denied', 'Not authorized to cancel');
      }

      // Cannot cancel completed bookings
      if (bookingData.status === 'completed') {
        throw new functions.https.HttpsError('failed-precondition', 'Cannot cancel completed booking');
      }

      // Update booking
      transaction.update(bookingRef, {
        status: 'cancelled',
        cancellation: {
          reason,
          cancelledBy: context.auth!.uid,
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Release capacity
      transaction.update(db.collection('activitySessions').doc(bookingData.sessionId), {
        bookedCount: admin.firestore.FieldValue.increment(-bookingData.participants.length),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update group status
      transaction.update(db.collection('groups').doc(bookingData.groupId), {
        status: 'cancelled',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    // Update session status
    const bookingDoc = await db.collection('bookings').doc(bookingId).get();
    const bookingData = bookingDoc.data() as Booking;
    await updateSessionStatus(bookingData.sessionId);

    await incrementCounter('activities_bookings_cancelled', 1);

    logger.info(`Booking cancelled: ${bookingId}`, { reason });

    return { success: true };

  } catch (error) {
    logger.error('Error cancelling booking:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to cancel booking');
  }
});

// Get booking details
export const getBooking = functions.https.onCall(async (data, context) => {
  const { bookingId } = data;

  if (!bookingId) {
    throw new functions.https.HttpsError('invalid-argument', 'Booking ID required');
  }

  try {
    const bookingDoc = await db.collection('bookings').doc(bookingId).get();

    if (!bookingDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Booking not found');
    }

    const bookingData = { id: bookingDoc.id, ...bookingDoc.data() } as Booking;

    // Check authorization
    if (context.auth) {
      const userId = context.auth.uid;
      const hasAccess = bookingData.organizerId === userId ||
                       bookingData.participants.some(p => p.userId === userId);

      if (!hasAccess) {
        throw new functions.https.HttpsError('permission-denied', 'Not authorized');
      }
    }

    // Enrich with related data
    const [activityDoc, sessionDoc, groupDoc] = await Promise.all([
      db.collection('activities').doc(bookingData.activityId).get(),
      db.collection('activitySessions').doc(bookingData.sessionId).get(),
      db.collection('groups').doc(bookingData.groupId).get(),
    ]);

    return {
      ...bookingData,
      activity: activityDoc.exists ? { id: activityDoc.id, ...activityDoc.data() } : null,
      session: sessionDoc.exists ? { id: sessionDoc.id, ...sessionDoc.data() } : null,
      group: groupDoc.exists ? { id: groupDoc.id, ...groupDoc.data() } : null,
    };

  } catch (error) {
    logger.error('Error getting booking:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to get booking');
  }
});

// Mark booking as completed
export const completeBooking = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { bookingId } = data;

  if (!bookingId) {
    throw new functions.https.HttpsError('invalid-argument', 'Booking ID required');
  }

  try {
    await db.runTransaction(async (transaction) => {
      const bookingRef = db.collection('bookings').doc(bookingId);
      const bookingDoc = await transaction.get(bookingRef);

      if (!bookingDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Booking not found');
      }

      const bookingData = bookingDoc.data() as Booking;

      // Only organizer or participants can mark as completed
      const canComplete = bookingData.organizerId === context.auth!.uid ||
                         bookingData.participants.some(p => p.userId === context.auth!.uid);

      if (!canComplete) {
        throw new functions.https.HttpsError('permission-denied', 'Not authorized');
      }

      // Can only complete confirmed bookings
      if (bookingData.status !== 'confirmed') {
        throw new functions.https.HttpsError('failed-precondition', 'Booking not confirmed');
      }

      // Update status
      transaction.update(bookingRef, {
        status: 'completed',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update group status
      transaction.update(db.collection('groups').doc(bookingData.groupId), {
        status: 'completed',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    await incrementCounter('activities_bookings_completed', 1);

    return { success: true };

  } catch (error) {
    logger.error('Error completing booking:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to complete booking');
  }
});

// Helper function to send booking confirmation notifications
async function sendBookingConfirmationNotifications(booking: Booking): Promise<void> {
  try {
    // Get activity details for notification
    const activityDoc = await db.collection('activities').doc(booking.activityId).get();
    const activityName = activityDoc.exists ? activityDoc.data()!.title : 'Activity';

    // Get session details for timing
    const sessionDoc = await db.collection('activitySessions').doc(booking.sessionId).get();
    const sessionTime = sessionDoc.exists ? 
      new Date(sessionDoc.data()!.startAt.seconds * 1000).toLocaleString() : '';

    // Send to all participants
    const notifications = booking.participants.map(async (participant) => {
      try {
        await sendNotification(participant.userId, {
          title: 'Booking Confirmed! 🎉',
          body: `Your booking for "${activityName}" is confirmed${sessionTime ? ` for ${sessionTime}` : ''}`,
          data: {
            type: 'booking_confirmed',
            bookingId: booking.id!,
            activityId: booking.activityId,
            sessionId: booking.sessionId,
          }
        });
      } catch (error) {
        logger.warn(`Failed to send confirmation notification to ${participant.userId}:`, error);
      }
    });

    await Promise.allSettled(notifications);

  } catch (error) {
    logger.error('Error sending booking confirmation notifications:', error);
  }
}