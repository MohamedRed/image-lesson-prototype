export const getStripeClient = async () => ({
  paymentIntents: {
    create: async (p: any) => ({ id: 'pi_test', client_secret: 'secret', amount: p.amount, metadata: p.metadata || {} }),
    capture: async (_id: string, _p: any) => ({ id: 'pi_test', amount_received: 1000, metadata: { orderId: 'o1' } }),
    retrieve: async (_id: string) => ({ id: 'pi_test' }),
  },
  refunds: {
    create: async (p: any) => ({ id: 're_test', amount: p.amount || 1000, status: 'succeeded' }),
    retrieve: async (_id: string) => ({ id: 're_test', amount: 1000, status: 'succeeded' }),
  },
  webhooks: {
    constructEvent: (_payload: any, _sig: any, _secret: any) => ({ id: 'evt_1', type: 'payment_intent.succeeded', data: { object: { id: 'pi_test' } } }),
  },
  payouts: {
    list: async (_: any, __: any) => ({ data: [] }),
  },
  accounts: {
    create: async (_: any) => ({ id: 'acct_test', payouts_enabled: true, details_submitted: true, requirements: { currently_due: [] } }),
    update: async (_id: string, _u: any) => ({ id: 'acct_test', payouts_enabled: true, details_submitted: true, requirements: { currently_due: [] } }),
    retrieve: async (_id: string) => ({ id: 'acct_test', payouts_enabled: true, details_submitted: true, requirements: { currently_due: [] } }),
    del: async (_id: string) => ({ id: 'acct_test', deleted: true }),
  },
  accountLinks: {
    create: async (_: any) => ({ url: 'https://connect.stripe.com/test' }),
  },
  transfers: {
    create: async (_: any) => ({ id: 'tr_test' }),
  },
});

export class StripePaymentService { static async createPaymentIntent(p:any){ const c=await getStripeClient(); return c.paymentIntents.create(p);} static async capturePaymentIntent(id:string,p?:any){ const c=await getStripeClient(); return c.paymentIntents.capture(id,p);} }
export class StripeRefundService { static async createRefund(p:any){ const c=await getStripeClient(); return c.refunds.create(p);} }
export class StripeWebhookService { static async constructEvent(payload:any,sig:any){ const c=await getStripeClient(); return c.webhooks.constructEvent(payload,sig,'secret'); } }
export class StripeAccountService { static async createAccount(p:any){ const c=await getStripeClient(); return c.accounts.create(p);} static async createAccountLink(id:string,p:any){ const c=await getStripeClient(); return c.accountLinks.create({ account: id, ...p }); } static async checkAccountRequirements(_id:string){ return { isPayoutEnabled: true, requirementsDue: [], detailsSubmitted: true }; } }









