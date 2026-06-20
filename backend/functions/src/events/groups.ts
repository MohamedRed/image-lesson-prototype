import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import { CallableContext } from "firebase-functions/v2/https";
import {
  AttendanceGroup,
  GroupStatus,
  Event,
  EventSession,
  EventInteraction,
  InteractionType,
  EventNotification,
  NotificationType
} from "./types";
import { sendNotification } from "./notifications";

const db = admin.firestore();

/**
 * Create an attendance group for an event
 */
export async function createAttendanceGroup(
  data: {
    eventId: string;
    sessionId?: string;
    name: string;
    invitedUserIds?: string[];
  },
  context: CallableContext
): Promise<AttendanceGroup> {
  try {
    if (!context.auth) {
      throw new Error("Authentication required");
    }

    const organizerId = context.auth.uid;

    // Verify event exists
    const eventDoc = await db.collection("events").doc(data.eventId).get();
    if (!eventDoc.exists) {
      throw new Error("Event not found");
    }
    const event = eventDoc.data() as Event;

    // Verify session if provided
    if (data.sessionId) {
      const sessionDoc = await db.collection("eventSessions").doc(data.sessionId).get();
      if (!sessionDoc.exists || sessionDoc.data()?.eventId !== data.eventId) {
        throw new Error("Invalid session");
      }
    }

    // Create chat thread (integrate with chat service)
    const chatThreadId = await createChatThread(organizerId, data.name);

    // Create group
    const groupData: Omit<AttendanceGroup, "id"> = {
      organizerId,
      eventId: data.eventId,
      sessionId: data.sessionId,
      name: data.name,
      status: GroupStatus.PLANNING,
      invitedUserIds: data.invitedUserIds || [],
      participantUserIds: [organizerId], // Organizer is automatically a participant
      chatThreadId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const groupRef = await db.collection("attendanceGroups").add(groupData);
    const groupId = groupRef.id;

    // Send invitations
    if (data.invitedUserIds && data.invitedUserIds.length > 0) {
      await sendGroupInvitations(
        groupId,
        data.invitedUserIds,
        organizerId,
        event.title,
        data.name
      );
    }

    // Track interaction
    await trackInteraction({
      userId: organizerId,
      type: InteractionType.RSVP,
      entityId: groupId,
      entityType: "group",
      context: { eventId: data.eventId }
    });

    logger.info("Attendance group created", { groupId, eventId: data.eventId });

    return { id: groupId, ...groupData } as AttendanceGroup;

  } catch (error: any) {
    logger.error("Failed to create attendance group", { error: error.message });
    throw error;
  }
}

/**
 * Invite friends to an attendance group
 */
export async function inviteFriendsToGroup(
  data: {
    groupId: string;
    userIds: string[];
  },
  context: CallableContext
): Promise<void> {
  try {
    if (!context.auth) {
      throw new Error("Authentication required");
    }

    const groupDoc = await db.collection("attendanceGroups").doc(data.groupId).get();
    if (!groupDoc.exists) {
      throw new Error("Group not found");
    }

    const group = groupDoc.data() as AttendanceGroup;
    
    // Verify user is organizer or participant
    if (group.organizerId !== context.auth.uid && 
        !group.participantUserIds.includes(context.auth.uid)) {
      throw new Error("Not authorized to invite to this group");
    }

    // Get event details
    const eventDoc = await db.collection("events").doc(group.eventId).get();
    const event = eventDoc.data() as Event;

    // Filter out already invited users
    const newInvites = data.userIds.filter(
      userId => !group.invitedUserIds.includes(userId) && 
                !group.participantUserIds.includes(userId)
    );

    if (newInvites.length === 0) {
      return;
    }

    // Update group with new invites
    await groupDoc.ref.update({
      invitedUserIds: admin.firestore.FieldValue.arrayUnion(...newInvites),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Send invitations
    await sendGroupInvitations(
      data.groupId,
      newInvites,
      context.auth.uid,
      event.title,
      group.name
    );

    logger.info("Friends invited to group", { 
      groupId: data.groupId, 
      count: newInvites.length 
    });

  } catch (error: any) {
    logger.error("Failed to invite friends", { error: error.message });
    throw error;
  }
}

/**
 * Update RSVP status for a group
 */
export async function updateRSVP(
  data: {
    groupId: string;
    attending: boolean;
  },
  context: CallableContext
): Promise<void> {
  try {
    if (!context.auth) {
      throw new Error("Authentication required");
    }

    const userId = context.auth.uid;
    const groupRef = db.collection("attendanceGroups").doc(data.groupId);
    const groupDoc = await groupRef.get();

    if (!groupDoc.exists) {
      throw new Error("Group not found");
    }

    const group = groupDoc.data() as AttendanceGroup;

    // Check if user was invited
    if (!group.invitedUserIds.includes(userId) && 
        !group.participantUserIds.includes(userId)) {
      throw new Error("User not invited to this group");
    }

    if (data.attending) {
      // Add to participants, remove from invited
      await groupRef.update({
        participantUserIds: admin.firestore.FieldValue.arrayUnion(userId),
        invitedUserIds: admin.firestore.FieldValue.arrayRemove(userId),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Add user to chat thread
      if (group.chatThreadId) {
        await addUserToChatThread(group.chatThreadId, userId);
      }

      // Notify organizer
      if (group.organizerId !== userId) {
        await sendRSVPNotification(
          group.organizerId,
          userId,
          group.name,
          true
        );
      }

    } else {
      // Remove from both lists
      await groupRef.update({
        participantUserIds: admin.firestore.FieldValue.arrayRemove(userId),
        invitedUserIds: admin.firestore.FieldValue.arrayRemove(userId),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Remove from chat thread
      if (group.chatThreadId) {
        await removeUserFromChatThread(group.chatThreadId, userId);
      }

      // Notify organizer
      if (group.organizerId !== userId) {
        await sendRSVPNotification(
          group.organizerId,
          userId,
          group.name,
          false
        );
      }
    }

    // Track interaction
    await trackInteraction({
      userId,
      type: InteractionType.RSVP,
      entityId: data.groupId,
      entityType: "group",
      context: { attending: data.attending }
    });

    logger.info("RSVP updated", { 
      groupId: data.groupId, 
      userId, 
      attending: data.attending 
    });

  } catch (error: any) {
    logger.error("Failed to update RSVP", { error: error.message });
    throw error;
  }
}

/**
 * Leave an attendance group
 */
export async function leaveGroup(
  data: {
    groupId: string;
  },
  context: CallableContext
): Promise<void> {
  try {
    if (!context.auth) {
      throw new Error("Authentication required");
    }

    const userId = context.auth.uid;
    const groupRef = db.collection("attendanceGroups").doc(data.groupId);
    const groupDoc = await groupRef.get();

    if (!groupDoc.exists) {
      throw new Error("Group not found");
    }

    const group = groupDoc.data() as AttendanceGroup;

    // Can't leave if you're the organizer
    if (group.organizerId === userId) {
      throw new Error("Organizer cannot leave the group");
    }

    // Remove from participants
    await groupRef.update({
      participantUserIds: admin.firestore.FieldValue.arrayRemove(userId),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Remove from chat thread
    if (group.chatThreadId) {
      await removeUserFromChatThread(group.chatThreadId, userId);
    }

    logger.info("User left group", { groupId: data.groupId, userId });

  } catch (error: any) {
    logger.error("Failed to leave group", { error: error.message });
    throw error;
  }
}

/**
 * Update group status (for order flow)
 */
export async function updateGroupStatus(
  groupId: string,
  status: GroupStatus
): Promise<void> {
  try {
    await db.collection("attendanceGroups").doc(groupId).update({
      status,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info("Group status updated", { groupId, status });

  } catch (error: any) {
    logger.error("Failed to update group status", { error: error.message });
    throw error;
  }
}

/**
 * Get group details with event and session info
 */
export async function getGroupDetails(
  groupId: string,
  userId: string
): Promise<{
  group: AttendanceGroup;
  event: Event;
  session?: EventSession;
}> {
  try {
    const groupDoc = await db.collection("attendanceGroups").doc(groupId).get();
    if (!groupDoc.exists) {
      throw new Error("Group not found");
    }

    const group = { id: groupDoc.id, ...groupDoc.data() } as AttendanceGroup;

    // Verify user is authorized to view group
    if (!group.participantUserIds.includes(userId) && 
        !group.invitedUserIds.includes(userId)) {
      throw new Error("Not authorized to view this group");
    }

    // Get event
    const eventDoc = await db.collection("events").doc(group.eventId).get();
    if (!eventDoc.exists) {
      throw new Error("Event not found");
    }
    const event = { id: eventDoc.id, ...eventDoc.data() } as Event;

    // Get session if specified
    let session: EventSession | undefined;
    if (group.sessionId) {
      const sessionDoc = await db.collection("eventSessions").doc(group.sessionId).get();
      if (sessionDoc.exists) {
        session = { id: sessionDoc.id, ...sessionDoc.data() } as EventSession;
      }
    }

    return { group, event, session };

  } catch (error: any) {
    logger.error("Failed to get group details", { error: error.message });
    throw error;
  }
}

/**
 * Send group invitations
 */
async function sendGroupInvitations(
  groupId: string,
  userIds: string[],
  inviterId: string,
  eventTitle: string,
  groupName: string
): Promise<void> {
  try {
    // Get inviter name
    const inviterDoc = await db.collection("users").doc(inviterId).get();
    const inviterName = inviterDoc.data()?.displayName || "Someone";

    // Send notifications in parallel
    const notifications = userIds.map(userId => 
      sendNotification({
        userId,
        type: NotificationType.GROUP_INVITE,
        title: "Event Invitation",
        body: `${inviterName} invited you to "${groupName}" for ${eventTitle}`,
        data: {
          groupId,
          inviterId,
          eventTitle,
          groupName
        }
      })
    );

    await Promise.all(notifications);

  } catch (error: any) {
    logger.error("Failed to send invitations", { error: error.message });
  }
}

/**
 * Send RSVP notification
 */
async function sendRSVPNotification(
  organizerId: string,
  userId: string,
  groupName: string,
  attending: boolean
): Promise<void> {
  try {
    const userDoc = await db.collection("users").doc(userId).get();
    const userName = userDoc.data()?.displayName || "Someone";

    await sendNotification({
      userId: organizerId,
      type: NotificationType.RSVP_UPDATE,
      title: "RSVP Update",
      body: `${userName} ${attending ? "joined" : "declined"} "${groupName}"`,
      data: {
        userId,
        groupName,
        attending
      }
    });

  } catch (error: any) {
    logger.error("Failed to send RSVP notification", { error: error.message });
  }
}

/**
 * Create chat thread for group
 */
async function createChatThread(organizerId: string, name: string): Promise<string> {
  try {
    // This would integrate with your chat service
    // For now, creating a simple thread document
    const threadRef = await db.collection("chatThreads").add({
      type: "event_group",
      name,
      createdBy: organizerId,
      participants: [organizerId],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return threadRef.id;

  } catch (error: any) {
    logger.error("Failed to create chat thread", { error: error.message });
    throw error;
  }
}

/**
 * Add user to chat thread
 */
async function addUserToChatThread(threadId: string, userId: string): Promise<void> {
  try {
    await db.collection("chatThreads").doc(threadId).update({
      participants: admin.firestore.FieldValue.arrayUnion(userId),
    });
  } catch (error: any) {
    logger.error("Failed to add user to chat", { error: error.message });
  }
}

/**
 * Remove user from chat thread
 */
async function removeUserFromChatThread(threadId: string, userId: string): Promise<void> {
  try {
    await db.collection("chatThreads").doc(threadId).update({
      participants: admin.firestore.FieldValue.arrayRemove(userId),
    });
  } catch (error: any) {
    logger.error("Failed to remove user from chat", { error: error.message });
  }
}

/**
 * Track interaction
 */
async function trackInteraction(interaction: Omit<EventInteraction, "id" | "timestamp">): Promise<void> {
  try {
    await db.collection("interactions").add({
      ...interaction,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
  } catch (error: any) {
    logger.error("Failed to track interaction", { error: error.message });
  }
}