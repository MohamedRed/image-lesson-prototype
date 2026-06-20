import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { withMetrics } from "../shared/metrics";

try { admin.app(); } catch { admin.initializeApp(); }

const db = admin.firestore();

/**
 * Send a message in a contract or RFQ conversation (HTTP)
 * POST /home/messages
 */
export const sendMessageHttp = withMetrics("sendMessageHttp",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { conversationId, conversationType, text, attachments } = req.body;
      
      if (!conversationId || !conversationType || !text) {
        res.status(400).json({ error: "Conversation ID, type, and text are required" });
        return;
      }

      // Validate conversation access
      const hasAccess = await validateConversationAccess(userId, conversationId, conversationType);
      if (!hasAccess) {
        res.status(403).json({ error: "Access denied to this conversation" });
        return;
      }

      // Redact PII from message text
      const redactedText = redactPII(text);
      
      const messageData = {
        conversationId,
        conversationType, // 'rfq' or 'contract'
        senderId: userId,
        text: redactedText,
        originalText: text !== redactedText ? text : null, // Store original if redacted
        attachments: attachments || [],
        type: 'chat',
        piiRedacted: text !== redactedText,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        readBy: [userId] // Sender automatically reads their own message
      };

      const messageRef = await db.collection('messages').add(messageData);

      // Update conversation metadata
      await updateConversationMetadata(conversationId, conversationType, messageData);

      logger.info("Message sent", { 
        messageId: messageRef.id,
        conversationId, 
        conversationType,
        senderId: userId,
        piiRedacted: messageData.piiRedacted
      });

      res.json({ 
        messageId: messageRef.id,
        text: redactedText,
        piiRedacted: messageData.piiRedacted
      });
    } catch (error: any) {
      logger.error("Failed to send message", { error: error.message });
      res.status(500).json({ error: "Failed to send message" });
    }
  })
);

/**
 * Get messages for a conversation
 * GET /home/messages?conversationId=:id&type=:type
 */
export const getMessagesHttp = withMetrics("getMessagesHttp",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { conversationId, type, limit = 50, lastMessageId } = req.query;
      
      if (!conversationId || !type) {
        res.status(400).json({ error: "Conversation ID and type are required" });
        return;
      }

      // Validate conversation access
      const hasAccess = await validateConversationAccess(userId, conversationId as string, type as string);
      if (!hasAccess) {
        res.status(403).json({ error: "Access denied to this conversation" });
        return;
      }

      let query = db.collection('messages')
        .where('conversationId', '==', conversationId)
        .where('conversationType', '==', type)
        .orderBy('createdAt', 'desc')
        .limit(Number(limit));

      // Pagination support
      if (lastMessageId) {
        const lastMessageDoc = await db.collection('messages').doc(lastMessageId as string).get();
        if (lastMessageDoc.exists) {
          query = query.startAfter(lastMessageDoc);
        }
      }

      const snapshot = await query.get();
      const messages = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));

      // Mark messages as read by current user
      const unreadMessages = messages.filter(msg => 
        msg.senderId !== userId && !msg.readBy?.includes(userId)
      );

      if (unreadMessages.length > 0) {
        const batch = db.batch();
        unreadMessages.forEach(msg => {
          batch.update(db.collection('messages').doc(msg.id), {
            readBy: admin.firestore.FieldValue.arrayUnion(userId)
          });
        });
        await batch.commit();
      }

      res.json({ 
        messages: messages.reverse(), // Return in chronological order
        hasMore: snapshot.size === Number(limit)
      });
    } catch (error: any) {
      logger.error("Failed to get messages", { error: error.message });
      res.status(500).json({ error: "Failed to get messages" });
    }
  })
);

/**
 * Send a counter-offer message (special message type)
 * POST /home/messages/counter
 */
export const sendCounterOfferHttp = withMetrics("sendCounterOfferHttp",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { bidId, newAmountMAD, newTimelineDays, message } = req.body;
      
      if (!bidId || newAmountMAD == null) {
        res.status(400).json({ error: "Bid ID and new amount are required" });
        return;
      }

      // Validate bid access and current state
      const bidDoc = await db.collection('bids').doc(bidId).get();
      if (!bidDoc.exists) {
        res.status(404).json({ error: "Bid not found" });
        return;
      }

      const bidData = bidDoc.data()!;
      
      // Check if user has access to this bid
      const isCustomer = bidData.customerId === userId;
      const isProfessional = bidData.proId === userId;
      
      if (!isCustomer && !isProfessional) {
        res.status(403).json({ error: "Access denied" });
        return;
      }

      const counterOfferData = {
        conversationId: bidData.rfqId,
        conversationType: 'rfq',
        senderId: userId,
        text: `Counter-offer: ${newAmountMAD} MAD${newTimelineDays ? `, ${newTimelineDays} days` : ''}${message ? `\n${message}` : ''}`,
        type: 'counter',
        counterDetails: {
          bidId,
          amountMAD: Number(newAmountMAD),
          timelineDays: newTimelineDays || null,
          message: message || null,
          round: (bidData.negotiationRound || 0) + 1,
          from: isCustomer ? 'customer' : 'professional'
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        readBy: [userId]
      };

      const messageRef = await db.collection('messages').add(counterOfferData);

      logger.info("Counter-offer message sent", { 
        messageId: messageRef.id,
        bidId, 
        amount: newAmountMAD,
        from: isCustomer ? 'customer' : 'professional'
      });

      res.json({ 
        messageId: messageRef.id,
        counterDetails: counterOfferData.counterDetails
      });
    } catch (error: any) {
      logger.error("Failed to send counter-offer message", { error: error.message });
      res.status(500).json({ error: "Failed to send counter-offer message" });
    }
  })
);

/**
 * Get unread message count for a user
 * GET /home/messages/unread-count
 */
export const getUnreadCountHttp = withMetrics("getUnreadCountHttp",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      // Get user's RFQs and contracts to find their conversations
      const [rfqsSnapshot, contractsSnapshot] = await Promise.all([
        db.collection('rfqs').where('customerId', '==', userId).get(),
        db.collection('contracts')
          .where('customerId', '==', userId)
          .get()
      ]);

      const [proContractsSnapshot] = await Promise.all([
        db.collection('contracts')
          .where('proId', '==', userId)
          .get()
      ]);

      const conversationIds = new Set<string>();
      
      // Add RFQ conversations
      rfqsSnapshot.docs.forEach(doc => conversationIds.add(doc.id));
      
      // Add contract conversations
      contractsSnapshot.docs.forEach(doc => conversationIds.add(doc.id));
      proContractsSnapshot.docs.forEach(doc => conversationIds.add(doc.id));

      if (conversationIds.size === 0) {
        res.json({ unreadCount: 0 });
        return;
      }

      // Count unread messages across all conversations
      const unreadQuery = db.collection('messages')
        .where('conversationId', 'in', Array.from(conversationIds))
        .where('senderId', '!=', userId);

      const unreadSnapshot = await unreadQuery.get();
      
      let unreadCount = 0;
      unreadSnapshot.docs.forEach(doc => {
        const data = doc.data();
        if (!data.readBy?.includes(userId)) {
          unreadCount++;
        }
      });

      res.json({ unreadCount });
    } catch (error: any) {
      logger.error("Failed to get unread count", { error: error.message });
      res.status(500).json({ error: "Failed to get unread count" });
    }
  })
);

// Helper Functions

async function validateConversationAccess(userId: string, conversationId: string, conversationType: string): Promise<boolean> {
  try {
    if (conversationType === 'rfq') {
      // Check if user is the RFQ owner or has bid on it
      const rfqDoc = await db.collection('rfqs').doc(conversationId).get();
      if (!rfqDoc.exists) return false;
      
      const rfqData = rfqDoc.data()!;
      if (rfqData.customerId === userId) return true;
      
      // Check if user has a bid on this RFQ
      const bidQuery = await db.collection('bids')
        .where('rfqId', '==', conversationId)
        .where('proId', '==', userId)
        .limit(1)
        .get();
      
      return !bidQuery.empty;
      
    } else if (conversationType === 'contract') {
      // Check if user is customer or professional in the contract
      const contractDoc = await db.collection('contracts').doc(conversationId).get();
      if (!contractDoc.exists) return false;
      
      const contractData = contractDoc.data()!;
      return contractData.customerId === userId || contractData.proId === userId;
    }
    
    return false;
  } catch (error) {
    logger.error("Error validating conversation access", { error, userId, conversationId, conversationType });
    return false;
  }
}

function redactPII(text: string): string {
  let redactedText = text;
  
  // Redact phone numbers (Moroccan format)
  redactedText = redactedText.replace(
    /(\+212|0)[5-7]\d{8}/g, 
    '[PHONE_REDACTED]'
  );
  
  // Redact international phone numbers
  redactedText = redactedText.replace(
    /\+\d{1,3}[-.\s]?\d{6,14}/g,
    '[PHONE_REDACTED]'
  );
  
  // Redact email addresses
  redactedText = redactedText.replace(
    /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g,
    '[EMAIL_REDACTED]'
  );
  
  // Redact URLs
  redactedText = redactedText.replace(
    /https?:\/\/[^\s]+/g,
    '[LINK_REDACTED]'
  );
  
  // Redact WhatsApp references
  redactedText = redactedText.replace(
    /whatsapp|wa\.me/gi,
    '[WHATSAPP_REDACTED]'
  );
  
  return redactedText;
}

async function updateConversationMetadata(conversationId: string, conversationType: string, messageData: any) {
  try {
    const metadataCollection = conversationType === 'rfq' ? 'rfqs' : 'contracts';
    
    await db.collection(metadataCollection).doc(conversationId).update({
      lastMessageAt: messageData.createdAt,
      lastMessageFrom: messageData.senderId,
      lastMessagePreview: messageData.text.substring(0, 100),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  } catch (error) {
    logger.warn("Failed to update conversation metadata", { error, conversationId, conversationType });
  }
}