import * as admin from "firebase-admin";
import { onCall } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { analytics } from "../shared/analytics";

const db = admin.firestore();

interface SendMessageData {
  conversationId: string;
  type: 'text' | 'image' | 'voice' | 'location' | 'action';
  content: string;
  attachments?: Array<{
    url: string;
    thumbURL?: string;
    kind: 'image' | 'video' | 'audio' | 'document';
  }>;
  action?: {
    kind: string;
    refId: string;
    refKind: string;
    meta: any;
  };
}

interface UpdateMessageData {
  conversationId: string;
  messageId: string;
  content: string;
}

interface DeleteMessageData {
  conversationId: string;
  messageId: string;
}

// Content validation and sanitization
function sanitizeContent(content: string, type: string): string {
  if (type === 'text') {
    // Basic text sanitization
    return content.trim().slice(0, 4000); // Max message length
  }
  return content;
}

function validateAttachments(attachments: any[]): boolean {
  if (!attachments || attachments.length === 0) return true;
  
  // Max 10 attachments per message
  if (attachments.length > 10) return false;
  
  for (const attachment of attachments) {
    if (!attachment.url || !attachment.kind) return false;
    if (!['image', 'video', 'audio', 'document'].includes(attachment.kind)) return false;
  }
  
  return true;
}

// Rate limiting check (simplified)
async function checkRateLimit(userId: string, conversationId: string): Promise<boolean> {
  // Check if user has sent more than 100 messages in last minute
  const oneMinuteAgo = new Date(Date.now() - 60 * 1000);
  
  const recentMessages = await db
    .collection("conversations")
    .doc(conversationId)
    .collection("messages")
    .where("senderId", "==", userId)
    .where("createdAt", ">=", oneMinuteAgo)
    .get();
  
  return recentMessages.size < 100;
}

// Send message
export const sendMessage = onCall(async (request) => {
  const { data, auth } = request;
  const { conversationId, type, content, attachments = [], action } = data as SendMessageData;

  if (!auth?.uid) {
    throw new Error("Authentication required");
  }

  if (!conversationId || !type || (!content && !attachments.length && !action)) {
    throw new Error("Missing required fields");
  }

  try {
    // Get conversation and verify participation
    const conversationRef = db.collection("conversations").doc(conversationId);
    const conversation = await conversationRef.get();

    if (!conversation.exists) {
      throw new Error("Conversation not found");
    }

    const conversationData = conversation.data()!;
    if (!conversationData.participants.includes(auth.uid)) {
      throw new Error("Not a participant in this conversation");
    }

    // Rate limiting
    const withinRateLimit = await checkRateLimit(auth.uid, conversationId);
    if (!withinRateLimit) {
      throw new Error("Rate limit exceeded");
    }

    // Validate content
    const sanitizedContent = sanitizeContent(content, type);
    if (!validateAttachments(attachments)) {
      throw new Error("Invalid attachments");
    }

    // Create message document
    const messageData: any = {
      senderId: auth.uid,
      type,
      content: sanitizedContent,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };

    if (attachments.length > 0) {
      messageData.attachments = attachments;
    }

    if (action) {
      messageData.action = action;
    }

    const batch = db.batch();

    // Add message
    const messageRef = conversationRef.collection('messages').doc();
    batch.set(messageRef, messageData);

    // Update conversation metadata
    const conversationUpdates: any = {
      lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    // Increment unread count for all participants except sender
    conversationData.participants.forEach((participantId: string) => {
      if (participantId !== auth.uid) {
        conversationUpdates[`unreadCount.${participantId}`] = admin.firestore.FieldValue.increment(1);
      }
    });

    batch.update(conversationRef, conversationUpdates);

    await batch.commit();

    // Send push notifications to participants (excluding sender)
    const otherParticipants = conversationData.participants.filter((uid: string) => uid !== auth.uid);
    
    // TODO: Integrate with FCM service for push notifications
    // await sendMessageNotifications(otherParticipants, messageData, conversationData);

    // Track analytics
    await analytics.track("message_sent", {
      userId: auth.uid,
      conversationId,
      messageType: type,
      hasAttachments: attachments.length > 0,
      hasAction: !!action,
      participantCount: conversationData.participants.length
    });

    logger.info(`Message sent in conversation ${conversationId} by ${auth.uid}`);

    return { 
      messageId: messageRef.id,
      success: true 
    };

  } catch (error: any) {
    logger.error("Error sending message", { 
      error: error.message, 
      userId: auth.uid, 
      conversationId 
    });
    throw new Error(error.message || "Failed to send message");
  }
});

// Update message
export const updateMessage = onCall(async (request) => {
  const { data, auth } = request;
  const { conversationId, messageId, content } = data as UpdateMessageData;

  if (!auth?.uid) {
    throw new Error("Authentication required");
  }

  if (!conversationId || !messageId || !content) {
    throw new Error("Missing required fields");
  }

  try {
    const messageRef = db
      .collection("conversations")
      .doc(conversationId)
      .collection("messages")
      .doc(messageId);
    
    const message = await messageRef.get();

    if (!message.exists) {
      throw new Error("Message not found");
    }

    const messageData = message.data()!;

    // Verify sender owns the message
    if (messageData.senderId !== auth.uid) {
      throw new Error("Not authorized to edit this message");
    }

    // Can only edit text messages
    if (messageData.type !== 'text') {
      throw new Error("Can only edit text messages");
    }

    // Can only edit recent messages (within 15 minutes)
    const fifteenMinutesAgo = new Date(Date.now() - 15 * 60 * 1000);
    const messageTime = messageData.createdAt.toDate();
    
    if (messageTime < fifteenMinutesAgo) {
      throw new Error("Can only edit messages within 15 minutes");
    }

    const sanitizedContent = sanitizeContent(content, 'text');

    await messageRef.update({
      content: sanitizedContent,
      editedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Track analytics
    await analytics.track("message_edited", {
      userId: auth.uid,
      conversationId,
      messageId
    });

    logger.info(`Message edited: ${messageId} in ${conversationId}`);

    return { success: true };

  } catch (error: any) {
    logger.error("Error updating message", { 
      error: error.message, 
      userId: auth.uid, 
      conversationId, 
      messageId 
    });
    throw new Error(error.message || "Failed to update message");
  }
});

// Delete message
export const deleteMessage = onCall(async (request) => {
  const { data, auth } = request;
  const { conversationId, messageId } = data as DeleteMessageData;

  if (!auth?.uid) {
    throw new Error("Authentication required");
  }

  if (!conversationId || !messageId) {
    throw new Error("Missing required fields");
  }

  try {
    const messageRef = db
      .collection("conversations")
      .doc(conversationId)
      .collection("messages")
      .doc(messageId);
    
    const message = await messageRef.get();

    if (!message.exists) {
      throw new Error("Message not found");
    }

    const messageData = message.data()!;

    // Verify sender owns the message
    if (messageData.senderId !== auth.uid) {
      throw new Error("Not authorized to delete this message");
    }

    // Can only delete recent messages (within 1 hour)
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    const messageTime = messageData.createdAt.toDate();
    
    if (messageTime < oneHourAgo) {
      throw new Error("Can only delete messages within 1 hour");
    }

    // Soft delete - mark as deleted rather than removing
    await messageRef.update({
      deletedAt: admin.firestore.FieldValue.serverTimestamp(),
      content: "[Message deleted]"
    });

    // Track analytics
    await analytics.track("message_deleted", {
      userId: auth.uid,
      conversationId,
      messageId
    });

    logger.info(`Message deleted: ${messageId} in ${conversationId}`);

    return { success: true };

  } catch (error: any) {
    logger.error("Error deleting message", { 
      error: error.message, 
      userId: auth.uid, 
      conversationId, 
      messageId 
    });
    throw new Error(error.message || "Failed to delete message");
  }
});

// Mark messages as read
export const markMessagesRead = onCall(async (request) => {
  const { data, auth } = request;
  const { conversationId } = data;

  if (!auth?.uid) {
    throw new Error("Authentication required");
  }

  if (!conversationId) {
    throw new Error("Conversation ID required");
  }

  try {
    const conversationRef = db.collection("conversations").doc(conversationId);
    const conversation = await conversationRef.get();

    if (!conversation.exists) {
      throw new Error("Conversation not found");
    }

    const conversationData = conversation.data()!;
    
    if (!conversationData.participants.includes(auth.uid)) {
      throw new Error("Not a participant in this conversation");
    }

    // Reset unread count for this user
    await conversationRef.update({
      [`unreadCount.${auth.uid}`]: 0
    });

    // Track analytics
    await analytics.track("messages_read", {
      userId: auth.uid,
      conversationId
    });

    return { success: true };

  } catch (error: any) {
    logger.error("Error marking messages as read", { 
      error: error.message, 
      userId: auth.uid, 
      conversationId 
    });
    throw new Error(error.message || "Failed to mark messages as read");
  }
});