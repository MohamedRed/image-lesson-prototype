import * as admin from 'firebase-admin';
import Stripe from 'stripe';
import {
  Booking,
  BookingStatus,
  PaymentStatus,
  PaymentMethod,
  Guest,
} from '../models/types';
import { ProviderRegistry } from '../providers/provider-interface';
import { AmadeusProvider } from '../providers/amadeus-provider';
import { logger } from '../../shared/utils/logger';
import { v4 as uuidv4 } from 'uuid';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || '', {
  apiVersion: '2023-10-16',
});

export class BookingService {
  private db: admin.firestore.Firestore;
  private providerRegistry: ProviderRegistry;
  
  constructor() {
    this.db = admin.firestore();
    this.providerRegistry = new ProviderRegistry();
    this.initializeProviders();
  }
  
  private initializeProviders(): void {
    const amadeusProvider = new AmadeusProvider({
      apiKey: process.env.AMADEUS_API_KEY,
      apiSecret: process.env.AMADEUS_API_SECRET,
    });
    
    if (amadeusProvider.isEnabled) {
      this.providerRegistry.register(amadeusProvider);
    }
  }
  
  async createBooking(userId: string, request: any): Promise<Booking> {
    const bookingId = uuidv4();
    
    try {
      // Start a transaction for atomic booking creation
      const booking = await this.db.runTransaction(async (transaction) => {
        // Check availability one more time
        const availabilityCheck = await this.checkAvailability(
          request.propertyId,
          request.roomTypeId,
          request.dateRange
        );
        
        if (!availabilityCheck.available) {
          throw new Error('Room is no longer available');
        }
        
        // Create payment intent with Stripe
        const paymentIntent = await this.createPaymentIntent(
          request.priceSnapshot.totalPrice,
          request.priceSnapshot.currency,
          bookingId
        );
        
        // Prepare booking document
        const bookingDoc: Booking = {
          id: bookingId,
          userId,
          propertyRef: request.property,
          roomTypeRef: request.roomType,
          ratePlanRef: request.ratePlan,
          guests: request.guests,
          dateRange: request.dateRange,
          priceSnapshot: request.priceSnapshot,
          paymentInfo: {
            method: request.paymentMethod || PaymentMethod.CARD,
            stripePaymentIntentId: paymentIntent.id,
            status: PaymentStatus.PENDING,
          },
          status: BookingStatus.PENDING,
          specialRequests: request.specialRequests,
          createdAt: new Date(),
          updatedAt: new Date(),
        };
        
        // Save booking to Firestore
        transaction.set(
          this.db.collection('accommodations_bookings').doc(bookingId),
          bookingDoc
        );
        
        // Reserve with provider
        const provider = this.getProviderForProperty(request.propertyId);
        if (provider) {
          const providerBooking = await provider.createBooking({
            propertyId: request.propertyId,
            roomTypeId: request.roomTypeId,
            ratePlanId: request.ratePlanId,
            checkIn: request.dateRange.startDate,
            checkOut: request.dateRange.endDate,
            guests: request.guests,
            payment: {
              method: request.paymentMethod,
              token: paymentIntent.id,
            },
            specialRequests: request.specialRequests,
          });
          
          bookingDoc.providerConfirmation = {
            provider: provider.name,
            confirmationCode: providerBooking.confirmationCode,
            providerBookingId: providerBooking.providerBookingId,
            providerStatus: providerBooking.status,
            deepLink: providerBooking.deepLink,
          };
        }
        
        return bookingDoc;
      });
      
      // Send confirmation email
      await this.sendBookingConfirmation(booking);
      
      // Log for analytics
      await this.logBookingEvent(booking);
      
      return booking;
    } catch (error) {
      logger.error(`Booking creation failed for ${bookingId}:`, error);
      
      // Cleanup on failure
      await this.cleanupFailedBooking(bookingId);
      
      throw error;
    }
  }
  
  async confirmBookingPayment(bookingId: string, paymentIntentId: string): Promise<Booking> {
    try {
      const bookingRef = this.db.collection('accommodations_bookings').doc(bookingId);
      const bookingDoc = await bookingRef.get();
      
      if (!bookingDoc.exists) {
        throw new Error('Booking not found');
      }
      
      const booking = bookingDoc.data() as Booking;
      
      // Verify payment intent
      const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);
      
      if (paymentIntent.status === 'succeeded') {
        // Update booking status
        await bookingRef.update({
          status: BookingStatus.CONFIRMED,
          'paymentInfo.status': PaymentStatus.SUCCEEDED,
          'paymentInfo.last4': paymentIntent.payment_method_details?.card?.last4,
          'paymentInfo.brand': paymentIntent.payment_method_details?.card?.brand,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        booking.status = BookingStatus.CONFIRMED;
        booking.paymentInfo.status = PaymentStatus.SUCCEEDED;
        
        // Send confirmation
        await this.sendPaymentConfirmation(booking);
      } else {
        throw new Error(`Payment failed with status: ${paymentIntent.status}`);
      }
      
      return booking;
    } catch (error) {
      logger.error(`Payment confirmation failed for booking ${bookingId}:`, error);
      throw error;
    }
  }
  
  async cancelBooking(userId: string, bookingId: string, reason?: string): Promise<any> {
    try {
      const bookingRef = this.db.collection('accommodations_bookings').doc(bookingId);
      const bookingDoc = await bookingRef.get();
      
      if (!bookingDoc.exists) {
        throw new Error('Booking not found');
      }
      
      const booking = bookingDoc.data() as Booking;
      
      // Verify user owns this booking
      if (booking.userId !== userId) {
        throw new Error('Unauthorized');
      }
      
      // Check cancellation policy
      const cancellationResult = this.calculateCancellationFees(booking);
      
      // Cancel with provider
      const provider = this.getProviderForProperty(booking.propertyRef.id);
      if (provider && booking.providerConfirmation) {
        await provider.cancelBooking(
          booking.providerConfirmation.providerBookingId || bookingId,
          reason
        );
      }
      
      // Process refund if payment was made
      if (booking.paymentInfo.stripePaymentIntentId && 
          booking.paymentInfo.status === PaymentStatus.SUCCEEDED) {
        await this.processRefund(
          booking.paymentInfo.stripePaymentIntentId,
          cancellationResult.refundAmount
        );
      }
      
      // Update booking status
      await bookingRef.update({
        status: BookingStatus.CANCELLED,
        cancellationReason: reason,
        cancellationDate: admin.firestore.FieldValue.serverTimestamp(),
        cancellationFee: cancellationResult.fee,
        refundAmount: cancellationResult.refundAmount,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      // Send cancellation confirmation
      await this.sendCancellationConfirmation(booking, cancellationResult);
      
      return cancellationResult;
    } catch (error) {
      logger.error(`Booking cancellation failed for ${bookingId}:`, error);
      throw error;
    }
  }
  
  async getUserBookings(userId: string): Promise<Booking[]> {
    try {
      const snapshot = await this.db
        .collection('accommodations_bookings')
        .where('userId', '==', userId)
        .orderBy('createdAt', 'desc')
        .limit(50)
        .get();
      
      return snapshot.docs.map(doc => doc.data() as Booking);
    } catch (error) {
      logger.error(`Failed to get bookings for user ${userId}:`, error);
      throw error;
    }
  }
  
  async getBookingDetails(userId: string, bookingId: string): Promise<Booking> {
    try {
      const bookingDoc = await this.db
        .collection('accommodations_bookings')
        .doc(bookingId)
        .get();
      
      if (!bookingDoc.exists) {
        throw new Error('Booking not found');
      }
      
      const booking = bookingDoc.data() as Booking;
      
      // Verify user owns this booking
      if (booking.userId !== userId) {
        throw new Error('Unauthorized');
      }
      
      return booking;
    } catch (error) {
      logger.error(`Failed to get booking ${bookingId}:`, error);
      throw error;
    }
  }
  
  private async checkAvailability(
    propertyId: string,
    roomTypeId: string,
    dateRange: any
  ): Promise<{ available: boolean }> {
    // Check availability with provider
    // This is a simplified implementation
    return { available: true };
  }
  
  private async createPaymentIntent(
    amount: number,
    currency: string,
    bookingId: string
  ): Promise<Stripe.PaymentIntent> {
    return await stripe.paymentIntents.create({
      amount: Math.round(amount * 100), // Convert to cents
      currency: currency.toLowerCase(),
      metadata: {
        bookingId,
        type: 'accommodation_booking',
      },
      automatic_payment_methods: {
        enabled: true,
      },
    });
  }
  
  private async processRefund(
    paymentIntentId: string,
    amount?: number
  ): Promise<Stripe.Refund> {
    const refundParams: Stripe.RefundCreateParams = {
      payment_intent: paymentIntentId,
    };
    
    if (amount !== undefined) {
      refundParams.amount = Math.round(amount * 100); // Convert to cents
    }
    
    return await stripe.refunds.create(refundParams);
  }
  
  private calculateCancellationFees(booking: Booking): {
    fee: number;
    refundAmount: number;
  } {
    const now = new Date();
    const checkIn = booking.dateRange.startDate;
    const totalAmount = booking.priceSnapshot.totalPrice;
    
    // Calculate hours until check-in
    const hoursUntilCheckIn = (checkIn.getTime() - now.getTime()) / (1000 * 60 * 60);
    
    // Apply cancellation policy
    const policy = booking.ratePlanRef.cancellationPolicy;
    
    switch (policy.type) {
      case 'FLEXIBLE':
        // Free cancellation up to 24 hours before
        if (hoursUntilCheckIn >= 24) {
          return { fee: 0, refundAmount: totalAmount };
        } else {
          return { fee: totalAmount * 0.1, refundAmount: totalAmount * 0.9 };
        }
      
      case 'MODERATE':
        // Free cancellation up to 5 days before
        if (hoursUntilCheckIn >= 120) {
          return { fee: 0, refundAmount: totalAmount };
        } else if (hoursUntilCheckIn >= 24) {
          return { fee: totalAmount * 0.5, refundAmount: totalAmount * 0.5 };
        } else {
          return { fee: totalAmount, refundAmount: 0 };
        }
      
      case 'STRICT':
        // Free cancellation up to 14 days before
        if (hoursUntilCheckIn >= 336) {
          return { fee: totalAmount * 0.1, refundAmount: totalAmount * 0.9 };
        } else {
          return { fee: totalAmount, refundAmount: 0 };
        }
      
      case 'NON_REFUNDABLE':
        return { fee: totalAmount, refundAmount: 0 };
      
      default:
        return { fee: 0, refundAmount: totalAmount };
    }
  }
  
  private getProviderForProperty(propertyId: string): any {
    // Determine which provider to use based on property ID prefix
    if (propertyId.startsWith('amadeus-')) {
      return this.providerRegistry.get('amadeus');
    }
    // Add more providers as needed
    return null;
  }
  
  private async sendBookingConfirmation(booking: Booking): Promise<void> {
    // Send email confirmation
    logger.info(`Sending booking confirmation for ${booking.id}`);
    // Implementation would use SendGrid or similar
  }
  
  private async sendPaymentConfirmation(booking: Booking): Promise<void> {
    // Send payment confirmation email
    logger.info(`Sending payment confirmation for ${booking.id}`);
  }
  
  private async sendCancellationConfirmation(
    booking: Booking,
    cancellationResult: any
  ): Promise<void> {
    // Send cancellation confirmation email
    logger.info(`Sending cancellation confirmation for ${booking.id}`);
  }
  
  private async logBookingEvent(booking: Booking): Promise<void> {
    // Log to BigQuery for analytics
    const event = {
      bookingId: booking.id,
      userId: booking.userId,
      propertyId: booking.propertyRef.id,
      checkIn: booking.dateRange.startDate,
      checkOut: booking.dateRange.endDate,
      totalAmount: booking.priceSnapshot.totalPrice,
      currency: booking.priceSnapshot.currency,
      timestamp: booking.createdAt,
    };
    
    // await bigQueryClient.insert('bookings', event);
  }
  
  private async cleanupFailedBooking(bookingId: string): Promise<void> {
    try {
      // Delete failed booking document
      await this.db.collection('accommodations_bookings').doc(bookingId).delete();
    } catch (error) {
      logger.error(`Failed to cleanup booking ${bookingId}:`, error);
    }
  }
}