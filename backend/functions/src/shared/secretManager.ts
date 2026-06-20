import { SecretManagerServiceClient } from "@google-cloud/secret-manager";

const sm = new SecretManagerServiceClient();
const secretCache: Record<string, string> = {};

// Map secret IDs to environment variable names for local development
const LOCAL_ENV_MAPPING: Record<string, string> = {
  "stripe-publishable-key": "STRIPE_PUBLIC_KEY",
  "stripe-secret-key": "STRIPE_SECRET_KEY",
  "stripe-webhook-secret": "STRIPE_WEBHOOK_SECRET",
  "mapbox-access-token": "MAPBOX_ACCESS_TOKEN",
  "livekit-ride-sharing-api-key": "LIVEKIT_API_KEY",
  "livekit-ride-sharing-api-secret": "LIVEKIT_API_SECRET",
  "livekit-ride-sharing-ws-url": "LIVEKIT_URL",
  "radar-publishable-key": "RADAR_PUBLIC_KEY",
  "radar-secret-key": "RADAR_SECRET_KEY",
  // dLocal (Wafacash) – local env mapping
  "dlocal-api-login": "DLOCAL_API_LOGIN",
  "dlocal-api-trans-key": "DLOCAL_API_TRANS_KEY",
  "dlocal-webhook-secret": "DLOCAL_WEBHOOK_SECRET",
  "dlocal-base-url": "DLOCAL_BASE_URL",
  // News API
  "newsapi-key": "NEWSAPI_KEY",
};

/**
 * Retrieves a secret from Google Cloud Secret Manager with caching
 * @param name - The full secret path (e.g., projects/PROJECT_ID/secrets/SECRET_ID/versions/latest)
 * @returns The secret value
 */
export async function getSecret(name: string): Promise<string> {
  // Check if running in emulator mode
  if (process.env.IS_EMULATOR === 'true' || process.env.FIRESTORE_EMULATOR_HOST) {
    // Extract secret ID from path
    const secretId = name.split('/')[3];
    const envVar = LOCAL_ENV_MAPPING[secretId];
    
    if (envVar && process.env[envVar]) {
      return process.env[envVar];
    }
    
    // Return mock value for local testing
    console.log(`⚠️  Using mock value for secret: ${secretId}`);
    return `mock_${secretId}_value`;
  }
  
  if (secretCache[name]) return secretCache[name];
  const [version] = await sm.accessSecretVersion({ name });
  const payload = version.payload?.data?.toString();
  if (!payload) throw new Error(`Secret ${name} has no payload`);
  secretCache[name] = payload;
  return payload;
}

/**
 * Helper function to construct secret path
 * @param secretId - The secret ID (e.g., "stripe-secret-key")
 * @returns Full secret path for the latest version
 */
export function secretPath(secretId: string): string {
  const projectId = process.env.GCP_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
  return `projects/${projectId}/secrets/${secretId}/versions/latest`;
}

/**
 * Common secret IDs used across the application
 */
export const SECRET_IDS = {
  STRIPE_PUBLISHABLE_KEY: "stripe-publishable-key",
  STRIPE_SECRET_KEY: "stripe-secret-key",
  STRIPE_WEBHOOK_SECRET: "stripe-webhook-secret",
  MAPBOX_ACCESS_TOKEN: "mapbox-access-token",
  SLACK_WEBHOOK_URL: "slack-webhook-url",
  // LiveKit credentials per feature/agent
  LIVEKIT_IMAGE_LESSON_API_KEY: "livekit-image-lesson-api-key",
  LIVEKIT_IMAGE_LESSON_API_SECRET: "livekit-image-lesson-api-secret",
  LIVEKIT_IMAGE_LESSON_WS_URL: "livekit-image-lesson-ws-url",
  LIVEKIT_RIDE_SHARING_API_KEY: "livekit-ride-sharing-api-key",
  LIVEKIT_RIDE_SHARING_API_SECRET: "livekit-ride-sharing-api-secret",
  LIVEKIT_RIDE_SHARING_WS_URL: "livekit-ride-sharing-ws-url",
  LIVEKIT_DEBATE_API_KEY: "livekit-debate-api-key",
  LIVEKIT_DEBATE_API_SECRET: "livekit-debate-api-secret",
  LIVEKIT_DEBATE_WS_URL: "livekit-debate-ws-url",
  LIVEKIT_FOOD_DELIVERY_API_KEY: "livekit-food-delivery-api-key",
  LIVEKIT_FOOD_DELIVERY_API_SECRET: "livekit-food-delivery-api-secret",
  LIVEKIT_FOOD_DELIVERY_WS_URL: "livekit-food-delivery-ws-url",
  RADAR_PUBLISHABLE_KEY: "radar-publishable-key",
  RADAR_SECRET_KEY: "radar-secret-key",
  // dLocal (Wafacash)
  DLOCAL_API_LOGIN: "dlocal-api-login",
  DLOCAL_API_TRANS_KEY: "dlocal-api-trans-key",
  DLOCAL_WEBHOOK_SECRET: "dlocal-webhook-secret",
  DLOCAL_BASE_URL: "dlocal-base-url",
  // News API
  NEWSAPI_KEY: "newsapi-key",
} as const; 