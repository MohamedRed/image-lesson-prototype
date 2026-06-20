import Stripe from "stripe";
import { logger } from "firebase-functions";
import { getSecret, secretPath, SECRET_IDS } from "../../shared/secretManager";

// Singleton Stripe client
let stripeClient: Stripe | null = null;

/**
 * Get initialized Stripe client
 * Handles secret retrieval and client caching
 */
export async function getStripeClient(): Promise<Stripe> {
  if (!stripeClient) {
    const secretKey = await getSecret(secretPath(SECRET_IDS.STRIPE_SECRET_KEY));
    stripeClient = new Stripe(secretKey, { apiVersion: "2022-11-15" });
    logger.info("Stripe client initialized");
  }
  return stripeClient;
}

/**
 * Payment Intent Service
 * Centralized payment intent management
 */
export class StripePaymentService {
  
  static async createPaymentIntent(params: {
    amount: number; // in cents
    currency: string;
    metadata?: Record<string, string>;
    captureMethod?: 'automatic' | 'manual';
    customerId?: string;
  }): Promise<Stripe.PaymentIntent> {
    try {
      const stripe = await getStripeClient();
      
      const paymentIntentParams: Stripe.PaymentIntentCreateParams = {
        amount: params.amount,
        currency: params.currency,
        metadata: params.metadata || {},
        capture_method: params.captureMethod || 'automatic',
      };

      if (params.customerId) {
        paymentIntentParams.customer = params.customerId;
      }

      const paymentIntent = await stripe.paymentIntents.create(paymentIntentParams);
      
      logger.info("Payment intent created", {
        paymentIntentId: paymentIntent.id,
        amount: params.amount,
        currency: params.currency,
      });

      return paymentIntent;
      
    } catch (error: any) {
      logger.error("Failed to create payment intent", {
        error: error.message,
        params,
      });
      throw new Error(`Payment intent creation failed: ${error.message}`);
    }
  }

  static async capturePaymentIntent(paymentIntentId: string, amountToCapture?: number): Promise<Stripe.PaymentIntent> {
    try {
      const stripe = await getStripeClient();
      
      const captureParams: Stripe.PaymentIntentCaptureParams = {};
      if (amountToCapture) {
        captureParams.amount_to_capture = amountToCapture;
      }

      const paymentIntent = await stripe.paymentIntents.capture(paymentIntentId, captureParams);
      
      logger.info("Payment intent captured", {
        paymentIntentId,
        amountCaptured: amountToCapture || paymentIntent.amount,
      });

      return paymentIntent;
      
    } catch (error: any) {
      logger.error("Failed to capture payment intent", {
        paymentIntentId,
        error: error.message,
      });
      throw new Error(`Payment capture failed: ${error.message}`);
    }
  }

  static async cancelPaymentIntent(paymentIntentId: string, reason?: string): Promise<Stripe.PaymentIntent> {
    try {
      const stripe = await getStripeClient();
      
      const cancelParams: Stripe.PaymentIntentCancelParams = {};
      if (reason) {
        cancelParams.cancellation_reason = reason as any;
      }

      const paymentIntent = await stripe.paymentIntents.cancel(paymentIntentId, cancelParams);
      
      logger.info("Payment intent cancelled", {
        paymentIntentId,
        reason,
      });

      return paymentIntent;
      
    } catch (error: any) {
      logger.error("Failed to cancel payment intent", {
        paymentIntentId,
        error: error.message,
      });
      throw new Error(`Payment cancellation failed: ${error.message}`);
    }
  }

  static async retrievePaymentIntent(paymentIntentId: string): Promise<Stripe.PaymentIntent> {
    try {
      const stripe = await getStripeClient();
      const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);
      
      logger.info("Payment intent retrieved", { paymentIntentId });
      return paymentIntent;
      
    } catch (error: any) {
      logger.error("Failed to retrieve payment intent", {
        paymentIntentId,
        error: error.message,
      });
      throw new Error(`Payment retrieval failed: ${error.message}`);
    }
  }
}

/**
 * Refund Service
 * Centralized refund management
 */
export class StripeRefundService {
  
  static async createRefund(params: {
    paymentIntentId: string;
    amount?: number; // in cents, if not provided refunds full amount
    reason?: string;
    metadata?: Record<string, string>;
  }): Promise<Stripe.Refund> {
    try {
      const stripe = await getStripeClient();
      
      const refundParams: Stripe.RefundCreateParams = {
        payment_intent: params.paymentIntentId,
        metadata: params.metadata || {},
      };

      if (params.amount) {
        refundParams.amount = params.amount;
      }

      if (params.reason) {
        refundParams.reason = params.reason as any;
      }

      const refund = await stripe.refunds.create(refundParams);
      
      logger.info("Refund created", {
        refundId: refund.id,
        paymentIntentId: params.paymentIntentId,
        amount: params.amount || 'full',
        reason: params.reason,
      });

      return refund;
      
    } catch (error: any) {
      logger.error("Failed to create refund", {
        error: error.message,
        params,
      });
      throw new Error(`Refund creation failed: ${error.message}`);
    }
  }

  static async retrieveRefund(refundId: string): Promise<Stripe.Refund> {
    try {
      const stripe = await getStripeClient();
      const refund = await stripe.refunds.retrieve(refundId);
      
      logger.info("Refund retrieved", { refundId });
      return refund;
      
    } catch (error: any) {
      logger.error("Failed to retrieve refund", {
        refundId,
        error: error.message,
      });
      throw new Error(`Refund retrieval failed: ${error.message}`);
    }
  }
}

/**
 * Webhook Service
 * Centralized webhook signature verification
 */
export class StripeWebhookService {
  
  static async constructEvent(payload: string | Buffer, signature: string): Promise<Stripe.Event> {
    try {
      const webhookSecret = await getSecret(secretPath(SECRET_IDS.STRIPE_WEBHOOK_SECRET));
      const stripe = await getStripeClient();
      
      const event = stripe.webhooks.constructEvent(payload, signature, webhookSecret);
      
      logger.info("Webhook event constructed", {
        eventId: event.id,
        type: event.type,
      });

      return event;
      
    } catch (error: any) {
      logger.error("Failed to construct webhook event", {
        error: error.message,
      });
      throw new Error(`Webhook verification failed: ${error.message}`);
    }
  }
}

/**
 * Customer Service
 * Centralized customer management
 */
export class StripeCustomerService {
  
  static async createCustomer(params: {
    email?: string;
    name?: string;
    metadata?: Record<string, string>;
  }): Promise<Stripe.Customer> {
    try {
      const stripe = await getStripeClient();
      
      const customer = await stripe.customers.create({
        email: params.email,
        name: params.name,
        metadata: params.metadata || {},
      });
      
      logger.info("Customer created", {
        customerId: customer.id,
        email: params.email,
      });

      return customer;
      
    } catch (error: any) {
      logger.error("Failed to create customer", {
        error: error.message,
        params,
      });
      throw new Error(`Customer creation failed: ${error.message}`);
    }
  }

  static async retrieveCustomer(customerId: string): Promise<Stripe.Customer> {
    try {
      const stripe = await getStripeClient();
      const customer = await stripe.customers.retrieve(customerId) as Stripe.Customer;
      
      logger.info("Customer retrieved", { customerId });
      return customer;
      
    } catch (error: any) {
      logger.error("Failed to retrieve customer", {
        customerId,
        error: error.message,
      });
      throw new Error(`Customer retrieval failed: ${error.message}`);
    }
  }

  static async updateCustomer(customerId: string, updates: {
    email?: string;
    name?: string;
    metadata?: Record<string, string>;
  }): Promise<Stripe.Customer> {
    try {
      const stripe = await getStripeClient();
      
      const customer = await stripe.customers.update(customerId, {
        email: updates.email,
        name: updates.name,
        metadata: updates.metadata,
      });
      
      logger.info("Customer updated", { customerId });
      return customer;
      
    } catch (error: any) {
      logger.error("Failed to update customer", {
        customerId,
        error: error.message,
        updates,
      });
      throw new Error(`Customer update failed: ${error.message}`);
    }
  }
}

/**
 * Transfer Service
 * For ride-sharing payouts to drivers
 */
export class StripeTransferService {
  
  static async createTransfer(params: {
    amount: number; // in cents
    currency: string;
    destination: string; // connected account ID
    metadata?: Record<string, string>;
  }): Promise<Stripe.Transfer> {
    try {
      const stripe = await getStripeClient();
      
      const transfer = await stripe.transfers.create({
        amount: params.amount,
        currency: params.currency,
        destination: params.destination,
        metadata: params.metadata || {},
      });
      
      logger.info("Transfer created", {
        transferId: transfer.id,
        amount: params.amount,
        destination: params.destination,
      });

      return transfer;
      
    } catch (error: any) {
      logger.error("Failed to create transfer", {
        error: error.message,
        params,
      });
      throw new Error(`Transfer creation failed: ${error.message}`);
    }
  }

  static async createDriverPayout(params: {
    driverId: string;
    stripeAccountId: string;
    amountUsd: number;
    validateAccount?: boolean;
  }): Promise<{
    success: boolean;
    transfer?: Stripe.Transfer;
    error?: string;
  }> {
    try {
      // Validate account requirements if requested
      if (params.validateAccount) {
        const requirements = await StripeAccountService.checkAccountRequirements(params.stripeAccountId);
        if (!requirements.isPayoutEnabled || requirements.requirementsDue.length > 0) {
          return {
            success: false,
            error: `Driver account not ready for payouts. Requirements due: ${requirements.requirementsDue.join(', ')}`,
          };
        }
      }

      // Create transfer
      const transfer = await this.createTransfer({
        amount: Math.round(params.amountUsd * 100), // Convert to cents
        currency: "usd",
        destination: params.stripeAccountId,
        metadata: { driverId: params.driverId },
      });

      return {
        success: true,
        transfer,
      };
      
    } catch (error: any) {
      logger.error("Driver payout failed", {
        driverId: params.driverId,
        error: error.message,
      });
      
      return {
        success: false,
        error: error.message,
      };
    }
  }
}

/**
 * Connect Account Service
 * For managing Stripe Connect accounts (ride-sharing drivers)
 */
export class StripeAccountService {
  
  static async retrieveAccount(accountId: string): Promise<Stripe.Account> {
    try {
      const stripe = await getStripeClient();
      const account = await stripe.accounts.retrieve(accountId);
      
      logger.info("Account retrieved successfully", { accountId });
      return account;
      
    } catch (error: any) {
      logger.error("Failed to retrieve account", {
        accountId,
        error: error.message,
      });
      throw new Error(`Account retrieval failed: ${error.message}`);
    }
  }

  static async createAccount(params: {
    type: 'express' | 'standard' | 'custom';
    country: string;
    email?: string;
    metadata?: Record<string, string>;
  }): Promise<Stripe.Account> {
    try {
      const stripe = await getStripeClient();
      
      const account = await stripe.accounts.create({
        type: params.type,
        country: params.country,
        email: params.email,
        metadata: params.metadata || {},
      });
      
      logger.info("Account created successfully", {
        accountId: account.id,
        type: params.type,
        country: params.country,
      });

      return account;
      
    } catch (error: any) {
      logger.error("Failed to create account", {
        error: error.message,
        params,
      });
      throw new Error(`Account creation failed: ${error.message}`);
    }
  }

  static async updateAccount(accountId: string, updates: {
    email?: string;
    metadata?: Record<string, string>;
    settings?: any;
  }): Promise<Stripe.Account> {
    try {
      const stripe = await getStripeClient();
      
      const account = await stripe.accounts.update(accountId, {
        email: updates.email,
        metadata: updates.metadata,
        settings: updates.settings,
      });
      
      logger.info("Account updated successfully", { accountId });
      return account;
      
    } catch (error: any) {
      logger.error("Failed to update account", {
        accountId,
        error: error.message,
        updates,
      });
      throw new Error(`Account update failed: ${error.message}`);
    }
  }

  static async checkAccountRequirements(accountId: string): Promise<{
    isPayoutEnabled: boolean;
    requirementsDue: string[];
    detailsSubmitted: boolean;
  }> {
    try {
      const account = await this.retrieveAccount(accountId);
      
      const result = {
        isPayoutEnabled: account.payouts_enabled || false,
        requirementsDue: (account as any).requirements?.currently_due || [],
        detailsSubmitted: account.details_submitted || false,
      };
      
      logger.info("Account requirements checked", {
        accountId,
        isPayoutEnabled: result.isPayoutEnabled,
        requirementsCount: result.requirementsDue.length,
      });

      return result;
      
    } catch (error: any) {
      logger.error("Failed to check account requirements", {
        accountId,
        error: error.message,
      });
      throw new Error(`Account requirements check failed: ${error.message}`);
    }
  }

  static async createAccountLink(accountId: string, params: {
    refreshUrl: string;
    returnUrl: string;
    type: 'account_onboarding' | 'account_update';
  }): Promise<Stripe.AccountLink> {
    try {
      const stripe = await getStripeClient();
      
      const accountLink = await stripe.accountLinks.create({
        account: accountId,
        refresh_url: params.refreshUrl,
        return_url: params.returnUrl,
        type: params.type,
      });
      
      logger.info("Account link created successfully", {
        accountId,
        type: params.type,
      });

      return accountLink;
      
    } catch (error: any) {
      logger.error("Failed to create account link", {
        accountId,
        error: error.message,
        params,
      });
      throw new Error(`Account link creation failed: ${error.message}`);
    }
  }

  static async deleteAccount(accountId: string): Promise<Stripe.DeletedAccount> {
    try {
      const stripe = await getStripeClient();
      const deleted = await stripe.accounts.del(accountId);
      
      logger.info("Account deleted successfully", { accountId });
      return deleted;
      
    } catch (error: any) {
      logger.error("Failed to delete account", {
        accountId,
        error: error.message,
      });
      throw new Error(`Account deletion failed: ${error.message}`);
    }
  }
}