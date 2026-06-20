import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { logger } from 'firebase-functions';
import { 
  Group,
  GroupDraft,
  GroupStatus,
  ActivitiesError,
  ErrorCodes,
  Interaction
} from './models';
import { incrementCounter } from '../shared/metrics';
import { sendNotification } from '../services/notifications/fcmService';

const db = admin.firestore();

// Create a new group
export const createGroup = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const groupDraft: GroupDraft = data;
  const { name, activityId, preferences, inviteUserIds = [] } = groupDraft;

  if (!name) {
    throw new functions.https.HttpsError('invalid-argument', 'Group name is required');
  }

  try {
    // If activity is specified, verify it exists
    if (activityId) {
      const activityDoc = await db.collection('activities').doc(activityId).get();
      if (!activityDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Activity not found');
      }
    }

    // Create chat thread for the group
    const chatThreadRef = db.collection('chatThreads').doc();
    await chatThreadRef.set({
      type: 'group',
      participants: [context.auth.uid, ...inviteUserIds],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Create the group
    const group: Omit<Group, 'id'> = {
      organizerId: context.auth.uid,
      name,
      activityId,
      cityId: 'casablanca', // TODO: Get from user location or preferences
      status: 'planning',
      preferences: preferences || {},
      invitedUserIds: inviteUserIds,
      participantUserIds: [context.auth.uid],
      chatThreadId: chatThreadRef.id,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const groupDoc = await db.collection('groups').add(group);

    // Send invitations
    if (inviteUserIds.length > 0) {
      await sendInvitations(groupDoc.id, inviteUserIds, context.auth.uid, name);
    }

    // Track interaction
    await db.collection('interactions').add({
      userId: context.auth.uid,
      type: 'invite',
      entityId: groupDoc.id,
      entityType: 'group',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      context: { inviteCount: inviteUserIds.length }
    });

    await incrementCounter('activities_groups_created', 1);

    logger.info(`Group created: ${groupDoc.id}`, { 
      groupId: groupDoc.id, 
      organizerId: context.auth.uid,
      activityId 
    });

    return { groupId: groupDoc.id };

  } catch (error) {
    logger.error('Error creating group:', error);
    throw new functions.https.HttpsError('internal', 'Failed to create group');
  }
});

// Invite friends to a group
export const inviteToGroup = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { groupId, userIds } = data;

  if (!groupId || !userIds || !Array.isArray(userIds)) {
    throw new functions.https.HttpsError('invalid-argument', 'Group ID and user IDs are required');
  }

  try {
    const groupRef = db.collection('groups').doc(groupId);
    const groupDoc = await groupRef.get();

    if (!groupDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Group not found');
    }

    const groupData = groupDoc.data() as Group;

    // Check if user is organizer or participant
    if (groupData.organizerId !== context.auth.uid && 
        !groupData.participantUserIds.includes(context.auth.uid)) {
      throw new functions.https.HttpsError('permission-denied', 'Not authorized to invite to this group');
    }

    // Add to invited users (avoiding duplicates)
    const newInvitedIds = userIds.filter(id => 
      !groupData.invitedUserIds.includes(id) && 
      !groupData.participantUserIds.includes(id)
    );

    if (newInvitedIds.length === 0) {
      return { success: true, message: 'All users already invited or participating' };
    }

    // Update group
    await groupRef.update({
      invitedUserIds: admin.firestore.FieldValue.arrayUnion(...newInvitedIds),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update chat thread participants
    if (groupData.chatThreadId) {
      await db.collection('chatThreads').doc(groupData.chatThreadId).update({
        participants: admin.firestore.FieldValue.arrayUnion(...newInvitedIds),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // Send invitations
    await sendInvitations(groupId, newInvitedIds, context.auth.uid, groupData.name);

    await incrementCounter('activities_invites_sent', newInvitedIds.length);

    return { success: true, inviteCount: newInvitedIds.length };

  } catch (error) {
    logger.error('Error inviting to group:', error);
    throw new functions.https.HttpsError('internal', 'Failed to send invitations');
  }
});

// Accept/decline group invitation
export const respondToInvitation = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { groupId, response } = data; // response: 'accept' | 'decline'

  if (!groupId || !['accept', 'decline'].includes(response)) {
    throw new functions.https.HttpsError('invalid-argument', 'Group ID and valid response required');
  }

  try {
    const groupRef = db.collection('groups').doc(groupId);

    await db.runTransaction(async (transaction) => {
      const groupDoc = await transaction.get(groupRef);

      if (!groupDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Group not found');
      }

      const groupData = groupDoc.data() as Group;

      // Check if user was invited
      if (!groupData.invitedUserIds.includes(context.auth!.uid)) {
        throw new functions.https.HttpsError('permission-denied', 'You were not invited to this group');
      }

      // Remove from invited list
      const updatedInvitedIds = groupData.invitedUserIds.filter(id => id !== context.auth!.uid);
      
      const updates: any = {
        invitedUserIds: updatedInvitedIds,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (response === 'accept') {
        // Add to participants
        updates.participantUserIds = admin.firestore.FieldValue.arrayUnion(context.auth!.uid);
      }

      transaction.update(groupRef, updates);
    });

    // Track interaction
    await db.collection('interactions').add({
      userId: context.auth.uid,
      type: response === 'accept' ? 'accept' : 'decline',
      entityId: groupId,
      entityType: 'group',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    await incrementCounter(`activities_invites_${response}ed`, 1);

    logger.info(`Group invitation ${response}ed`, { 
      groupId, 
      userId: context.auth.uid,
      response 
    });

    return { success: true };

  } catch (error) {
    logger.error('Error responding to invitation:', error);
    throw new functions.https.HttpsError('internal', 'Failed to respond to invitation');
  }
});

// Get groups for user
export const getUserGroups = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { status, limit = 20 } = data;

  try {
    let query = db.collection('groups')
      .where('participantUserIds', 'array-contains', context.auth.uid)
      .orderBy('updatedAt', 'desc')
      .limit(limit);

    if (status) {
      query = query.where('status', '==', status);
    }

    const snapshot = await query.get();

    const groups = await Promise.all(snapshot.docs.map(async (doc) => {
      const groupData = { id: doc.id, ...doc.data() } as Group;

      // Get activity details if available
      if (groupData.activityId) {
        const activityDoc = await db.collection('activities').doc(groupData.activityId).get();
        if (activityDoc.exists) {
          (groupData as any).activity = { id: activityDoc.id, ...activityDoc.data() };
        }
      }

      return groupData;
    }));

    return { groups };

  } catch (error) {
    logger.error('Error getting user groups:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get groups');
  }
});

// Update group status
export const updateGroupStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { groupId, status, sessionId } = data;

  if (!groupId || !status) {
    throw new functions.https.HttpsError('invalid-argument', 'Group ID and status are required');
  }

  try {
    const groupRef = db.collection('groups').doc(groupId);
    const groupDoc = await groupRef.get();

    if (!groupDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Group not found');
    }

    const groupData = groupDoc.data() as Group;

    // Only organizer can update status
    if (groupData.organizerId !== context.auth.uid) {
      throw new functions.https.HttpsError('permission-denied', 'Only group organizer can update status');
    }

    const updates: any = {
      status,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (sessionId) {
      updates.sessionId = sessionId;
    }

    await groupRef.update(updates);

    // Notify participants of status change
    const participantIds = groupData.participantUserIds.filter(id => id !== context.auth.uid);
    if (participantIds.length > 0) {
      await sendStatusUpdateNotifications(groupId, status, participantIds, groupData.name);
    }

    return { success: true };

  } catch (error) {
    logger.error('Error updating group status:', error);
    throw new functions.https.HttpsError('internal', 'Failed to update group status');
  }
});

// Get group details
export const getGroup = functions.https.onCall(async (data, context) => {
  const { groupId } = data;

  if (!groupId) {
    throw new functions.https.HttpsError('invalid-argument', 'Group ID is required');
  }

  try {
    const groupDoc = await db.collection('groups').doc(groupId).get();

    if (!groupDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Group not found');
    }

    const groupData = { id: groupDoc.id, ...groupDoc.data() } as Group;

    // Check if user has access (participant, invited, or public discovery)
    if (context.auth) {
      const userId = context.auth.uid;
      const hasAccess = groupData.participantUserIds.includes(userId) || 
                       groupData.invitedUserIds.includes(userId) ||
                       groupData.organizerId === userId;

      if (!hasAccess) {
        // Only return basic public info
        return {
          id: groupData.id,
          name: groupData.name,
          status: groupData.status,
          participantCount: groupData.participantUserIds.length,
        };
      }
    }

    // Get full details for authorized users
    if (groupData.activityId) {
      const activityDoc = await db.collection('activities').doc(groupData.activityId).get();
      if (activityDoc.exists) {
        (groupData as any).activity = { id: activityDoc.id, ...activityDoc.data() };
      }
    }

    if (groupData.sessionId) {
      const sessionDoc = await db.collection('activitySessions').doc(groupData.sessionId).get();
      if (sessionDoc.exists) {
        (groupData as any).session = { id: sessionDoc.id, ...sessionDoc.data() };
      }
    }

    return groupData;

  } catch (error) {
    logger.error('Error getting group:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get group');
  }
});

// Helper function to send invitation notifications
async function sendInvitations(
  groupId: string, 
  userIds: string[], 
  organizerId: string, 
  groupName: string
): Promise<void> {
  try {
    // Get organizer info
    const organizerDoc = await admin.auth().getUser(organizerId);
    const organizerName = organizerDoc.displayName || 'Someone';

    // Send notifications to each invited user
    const notifications = userIds.map(async (userId) => {
      try {
        await sendNotification(userId, {
          title: 'Activity Invitation',
          body: `${organizerName} invited you to join "${groupName}"`,
          data: {
            type: 'group_invitation',
            groupId: groupId,
            organizerId: organizerId,
          }
        });
      } catch (error) {
        logger.warn(`Failed to send invitation notification to ${userId}:`, error);
      }
    });

    await Promise.allSettled(notifications);

  } catch (error) {
    logger.error('Error sending invitation notifications:', error);
  }
}

// Helper function to send status update notifications
async function sendStatusUpdateNotifications(
  groupId: string,
  status: GroupStatus,
  participantIds: string[],
  groupName: string
): Promise<void> {
  try {
    const statusMessages = {
      'planning': 'Group is in planning phase',
      'booking': 'Group is ready for booking',
      'confirmed': 'Activity booking confirmed!',
      'completed': 'Activity completed',
      'cancelled': 'Activity cancelled',
    };

    const message = statusMessages[status] || 'Group status updated';

    const notifications = participantIds.map(async (userId) => {
      try {
        await sendNotification(userId, {
          title: `${groupName} - Update`,
          body: message,
          data: {
            type: 'group_status_update',
            groupId: groupId,
            status: status,
          }
        });
      } catch (error) {
        logger.warn(`Failed to send status notification to ${userId}:`, error);
      }
    });

    await Promise.allSettled(notifications);

  } catch (error) {
    logger.error('Error sending status update notifications:', error);
  }
}