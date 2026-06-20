import { beforeEach } from "node:test";
import { getSecret, secretPath, SECRET_IDS } from "../src/secretManager";

// Mock the Google Cloud Secret Manager for testing
jest.mock("@google-cloud/secret-manager", () => ({
  SecretManagerServiceClient: jest.fn().mockImplementation(() => ({
    accessSecretVersion: jest.fn().mockResolvedValue([{
      payload: {
        data: Buffer.from("test-secret-value")
      }
    }])
  }))
}));

describe("Secret Manager", () => {
  beforeEach(() => {
    // Clear the cache between tests
    jest.resetModules();
  });

  test("should construct secret path correctly", () => {
    process.env.GCP_PROJECT = "test-project";
    const path = secretPath(SECRET_IDS.STRIPE_SECRET_KEY);
    expect(path).toBe("projects/test-project/secrets/stripe-secret-key/versions/latest");
  });

  test("should retrieve secret from Secret Manager", async () => {
    const secret = await getSecret(secretPath(SECRET_IDS.STRIPE_SECRET_KEY));
    expect(secret).toBe("test-secret-value");
  });

  test("should use cached secret on second call", async () => {
    const { SecretManagerServiceClient } = require("@google-cloud/secret-manager");
    const mockAccessSecretVersion = jest.fn().mockResolvedValue([{
      payload: {
        data: Buffer.from("cached-secret")
      }
    }]);
    
    SecretManagerServiceClient.mockImplementation(() => ({
      accessSecretVersion: mockAccessSecretVersion
    }));

    // Fresh import to get new instance
    delete require.cache[require.resolve("../src/secretManager")];
    const { getSecret, secretPath, SECRET_IDS } = require("../src/secretManager");

    const path = secretPath(SECRET_IDS.MAPBOX_ACCESS_TOKEN);
    
    // First call should hit the API
    await getSecret(path);
    expect(mockAccessSecretVersion).toHaveBeenCalledTimes(1);
    
    // Second call should use cache
    await getSecret(path);
    expect(mockAccessSecretVersion).toHaveBeenCalledTimes(1);
  });

  test("should have all required secret IDs defined", () => {
    expect(SECRET_IDS.STRIPE_SECRET_KEY).toBe("stripe-secret-key");
    expect(SECRET_IDS.STRIPE_WEBHOOK_SECRET).toBe("stripe-webhook-secret");
    expect(SECRET_IDS.MAPBOX_ACCESS_TOKEN).toBe("mapbox-access-token");
    expect(SECRET_IDS.SLACK_WEBHOOK_URL).toBe("slack-webhook-url");
    expect(SECRET_IDS.LIVEKIT_API_KEY).toBe("livekit-api-key");
    expect(SECRET_IDS.LIVEKIT_API_SECRET).toBe("livekit-api-secret");
    expect(SECRET_IDS.LIVEKIT_WS_URL).toBe("livekit-ws-url");
  });
}); 