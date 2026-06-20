import { logger } from "firebase-functions";
import * as admin from "firebase-admin";

try { admin.app(); } catch { admin.initializeApp(); }

// Payment Provider Interface for Moroccan Market
export interface PaymentProvider {
  createPaymentIntent(args: CreatePaymentIntentArgs): Promise<PaymentIntentResult>;
  capturePayment(args: CapturePaymentArgs): Promise<void>;
  refundPayment(args: RefundPaymentArgs): Promise<RefundResult>;
  createTransfer(args: CreateTransferArgs): Promise<TransferResult>;
  getPaymentStatus(paymentId: string): Promise<PaymentStatus>;
  createPayout(args: CreatePayoutArgs): Promise<PayoutResult>;
}

export interface CreatePaymentIntentArgs {
  amount: number;
  currency: 'MAD';
  customerId: string;
  description: string;
  metadata: Record<string, any>;
  paymentMethods?: string[]; // ['card', 'wallet', 'bank_transfer']
  returnUrl?: string;
}

export interface PaymentIntentResult {
  id: string;
  clientSecret?: string;
  status: 'pending' | 'requires_action' | 'succeeded' | 'failed';
  paymentUrl?: string; // For redirect-based payments
  expiresAt: Date;
}

export interface CapturePaymentArgs {
  paymentIntentId: string;
  amount?: number; // For partial capture
}

export interface RefundPaymentArgs {
  paymentId: string;
  amount?: number; // For partial refund
  reason?: string;
  metadata?: Record<string, any>;
}

export interface RefundResult {
  id: string;
  amount: number;
  status: 'pending' | 'succeeded' | 'failed';
  estimatedArrival?: Date;
}

export interface CreateTransferArgs {
  amount: number;
  destination: string; // Professional's account ID
  currency: 'MAD';
  description: string;
  metadata?: Record<string, any>;
}

export interface TransferResult {
  id: string;
  status: 'pending' | 'succeeded' | 'failed';
  estimatedArrival?: Date;
}

export interface CreatePayoutArgs {
  professionalId: string;
  amount: number;
  currency: 'MAD';
  method: 'bank_transfer' | 'mobile_money' | 'cash_pickup';
  metadata?: Record<string, any>;
}

export interface PayoutResult {
  id: string;
  status: 'pending' | 'processing' | 'succeeded' | 'failed';
  estimatedArrival?: Date;
  trackingNumber?: string;
}

export interface PaymentStatus {
  id: string;
  status: 'pending' | 'processing' | 'succeeded' | 'failed' | 'cancelled';
  amount: number;
  currency: string;
  createdAt: Date;
  updatedAt: Date;
  failureReason?: string;
}

/**
 * Moroccan Payment Service Provider Simulator
 * Simulates integration with local PSPs like CMI, Maroc Telecommerce, or international ones
 */
export class MoroccanPSPSimulator implements PaymentProvider {
  private readonly pspName: string;
  private readonly apiKey: string;
  private readonly sandbox: boolean;

  constructor(config: { pspName: string; apiKey: string; sandbox?: boolean }) {
    this.pspName = config.pspName;
    this.apiKey = config.apiKey;
    this.sandbox = config.sandbox ?? true;
  }

  async createPaymentIntent(args: CreatePaymentIntentArgs): Promise<PaymentIntentResult> {
    logger.info("Creating payment intent", { 
      psp: this.pspName, 
      amount: args.amount, 
      currency: args.currency 
    });

    // Simulate API call to Moroccan PSP
    await this.simulateNetworkDelay();

    const paymentIntentId = `pi_${this.generateId()}`;
    const clientSecret = this.sandbox ? `${paymentIntentId}_secret_test` : `${paymentIntentId}_secret`;

    // Simulate different payment methods available in Morocco
    const availableMethods = args.paymentMethods || ['card', 'wallet', 'bank_transfer'];
    
    // Store payment intent in Firestore for tracking
    await admin.firestore().collection('_internal/payments/intents').doc(paymentIntentId).set({
      id: paymentIntentId,
      amount: args.amount,
      currency: args.currency,
      customerId: args.customerId,
      description: args.description,
      metadata: args.metadata,
      availableMethods,
      status: 'pending',
      psp: this.pspName,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 30 * 60 * 1000) // 30 minutes
      )
    });

    return {
      id: paymentIntentId,
      clientSecret,
      status: 'pending',
      paymentUrl: this.sandbox ? 
        `https://sandbox-pay.${this.pspName}.ma/pay/${paymentIntentId}` :
        `https://pay.${this.pspName}.ma/pay/${paymentIntentId}`,
      expiresAt: new Date(Date.now() + 30 * 60 * 1000)
    };
  }

  async capturePayment(args: CapturePaymentArgs): Promise<void> {
    logger.info("Capturing payment", { 
      psp: this.pspName, 
      paymentIntentId: args.paymentIntentId 
    });

    await this.simulateNetworkDelay();

    // Simulate success/failure rates
    const success = Math.random() > 0.05; // 95% success rate

    if (!success) {
      throw new Error("Payment capture failed - insufficient funds");
    }

    // Update payment intent status
    await admin.firestore()
      .collection('_internal/payments/intents')
      .doc(args.paymentIntentId)
      .update({
        status: 'succeeded',
        capturedAt: admin.firestore.FieldValue.serverTimestamp(),
        capturedAmount: args.amount || null
      });

    logger.info("Payment captured successfully", { 
      paymentIntentId: args.paymentIntentId 
    });
  }

  async refundPayment(args: RefundPaymentArgs): Promise<RefundResult> {
    logger.info("Processing refund", { 
      psp: this.pspName, 
      paymentId: args.paymentId, 
      amount: args.amount 
    });

    await this.simulateNetworkDelay();

    const refundId = `rf_${this.generateId()}`;
    
    // Get original payment to determine refund amount
    const paymentDoc = await admin.firestore()
      .collection('_internal/payments/intents')
      .doc(args.paymentId)
      .get();

    if (!paymentDoc.exists) {
      throw new Error("Payment not found");
    }

    const paymentData = paymentDoc.data()!;
    const refundAmount = args.amount || paymentData.amount;

    // Simulate processing time for Moroccan banking system
    const estimatedArrival = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000); // 3 business days

    // Store refund record
    await admin.firestore().collection('_internal/payments/refunds').doc(refundId).set({
      id: refundId,
      paymentId: args.paymentId,
      amount: refundAmount,
      currency: 'MAD',
      reason: args.reason || 'requested_by_customer',
      status: 'pending',
      psp: this.pspName,
      metadata: args.metadata || {},
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      estimatedArrival: admin.firestore.Timestamp.fromDate(estimatedArrival)
    });

    // Simulate async processing
    this.simulateAsyncRefundProcessing(refundId);

    return {
      id: refundId,
      amount: refundAmount,
      status: 'pending',
      estimatedArrival
    };
  }

  async createTransfer(args: CreateTransferArgs): Promise<TransferResult> {
    logger.info("Creating transfer", { 
      psp: this.pspName, 
      amount: args.amount, 
      destination: args.destination 
    });

    await this.simulateNetworkDelay();

    const transferId = `tr_${this.generateId()}`;
    
    // Simulate transfer processing time
    const estimatedArrival = new Date(Date.now() + 24 * 60 * 60 * 1000); // Next business day

    // Store transfer record
    await admin.firestore().collection('_internal/payments/transfers').doc(transferId).set({
      id: transferId,
      amount: args.amount,
      currency: args.currency,
      destination: args.destination,
      description: args.description,
      status: 'pending',
      psp: this.pspName,
      metadata: args.metadata || {},
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      estimatedArrival: admin.firestore.Timestamp.fromDate(estimatedArrival)
    });

    // Simulate async processing
    this.simulateAsyncTransferProcessing(transferId);

    return {
      id: transferId,
      status: 'pending',
      estimatedArrival
    };
  }

  async getPaymentStatus(paymentId: string): Promise<PaymentStatus> {
    const paymentDoc = await admin.firestore()
      .collection('_internal/payments/intents')
      .doc(paymentId)
      .get();

    if (!paymentDoc.exists) {
      throw new Error("Payment not found");
    }

    const data = paymentDoc.data()!;
    
    return {
      id: paymentId,
      status: data.status,
      amount: data.amount,
      currency: data.currency,
      createdAt: data.createdAt.toDate(),
      updatedAt: data.updatedAt?.toDate() || data.createdAt.toDate(),
      failureReason: data.failureReason || undefined
    };
  }

  async createPayout(args: CreatePayoutArgs): Promise<PayoutResult> {
    logger.info("Creating payout", { 
      psp: this.pspName, 
      professionalId: args.professionalId, 
      amount: args.amount,
      method: args.method 
    });

    await this.simulateNetworkDelay();

    const payoutId = `po_${this.generateId()}`;
    
    // Different processing times based on payout method
    let estimatedArrival: Date;
    let trackingNumber: string | undefined;

    switch (args.method) {
      case 'bank_transfer':
        estimatedArrival = new Date(Date.now() + 24 * 60 * 60 * 1000); // 1 business day
        break;
      case 'mobile_money':
        estimatedArrival = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes
        break;
      case 'cash_pickup':
        estimatedArrival = new Date(Date.now() + 2 * 60 * 60 * 1000); // 2 hours
        trackingNumber = `CP${Math.random().toString(36).substr(2, 9).toUpperCase()}`;
        break;
      default:
        estimatedArrival = new Date(Date.now() + 24 * 60 * 60 * 1000);
    }

    // Store payout record
    await admin.firestore().collection('_internal/payments/payouts').doc(payoutId).set({
      id: payoutId,
      professionalId: args.professionalId,
      amount: args.amount,
      currency: args.currency,
      method: args.method,
      status: 'pending',
      psp: this.pspName,
      metadata: args.metadata || {},
      trackingNumber,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      estimatedArrival: admin.firestore.Timestamp.fromDate(estimatedArrival)
    });

    // Simulate async processing
    this.simulateAsyncPayoutProcessing(payoutId, args.method);

    return {
      id: payoutId,
      status: 'pending',
      estimatedArrival,
      trackingNumber
    };
  }

  // Helper methods for simulation

  private async simulateNetworkDelay(): Promise<void> {
    const delay = Math.random() * 2000 + 500; // 500ms to 2.5s
    return new Promise(resolve => setTimeout(resolve, delay));
  }

  private generateId(): string {
    return Math.random().toString(36).substr(2, 12);
  }

  private async simulateAsyncRefundProcessing(refundId: string): Promise<void> {
    // Simulate processing after a delay
    setTimeout(async () => {
      try {
        const success = Math.random() > 0.02; // 98% success rate
        
        await admin.firestore()
          .collection('_internal/payments/refunds')
          .doc(refundId)
          .update({
            status: success ? 'succeeded' : 'failed',
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
            failureReason: success ? null : 'Bank processing error'
          });

        logger.info("Refund processed", { refundId, success });
      } catch (error) {
        logger.error("Refund processing failed", { refundId, error });
      }
    }, Math.random() * 30000 + 10000); // 10-40 seconds
  }

  private async simulateAsyncTransferProcessing(transferId: string): Promise<void> {
    setTimeout(async () => {
      try {
        const success = Math.random() > 0.03; // 97% success rate
        
        await admin.firestore()
          .collection('_internal/payments/transfers')
          .doc(transferId)
          .update({
            status: success ? 'succeeded' : 'failed',
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
            failureReason: success ? null : 'Destination account invalid'
          });

        logger.info("Transfer processed", { transferId, success });
      } catch (error) {
        logger.error("Transfer processing failed", { transferId, error });
      }
    }, Math.random() * 60000 + 30000); // 30-90 seconds
  }

  private async simulateAsyncPayoutProcessing(payoutId: string, method: string): Promise<void> {
    const processingTime = method === 'mobile_money' ? 5000 : 
                          method === 'cash_pickup' ? 10000 : 30000;
    
    setTimeout(async () => {
      try {
        const success = Math.random() > 0.05; // 95% success rate
        
        await admin.firestore()
          .collection('_internal/payments/payouts')
          .doc(payoutId)
          .update({
            status: success ? 'succeeded' : 'failed',
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
            failureReason: success ? null : 'Payout processing error'
          });

        logger.info("Payout processed", { payoutId, method, success });
      } catch (error) {
        logger.error("Payout processing failed", { payoutId, error });
      }
    }, processingTime);
  }
}

/**
 * Factory function to create payment provider based on configuration
 */
export function createPaymentProvider(): PaymentProvider {
  const config = {
    pspName: process.env.PSP_NAME || 'cmi', // CMI, Maroc Telecommerce, etc.
    apiKey: process.env.PSP_API_KEY || 'test_key',
    sandbox: process.env.NODE_ENV !== 'production'
  };

  return new MoroccanPSPSimulator(config);
}

/**
 * Webhook handler for payment status updates
 */
export async function handlePSPWebhook(req: any, res: any): Promise<void> {
  try {
    // Verify webhook signature (implementation depends on PSP)
    const signature = req.headers['x-psp-signature'];
    if (!verifyWebhookSignature(req.body, signature)) {
      res.status(401).json({ error: "Invalid signature" });
      return;
    }

    const { event_type, data } = req.body;

    switch (event_type) {
      case 'payment.succeeded':
        await handlePaymentSucceeded(data);
        break;
      case 'payment.failed':
        await handlePaymentFailed(data);
        break;
      case 'refund.succeeded':
        await handleRefundSucceeded(data);
        break;
      case 'transfer.succeeded':
        await handleTransferSucceeded(data);
        break;
      case 'payout.succeeded':
        await handlePayoutSucceeded(data);
        break;
      default:
        logger.warn("Unknown webhook event", { event_type });
    }

    res.json({ received: true });
  } catch (error: any) {
    logger.error("Webhook processing failed", { error: error.message });
    res.status(500).json({ error: "Webhook processing failed" });
  }
}

// Webhook event handlers
async function handlePaymentSucceeded(data: any): Promise<void> {
  const { payment_intent_id, amount, currency } = data;
  
  // Update escrow status
  const escrowSnapshot = await admin.firestore()
    .collection('escrows')
    .where('paymentIntentId', '==', payment_intent_id)
    .limit(1)
    .get();

  if (!escrowSnapshot.empty) {
    await escrowSnapshot.docs[0].ref.update({
      status: 'held',
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  }

  logger.info("Payment succeeded webhook processed", { payment_intent_id, amount });
}

async function handlePaymentFailed(data: any): Promise<void> {
  const { payment_intent_id, failure_reason } = data;
  
  const escrowSnapshot = await admin.firestore()
    .collection('escrows')
    .where('paymentIntentId', '==', payment_intent_id)
    .limit(1)
    .get();

  if (!escrowSnapshot.empty) {
    await escrowSnapshot.docs[0].ref.update({
      status: 'failed',
      failureReason: failure_reason,
      failedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  }

  logger.info("Payment failed webhook processed", { payment_intent_id, failure_reason });
}

async function handleRefundSucceeded(data: any): Promise<void> {
  // Implementation for successful refund processing
  logger.info("Refund succeeded webhook processed", data);
}

async function handleTransferSucceeded(data: any): Promise<void> {
  // Implementation for successful transfer processing
  logger.info("Transfer succeeded webhook processed", data);
}

async function handlePayoutSucceeded(data: any): Promise<void> {
  // Implementation for successful payout processing
  logger.info("Payout succeeded webhook processed", data);
}

function verifyWebhookSignature(payload: any, signature: string): boolean {
  // Implement signature verification based on PSP requirements
  // This is a placeholder implementation
  return signature === 'valid_test_signature' || process.env.NODE_ENV === 'development';
}