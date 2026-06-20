import * as admin from "firebase-admin";
import { onCall } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { analytics } from "../shared/analytics";

const db = admin.firestore();

interface CreateWatchPartyData {
  conversationId: string;
  mediaURL?: string;
  title?: string;
}

interface JoinWatchPartyData {
  conversationId: string;
}

interface UpdatePlaybackData {
  conversationId: string;
  action: 'play' | 'pause' | 'seek';
  positionMs?: number;
}

// Create watch party
export const createWatchParty = onCall(async (request) => {
  const { data, auth } = request;
  const { conversationId, mediaURL, title } = data as CreateWatchPartyData;

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

    // Generate LiveKit room name
    const roomName = `friends_${conversationId}`;

    // Create or update watch party document
    const watchPartyData = {
      conversationId,
      roomName,
      createdBy: auth.uid,
      participants: [auth.uid],
      playback: {
        state: 'paused',
        positionMs: 0,
        mediaURL: mediaURL || null,
        title: title || null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: auth.uid
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    const watchPartyRef = db.collection("watchParties").doc(conversationId);
    await watchPartyRef.set(watchPartyData);

    // Add system message to conversation
    const systemMessage = {
      senderId: 'system',
      type: 'system',
      content: `${auth.uid} started a watch party${title ? ` - "${title}"` : ''}`,
      action: {
        kind: 'watch_party',
        refId: conversationId,
        refKind: 'watchParty',
        meta: { roomName, mediaURL, title }
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };

    await conversationRef.collection('messages').add(systemMessage);

    // Track analytics
    await analytics.track("watch_party_created", {
      userId: auth.uid,
      conversationId,
      roomName,
      hasMediaURL: !!mediaURL,
      participantCount: conversationData.participants.length
    });

    logger.info(`Watch party created: ${conversationId} by ${auth.uid}`);

    return {
      roomName,
      watchPartyId: conversationId,
      success: true
    };

  } catch (error: any) {
    logger.error("Error creating watch party", { 
      error: error.message, 
      userId: auth.uid, 
      conversationId 
    });
    throw new Error(error.message || "Failed to create watch party");
  }
});

// Join watch party
export const joinWatchParty = onCall(async (request) => {
  const { data, auth } = request;
  const { conversationId } = data as JoinWatchPartyData;

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

    // Get or create watch party
    const watchPartyRef = db.collection("watchParties").doc(conversationId);
    const watchParty = await watchPartyRef.get();

    if (!watchParty.exists) {
      throw new Error("Watch party not found");
    }

    const watchPartyData = watchParty.data()!;

    // Add user to participants if not already there
    if (!watchPartyData.participants.includes(auth.uid)) {
      await watchPartyRef.update({
        participants: admin.firestore.FieldValue.arrayUnion(auth.uid),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    // Track analytics
    await analytics.track("watch_party_joined", {
      userId: auth.uid,
      conversationId,
      roomName: watchPartyData.roomName
    });

    logger.info(`User joined watch party: ${auth.uid} joined ${conversationId}`);

    return {
      roomName: watchPartyData.roomName,
      playback: watchPartyData.playback,
      participants: watchPartyData.participants,
      success: true
    };

  } catch (error: any) {
    logger.error("Error joining watch party", { 
      error: error.message, 
      userId: auth.uid, 
      conversationId 
    });
    throw new Error(error.message || "Failed to join watch party");
  }
});

// Leave watch party
export const leaveWatchParty = onCall(async (request) => {
  const { data, auth } = request;
  const { conversationId } = data;

  if (!auth?.uid) {
    throw new Error("Authentication required");
  }

  if (!conversationId) {
    throw new Error("Conversation ID required");
  }

  try {
    const watchPartyRef = db.collection("watchParties").doc(conversationId);
    const watchParty = await watchPartyRef.get();

    if (!watchParty.exists) {
      return { success: true }; // Already not in party
    }

    const watchPartyData = watchParty.data()!;

    // Remove user from participants
    await watchPartyRef.update({
      participants: admin.firestore.FieldValue.arrayRemove(auth.uid),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // If no participants left, clean up the watch party
    const updatedParty = await watchPartyRef.get();
    const updatedData = updatedParty.data()!;
    
    if (updatedData.participants.length === 0) {
      await watchPartyRef.delete();
      
      // Add system message about party ending
      const conversationRef = db.collection("conversations").doc(conversationId);
      const endMessage = {
        senderId: 'system',
        type: 'system',
        content: 'Watch party ended',
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      };
      await conversationRef.collection('messages').add(endMessage);
    }

    // Track analytics
    await analytics.track("watch_party_left", {
      userId: auth.uid,
      conversationId,
      remainingParticipants: Math.max(0, updatedData.participants.length)
    });

    logger.info(`User left watch party: ${auth.uid} left ${conversationId}`);

    return { success: true };

  } catch (error: any) {
    logger.error("Error leaving watch party", { 
      error: error.message, 
      userId: auth.uid, 
      conversationId 
    });
    throw new Error(error.message || "Failed to leave watch party");
  }
});

// Update playback state (for synchronized watching)
export const updatePlayback = onCall(async (request) => {
  const { data, auth } = request;
  const { conversationId, action, positionMs } = data as UpdatePlaybackData;

  if (!auth?.uid) {
    throw new Error("Authentication required");
  }

  if (!conversationId || !action) {
    throw new Error("Missing required fields");
  }

  if (!['play', 'pause', 'seek'].includes(action)) {
    throw new Error("Invalid playback action");
  }

  if (action === 'seek' && typeof positionMs !== 'number') {
    throw new Error("Position required for seek action");
  }

  try {
    const watchPartyRef = db.collection("watchParties").doc(conversationId);
    const watchParty = await watchPartyRef.get();

    if (!watchParty.exists) {
      throw new Error("Watch party not found");
    }

    const watchPartyData = watchParty.data()!;

    // Verify user is a participant
    if (!watchPartyData.participants.includes(auth.uid)) {
      throw new Error("Not a participant in this watch party");
    }

    // Update playback state
    const playbackUpdate: any = {
      state: action === 'play' ? 'playing' : action === 'pause' ? 'paused' : watchPartyData.playback.state,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: auth.uid
    };

    if (action === 'seek' && positionMs !== undefined) {
      playbackUpdate.positionMs = positionMs;
    } else if (action === 'play') {
      // When resuming, maintain current position or start from where it was paused
      playbackUpdate.positionMs = watchPartyData.playback.positionMs || 0;
    }

    await watchPartyRef.update({
      'playback': {
        ...watchPartyData.playback,
        ...playbackUpdate
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Note: In a real implementation, you would also send this update via LiveKit data tracks
    // to synchronize playback across all participants in real-time

    // Track analytics
    await analytics.track("playback_updated", {
      userId: auth.uid,
      conversationId,
      action,
      positionMs: playbackUpdate.positionMs
    });

    return { success: true };

  } catch (error: any) {
    logger.error("Error updating playback", { 
      error: error.message, 
      userId: auth.uid, 
      conversationId, 
      action 
    });
    throw new Error(error.message || "Failed to update playback");
  }
});

// Get watch party info
export const getWatchParty = onCall(async (request) => {
  const { data, auth } = request;
  const { conversationId } = data;

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

    const watchPartyRef = db.collection("watchParties").doc(conversationId);
    const watchParty = await watchPartyRef.get();

    if (!watchParty.exists) {
      return { exists: false };
    }

    const watchPartyData = watchParty.data()!;

    return {
      exists: true,
      roomName: watchPartyData.roomName,
      playback: watchPartyData.playback,
      participants: watchPartyData.participants,
      createdBy: watchPartyData.createdBy,
      createdAt: watchPartyData.createdAt
    };

  } catch (error: any) {
    logger.error("Error getting watch party", { 
      error: error.message, 
      userId: auth.uid, 
      conversationId 
    });
    throw new Error(error.message || "Failed to get watch party");
  }
});