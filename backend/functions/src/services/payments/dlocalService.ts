import { logger } from "firebase-functions";
import { getSecret, secretPath, SECRET_IDS } from "../../shared/secretManager";

type DlocalEnv = {
  apiLogin: string;
  apiTransKey: string;
  baseUrl: string;
};

let cachedEnv: DlocalEnv | null = null;

async function getEnv(): Promise<DlocalEnv> {
  if (cachedEnv) return cachedEnv;
  const apiLogin = await getSecret(secretPath(SECRET_IDS.DLOCAL_API_LOGIN));
  const apiTransKey = await getSecret(secretPath(SECRET_IDS.DLOCAL_API_TRANS_KEY));
  const baseUrl = (await getSecret(secretPath(SECRET_IDS.DLOCAL_BASE_URL))) || "https://sandbox.dlocal.com";
  cachedEnv = { apiLogin, apiTransKey, baseUrl };
  return cachedEnv;
}

export type DlocalPaymentInit = {
  amount: number; // in MAD
  currency: 'MAD';
  orderId: string; // our reference
  description?: string;
  callbackUrl?: string; // webhook
  returnUrl?: string;   // customer return
  customer?: { id?: string; email?: string; name?: string };
  method?: 'CASH' | 'CARD';
  channel?: 'WAFACASH' | 'CASHPLUS' | 'GENERIC';
  metadata?: Record<string, any>;
};

export type DlocalInitResponse = {
  id: string;
  status: string;
  redirectUrl?: string;
};

export class DlocalService {
  static async initPayment(params: DlocalPaymentInit): Promise<DlocalInitResponse> {
    const env = await getEnv();
    // For now, do not perform real HTTP calls; stub a response structured like dLocal redirect
    const id = `dloc_${Math.random().toString(36).slice(2)}`;
    logger.info("dLocal initPayment (stub)", { id, amount: params.amount, method: params.method, channel: params.channel });
    return {
      id,
      status: 'pending',
      redirectUrl: params.method === 'CASH' ? `${env.baseUrl}/cash/${id}` : `${env.baseUrl}/pay/${id}`,
    };
  }

  static async verifyWebhookSignature(rawBody: Buffer | string, signature: string | undefined): Promise<boolean> {
    // In real integration, compute HMAC using apiTransKey and compare with header
    const secret = await getSecret(secretPath(SECRET_IDS.DLOCAL_WEBHOOK_SECRET));
    if (!signature) return false;
    // Stub: accept signature that matches the secret or emulator mode
    const ok = signature === secret || process.env.IS_EMULATOR === 'true' || !!process.env.FIRESTORE_EMULATOR_HOST;
    if (!ok) logger.warn("dLocal webhook signature mismatch");
    return ok;
  }

  static async getPaymentStatus(paymentId: string): Promise<'pending'|'succeeded'|'failed'|'cancelled'> {
    // Stub: randomly succeed; in production call dLocal /payments/:id
    logger.info("dLocal getPaymentStatus (stub)", { paymentId });
    return 'succeeded';
  }
}










