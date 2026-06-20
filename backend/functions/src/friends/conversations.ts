import * as admin from "firebase-admin";
import { onCall } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { analytics } from "../shared/analytics";

const db = admin.firestore();

interface OpenConversationData {
  userIds: string[];
  type?: 'direct' | 'group';
  title?: string;
}

interface CreateGroupData {
  userIds: string[];
  title: string;
}

interface UpdateGroupData {
  conversationId: string;
  title?: string;
  addParticipants?: string[];
  removeParticipants?: string[];
}

// Helper to generate conversation ID for direct chats
function getDirectConversationId(uid1: string, uid2: string): string {
  return uid1 < uid2 ? `direct_${uid1}_${uid2}` : `direct_${uid2}_${uid1}`;
}

// Helper to verify friendship for direct conversations
async function verifyFriendship(uid1: string, uid2: string): Promise<boolean> {
  const friendshipId = uid1 < uid2 ? `${uid1}_${uid2}` : `${uid2}_${uid1}`;
  const friendship = await db.collection("friendships").doc(friendshipId).get();
  return friendship.exists && friendship.data()?.status === "accepted";
}

// Open or create conversation
export const openConversation = onCall(async (request) => {
  const { data, auth } = request;
  const { userIds, type = 'direct', title } = data as OpenConversationData;

  if (!auth?.uid) {
    throw new Error("Authentication required");
  }

  // Include the requesting user in participants
  const allParticipants = Array.from(new Set([auth.uid, ...userIds]));

  if (allParticipants.length < 2) {
    throw new Error("At least 2 participants required");
  }

  try {
    let conversationRef: admin.firestore.DocumentReference;
    let conversationId: string;

    if (type === 'direct' && allParticipants.length === 2) {
      // Direct conversation
      const otherUserId = allParticipants.find(id => id !== auth.uid)!;
      
      // Verify friendship for direct chats
      const areFriends = await verifyFriendship(auth.uid, otherUserId);
      if (!areFriends) {
        throw new Error("Can only start direct conversations with friends");
      }

      conversationId = getDirectConversationId(auth.uid, otherUserId);
      conversationRef = db.collection("conversations").doc(conversationId);

      // Check if conversation already exists
      const existingConvo = await conversationRef.get();
      if (existingConvo.exists) {
        return { 
          conversationId, 
          conversation: existingConvo.data(),
          created: false 
        };
      }

      // Create new direct conversation
      const conversationData = {
        type: 'direct',
        participants: allParticipants.sort(),
        admins: allParticipants.sort(), // Both are admins in direct chat
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastMessageAt: null,
        unreadCount: allParticipants.reduce((acc, uid) => ({ ...acc, [uid]: 0 }), {})
      };

      await conversationRef.set(conversationData);

      // Track analytics
      await analytics.track("direct_conversation_created", {
        userId: auth.uid,
        participants: allParticipants,
        conversationId
      });

      return { 
        conversationId, 
        conversation: conversationData,
        created: true 
      };

    } else {
      // Group conversation
      if (!title || title.trim().length === 0) {
        throw new Error("Group title required");
      }

      conversationRef = db.collection("conversations").doc();
      conversationId = conversationRef.id;

      const conversationData = {
        type: 'group',
        participants: allParticipants.sort(),
        admins: [auth.uid], // Creator is admin
        title: title.trim(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastMessageAt: null,
        unreadCount: allParticipants.reduce((acc, uid) => ({ ...acc, [uid]: 0 }), {})
      };

      await conversationRef.set(conversationData);

      // Create system message for group creation
      const systemMessage = {
        senderId: 'system',
        type: 'system',
        content: `${auth.uid} created the group "${title}"`,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      };

      await conversationRef.collection('messages').add(systemMessage);

      // Track analytics
      await analytics.track("group_conversation_created", {
        userId: auth.uid,
        participants: allParticipants,
        conversationId,
        participantCount: allParticipants.length
      });

      return { 
        conversationId, 
        conversation: conversationData,
        created: true 
      };
    }

  } catch (error: any) {
    logger.error("Error opening conversation", { 
      error: error.message, 
      userId: auth.uid, 
      userIds, 
      type 
    });
    throw new Error(error.message || "Failed to open conversation");
  }
});

// Update group conversation
export const updateGroup = onCall(async (request) => {
  const { data, auth } = request;
  const { conversationId, title, addParticipants = [], removeParticipants = [] } = data as UpdateGroupData;

  if (!auth?.uid) {
    throw new Error("Authentication required");
  }

  try {
    const conversationRef = db.collection("conversations").doc(conversationId);
    const conversation = await conversationRef.get();

    if (!conversation.exists) {
      throw new Error("Conversation not found");
    }

    const conversationData = conversation.data()!;

    // Verify user is a participant
    if (!conversationData.participants.includes(auth.uid)) {
      throw new Error("Not a participant in this conversation");
    }

    // Verify user is an admin for admin actions
    const isAdmin = conversationData.admins.includes(auth.uid);
    if ((addParticipants.length > 0 || removeParticipants.length > 0) && !isAdmin) {
      throw new Error("Only admins can manage participants");
    }

    const batch = db.batch();
    const updates: any = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    // Update title if provided
    if (title !== undefined && title.trim().length > 0) {
      updates.title = title.trim();
      
      // Add system message for title change
      const titleMessage = {
        senderId: 'system',
        type: 'system',
        content: `${auth.uid} changed the group name to "${title.trim()}"`,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      };
      const messageRef = conversationRef.collection('messages').doc();
      batch.set(messageRef, titleMessage);
    }

    // Add participants
    if (addParticipants.length > 0) {
      const newParticipants = [...conversationData.participants, ...addParticipants];
      updates.participants = Array.from(new Set(newParticipants)).sort();
      
      // Initialize unread count for new participants
      addParticipants.forEach(uid => {
        updates[`unreadCount.${uid}`] = 0;
      });

      // Add system message for participants added
      const addMessage = {
        senderId: 'system',
        type: 'system',
        content: `${auth.uid} added ${addParticipants.length} participant(s) to the group`,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      };
      const messageRef = conversationRef.collection('messages').doc();
      batch.set(messageRef, addMessage);
    }

    // Remove participants
    if (removeParticipants.length > 0) {
      const remainingParticipants = conversationData.participants.filter(
        (uid: string) => !removeParticipants.includes(uid)
      );
      updates.participants = remainingParticipants;

      // Remove from admins if they were admins
      const remainingAdmins = conversationData.admins.filter(
        (uid: string) => !removeParticipants.includes(uid)
      );
      updates.admins = remainingAdmins;

      // Remove unread count fields
      removeParticipants.forEach(uid => {
        updates[`unreadCount.${uid}`] = admin.firestore.FieldValue.delete();
      });

      // Add system message for participants removed
      const removeMessage = {
        senderId: 'system',
        type: 'system',
        content: `${auth.uid} removed ${removeParticipants.length} participant(s) from the group`,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      };
      const messageRef = conversationRef.collection('messages').doc();
      batch.set(messageRef, removeMessage);
    }

    batch.update(conversationRef, updates);
    await batch.commit();

    // Track analytics
    await analytics.track("group_conversation_updated", {
      userId: auth.uid,
      conversationId,
      titleChanged: title !== undefined,
      participantsAdded: addParticipants.length,
      participantsRemoved: removeParticipants.length
    });

    logger.info(`Group conversation updated: ${conversationId}`);

    return { success: true };

  } catch (error: any) {
    logger.error("Error updating group", { 
      error: error.message, 
      userId: auth.uid, 
      conversationId 
    });
    throw new Error(error.message || "Failed to update group");
  }
});

// Leave conversation
export const leaveConversation = onCall(async (request) => {
  const { data, auth } = request;
  const { conversationId } = data;

  if (!auth?.uid) {
    throw new Error("Authentication required");
  }

  try {
    const conversationRef = db.collection("conversations").doc(conversationId);
    const conversation = await conversationRef.get();

    if (!conversation.exists) {
      throw new Error("Conversation not found");
    }

    const conversationData = conversation.data()!;

    // Verify user is a participant
    if (!conversationData.participants.includes(auth.uid)) {
      throw new Error("Not a participant in this conversation");
    }

    // Can't leave direct conversations
    if (conversationData.type === 'direct') {
      throw new Error("Cannot leave direct conversations");
    }

    const batch = db.batch();
    
    // Remove from participants and admins
    const remainingParticipants = conversationData.participants.filter(
      (uid: string) => uid !== auth.uid
    );
    const remainingAdmins = conversationData.admins.filter(
      (uid: string) => uid !== auth.uid
    );

    const updates: any = {
      participants: remainingParticipants,
      admins: remainingAdmins,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      [`unreadCount.${auth.uid}`]: admin.firestore.FieldValue.delete()
    };

    batch.update(conversationRef, updates);

    // Add system message
    const leaveMessage = {
      senderId: 'system',
      type: 'system',
      content: `${auth.uid} left the group`,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };
    const messageRef = conversationRef.collection('messages').doc();
    batch.set(messageRef, leaveMessage);

    await batch.commit();

    // Track analytics
    await analytics.track("conversation_left", {
      userId: auth.uid,
      conversationId
    });

    logger.info(`User left conversation: ${auth.uid} left ${conversationId}`);

    return { success: true };

  } catch (error: any) {
    logger.error("Error leaving conversation", { 
      error: error.message, 
      userId: auth.uid, 
      conversationId 
    });
    throw new Error(error.message || "Failed to leave conversation");
  }
});