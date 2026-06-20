import * as admin from "firebase-admin";
import { onCall } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { analytics } from "../shared/analytics";

const db = admin.firestore();

interface SetPresenceData {
  status: 'online' | 'away' | 'dnd' | 'offline';
}

interface SetTypingData {
  conversationId: string;
  isTyping: boolean;
}

// Set user presence status
export const setPresence = onCall(async (request) => {
  const { data, auth } = request;
  const { status } = data as SetPresenceData;

  if (!auth?.uid) {
    throw new Error("Authentication required");
  }

  if (!['online', 'away', 'dnd', 'offline'].includes(status)) {
    throw new Error("Invalid presence status");
  }

  try {
    const presenceRef = db.collection("presence").doc(auth.uid);
    
    const presenceData = {
      status,
      lastActiveAt: admin.firestore.FieldValue.serverTimestamp()
    };

    await presenceRef.set(presenceData, { merge: true });

    // Track analytics for significant status changes
    if (status === 'online' || status === 'offline') {
      await analytics.track("presence_changed", {
        userId: auth.uid,
        status,
        timestamp: Date.now()
      });
    }

    logger.info(`Presence updated for ${auth.uid}: ${status}`);

    return { success: true };

  } catch (error: any) {
    logger.error("Error setting presence", { 
      error: error.message, 
      userId: auth.uid, 
      status 
    });
    throw new Error(error.message || "Failed to set presence");
  }
});

// Set typing indicator
export const setTyping = onCall(async (request) => {
  const { data, auth } = request;
  const { conversationId, isTyping } = data as SetTypingData;

  if (!auth?.uid) {
    throw new Error("Authentication required");
  }

  if (!conversationId) {
    throw new Error("Conversation ID required");
  }

  try {
    // Verify user is participant in conversation
    const conversationRef = db.collection("conversations").doc(conversationId);
    const conversation = await conversationRef.get();

    if (!conversation.exists) {
      throw new Error("Conversation not found");
    }

    const conversationData = conversation.data()!;
    if (!conversationData.participants.includes(auth.uid)) {
      throw new Error("Not a participant in this conversation");
    }

    const typingRef = db.collection("typing").doc(conversationId).collection("users").doc(auth.uid);

    if (isTyping) {
      // Set typing indicator with TTL
      await typingRef.set({
        isTyping: true,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        // Set TTL for auto-cleanup (typing indicators should be short-lived)
        expiresAt: new Date(Date.now() + 30 * 1000) // 30 seconds
      });
    } else {
      // Remove typing indicator
      await typingRef.delete();
    }

    return { success: true };

  } catch (error: any) {
    logger.error("Error setting typing indicator", { 
      error: error.message, 
      userId: auth.uid, 
      conversationId, 
      isTyping 
    });
    throw new Error(error.message || "Failed to set typing indicator");
  }
});

// Get friends presence (batch)
export const getFriendsPresence = onCall(async (request) => {
  const { data, auth } = request;
  const { friendIds } = data;

  if (!auth?.uid) {
    throw new Error("Authentication required");
  }

  if (!friendIds || !Array.isArray(friendIds) || friendIds.length === 0) {
    throw new Error("Friend IDs required");
  }

  // Limit batch size
  if (friendIds.length > 100) {
    throw new Error("Too many friend IDs (max 100)");
  }

  try {
    // Verify friendships (sample check for security)
    // In production, you might want to verify all friendships
    const presencePromises = friendIds.slice(0, 10).map(async (friendId: string) => {
      const friendshipId = auth.uid < friendId ? `${auth.uid}_${friendId}` : `${friendId}_${auth.uid}`;
      const friendship = await db.collection("friendships").doc(friendshipId).get();
      
      if (!friendship.exists || friendship.data()?.status !== 'accepted') {
        return null;
      }

      const presence = await db.collection("presence").doc(friendId).get();
      return {
        userId: friendId,
        ...(presence.exists ? presence.data() : { status: 'offline', lastActiveAt: null })
      };
    });

    const presenceResults = await Promise.all(presencePromises);
    const validPresence = presenceResults.filter(p => p !== null);

    return { presence: validPresence };

  } catch (error: any) {
    logger.error("Error getting friends presence", { 
      error: error.message, 
      userId: auth.uid, 
      friendCount: friendIds.length 
    });
    throw new Error(error.message || "Failed to get friends presence");
  }
});

// Cleanup expired typing indicators (scheduled function)
export const cleanupTypingIndicators = async () => {
  try {
    const now = new Date();
    const expiredQuery = db.collectionGroup("users")
      .where("expiresAt", "<=", now)
      .limit(100);

    const expired = await expiredQuery.get();
    
    if (expired.empty) {
      return;
    }

    const batch = db.batch();
    expired.docs.forEach(doc => {
      batch.delete(doc.ref);
    });

    await batch.commit();

    logger.info(`Cleaned up ${expired.size} expired typing indicators`);

  } catch (error: any) {
    logger.error("Error cleaning up typing indicators", { error: error.message });
  }
};

// Update presence based on activity (called by client heartbeat)
export const updatePresenceActivity = onCall(async (request) => {
  const { auth } = request;

  if (!auth?.uid) {
    throw new Error("Authentication required");
  }

  try {
    const presenceRef = db.collection("presence").doc(auth.uid);
    
    await presenceRef.update({
      lastActiveAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: true };

  } catch (error: any) {
    // Don't log errors for this frequent operation unless it's critical
    if (error.message !== "No document to update") {
      logger.error("Error updating presence activity", { 
        error: error.message, 
        userId: auth.uid 
      });
    }
    throw new Error(error.message || "Failed to update presence activity");
  }
});