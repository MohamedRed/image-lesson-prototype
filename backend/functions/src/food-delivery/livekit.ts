import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { LiveKitTokenService, LiveKitFeature, FoodDeliveryRole } from "../services/livekit/livekitService";

const db = admin.firestore();

/**
 * Generate LiveKit token for voice ordering with AI assistant
 */
export const getVoiceOrderingToken = onRequest({ cors: true }, async (req, res) => {
  try {
    const { orderId, restaurantId } = req.body;
    const userId = (req as any).auth?.uid;
    
    if (!userId) {
      res.status(401).json({ error: "Authentication required" });
      return;
    }
    
    if (!restaurantId) {
      res.status(400).json({ error: "Restaurant ID is required" });
      return;
    }

    // Generate session ID based on user and restaurant
    const sessionId = orderId || `voice-order-${userId}-${restaurantId}-${Date.now()}`;
    
    // Create or update voice ordering session in Firestore
    const voiceSessionData = {
      customerId: userId,
      restaurantId,
      orderId: orderId || null,
      status: "active",
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
      aiAssistantEnabled: true,
      voiceRecognitionEnabled: true,
      menuAccessEnabled: true,
    };

    await db.collection("voiceOrderingSessions").doc(sessionId).set(voiceSessionData, { merge: true });

    // Generate LiveKit token for customer
    const tokenResponse = await LiveKitTokenService.generateToken({
      feature: LiveKitFeature.FoodDelivery,
      sessionId,
      userId,
      role: FoodDeliveryRole.Customer,
      roomName: `voice-order-${restaurantId}-${sessionId}`,
    });

    res.json({
      token: tokenResponse.participantToken,
      wsUrl: tokenResponse.serverUrl,
      roomName: tokenResponse.roomName,
      sessionId,
      participantIdentity: userId,
      aiAssistantEnabled: true,
    });

  } catch (err: any) {
    logger.error("getVoiceOrderingToken failed", err);
    res.status(500).json({ error: err?.message ?? "internal" });
  }
});

/**
 * Generate LiveKit token for restaurant staff
 */
export const getRestaurantToken = onRequest({ cors: true }, async (req, res) => {
  try {
    const { orderId, restaurantId } = req.body;
    const userId = (req as any).auth?.uid;
    
    if (!userId || !restaurantId) {
      res.status(400).json({ error: "Missing required fields" });
      return;
    }

    // Verify user works at this restaurant
    const restaurantDoc = await db.collection("restaurants").doc(restaurantId).get();
    if (!restaurantDoc.exists) {
      res.status(404).json({ error: "Restaurant not found" });
      return;
    }

    const restaurant = restaurantDoc.data()!;
    if (restaurant.ownerId !== userId && !restaurant.staffIds?.includes(userId)) {
      res.status(403).json({ error: "Unauthorized: Not a staff member" });
      return;
    }

    const sessionId = `restaurant-${restaurantId}-${orderId || Date.now()}`;

    // Generate LiveKit token for restaurant
    const tokenResponse = await LiveKitTokenService.generateToken({
      feature: LiveKitFeature.FoodDelivery,
      sessionId,
      userId,
      role: FoodDeliveryRole.Restaurant,
      roomName: `restaurant-comm-${restaurantId}-${orderId}`,
    });

    res.json({
      token: tokenResponse.participantToken,
      wsUrl: tokenResponse.serverUrl,
      roomName: tokenResponse.roomName,
      sessionId,
      participantIdentity: `restaurant-${userId}`,
    });

  } catch (err: any) {
    logger.error("getRestaurantToken failed", err);
    res.status(500).json({ error: err?.message ?? "internal" });
  }
});

/**
 * Generate LiveKit token for delivery courier
 */
export const getCourierToken = onRequest({ cors: true }, async (req, res) => {
  try {
    const { orderId } = req.body;
    const courierId = (req as any).auth?.uid;
    
    if (!courierId || !orderId) {
      res.status(400).json({ error: "Missing required fields" });
      return;
    }

    // Verify courier is assigned to this order
    const orderDoc = await db.collection("orders").doc(orderId).get();
    if (!orderDoc.exists) {
      res.status(404).json({ error: "Order not found" });
      return;
    }

    const order = orderDoc.data()!;
    if (order.courierId !== courierId) {
      res.status(403).json({ error: "Unauthorized: Not assigned to this order" });
      return;
    }

    const sessionId = `delivery-${orderId}`;

    // Generate LiveKit token for courier
    const tokenResponse = await LiveKitTokenService.generateToken({
      feature: LiveKitFeature.FoodDelivery,
      sessionId,
      userId: courierId,
      role: FoodDeliveryRole.Courier,
      roomName: `delivery-comm-${orderId}`,
    });

    res.json({
      token: tokenResponse.participantToken,
      wsUrl: tokenResponse.serverUrl,
      roomName: tokenResponse.roomName,
      sessionId,
      participantIdentity: `courier-${courierId}`,
      orderId,
    });

  } catch (err: any) {
    logger.error("getCourierToken failed", err);
    res.status(500).json({ error: err?.message ?? "internal" });
  }
});

/**
 * Generate LiveKit token for AI assistant
 * This endpoint is called by the AI service to join voice ordering sessions
 */
export const getAIAssistantToken = onRequest({ cors: true }, async (req, res) => {
  try {
    const { sessionId, restaurantId } = req.body;
    const apiKey = req.headers['x-api-key'] as string;
    
    // Validate API key for AI service (implement proper auth)
    if (!apiKey || apiKey !== process.env.AI_SERVICE_API_KEY) {
      res.status(401).json({ error: "Invalid API key" });
      return;
    }
    
    if (!sessionId || !restaurantId) {
      res.status(400).json({ error: "Missing required fields" });
      return;
    }

    // Verify voice ordering session exists
    const sessionDoc = await db.collection("voiceOrderingSessions").doc(sessionId).get();
    if (!sessionDoc.exists) {
      res.status(404).json({ error: "Voice ordering session not found" });
      return;
    }

    const session = sessionDoc.data()!;
    if (!session.aiAssistantEnabled) {
      res.status(403).json({ error: "AI assistant not enabled for this session" });
      return;
    }

    // Generate LiveKit token for AI assistant
    const tokenResponse = await LiveKitTokenService.generateToken({
      feature: LiveKitFeature.FoodDelivery,
      sessionId,
      userId: `ai-assistant-${sessionId}`,
      role: FoodDeliveryRole.AIAssistant,
      roomName: `voice-order-${restaurantId}-${sessionId}`,
    });

    // Update session to indicate AI joined
    await db.collection("voiceOrderingSessions").doc(sessionId).update({
      aiAssistantJoined: true,
      aiJoinedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.json({
      token: tokenResponse.participantToken,
      wsUrl: tokenResponse.serverUrl,
      roomName: tokenResponse.roomName,
      sessionId,
      participantIdentity: `ai-assistant-${sessionId}`,
      restaurantId: session.restaurantId,
      customerId: session.customerId,
    });

  } catch (err: any) {
    logger.error("getAIAssistantToken failed", err);
    res.status(500).json({ error: err?.message ?? "internal" });
  }
});

/**
 * Generate LiveKit token for customer support
 */
export const getSupportToken = onRequest({ cors: true }, async (req, res) => {
  try {
    const { orderId, sessionType = "support" } = req.body;
    const supportUserId = (req as any).auth?.uid;
    
    if (!supportUserId || !orderId) {
      res.status(400).json({ error: "Missing required fields" });
      return;
    }

    // Verify user is support staff
    const userDoc = await db.collection("supportStaff").doc(supportUserId).get();
    if (!userDoc.exists) {
      res.status(403).json({ error: "Unauthorized: Not a support staff member" });
      return;
    }

    const sessionId = `support-${orderId}-${Date.now()}`;

    // Generate LiveKit token for support
    const tokenResponse = await LiveKitTokenService.generateToken({
      feature: LiveKitFeature.FoodDelivery,
      sessionId,
      userId: supportUserId,
      role: FoodDeliveryRole.Support,
      roomName: `support-${sessionType}-${orderId}`,
    });

    // Log support session
    await db.collection("supportSessions").doc(sessionId).set({
      supportUserId,
      orderId,
      sessionType,
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
      status: "active",
    });

    res.json({
      token: tokenResponse.participantToken,
      wsUrl: tokenResponse.serverUrl,
      roomName: tokenResponse.roomName,
      sessionId,
      participantIdentity: `support-${supportUserId}`,
      orderId,
    });

  } catch (err: any) {
    logger.error("getSupportToken failed", err);
    res.status(500).json({ error: err?.message ?? "internal" });
  }
});

/**
 * End a voice ordering session
 */
export const endVoiceOrderingSession = onRequest({ cors: true }, async (req, res) => {
  try {
    const { sessionId } = req.body;
    const userId = (req as any).auth?.uid;
    
    if (!sessionId || !userId) {
      res.status(400).json({ error: "Missing required fields" });
      return;
    }

    // Get session data
    const sessionDoc = await db.collection("voiceOrderingSessions").doc(sessionId).get();
    if (!sessionDoc.exists) {
      res.status(404).json({ error: "Session not found" });
      return;
    }

    const session = sessionDoc.data()!;
    if (session.customerId !== userId) {
      res.status(403).json({ error: "Unauthorized" });
      return;
    }

    // Update session status
    await db.collection("voiceOrderingSessions").doc(sessionId).update({
      status: "ended",
      endedAt: admin.firestore.FieldValue.serverTimestamp(),
      endedBy: userId,
    });

    res.json({
      success: true,
      sessionId,
      message: "Voice ordering session ended successfully",
    });

  } catch (err: any) {
    logger.error("endVoiceOrderingSession failed", err);
    res.status(500).json({ error: err?.message ?? "internal" });
  }
});

/**
 * Get active voice ordering sessions for a restaurant
 */
export const getRestaurantVoiceSessions = onRequest({ cors: true }, async (req, res) => {
  try {
    const { restaurantId } = req.query;
    const userId = (req as any).auth?.uid;
    
    if (!restaurantId || !userId) {
      res.status(400).json({ error: "Missing required fields" });
      return;
    }

    // Verify user has access to this restaurant
    const restaurantDoc = await db.collection("restaurants").doc(restaurantId as string).get();
    if (!restaurantDoc.exists) {
      res.status(404).json({ error: "Restaurant not found" });
      return;
    }

    const restaurant = restaurantDoc.data()!;
    if (restaurant.ownerId !== userId && !restaurant.staffIds?.includes(userId)) {
      res.status(403).json({ error: "Unauthorized" });
      return;
    }

    // Get active sessions
    const sessionsSnapshot = await db.collection("voiceOrderingSessions")
      .where("restaurantId", "==", restaurantId)
      .where("status", "==", "active")
      .orderBy("startedAt", "desc")
      .limit(20)
      .get();

    const sessions = sessionsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      startedAt: doc.data().startedAt?.toDate?.() || null,
    }));

    res.json({
      success: true,
      sessions,
      restaurantId,
    });

  } catch (err: any) {
    logger.error("getRestaurantVoiceSessions failed", err);
    res.status(500).json({ error: err?.message ?? "internal" });
  }
});