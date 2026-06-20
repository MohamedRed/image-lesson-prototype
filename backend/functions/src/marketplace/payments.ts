import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { trace } from '../shared/trace';
import { analytics } from '../shared/analytics';
import { fcmService } from '../services/notifications/fcmService';
import { templates } from '../services/notifications/templates';

const db = getFirestore();

interface CODPaymentData {
  reservationId: string;
  amount: {
    amount: number;
    currency: string;
  };
  paymentMethod: 'cod';
}

interface EscrowPaymentData {
  reservationId: string;
  amount: {
    amount: number;
    currency: string;
  };
  paymentMethod: 'escrow';
  paymentSource: {
    type: 'card' | 'bank_transfer';
    token?: string; // Stripe payment method token
  };
}

interface PaymentConfirmation {
  paymentId: string;
  confirmed: boolean;
  evidence?: string[];
  notes?: string;
}

/**
 * Initialize COD payment
 * Per Section 13 - COD Payment Flow
 */
export const initializeCODPayment = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.initializeCODPayment', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const data = request.data as CODPaymentData;
      const buyerId = request.auth.uid;

      if (!data.reservationId || !data.amount || data.amount.amount <= 0) {
        throw new HttpsError('invalid-argument', 'Valid reservation ID and amount are required');
      }

      try {
        const result = await db.runTransaction(async (transaction) => {
          // Verify reservation
          const reservationRef = db.collection('reservations').doc(data.reservationId);
          const reservationDoc = await transaction.get(reservationRef);

          if (!reservationDoc.exists) {
            throw new HttpsError('not-found', 'Reservation not found');
          }

          const reservation = reservationDoc.data();

          if (reservation?.buyerId !== buyerId) {
            throw new HttpsError('permission-denied', 'You are not the buyer for this reservation');
          }

          if (reservation?.status !== 'confirmed') {
            throw new HttpsError('failed-precondition', 'Reservation must be confirmed to initialize payment');
          }

          // Check if payment already exists
          const existingPayment = await db.collection('payments')
            .where('reservationId', '==', data.reservationId)
            .where('status', 'in', ['pending', 'confirmed', 'completed'])
            .get();

          if (!existingPayment.empty) {
            throw new HttpsError('already-exists', 'Payment already exists for this reservation');
          }

          // Create COD payment record
          const paymentRef = db.collection('payments').doc();
          const payment = {
            id: paymentRef.id,
            reservationId: data.reservationId,
            listingId: reservation.listingId,
            buyerId,
            sellerId: reservation.sellerId,
            amount: data.amount,
            paymentMethod: 'cod',
            status: 'pending',
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
            metadata: {
              meetupLocation: reservation.meetupLocation,
              scheduledAt: reservation.scheduledAt
            }
          };

          transaction.set(paymentRef, payment);

          // Update reservation
          transaction.update(reservationRef, {
            paymentId: paymentRef.id,
            paymentMethod: 'cod',
            updatedAt: FieldValue.serverTimestamp()
          });

          return {
            paymentId: paymentRef.id,
            status: 'pending'
          };
        });

        // Analytics
        await analytics.track('marketplace_cod_payment_initialized', {
          buyerId,
          reservationId: data.reservationId,
          amount: data.amount.amount,
          currency: data.amount.currency
        });

        return { success: true, ...result };

      } catch (error) {
        logger.error('Error initializing COD payment', { buyerId, reservationId: data.reservationId, error });
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', 'Failed to initialize COD payment');
      }
    });
  }
);

/**
 * Initialize escrow payment
 * Per Section 13 - Escrow Phase 2
 */
export const initializeEscrowPayment = onCall(
  { cors: true, enforceAppCheck: true, secrets: ['STRIPE_SECRET_KEY'] },
  async (request) => {
    return trace('marketplace.initializeEscrowPayment', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const data = request.data as EscrowPaymentData;
      const buyerId = request.auth.uid;

      if (!data.reservationId || !data.amount || !data.paymentSource) {
        throw new HttpsError('invalid-argument', 'Valid reservation ID, amount, and payment source are required');
      }

      try {
        const result = await db.runTransaction(async (transaction) => {
          // Verify reservation
          const reservationRef = db.collection('reservations').doc(data.reservationId);
          const reservationDoc = await transaction.get(reservationRef);

          if (!reservationDoc.exists) {
            throw new HttpsError('not-found', 'Reservation not found');
          }

          const reservation = reservationDoc.data();

          if (reservation?.buyerId !== buyerId) {
            throw new HttpsError('permission-denied', 'You are not the buyer for this reservation');
          }

          if (reservation?.status !== 'confirmed') {
            throw new HttpsError('failed-precondition', 'Reservation must be confirmed to initialize payment');
          }

          // Create escrow payment record
          const paymentRef = db.collection('payments').doc();
          
          // In production, would integrate with Stripe
          const stripeIntent = await createStripePaymentIntent(data.amount, data.paymentSource);

          const payment = {
            id: paymentRef.id,
            reservationId: data.reservationId,
            listingId: reservation.listingId,
            buyerId,
            sellerId: reservation.sellerId,
            amount: data.amount,
            paymentMethod: 'escrow',
            status: 'pending_capture',
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
            escrowDetails: {
              stripePaymentIntentId: stripeIntent.id,
              holdUntil: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days hold
              releaseCondition: 'completion_confirmation'
            },
            metadata: {
              meetupLocation: reservation.meetupLocation,
              scheduledAt: reservation.scheduledAt
            }
          };

          transaction.set(paymentRef, payment);

          // Update reservation
          transaction.update(reservationRef, {
            paymentId: paymentRef.id,
            paymentMethod: 'escrow',
            updatedAt: FieldValue.serverTimestamp()
          });

          return {
            paymentId: paymentRef.id,
            clientSecret: stripeIntent.client_secret,
            status: 'pending_capture'
          };
        });

        // Analytics
        await analytics.track('marketplace_escrow_payment_initialized', {
          buyerId,
          reservationId: data.reservationId,
          amount: data.amount.amount,
          currency: data.amount.currency,
          paymentSourceType: data.paymentSource.type
        });

        return { success: true, ...result };

      } catch (error) {
        logger.error('Error initializing escrow payment', { buyerId, reservationId: data.reservationId, error });
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', 'Failed to initialize escrow payment');
      }
    });
  }
);

/**
 * Confirm COD payment (after meetup)
 */
export const confirmCODPayment = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.confirmCODPayment', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const { paymentId, confirmed, evidence, notes } = request.data as PaymentConfirmation;
      const userId = request.auth.uid;

      try {
        const result = await db.runTransaction(async (transaction) => {
          const paymentRef = db.collection('payments').doc(paymentId);
          const paymentDoc = await transaction.get(paymentRef);

          if (!paymentDoc.exists) {
            throw new HttpsError('not-found', 'Payment not found');
          }

          const payment = paymentDoc.data();

          // Verify user permission (seller confirms COD payment)
          if (payment?.sellerId !== userId) {
            throw new HttpsError('permission-denied', 'Only the seller can confirm COD payment');
          }

          if (payment?.paymentMethod !== 'cod') {
            throw new HttpsError('invalid-argument', 'Not a COD payment');
          }

          if (payment?.status !== 'pending') {
            throw new HttpsError('failed-precondition', 'Payment is not pending confirmation');
          }

          const updateData: any = {
            status: confirmed ? 'completed' : 'disputed',
            confirmedBy: userId,
            confirmedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp()
          };

          if (evidence) {
            updateData.evidence = evidence;
          }

          if (notes) {
            updateData.notes = notes;
          }

          if (!confirmed) {
            updateData.disputeReason = 'payment_not_received';
          }

          transaction.update(paymentRef, updateData);

          // If confirmed, update seller stats and earnings
          if (confirmed) {
            const sellerRef = db.collection('users').doc(payment.sellerId);
            transaction.update(sellerRef, {
              'marketplace.earnings.totalAmount': FieldValue.increment(payment.amount.amount),
              'marketplace.earnings.lastPaymentAt': FieldValue.serverTimestamp(),
              'marketplace.stats.successfulSales': FieldValue.increment(1)
            });
          }

          return { success: true, status: updateData.status };
        });

        // Analytics
        await analytics.track('marketplace_cod_payment_confirmed', {
          sellerId: userId,
          paymentId,
          confirmed,
          hasEvidence: !!evidence
        });

        return result;

      } catch (error) {
        logger.error('Error confirming COD payment', { userId, paymentId, error });
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', 'Failed to confirm COD payment');
      }
    });
  }
);

/**
 * Release escrow payment
 */
export const releaseEscrowPayment = onCall(
  { cors: true, enforceAppCheck: true, secrets: ['STRIPE_SECRET_KEY'] },
  async (request) => {
    return trace('marketplace.releaseEscrowPayment', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const { paymentId, releaseReason } = request.data;
      const userId = request.auth.uid;

      try {
        const result = await db.runTransaction(async (transaction) => {
          const paymentRef = db.collection('payments').doc(paymentId);
          const paymentDoc = await transaction.get(paymentRef);

          if (!paymentDoc.exists) {
            throw new HttpsError('not-found', 'Payment not found');
          }

          const payment = paymentDoc.data();

          // Verify user permission (buyer or system can release)
          if (payment?.buyerId !== userId && userId !== 'system') {
            throw new HttpsError('permission-denied', 'You cannot release this payment');
          }

          if (payment?.paymentMethod !== 'escrow') {
            throw new HttpsError('invalid-argument', 'Not an escrow payment');
          }

          if (payment?.status !== 'held') {
            throw new HttpsError('failed-precondition', 'Payment is not in escrow');
          }

          // Release payment via Stripe
          const stripeTransfer = await releaseStripePayment(
            payment.escrowDetails.stripePaymentIntentId,
            payment.sellerId,
            payment.amount
          );

          const updateData = {
            status: 'completed',
            releasedBy: userId,
            releasedAt: FieldValue.serverTimestamp(),
            releaseReason: releaseReason || 'completion_confirmed',
            updatedAt: FieldValue.serverTimestamp(),
            stripeTransferId: stripeTransfer.id
          };

          transaction.update(paymentRef, updateData);

          // Update seller earnings
          const sellerRef = db.collection('users').doc(payment.sellerId);
          transaction.update(sellerRef, {
            'marketplace.earnings.totalAmount': FieldValue.increment(payment.amount.amount),
            'marketplace.earnings.lastPaymentAt': FieldValue.serverTimestamp(),
            'marketplace.stats.successfulSales': FieldValue.increment(1)
          });

          return { success: true, transferId: stripeTransfer.id };
        });

        // Analytics
        await analytics.track('marketplace_escrow_payment_released', {
          releasedBy: userId,
          paymentId,
          releaseReason: releaseReason || 'completion_confirmed'
        });

        return result;

      } catch (error) {
        logger.error('Error releasing escrow payment', { userId, paymentId, error });
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', 'Failed to release escrow payment');
      }
    });
  }
);

/**
 * Dispute payment
 */
export const disputePayment = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.disputePayment', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const { paymentId, reason, description, evidence } = request.data;
      const userId = request.auth.uid;

      try {
        const paymentRef = db.collection('payments').doc(paymentId);
        const paymentDoc = await paymentRef.get();

        if (!paymentDoc.exists) {
          throw new HttpsError('not-found', 'Payment not found');
        }

        const payment = paymentDoc.data();

        // Verify user is participant
        if (payment?.buyerId !== userId && payment?.sellerId !== userId) {
          throw new HttpsError('permission-denied', 'You are not a participant in this payment');
        }

        // Check if payment can be disputed
        if (!['pending', 'held', 'completed'].includes(payment?.status)) {
          throw new HttpsError('failed-precondition', 'Payment cannot be disputed');
        }

        // Create dispute record
        const disputeRef = db.collection('disputes').doc();
        const dispute = {
          id: disputeRef.id,
          paymentId,
          reservationId: payment.reservationId,
          initiatedBy: userId,
          reason,
          description: description || '',
          evidence: evidence || [],
          status: 'pending',
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp()
        };

        await disputeRef.set(dispute);

        // Update payment status
        await paymentRef.update({
          status: 'disputed',
          disputeId: disputeRef.id,
          disputedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp()
        });

        // Analytics
        await analytics.track('marketplace_payment_disputed', {
          userId,
          paymentId,
          disputeId: disputeRef.id,
          reason,
          hasEvidence: evidence && evidence.length > 0
        });

        return { success: true, disputeId: disputeRef.id };

      } catch (error) {
        logger.error('Error disputing payment', { userId, paymentId, error });
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', 'Failed to dispute payment');
      }
    });
  }
);

/**
 * Trigger: Send payment notifications
 */
export const onPaymentCreated = onDocumentCreated(
  'payments/{paymentId}',
  async (event) => {
    const paymentData = event.data?.data();
    const paymentId = event.params.paymentId;

    if (!paymentData) return;

    try {
      // Get user and listing details
      const buyerDoc = await db.collection('users').doc(paymentData.buyerId).get();
      const sellerDoc = await db.collection('users').doc(paymentData.sellerId).get();
      const listingDoc = await db.collection('listings').doc(paymentData.listingId).get();

      const buyer = buyerDoc.data();
      const seller = sellerDoc.data();
      const listing = listingDoc.data();

      // Notify both parties
      if (buyer?.notificationSettings?.payments !== false) {
        const buyerNotification = templates.generatePaymentInitializedNotification({
          listingTitle: listing?.title || 'Item',
          amount: paymentData.amount,
          paymentMethod: paymentData.paymentMethod,
          paymentId
        });

        await fcmService.sendToUser(paymentData.buyerId, buyerNotification);
      }

      if (seller?.notificationSettings?.payments !== false) {
        const sellerNotification = templates.generatePaymentReceivedNotification({
          buyerName: buyer?.displayName || 'Buyer',
          listingTitle: listing?.title || 'Your item',
          amount: paymentData.amount,
          paymentMethod: paymentData.paymentMethod,
          paymentId
        });

        await fcmService.sendToUser(paymentData.sellerId, sellerNotification);
      }

      // Analytics
      await analytics.track('marketplace_payment_notifications_sent', {
        paymentId,
        buyerId: paymentData.buyerId,
        sellerId: paymentData.sellerId,
        paymentMethod: paymentData.paymentMethod
      });

    } catch (error) {
      logger.error('Error sending payment notifications', { paymentId, error });
    }
  }
);

/**
 * Background task: Auto-release expired escrow payments
 */
export const autoReleaseEscrowPayments = onCall(
  { invoker: 'private' },
  async () => {
    return trace('marketplace.autoReleaseEscrowPayments', 'system', async () => {
      try {
        const now = new Date();

        // Find expired escrow payments
        const expiredPayments = await db.collection('payments')
          .where('paymentMethod', '==', 'escrow')
          .where('status', '==', 'held')
          .where('escrowDetails.holdUntil', '<=', now)
          .get();

        let releasedCount = 0;

        for (const doc of expiredPayments.docs) {
          try {
            // Auto-release the payment
            await releaseEscrowPayment({
              auth: { uid: 'system' },
              data: {
                paymentId: doc.id,
                releaseReason: 'auto_release_expired'
              }
            } as any);

            releasedCount++;

          } catch (error) {
            logger.error('Error auto-releasing payment', { paymentId: doc.id, error });
          }
        }

        logger.info(`Auto-released ${releasedCount} expired escrow payments`);
        return { releasedCount };

      } catch (error) {
        logger.error('Error in autoReleaseEscrowPayments', { error });
        throw new HttpsError('internal', 'Failed to auto-release escrow payments');
      }
    });
  }
);

// Helper functions

async function createStripePaymentIntent(amount: any, paymentSource: any): Promise<any> {
  // Mock Stripe integration - in production would use actual Stripe SDK
  return {
    id: `pi_mock_${Date.now()}`,
    client_secret: `pi_mock_${Date.now()}_secret_${Math.random()}`,
    status: 'requires_confirmation'
  };
}

async function releaseStripePayment(paymentIntentId: string, sellerId: string, amount: any): Promise<any> {
  // Mock Stripe transfer - in production would use actual Stripe SDK
  return {
    id: `tr_mock_${Date.now()}`,
    amount: amount.amount,
    destination: sellerId,
    status: 'paid'
  };
}