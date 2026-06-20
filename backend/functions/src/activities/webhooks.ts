import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { logger } from 'firebase-functions';
import { onRequest } from 'firebase-functions/v2/https';
import { onDocumentWritten, onDocumentCreated } from 'firebase-functions/v2/firestore';
import Stripe from 'stripe';
import { getStripeClient, StripeWebhookService } from '../services/payments/stripeService';
import { sendNotification } from '../services/notifications/fcmService';
import { 
  Booking, 
  SplitIntent, 
  ActivityGroup, 
  PartnerRequest 
} from './models';
import { incrementCounter } from '../shared/metrics';

const db = admin.firestore();

// Stripe webhook handler for Activities payments
export const activitiesStripeWebhook = onRequest({ cors: true }, async (req, res) => {
  const sig = req.headers["stripe-signature"] as string | undefined;
  if (!sig) {
    res.status(400).send("Missing signature");
    return;
  }

  let event: Stripe.Event;
  try {
    event = await StripeWebhookService.constructEvent(req.rawBody as Buffer, sig);
  } catch (err: any) {
    logger.error("Activities Stripe webhook signature verification failed", err);
    res.status(400).send(`Webhook Error: ${err.message}`);
    return;
  }

  try {
    switch (event.type) {
      case 'payment_intent.succeeded':
        await handlePaymentSuccess(event.data.object as Stripe.PaymentIntent);
        break;
        
      case 'payment_intent.payment_failed':
        await handlePaymentFailure(event.data.object as Stripe.PaymentIntent);
        break;
        
      case 'payment_method.attached':
        // Handle payment method attachment if needed
        break;
        
      default:
        logger.info(`Unhandled Stripe event type: ${event.type}`);
    }

    res.json({ received: true });

  } catch (error) {
    logger.error('Error processing Stripe webhook:', error);
    res.status(500).json({ error: 'Webhook processing failed' });
  }
});

// Handle successful payment
async function handlePaymentSuccess(paymentIntent: Stripe.PaymentIntent): Promise<void> {
  const { metadata } = paymentIntent;
  
  if (!metadata.type || metadata.type !== 'activities_split_payment') {
    return;
  }

  const { splitId, userId, bookingId } = metadata;
  
  if (!splitId || !userId || !bookingId) {
    logger.error('Missing required metadata in payment intent:', metadata);
    return;
  }

  try {
    await db.runTransaction(async (transaction) => {
      // Update split intent
      const splitRef = db.collection('splitIntents').doc(splitId);
      const splitDoc = await transaction.get(splitRef);
      
      if (!splitDoc.exists) {
        throw new Error(`Split intent ${splitId} not found`);
      }

      const splitData = splitDoc.data() as SplitIntent;
      
      // Update user's share status
      const updatedShares = splitData.shares.map(share => {
        if (share.userId === userId) {
          return {
            ...share,
            status: 'paid' as const,
            paymentIntentId: paymentIntent.id,
            paidAt: admin.firestore.FieldValue.serverTimestamp(),
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

      // If all paid, update booking status
      if (allPaid) {
        const bookingRef = db.collection('bookings').doc(bookingId);
        transaction.update(bookingRef, {
          status: 'confirmed',
          paymentStatus: 'paid',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Update associated group status
        const bookingDoc = await transaction.get(bookingRef);
        if (bookingDoc.exists) {
          const bookingData = bookingDoc.data() as Booking;
          transaction.update(db.collection('groups').doc(bookingData.groupId), {
            status: 'confirmed',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }
    });

    // Send success notification
    await sendPaymentSuccessNotification(userId, splitId);
    
    await incrementCounter('activities_payments_succeeded', 1);
    
    logger.info('Payment processed successfully', {
      splitId,
      userId,
      bookingId,
      amount: paymentIntent.amount / 100
    });

  } catch (error) {
    logger.error('Error handling payment success:', error);
    throw error;
  }
}

// Handle failed payment
async function handlePaymentFailure(paymentIntent: Stripe.PaymentIntent): Promise<void> {
  const { metadata } = paymentIntent;
  
  if (!metadata.type || metadata.type !== 'activities_split_payment') {
    return;
  }

  const { splitId, userId } = metadata;
  
  if (!splitId || !userId) {
    logger.error('Missing required metadata in failed payment:', metadata);
    return;
  }

  try {
    // Send failure notification
    await sendPaymentFailureNotification(userId, splitId, paymentIntent.last_payment_error?.message);
    
    await incrementCounter('activities_payments_failed', 1);
    
    logger.info('Payment failure handled', {
      splitId,
      userId,
      error: paymentIntent.last_payment_error?.message
    });

  } catch (error) {
    logger.error('Error handling payment failure:', error);
  }
}

// Booking status change notifications
export const bookingStatusNotifier = onDocumentWritten('bookings/{bookingId}', async (event) => {
  const before = event.data?.before?.data() as Booking | undefined;
  const after = event.data?.after?.data() as Booking | undefined;
  
  if (!after) return;

  const statusChanged = before?.status !== after.status;
  if (!statusChanged) return;

  try {
    // Get group and participants
    const groupDoc = await db.collection('groups').doc(after.groupId).get();
    if (!groupDoc.exists) return;

    const group = groupDoc.data() as ActivityGroup;
    
    // Send notifications to all group participants
    const notifications = group.participantUserIds.map(async (userId) => {
      await sendBookingStatusNotification(userId, after, group.name);
    });

    await Promise.allSettled(notifications);
    
    await incrementCounter('activities_booking_notifications_sent', group.participantUserIds.length);

  } catch (error) {
    logger.error('Error sending booking notifications:', error);
  }
});

// Group invitation notifications
export const groupInvitationNotifier = onDocumentWritten('groups/{groupId}', async (event) => {
  const before = event.data?.before?.data() as ActivityGroup | undefined;
  const after = event.data?.after?.data() as ActivityGroup | undefined;
  
  if (!after) return;

  // Check for new invitations
  const beforeInvited = new Set(before?.invitedUserIds || []);
  const afterInvited = new Set(after.invitedUserIds || []);
  
  const newInvitations = Array.from(afterInvited).filter(userId => !beforeInvited.has(userId));
  
  if (newInvitations.length === 0) return;

  try {
    // Get organizer info
    const organizerRecord = await admin.auth().getUser(after.organizerId);
    const organizerName = organizerRecord.displayName || 'Someone';

    // Send invitations
    const notifications = newInvitations.map(async (userId) => {
      await sendGroupInvitationNotification(userId, after, organizerName);
    });

    await Promise.allSettled(notifications);
    
    await incrementCounter('activities_group_invitations_sent', newInvitations.length);

  } catch (error) {
    logger.error('Error sending group invitation notifications:', error);
  }
});

// Partner interest notifications
export const partnerInterestNotifier = onDocumentWritten('partnerRequests/{requestId}', async (event) => {
  const before = event.data?.before?.data() as PartnerRequest | undefined;
  const after = event.data?.after?.data() as PartnerRequest | undefined;
  
  if (!after) return;

  // Check for new interested users
  const beforeInterested = new Set(before?.interestedUserIds || []);
  const afterInterested = new Set(after.interestedUserIds || []);
  
  const newInterests = Array.from(afterInterested).filter(userId => !beforeInterested.has(userId));
  
  if (newInterests.length === 0) return;

  try {
    // Send notifications to organizer for each new interest
    const notifications = newInterests.map(async (interestedUserId) => {
      try {
        const interestedUser = await admin.auth().getUser(interestedUserId);
        const userName = interestedUser.displayName || 'Someone';
        
        await sendPartnerInterestNotification(after.organizerId, after, userName);
      } catch (error) {
        logger.warn(`Failed to send partner interest notification for ${interestedUserId}:`, error);
      }
    });

    await Promise.allSettled(notifications);
    
    await incrementCounter('activities_partner_interest_notifications_sent', newInterests.length);

  } catch (error) {
    logger.error('Error sending partner interest notifications:', error);
  }
});

// Session reminder notifications (scheduled)
export const sessionReminders = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async (context) => {
    try {
      const now = admin.firestore.Timestamp.now();
      const reminderTime = admin.firestore.Timestamp.fromDate(
        new Date(now.toDate().getTime() + 24 * 60 * 60 * 1000) // 24 hours from now
      );

      // Find bookings with sessions starting in ~24 hours
      const bookingsSnapshot = await db.collection('bookings')
        .where('status', '==', 'confirmed')
        .get();

      let remindersCount = 0;

      for (const bookingDoc of bookingsSnapshot.docs) {
        const booking = bookingDoc.data() as Booking;
        
        // Get session details
        const sessionDoc = await db.collection('activitySessions').doc(booking.sessionId).get();
        if (!sessionDoc.exists) continue;

        const session = sessionDoc.data();
        if (!session?.startTime) continue;

        const sessionStart = session.startTime as admin.firestore.Timestamp;
        const timeDiff = sessionStart.toDate().getTime() - reminderTime.toDate().getTime();
        
        // Send reminder if session starts within the next hour from reminder time
        if (timeDiff >= 0 && timeDiff <= 60 * 60 * 1000) {
          // Get activity details
          const activityDoc = await db.collection('activities').doc(booking.activityId).get();
          const activity = activityDoc.exists ? activityDoc.data() : null;

          // Send reminders to all participants
          const notifications = booking.participants.map(async (participant) => {
            await sendSessionReminderNotification(
              participant.userId, 
              booking, 
              session, 
              activity?.title || 'Your Activity'
            );
          });

          await Promise.allSettled(notifications);
          remindersCount += booking.participants.length;
        }
      }

      await incrementCounter('activities_session_reminders_sent', remindersCount);
      
      logger.info(`Sent ${remindersCount} session reminders`);

    } catch (error) {
      logger.error('Error sending session reminders:', error);
      throw error;
    }
  });

// Notification helper functions
async function sendPaymentSuccessNotification(userId: string, splitId: string): Promise<void> {
  await sendNotification(userId, {
    title: 'Payment Successful! ✅',
    body: 'Your activity payment has been processed successfully',
    data: {
      type: 'payment_success',
      splitId: splitId,
    }
  });
}

async function sendPaymentFailureNotification(userId: string, splitId: string, errorMessage?: string): Promise<void> {
  await sendNotification(userId, {
    title: 'Payment Failed ❌',
    body: errorMessage || 'Your payment could not be processed. Please try again.',
    data: {
      type: 'payment_failed',
      splitId: splitId,
    }
  });
}

async function sendBookingStatusNotification(userId: string, booking: Booking, groupName: string): Promise<void> {
  let title: string;
  let body: string;

  switch (booking.status) {
    case 'confirmed':
      title = 'Booking Confirmed! 🎉';
      body = `Your activity booking for "${groupName}" is now confirmed`;
      break;
    case 'cancelled':
      title = 'Booking Cancelled';
      body = `Your activity booking for "${groupName}" has been cancelled`;
      break;
    case 'awaitingSplit':
      title = 'Payment Required 💳';
      body = `Please complete your payment for "${groupName}"`;
      break;
    default:
      return; // Don't send notification for other statuses
  }

  await sendNotification(userId, {
    title,
    body,
    data: {
      type: 'booking_status_change',
      bookingId: booking.id,
      status: booking.status,
      groupName: groupName,
    }
  });
}

async function sendGroupInvitationNotification(userId: string, group: ActivityGroup, organizerName: string): Promise<void> {
  await sendNotification(userId, {
    title: 'Group Invitation 👥',
    body: `${organizerName} invited you to join "${group.name}"`,
    data: {
      type: 'group_invitation',
      groupId: group.id,
      organizerName: organizerName,
    }
  });
}

async function sendPartnerInterestNotification(organizerId: string, request: PartnerRequest, interestedUserName: string): Promise<void> {
  await sendNotification(organizerId, {
    title: 'Partner Interest! 🤝',
    body: `${interestedUserName} is interested in your ${request.activityCategory} partner request`,
    data: {
      type: 'partner_interest',
      requestId: request.id,
      interestedUserName: interestedUserName,
    }
  });
}

async function sendSessionReminderNotification(
  userId: string, 
  booking: Booking, 
  session: any, 
  activityTitle: string
): Promise<void> {
  const sessionTime = (session.startTime as admin.firestore.Timestamp).toDate();
  const timeString = sessionTime.toLocaleTimeString('en-US', { 
    hour: '2-digit', 
    minute: '2-digit' 
  });

  await sendNotification(userId, {
    title: 'Activity Reminder ⏰',
    body: `"${activityTitle}" starts tomorrow at ${timeString}`,
    data: {
      type: 'session_reminder',
      bookingId: booking.id,
      sessionId: booking.sessionId,
      activityTitle: activityTitle,
    }
  });
}