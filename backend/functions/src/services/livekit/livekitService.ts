import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { AccessToken } from "livekit-server-sdk";
import { getSecret, secretPath, SECRET_IDS } from "../../shared/secretManager";

// Supported LiveKit features
export enum LiveKitFeature {
  ImageLesson = "image-lesson",
  RideSharing = "ride-sharing", 
  Debate = "debate",
  FoodDelivery = "food-delivery"
}

// Role enums for each feature
export enum DebateRole {
  Debater = "debater",
  Audience = "audience"
}

export enum RideSharingRole {
  Driver = "driver",
  Passenger = "passenger"
}

export enum ImageLessonRole {
  Teacher = "teacher",
  Student = "student"
}

export enum FoodDeliveryRole {
  Customer = "customer",
  Restaurant = "restaurant", 
  Courier = "courier",
  AIAssistant = "ai_assistant",
  Support = "support"
}

// Union type for all possible roles
export type LiveKitRole = DebateRole | RideSharingRole | ImageLessonRole | FoodDeliveryRole;

// Token permissions interface
export interface TokenPermissions {
  roomJoin?: boolean;
  canPublish?: boolean;
  canSubscribe?: boolean;
  canPublishData?: boolean;
  hidden?: boolean;
  canUpdateOwnMetadata?: boolean;
}

// Token generation parameters
export interface TokenParams {
  feature: LiveKitFeature;
  userId?: string;
  roomName?: string;
  sessionId?: string;
  role?: LiveKitRole;
  permissions?: TokenPermissions;
}

// Token response
export interface TokenResponse {
  serverUrl: string;
  participantToken: string;
  roomName: string;
  feature: LiveKitFeature;
}

/**
 * LiveKit Token Service
 * Centralized token generation for all LiveKit features
 */
export class LiveKitTokenService {
  
  /**
   * Get credentials for a specific feature
   */
  private static async getFeatureCredentials(feature: LiveKitFeature): Promise<{
    apiKey: string;
    apiSecret: string;
    wsUrl: string;
  }> {
    let apiKey: string;
    let apiSecret: string;
    let wsUrl: string;
    
    switch (feature) {
      case LiveKitFeature.ImageLesson:
        apiKey = await getSecret(secretPath(SECRET_IDS.LIVEKIT_IMAGE_LESSON_API_KEY));
        apiSecret = await getSecret(secretPath(SECRET_IDS.LIVEKIT_IMAGE_LESSON_API_SECRET));
        wsUrl = await getSecret(secretPath(SECRET_IDS.LIVEKIT_IMAGE_LESSON_WS_URL));
        break;
      case LiveKitFeature.RideSharing:
        apiKey = await getSecret(secretPath(SECRET_IDS.LIVEKIT_RIDE_SHARING_API_KEY));
        apiSecret = await getSecret(secretPath(SECRET_IDS.LIVEKIT_RIDE_SHARING_API_SECRET));
        wsUrl = await getSecret(secretPath(SECRET_IDS.LIVEKIT_RIDE_SHARING_WS_URL));
        break;
      case LiveKitFeature.Debate:
        apiKey = await getSecret(secretPath(SECRET_IDS.LIVEKIT_DEBATE_API_KEY));
        apiSecret = await getSecret(secretPath(SECRET_IDS.LIVEKIT_DEBATE_API_SECRET));
        wsUrl = await getSecret(secretPath(SECRET_IDS.LIVEKIT_DEBATE_WS_URL));
        break;
      case LiveKitFeature.FoodDelivery:
        apiKey = await getSecret(secretPath(SECRET_IDS.LIVEKIT_FOOD_DELIVERY_API_KEY));
        apiSecret = await getSecret(secretPath(SECRET_IDS.LIVEKIT_FOOD_DELIVERY_API_SECRET));
        wsUrl = await getSecret(secretPath(SECRET_IDS.LIVEKIT_FOOD_DELIVERY_WS_URL));
        break;
      default:
        throw new Error(`Unknown LiveKit feature: ${feature}`);
    }

    return { apiKey, apiSecret, wsUrl };
  }

  /**
   * Get role-based permissions
   */
  private static getRoleBasedPermissions(feature: LiveKitFeature, role?: LiveKitRole): TokenPermissions {
    const basePermissions: TokenPermissions = {
      roomJoin: true,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true, // For RPC communication with agents
      hidden: false,
      canUpdateOwnMetadata: true,
    };

    // Role-based permission customizations
    if (feature === LiveKitFeature.Debate && role) {
      switch (role) {
        case DebateRole.Debater:
          return { ...basePermissions, canPublish: true };
        case DebateRole.Audience:
          return { ...basePermissions, canPublish: false };
      }
    }

    if (feature === LiveKitFeature.ImageLesson && role) {
      switch (role) {
        case ImageLessonRole.Teacher:
          return { ...basePermissions, canPublish: true };
        case ImageLessonRole.Student:
          return { ...basePermissions, canPublish: false };
      }
    }

    if (feature === LiveKitFeature.RideSharing && role) {
      // Both drivers and passengers can publish for location sharing
      return { ...basePermissions, canPublish: true, canPublishData: true };
    }

    if (feature === LiveKitFeature.FoodDelivery && role) {
      switch (role) {
        case FoodDeliveryRole.Customer:
          return { ...basePermissions, canPublish: true }; // Voice ordering with AI
        case FoodDeliveryRole.Restaurant:
          return { ...basePermissions, canPublish: true }; // Order confirmations, updates
        case FoodDeliveryRole.Courier:
          return { ...basePermissions, canPublish: true }; // Delivery updates, location
        case FoodDeliveryRole.AIAssistant:
          return { ...basePermissions, canPublish: true, canPublishData: true }; // AI responses, menu data
        case FoodDeliveryRole.Support:
          return { ...basePermissions, canPublish: true }; // Customer support calls
      }
    }

    return basePermissions;
  }

  /**
   * Generate a LiveKit access token
   */
  static async generateToken(params: TokenParams): Promise<TokenResponse> {
    try {
      const { feature, userId, roomName, sessionId, role, permissions } = params;
      
      // Get credentials for the feature
      const { apiKey, apiSecret, wsUrl } = await this.getFeatureCredentials(feature);

      // Generate user identity
      const defaultSessionId = Math.random().toString(36).slice(2, 8);
      const identity = userId ?? `${feature}-user-${sessionId ?? defaultSessionId}`;
      
      // Generate room name
      const room = roomName ?? `${feature}-${sessionId ?? defaultSessionId}`;

      // Get permissions (use provided, role-based, or defaults)
      const tokenPermissions = permissions ?? this.getRoleBasedPermissions(feature, role);

      // Create access token
      const accessToken = new AccessToken(apiKey, apiSecret, { identity });
      
      // Add grants
      accessToken.addGrant({
        room,
        ...tokenPermissions,
      });

      const token = await accessToken.toJwt();

      logger.info("LiveKit token generated", {
        feature,
        identity,
        room,
        role,
        permissions: tokenPermissions,
      });

      return {
        serverUrl: wsUrl,
        participantToken: token,
        roomName: room,
        feature,
      };

    } catch (error: any) {
      logger.error("LiveKit token generation failed", {
        feature: params.feature,
        error: error.message,
        params,
      });
      throw new Error(`LiveKit token generation failed: ${error.message}`);
    }
  }

}

/**
 * HTTP endpoint for token generation (maintains backward compatibility)
 */
export const livekitToken = onRequest({ cors: true }, async (req, res) => {
  try {
    const feature = req.body?.feature ?? LiveKitFeature.RideSharing;
    const sessionId = req.body?.sessionId;
    const userId = (req as any).auth?.uid ?? req.body?.uid;
    const roomName = req.body?.roomName;
    const role = req.body?.role as LiveKitRole;
    const permissions = req.body?.permissions;

    const tokenResponse = await LiveKitTokenService.generateToken({
      feature: feature as LiveKitFeature,
      userId,
      roomName,
      sessionId,
      role,
      permissions,
    });

    res.json(tokenResponse);
  } catch (err: any) {
    logger.error("livekitToken endpoint failed", err);
    res.status(500).json({ error: err?.message ?? "internal" });
  }
});