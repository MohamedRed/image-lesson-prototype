import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { logger } from 'firebase-functions';
import { 
  SplitIntent,
  SplitIntentRequest,
  SplitShare,
  SplitStatus,
  Booking,
  ActivitiesError,
  ErrorCodes
} from './models';
import { incrementCounter } from '../shared/metrics';
import { getStripeClient } from '../services/payments/stripeService';
import { sendNotification } from '../services/notifications/fcmService';

const db = admin.firestore();

// Create split payment intent
export const createSplitIntent = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const request: SplitIntentRequest = data;
  const { bookingId, shareType, customShares } = request;

  if (!bookingId || !shareType) {
    throw new functions.https.HttpsError('invalid-argument', 'Booking ID and share type required');
  }

  try {
    const result = await db.runTransaction(async (transaction) => {
      // Get booking
      const bookingRef = db.collection('bookings').doc(bookingId);
      const bookingDoc = await transaction.get(bookingRef);

      if (!bookingDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Booking not found');
      }

      const bookingData = bookingDoc.data() as Booking;

      // Only organizer can create split
      if (bookingData.organizerId !== context.auth!.uid) {
        throw new functions.https.HttpsError('permission-denied', 'Only organizer can create split');
      }

      // Can only split pending or awaiting_split bookings
      if (!['pending', 'awaiting_split'].includes(bookingData.status)) {
        throw new functions.https.HttpsError('failed-precondition', 'Booking cannot be split');
      }

      // Calculate shares
      const shares = calculateShares(
        bookingData.participants.map(p => ({ userId: p.userId, userName: p.userName })),
        bookingData.totalAmount,
        shareType,
        customShares
      );

      // Validate total matches booking amount
      const totalShares = shares.reduce((sum, share) => sum + share.amount, 0);
      if (Math.abs(totalShares - bookingData.totalAmount) > 0.01) { // Allow 1 centime tolerance
        throw new functions.https.HttpsError('invalid-argument', 'Share amounts do not match booking total');
      }

      // Create split intent
      const splitIntent: Omit<SplitIntent, 'id'> = {
        bookingId,
        shareType,
        shares,
        status: 'pending',
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000)), // 24 hours
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      const splitRef = db.collection('splitIntents').doc();
      transaction.set(splitRef, splitIntent);

      // Update booking status
      transaction.update(bookingRef, {
        status: 'awaiting_split',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { splitId: splitRef.id, shares };
    });

    // Send split payment notifications
    await sendSplitPaymentNotifications(result.splitId, bookingId, result.shares);

    await incrementCounter('activities_splits_created', 1);

    logger.info(`Split payment created: ${result.splitId}`, {
      splitId: result.splitId,
      bookingId,
      shareType,
      participantCount: result.shares.length
    });

    return { splitId: result.splitId };

  } catch (error) {
    logger.error('Error creating split payment:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to create split payment');
  }
});

// Pay split share
export const paySplitShare = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { splitId, paymentMethodId } = data;

  if (!splitId || !paymentMethodId) {
    throw new functions.https.HttpsError('invalid-argument', 'Split ID and payment method required');
  }

  try {
    const result = await db.runTransaction(async (transaction) => {
      const splitRef = db.collection('splitIntents').doc(splitId);
      const splitDoc = await transaction.get(splitRef);

      if (!splitDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Split intent not found');
      }

      const splitData = splitDoc.data() as SplitIntent;

      // Check if split is still valid
      if (splitData.status === 'expired' || splitData.status === 'cancelled') {
        throw new functions.https.HttpsError('failed-precondition', 'Split payment expired or cancelled');
      }

      // Check expiry
      const now = admin.firestore.Timestamp.now();
      if (now > splitData.expiresAt) {
        transaction.update(splitRef, {
          status: 'expired',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        throw new functions.https.HttpsError('failed-precondition', 'Split payment expired');
      }

      // Find user's share
      const userShare = splitData.shares.find(share => share.userId === context.auth!.uid);
      if (!userShare) {
        throw new functions.https.HttpsError('not-found', 'No share found for user');
      }

      // Check if already paid
      if (userShare.status === 'paid') {
        throw new functions.https.HttpsError('failed-precondition', 'Share already paid');
      }

      return { splitData, userShare };
    });

    // Process Stripe payment
    const stripe = getStripeClient();
    
    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(result.userShare.amount * 100), // Convert MAD to cents
      currency: 'mad',
      payment_method: paymentMethodId,
      confirmation_method: 'manual',
      confirm: true,
      metadata: {
        splitId: splitId,
        userId: context.auth.uid,
        bookingId: result.splitData.bookingId,
        type: 'activities_split_payment'
      },
      return_url: 'https://your-app.com/payment-return', // TODO: Configure proper return URL
    });

    // Update split with payment intent
    await db.runTransaction(async (transaction) => {
      const splitRef = db.collection('splitIntents').doc(splitId);
      const splitDoc = await transaction.get(splitRef);
      const splitData = splitDoc.data() as SplitIntent;

      const updatedShares = splitData.shares.map(share => {
        if (share.userId === context.auth!.uid) {
          return {
            ...share,
            status: paymentIntent.status === 'succeeded' ? 'paid' as const : 'pending' as const,
            paymentIntentId: paymentIntent.id,
            paidAt: paymentIntent.status === 'succeeded' ? 
              admin.firestore.FieldValue.serverTimestamp() : 
              undefined,
          };
        }
        return share;
      });

      // Check if all shares are paid
      const allPaid = updatedShares.every(share => share.status === 'paid');
      
      transaction.update(splitRef, {
        shares: updatedShares,
        status: allPaid ? 'paid' : 'partial',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // If all paid, confirm the booking
      if (allPaid) {
        await confirmBookingAfterSplit(result.splitData.bookingId, transaction);
      }
    });

    await incrementCounter('activities_split_payments', 1);
    await incrementCounter('activities_split_revenue', result.userShare.amount);

    logger.info(`Split payment processed: ${splitId}`, {
      userId: context.auth.uid,
      amount: result.userShare.amount,
      paymentIntentId: paymentIntent.id,
      status: paymentIntent.status
    });

    return {
      success: true,
      paymentIntentId: paymentIntent.id,
      status: paymentIntent.status,
      clientSecret: paymentIntent.client_secret
    };

  } catch (error) {
    logger.error('Error processing split payment:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to process payment');
  }
});

// Get split intent details
export const getSplitIntent = functions.https.onCall(async (data, context) => {
  const { splitId } = data;

  if (!splitId) {
    throw new functions.https.HttpsError('invalid-argument', 'Split ID required');
  }

  try {
    const splitDoc = await db.collection('splitIntents').doc(splitId).get();

    if (!splitDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Split intent not found');
    }

    const splitData = { id: splitDoc.id, ...splitDoc.data() } as SplitIntent;

    // Check authorization - user must be in the split
    if (context.auth) {
      const userInSplit = splitData.shares.some(share => share.userId === context.auth!.uid);
      if (!userInSplit) {
        throw new functions.https.HttpsError('permission-denied', 'Not authorized');
      }
    }

    // Get booking details
    const bookingDoc = await db.collection('bookings').doc(splitData.bookingId).get();
    const booking = bookingDoc.exists ? { id: bookingDoc.id, ...bookingDoc.data() } : null;

    return {
      ...splitData,
      booking
    };

  } catch (error) {
    logger.error('Error getting split intent:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to get split intent');
  }
});

// Cancel split intent
export const cancelSplitIntent = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { splitId } = data;

  if (!splitId) {
    throw new functions.https.HttpsError('invalid-argument', 'Split ID required');
  }

  try {
    await db.runTransaction(async (transaction) => {
      const splitRef = db.collection('splitIntents').doc(splitId);
      const splitDoc = await transaction.get(splitRef);

      if (!splitDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Split intent not found');
      }

      const splitData = splitDoc.data() as SplitIntent;

      // Get booking to check authorization
      const bookingDoc = await transaction.get(db.collection('bookings').doc(splitData.bookingId));
      const bookingData = bookingDoc.data() as Booking;

      // Only organizer can cancel split
      if (bookingData.organizerId !== context.auth!.uid) {
        throw new functions.https.HttpsError('permission-denied', 'Only organizer can cancel split');
      }

      // Cannot cancel fully paid splits
      if (splitData.status === 'paid') {
        throw new functions.https.HttpsError('failed-precondition', 'Cannot cancel paid split');
      }

      // Update split status
      transaction.update(splitRef, {
        status: 'cancelled',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update booking status back to pending
      transaction.update(db.collection('bookings').doc(splitData.bookingId), {
        status: 'pending',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return { success: true };

  } catch (error) {
    logger.error('Error cancelling split intent:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to cancel split');
  }
});

// Helper function to calculate shares
function calculateShares(
  participants: Array<{ userId: string; userName: string }>,
  totalAmount: number,
  shareType: 'even' | 'custom',
  customShares?: Array<{ userId: string; amount: number }>
): SplitShare[] {
  if (shareType === 'even') {
    const amountPerPerson = Math.round((totalAmount / participants.length) * 100) / 100; // Round to 2 decimal places
    let remainingAmount = totalAmount;
    
    return participants.map((participant, index) => {
      // For the last participant, assign remaining amount to handle rounding
      const amount = index === participants.length - 1 ? remainingAmount : amountPerPerson;
      remainingAmount -= amount;
      
      return {
        userId: participant.userId,
        userName: participant.userName,
        amount: amount,
        status: 'pending'
      };
    });
  } else if (shareType === 'custom' && customShares) {
    // Validate custom shares
    const shareMap = new Map(customShares.map(s => [s.userId, s.amount]));
    
    return participants.map(participant => {
      const amount = shareMap.get(participant.userId) || 0;
      return {
        userId: participant.userId,
        userName: participant.userName,
        amount: amount,
        status: 'pending'
      };
    });
  }

  throw new Error('Invalid share type or missing custom shares');
}

// Helper function to confirm booking after successful split payment
async function confirmBookingAfterSplit(
  bookingId: string, 
  transaction: admin.firestore.Transaction
): Promise<void> {
  const bookingRef = db.collection('bookings').doc(bookingId);
  
  transaction.update(bookingRef, {
    status: 'confirmed',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Update group status
  const bookingDoc = await transaction.get(bookingRef);
  const bookingData = bookingDoc.data() as Booking;
  
  transaction.update(db.collection('groups').doc(bookingData.groupId), {
    status: 'confirmed',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// Helper function to send split payment notifications
async function sendSplitPaymentNotifications(
  splitId: string,
  bookingId: string,
  shares: SplitShare[]
): Promise<void> {
  try {
    // Get booking details for context
    const bookingDoc = await db.collection('bookings').doc(bookingId).get();
    const bookingData = bookingDoc.data() as Booking;

    // Get activity name
    const activityDoc = await db.collection('activities').doc(bookingData.activityId).get();
    const activityName = activityDoc.exists ? activityDoc.data()!.title : 'Activity';

    // Send notification to each participant
    const notifications = shares.map(async (share) => {
      try {
        await sendNotification(share.userId, {
          title: 'Payment Required',
          body: `Please pay ${share.amount} MAD for "${activityName}"`,
          data: {
            type: 'split_payment_request',
            splitId: splitId,
            bookingId: bookingId,
            amount: share.amount.toString(),
          }
        });
      } catch (error) {
        logger.warn(`Failed to send split payment notification to ${share.userId}:`, error);
      }
    });

    await Promise.allSettled(notifications);

  } catch (error) {
    logger.error('Error sending split payment notifications:', error);
  }
}

// Cron job to handle expired split intents
export const handleExpiredSplits = functions
  .runWith({
    timeoutSeconds: 300,
    memory: '512MB'
  })
  .pubsub.schedule('every 1 hours')
  .onRun(async (context) => {
    try {
      const now = admin.firestore.Timestamp.now();
      
      // Find expired split intents
      const expiredSplits = await db.collection('splitIntents')
        .where('status', 'in', ['pending', 'partial'])
        .where('expiresAt', '<', now)
        .limit(100)
        .get();

      const batch = db.batch();
      let expiredCount = 0;

      expiredSplits.docs.forEach(doc => {
        const splitData = doc.data() as SplitIntent;
        
        // Update split status
        batch.update(doc.ref, {
          status: 'expired',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Update associated booking
        const bookingRef = db.collection('bookings').doc(splitData.bookingId);
        batch.update(bookingRef, {
          status: 'cancelled',
          cancellation: {
            reason: 'Split payment expired',
            cancelledBy: 'system',
            cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        expiredCount++;
      });

      if (expiredCount > 0) {
        await batch.commit();
        logger.info(`Expired ${expiredCount} split intents`);
      }

      return { expiredCount };

    } catch (error) {
      logger.error('Error handling expired splits:', error);
      throw error;
    }
  });