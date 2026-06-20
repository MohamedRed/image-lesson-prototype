import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { trace } from '../shared/trace';
import { analytics } from '../shared/analytics';
import { fcmService } from '../services/notifications/fcmService';
import { templates } from '../services/notifications/templates';

const db = getFirestore();

interface MessageDraft {
  type: 'text' | 'image' | 'system';
  content: string;
  imageUrl?: string;
}

interface ConversationData {
  participants: string[];
  listingId: string;
  lastMessageAt: Date;
  unreadCount: { [userId: string]: number };
}

/**
 * Open a conversation between users about a listing
 * Per Section 11 - Messaging & Notifications
 */
export const openConversation = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.openConversation', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const { userId: otherUserId, listingId } = request.data;
      const currentUserId = request.auth.uid;

      if (!otherUserId || !listingId) {
        throw new HttpsError('invalid-argument', 'User ID and listing ID are required');
      }

      if (currentUserId === otherUserId) {
        throw new HttpsError('invalid-argument', 'Cannot start conversation with yourself');
      }

      try {
        // Check if listing exists and is active
        const listingDoc = await db.collection('listings').doc(listingId).get();
        if (!listingDoc.exists) {
          throw new HttpsError('not-found', 'Listing not found');
        }

        const listing = listingDoc.data();
        if (listing?.status !== 'active') {
          throw new HttpsError('failed-precondition', 'Cannot message about inactive listing');
        }

        // Check if conversation already exists
        const existingConversation = await findExistingConversation(currentUserId, otherUserId, listingId);
        if (existingConversation) {
          return existingConversation;
        }

        // Create new conversation
        const conversationRef = db.collection('conversations').doc();
        const conversationData: ConversationData = {
          participants: [currentUserId, otherUserId].sort(),
          listingId,
          lastMessageAt: new Date(),
          unreadCount: {
            [currentUserId]: 0,
            [otherUserId]: 0
          }
        };

        await conversationRef.set({
          ...conversationData,
          id: conversationRef.id,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp()
        });

        // Send initial system message
        await sendSystemMessage(conversationRef.id, 'Conversation started');

        // Analytics
        await analytics.track('marketplace_conversation_started', {
          initiatorId: currentUserId,
          participantId: otherUserId,
          listingId,
          conversationId: conversationRef.id
        });

        return {
          id: conversationRef.id,
          ...conversationData
        };

      } catch (error) {
        logger.error('Error opening conversation', { currentUserId, otherUserId, listingId, error });
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', 'Failed to open conversation');
      }
    });
  }
);

/**
 * Send a message in a conversation
 */
export const sendMessage = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.sendMessage', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const { conversationId, type, content, imageUrl } = request.data;
      const senderId = request.auth.uid;

      if (!conversationId || !type || !content) {
        throw new HttpsError('invalid-argument', 'Conversation ID, type, and content are required');
      }

      try {
        // Verify conversation exists and user is participant
        const conversationDoc = await db.collection('conversations').doc(conversationId).get();
        if (!conversationDoc.exists) {
          throw new HttpsError('not-found', 'Conversation not found');
        }

        const conversation = conversationDoc.data();
        if (!conversation?.participants.includes(senderId)) {
          throw new HttpsError('permission-denied', 'Not a participant in this conversation');
        }

        // Content moderation
        const moderationResult = await moderateMessageContent(content, type);
        if (!moderationResult.allowed) {
          throw new HttpsError('invalid-argument', `Message blocked: ${moderationResult.reason}`);
        }

        // Rate limiting check
        const canSend = await checkMessageRateLimit(senderId, conversationId);
        if (!canSend) {
          throw new HttpsError('resource-exhausted', 'Message rate limit exceeded');
        }

        // Create message
        const messageRef = db.collection('conversations').doc(conversationId).collection('messages').doc();
        const messageData = {
          id: messageRef.id,
          conversationId,
          senderId,
          type,
          content: moderationResult.filteredContent || content,
          imageUrl: imageUrl || null,
          createdAt: FieldValue.serverTimestamp(),
          edited: false,
          editedAt: null
        };

        await messageRef.set(messageData);

        // Update conversation
        const otherParticipant = conversation.participants.find((p: string) => p !== senderId);
        await db.collection('conversations').doc(conversationId).update({
          lastMessageAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          [`unreadCount.${otherParticipant}`]: FieldValue.increment(1)
        });

        // Analytics
        await analytics.track('marketplace_message_sent', {
          senderId,
          conversationId,
          messageType: type,
          messageLength: content.length,
          hasImage: !!imageUrl
        });

        return { success: true, messageId: messageRef.id };

      } catch (error) {
        logger.error('Error sending message', { senderId, conversationId, error });
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', 'Failed to send message');
      }
    });
  }
);

/**
 * Mark messages as read
 */
export const markMessagesRead = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.markMessagesRead', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const { conversationId } = request.data;
      const userId = request.auth.uid;

      if (!conversationId) {
        throw new HttpsError('invalid-argument', 'Conversation ID is required');
      }

      try {
        // Verify user is participant
        const conversationDoc = await db.collection('conversations').doc(conversationId).get();
        if (!conversationDoc.exists) {
          throw new HttpsError('not-found', 'Conversation not found');
        }

        const conversation = conversationDoc.data();
        if (!conversation?.participants.includes(userId)) {
          throw new HttpsError('permission-denied', 'Not a participant in this conversation');
        }

        // Reset unread count
        await db.collection('conversations').doc(conversationId).update({
          [`unreadCount.${userId}`]: 0,
          updatedAt: FieldValue.serverTimestamp()
        });

        return { success: true };

      } catch (error) {
        logger.error('Error marking messages read', { userId, conversationId, error });
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', 'Failed to mark messages as read');
      }
    });
  }
);

/**
 * Report a conversation or message
 */
export const reportConversation = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.reportConversation', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const { conversationId, messageId, reason, description } = request.data;
      const reporterId = request.auth.uid;

      if (!conversationId || !reason) {
        throw new HttpsError('invalid-argument', 'Conversation ID and reason are required');
      }

      try {
        // Create report
        const reportRef = db.collection('reports').doc();
        await reportRef.set({
          id: reportRef.id,
          type: 'conversation',
          reporterId,
          conversationId,
          messageId: messageId || null,
          reason,
          description: description || '',
          status: 'pending',
          createdAt: FieldValue.serverTimestamp(),
          reviewedAt: null,
          reviewedBy: null,
          resolution: null
        });

        // If severity is high, take immediate action
        if (reason === 'harassment' || reason === 'fraud') {
          await takeImmediateAction(conversationId, messageId, reason);
        }

        // Analytics
        await analytics.track('marketplace_conversation_reported', {
          reporterId,
          conversationId,
          reason,
          hasMessageId: !!messageId
        });

        return { success: true, reportId: reportRef.id };

      } catch (error) {
        logger.error('Error reporting conversation', { reporterId, conversationId, error });
        throw new HttpsError('internal', 'Failed to report conversation');
      }
    });
  }
);

/**
 * Trigger: Send notification when message is created
 */
export const onMessageCreated = onDocumentCreated(
  'conversations/{conversationId}/messages/{messageId}',
  async (event) => {
    const messageData = event.data?.data();
    const conversationId = event.params.conversationId;
    const messageId = event.params.messageId;

    if (!messageData) return;

    try {
      // Get conversation details
      const conversationDoc = await db.collection('conversations').doc(conversationId).get();
      if (!conversationDoc.exists) return;

      const conversation = conversationDoc.data();
      
      // Get listing details for context
      const listingDoc = await db.collection('listings').doc(conversation.listingId).get();
      const listing = listingDoc.data();

      // Find recipient (other participant)
      const recipientId = conversation.participants.find((p: string) => p !== messageData.senderId);
      if (!recipientId) return;

      // Get sender details
      const senderDoc = await db.collection('users').doc(messageData.senderId).get();
      const sender = senderDoc.data();

      // Get recipient's notification preferences
      const recipientDoc = await db.collection('users').doc(recipientId).get();
      const recipient = recipientDoc.data();

      // Skip if notifications disabled
      if (recipient?.notificationSettings?.messages === false) return;

      // Generate notification
      const notification = templates.generateMarketplaceMessageNotification({
        senderName: sender?.displayName || 'Someone',
        listingTitle: listing?.title || 'Item',
        messagePreview: messageData.content.substring(0, 50),
        conversationId,
        listingId: conversation.listingId
      });

      // Send push notification
      await fcmService.sendToUser(recipientId, notification);

      // Track notification sent
      await analytics.track('marketplace_message_notification_sent', {
        senderId: messageData.senderId,
        recipientId,
        conversationId,
        listingId: conversation.listingId
      });

    } catch (error) {
      logger.error('Error sending message notification', { conversationId, messageId, error });
    }
  }
);

// Helper functions

async function findExistingConversation(user1: string, user2: string, listingId: string) {
  const participants = [user1, user2].sort();
  
  const snapshot = await db.collection('conversations')
    .where('participants', '==', participants)
    .where('listingId', '==', listingId)
    .limit(1)
    .get();

  if (snapshot.empty) return null;

  const doc = snapshot.docs[0];
  return {
    id: doc.id,
    ...doc.data()
  };
}

async function sendSystemMessage(conversationId: string, content: string) {
  const messageRef = db.collection('conversations').doc(conversationId).collection('messages').doc();
  
  await messageRef.set({
    id: messageRef.id,
    conversationId,
    senderId: 'system',
    type: 'system',
    content,
    createdAt: FieldValue.serverTimestamp()
  });
}

async function moderateMessageContent(content: string, type: string) {
  // Anti-fraud filters per Section 11
  const forbiddenPatterns = [
    /whatsapp/i,
    /telegram/i,
    /paypal/i,
    /western\s+union/i,
    /bitcoin/i,
    /crypto/i,
    /send\s+money/i,
    /transfer\s+money/i,
    /bank\s+account/i,
    /credit\s+card/i,
    /\b\d{4}\s*\d{4}\s*\d{4}\s*\d{4}\b/, // Credit card pattern
    /\b\d{3}-\d{2}-\d{4}\b/, // SSN pattern
    /https?:\/\/(?!liive\.app)[^\s]+/i // External links
  ];

  const violations = forbiddenPatterns.filter(pattern => pattern.test(content));

  if (violations.length > 0) {
    return {
      allowed: false,
      reason: 'Contains forbidden content (external payment methods or links)',
      filteredContent: null
    };
  }

  // Content filtering for inappropriate language
  const inappropriateWords = ['scam', 'fake', 'stolen', 'illegal'];
  const hasInappropriate = inappropriateWords.some(word => 
    content.toLowerCase().includes(word)
  );

  if (hasInappropriate) {
    return {
      allowed: true,
      reason: 'Contains flagged words',
      filteredContent: content.replace(/\b(scam|fake|stolen|illegal)\b/gi, '[filtered]')
    };
  }

  return {
    allowed: true,
    reason: null,
    filteredContent: null
  };
}

async function checkMessageRateLimit(userId: string, conversationId: string): Promise<boolean> {
  // Check if user has sent too many messages recently
  const oneMinuteAgo = new Date(Date.now() - 60 * 1000);
  
  const recentMessages = await db.collection('conversations')
    .doc(conversationId)
    .collection('messages')
    .where('senderId', '==', userId)
    .where('createdAt', '>=', oneMinuteAgo)
    .get();

  const messageCount = recentMessages.size;
  const limit = 10; // Max 10 messages per minute

  return messageCount < limit;
}

async function takeImmediateAction(conversationId: string, messageId: string | null, reason: string) {
  // Take immediate action for severe violations
  switch (reason) {
    case 'harassment':
      // Temporarily restrict the conversation
      await db.collection('conversations').doc(conversationId).update({
        restricted: true,
        restrictedReason: 'harassment_report',
        restrictedAt: FieldValue.serverTimestamp()
      });
      break;
      
    case 'fraud':
      // Flag conversation for urgent review
      await db.collection('conversations').doc(conversationId).update({
        flagged: true,
        flaggedReason: 'fraud_report',
        flaggedAt: FieldValue.serverTimestamp(),
        urgentReview: true
      });
      break;
  }

  // If specific message reported, flag it
  if (messageId) {
    await db.collection('conversations')
      .doc(conversationId)
      .collection('messages')
      .doc(messageId)
      .update({
        flagged: true,
        flaggedReason: reason,
        flaggedAt: FieldValue.serverTimestamp()
      });
  }
}