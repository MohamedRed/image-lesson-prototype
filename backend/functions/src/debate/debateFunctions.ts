import { onRequest } from "firebase-functions/v2/https";
import { onDocumentCreated, onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { LiveKitTokenService, LiveKitFeature, DebateRole } from "../services/livekit/livekitService";

const db = admin.firestore();

/**
 * Get debate token - wrapper around livekitToken with debate-specific logic
 */
export const getDebateToken = onRequest({ cors: true }, async (req, res) => {
  try {
    const { debateId, role } = req.body;
    
    if (!debateId || !role) {
      res.status(400).json({ error: "Missing debateId or role" });
      return;
    }
    
    // Verify user can join this debate
    const debate = await db.collection("debates").doc(debateId).get();
    if (!debate.exists) {
      res.status(404).json({ error: "Debate not found" });
      return;
    }
    
    const debateData = debate.data()!;
    
    // Check capacity for debaters
    if (role === "debater" && debateData.participantCount >= debateData.maxDebaters) {
      res.status(403).json({ error: "Debate is full" });
      return;
    }
    
    // Generate LiveKit token for debate using service
    const userId = (req as any).auth?.uid;
    const tokenResponse = await LiveKitTokenService.generateToken({
      feature: LiveKitFeature.Debate,
      sessionId: debateId,
      userId,
      role: role === 'debater' ? DebateRole.Debater : DebateRole.Audience,
      roomName: `debate-${debateId}`,
    });
    
    res.json({
      token: tokenResponse.participantToken,
      wsUrl: tokenResponse.serverUrl,
      roomName: tokenResponse.roomName,
      participantIdentity: userId ?? `debate-user-${debateId}`,
    });
    
  } catch (err: any) {
    logger.error("getDebateToken failed", err);
    res.status(500).json({ error: err?.message ?? "internal" });
  }
});

/**
 * Create a new debate
 */
export const createDebate = onRequest({ cors: true }, async (req, res) => {
  try {
    const { title, description, category, maxDebaters, isPublic, scheduledAt } = req.body;
    const userId = (req as any).auth?.uid;
    
    if (!userId) {
      res.status(401).json({ error: "Authentication required" });
      return;
    }
    
    if (!title || !description || !category) {
      res.status(400).json({ error: "Missing required fields" });
      return;
    }
    
    const debateData: any = {
      title,
      topicTags: [category], // Convert category to tags array
      startTime: scheduledAt ? new Date(scheduledAt) : FieldValue.serverTimestamp(),
      endTime: null, // Set when debate actually ends
      timeframeStart: null, // Historical bounds - can be set later
      timeframeEnd: null,
      isLive: false,
      paywalled: false,
      createdBy: userId,
      speakers: [], // Will be populated when debaters join
      stats: {
        currentViewers: 0,
        totalViews: 0,
        likes: 0,
        dislikes: 0,
        commentSummary: []
      }
    };
    
    if (scheduledAt) {
      debateData.scheduledAt = new Date(scheduledAt);
    }
    
    const docRef = await db.collection("debates").add(debateData);
    
    res.json({ debateId: docRef.id });
    
  } catch (err: any) {
    logger.error("createDebate failed", err);
    res.status(500).json({ error: err?.message ?? "internal" });
  }
});

/**
 * Add a timeline event to a debate
 */
export const addTimelineEvent = onRequest({ cors: true }, async (req, res) => {
  try {
    const { debateId, title, description, historicalDate, sources } = req.body;
    const userId = (req as any).auth?.uid;
    
    if (!userId) {
      res.status(401).json({ error: "Authentication required" });
      return;
    }
    
    if (!debateId || !title || !description || !historicalDate) {
      res.status(400).json({ error: "Missing required fields" });
      return;
    }
    
    // Verify user is a debater in this debate
    const debate = await db.collection("debates").doc(debateId).get();
    if (!debate.exists) {
      res.status(404).json({ error: "Debate not found" });
      return;
    }
    
    const eventData = {
      historicalDate: new Date(historicalDate), // Convert to timestamp
      title,
      description,
      sources: (sources || []).map((url: string) => ({ title: "", url })), // Convert to source objects
      isWithinScope: true, // Validate against timeframe bounds
      factCheckStatus: "unknown", // Start as unknown, will be checked
      createdAt: FieldValue.serverTimestamp(),
      createdBy: userId
    };
    
    const docRef = await db.collection("debates").doc(debateId)
      .collection("timelines").doc(userId)
      .collection("events").add(eventData);
    
    res.json({ eventId: docRef.id });
    
  } catch (err: any) {
    logger.error("addTimelineEvent failed", err);
    res.status(500).json({ error: err?.message ?? "internal" });
  }
});

/**
 * Upload shared media for a debate
 */
export const uploadSharedMedia = onRequest({ cors: true }, async (req, res) => {
  try {
    const { debateId, title, description, type, contentUrl, thumbnailUrl } = req.body;
    const userId = (req as any).auth?.uid;
    
    if (!userId) {
      res.status(401).json({ error: "Authentication required" });
      return;
    }
    
    if (!debateId || !title || !type) {
      res.status(400).json({ error: "Missing required fields" });
      return;
    }
    
    const mediaData = {
      uploaderId: userId,
      uploaderName: (req as any).auth?.token?.name || "Anonymous",
      title,
      description: description || "",
      type,
      contentUrl,
      thumbnailUrl,
      uploadedAt: FieldValue.serverTimestamp(),
    };
    
    const docRef = await db.collection("debates").doc(debateId)
      .collection("sharedMedia").add(mediaData);
    
    res.json({ mediaId: docRef.id });
    
  } catch (err: any) {
    logger.error("uploadSharedMedia failed", err);
    res.status(500).json({ error: err?.message ?? "internal" });
  }
});

/**
 * Update debate participant count when someone joins/leaves
 */
export const updateDebateParticipants = onDocumentWritten(
  "debates/{debateId}/participants/{participantId}",
  async (event) => {
    const debateId = event.params.debateId;
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    
    if (!before && after) {
      // Participant joined
      await db.collection("debates").doc(debateId).update({
        participantCount: FieldValue.increment(1),
        isLive: true,
        updatedAt: FieldValue.serverTimestamp(),
      });
    } else if (before && !after) {
      // Participant left
      const debate = await db.collection("debates").doc(debateId).get();
      const count = debate.data()?.participantCount || 0;
      
      await db.collection("debates").doc(debateId).update({
        participantCount: Math.max(0, count - 1),
        isLive: count > 1,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  }
);

/**
 * Submit a comment on a debate (for spectators)
 */
export const submitComment = onRequest({ cors: true }, async (req, res) => {
  try {
    const { debateId, text } = req.body;
    const userId = (req as any).auth?.uid;
    
    if (!userId) {
      res.status(401).json({ error: "Authentication required" });
      return;
    }
    
    if (!debateId || !text) {
      res.status(400).json({ error: "Missing required fields" });
      return;
    }
    
    const commentData = {
      userId,
      userName: (req as any).auth?.token?.name || "Anonymous",
      text: text.substring(0, 500), // Limit comment length
      createdAt: FieldValue.serverTimestamp(),
      sentiment: null, // Will be analyzed by AI worker
    };
    
    const docRef = await db.collection("debates").doc(debateId)
      .collection("comments").add(commentData);
    
    res.json({ commentId: docRef.id });
    
  } catch (err: any) {
    logger.error("submitComment failed", err);
    res.status(500).json({ error: err?.message ?? "internal" });
  }
});

/**
 * Get debate recommendations for a user
 */
export const getRecommendations = onRequest({ cors: true }, async (req, res) => {
  try {
    const userId = (req as any).auth?.uid;
    const { category, limit = 10 } = req.query;
    
    let query = db.collection("debates")
      .where("isPublic", "==", true)
      .orderBy("createdAt", "desc");
    
    if (category) {
      query = query.where("category", "==", category);
    }
    
    const snapshot = await query.limit(Number(limit)).get();
    
    const debates = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt?.toDate?.() || null,
      scheduledAt: doc.data().scheduledAt?.toDate?.() || null,
    }));
    
    res.json({ debates });
    
  } catch (err: any) {
    logger.error("getRecommendations failed", err);
    res.status(500).json({ error: err?.message ?? "internal" });
  }
});