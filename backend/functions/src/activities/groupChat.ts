import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { logger } from 'firebase-functions';
import { 
  ActivityGroup, 
  Booking
} from './models';
import { incrementCounter } from '../shared/metrics';

const db = admin.firestore();

// Create group chat when activity group is created
export const createActivityGroupChat = functions.firestore
  .document('groups/{groupId}')
  .onCreate(async (snap, context) => {
    const group = snap.data() as ActivityGroup;
    const groupId = context.params.groupId;

    try {
      // Create conversation for the activity group
      const conversationId = `activity_group_${groupId}`;
      const conversationData = {
        type: 'activity_group',
        title: group.name,
        participants: group.participantUserIds.sort(),
        admins: [group.organizerId], // Only organizer is admin initially
        activityGroupId: groupId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastMessageAt: null,
        unreadCount: group.participantUserIds.reduce((acc, uid) => ({ ...acc, [uid]: 0 }), {})
      };

      await db.collection('conversations').doc(conversationId).set(conversationData);

      // Update group with chat thread ID
      await snap.ref.update({
        chatThreadId: conversationId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Send welcome message
      await sendWelcomeMessage(conversationId, group);

      await incrementCounter('activities_group_chats_created', 1);

      logger.info('Activity group chat created', {
        groupId,
        conversationId,
        organizerId: group.organizerId,
        participantCount: group.participantUserIds.length
      });

    } catch (error) {
      logger.error('Error creating activity group chat:', error);
      // Don't throw - group creation should not fail due to chat issues
    }
  });

// Update group chat when group participants change
export const updateActivityGroupChat = functions.firestore
  .document('groups/{groupId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() as ActivityGroup;
    const after = change.after.data() as ActivityGroup;
    const groupId = context.params.groupId;

    if (!after.chatThreadId) return; // No chat created yet

    try {
      // Check for participant changes
      const beforeParticipants = new Set(before.participantUserIds || []);
      const afterParticipants = new Set(after.participantUserIds || []);
      
      const addedParticipants = Array.from(afterParticipants).filter(uid => !beforeParticipants.has(uid));
      const removedParticipants = Array.from(beforeParticipants).filter(uid => !afterParticipants.has(uid));

      if (addedParticipants.length === 0 && removedParticipants.length === 0 && before.name === after.name) {
        return; // No relevant changes
      }

      // Update conversation
      const updates: any = {
        participants: after.participantUserIds.sort(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      // Update title if changed
      if (before.name !== after.name) {
        updates.title = after.name;
      }

      // Update unread counts for new participants
      if (addedParticipants.length > 0) {
        const currentUnreadCount = before.participantUserIds.reduce((acc, uid) => ({ ...acc, [uid]: 0 }), {});
        updates.unreadCount = after.participantUserIds.reduce((acc, uid) => ({ 
          ...acc, 
          [uid]: currentUnreadCount[uid] || 0 
        }), {});
      }

      await db.collection('conversations').doc(after.chatThreadId).update(updates);

      // Send system messages for participant changes
      if (addedParticipants.length > 0) {
        await sendParticipantAddedMessage(after.chatThreadId, addedParticipants, after.organizerId);
      }

      if (removedParticipants.length > 0) {
        await sendParticipantRemovedMessage(after.chatThreadId, removedParticipants, after.organizerId);
      }

      logger.info('Activity group chat updated', {
        groupId,
        conversationId: after.chatThreadId,
        addedParticipants,
        removedParticipants,
        titleChanged: before.name !== after.name
      });

    } catch (error) {
      logger.error('Error updating activity group chat:', error);
    }
  });

// Send booking confirmation message to group chat
export const sendBookingConfirmationToChat = functions.firestore
  .document('bookings/{bookingId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() as Booking;
    const after = change.after.data() as Booking;

    // Only react to status changes to 'confirmed'
    if (before.status === after.status || after.status !== 'confirmed') {
      return;
    }

    try {
      // Get group and chat thread
      const groupDoc = await db.collection('groups').doc(after.groupId).get();
      if (!groupDoc.exists) return;

      const group = groupDoc.data() as ActivityGroup;
      if (!group.chatThreadId) return;

      // Get activity details
      const activityDoc = await db.collection('activities').doc(after.activityId).get();
      const activity = activityDoc.exists ? activityDoc.data() : null;

      // Get session details
      const sessionDoc = await db.collection('activitySessions').doc(after.sessionId).get();
      const session = sessionDoc.exists ? sessionDoc.data() : null;

      // Send confirmation message
      await sendBookingConfirmedMessage(
        group.chatThreadId, 
        after, 
        activity?.title || 'Activity',
        session
      );

      logger.info('Booking confirmation sent to group chat', {
        bookingId: after.id,
        groupId: after.groupId,
        conversationId: group.chatThreadId
      });

    } catch (error) {
      logger.error('Error sending booking confirmation to chat:', error);
    }
  });

// Get activity group chat
export const getActivityGroupChat = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { groupId } = data;

  if (!groupId) {
    throw new functions.https.HttpsError('invalid-argument', 'Group ID required');
  }

  try {
    // Verify user is in the group
    const groupDoc = await db.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Group not found');
    }

    const group = groupDoc.data() as ActivityGroup;
    if (!group.participantUserIds.includes(context.auth.uid)) {
      throw new functions.https.HttpsError('permission-denied', 'Not a group member');
    }

    if (!group.chatThreadId) {
      throw new functions.https.HttpsError('not-found', 'Group chat not found');
    }

    // Get conversation
    const conversationDoc = await db.collection('conversations').doc(group.chatThreadId).get();
    if (!conversationDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Conversation not found');
    }

    return {
      conversationId: group.chatThreadId,
      conversation: conversationDoc.data()
    };

  } catch (error) {
    logger.error('Error getting activity group chat:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to get group chat');
  }
});

// Send message to activity group chat
export const sendActivityGroupMessage = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { groupId, messageText, messageType = 'text' } = data;

  if (!groupId || !messageText) {
    throw new functions.https.HttpsError('invalid-argument', 'Group ID and message text required');
  }

  try {
    // Verify user is in the group
    const groupDoc = await db.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Group not found');
    }

    const group = groupDoc.data() as ActivityGroup;
    if (!group.participantUserIds.includes(context.auth.uid)) {
      throw new functions.https.HttpsError('permission-denied', 'Not a group member');
    }

    if (!group.chatThreadId) {
      throw new functions.https.HttpsError('not-found', 'Group chat not found');
    }

    // Create message using existing friends messaging system
    const messageData = {
      conversationId: group.chatThreadId,
      text: messageText,
      type: messageType,
      replyToId: data.replyToId || null,
      attachments: data.attachments || []
    };

    // Call the existing sendMessage function
    // Note: This would ideally call the friends sendMessage function directly
    // For now, we'll create the message directly
    const message = {
      conversationId: group.chatThreadId,
      senderId: context.auth.uid,
      text: messageText,
      type: messageType,
      replyToId: data.replyToId || null,
      attachments: data.attachments || [],
      reactions: {},
      editHistory: [],
      isDeleted: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    const messageRef = await db.collection('messages').add(message);

    // Update conversation with last message
    await db.collection('conversations').doc(group.chatThreadId).update({
      lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      // Increment unread count for all participants except sender
      unreadCount: admin.firestore.FieldValue.increment(1)
    });

    await incrementCounter('activities_group_messages_sent', 1);

    return { messageId: messageRef.id };

  } catch (error) {
    logger.error('Error sending activity group message:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to send message');
  }
});

// Helper functions
async function sendWelcomeMessage(conversationId: string, group: ActivityGroup): Promise<void> {
  const welcomeMessage = {
    conversationId,
    senderId: 'system',
    text: `Welcome to ${group.name}! This is your group chat for coordinating activities together. 🎉`,
    type: 'system',
    replyToId: null,
    attachments: [],
    reactions: {},
    editHistory: [],
    isDeleted: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  await db.collection('messages').add(welcomeMessage);
}

async function sendParticipantAddedMessage(
  conversationId: string, 
  addedParticipants: string[], 
  organizerId: string
): Promise<void> {
  // Get user names (simplified - in real implementation would fetch from user profiles)
  const participantNames = addedParticipants.map(uid => uid.substring(0, 8)).join(', ');
  
  const message = {
    conversationId,
    senderId: 'system',
    text: `${participantNames} joined the group`,
    type: 'system',
    replyToId: null,
    attachments: [],
    reactions: {},
    editHistory: [],
    isDeleted: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  await db.collection('messages').add(message);
}

async function sendParticipantRemovedMessage(
  conversationId: string, 
  removedParticipants: string[], 
  organizerId: string
): Promise<void> {
  const participantNames = removedParticipants.map(uid => uid.substring(0, 8)).join(', ');
  
  const message = {
    conversationId,
    senderId: 'system',
    text: `${participantNames} left the group`,
    type: 'system',
    replyToId: null,
    attachments: [],
    reactions: {},
    editHistory: [],
    isDeleted: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  await db.collection('messages').add(message);
}

async function sendBookingConfirmedMessage(
  conversationId: string,
  booking: Booking,
  activityTitle: string,
  session: any
): Promise<void> {
  let messageText = `🎉 Booking confirmed for "${activityTitle}"!`;
  
  if (session?.startTime) {
    const startTime = session.startTime.toDate();
    const dateString = startTime.toLocaleDateString();
    const timeString = startTime.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    messageText += `\n📅 ${dateString} at ${timeString}`;
  }

  messageText += `\n💰 Total: ${booking.totalAmount} MAD`;
  
  if (booking.participants.length > 1) {
    messageText += `\n👥 ${booking.participants.length} participants`;
  }

  const message = {
    conversationId,
    senderId: 'system',
    text: messageText,
    type: 'booking_confirmation',
    replyToId: null,
    attachments: [],
    metadata: {
      bookingId: booking.id,
      activityTitle,
      totalAmount: booking.totalAmount
    },
    reactions: {},
    editHistory: [],
    isDeleted: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  await db.collection('messages').add(message);
}