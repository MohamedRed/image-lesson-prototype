import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import { CallableContext } from "firebase-functions/v2/https";
import { sendNotification } from "./notifications";
import {
  EventsFriend,
  FriendEventActivity,
  FriendActivityType,
  EventInvite,
  InviteResponse,
  Event
} from "./types";

const db = admin.firestore();

/**
 * Get user's friends with event context
 */
export async function getFriends(
  userId: string
): Promise<EventsFriend[]> {
  try {
    // Get friends from FriendsService (assuming it exists)
    const friendsDoc = await db.collection("userProfiles").doc(userId).get();
    const friendIds = friendsDoc.data()?.friendIds || [];
    
    if (friendIds.length === 0) {
      return [];
    }
    
    const friends: EventsFriend[] = [];
    
    // Batch get friend profiles
    const friendProfiles = await Promise.all(
      friendIds.map((friendId: string) => 
        db.collection("userProfiles").doc(friendId).get()
      )
    );
    
    for (const profile of friendProfiles) {
      if (profile.exists) {
        const data = profile.data()!;
        
        // Get mutual friends count
        const mutualCount = await getMutualFriendsCount(userId, profile.id);
        
        friends.push({
          id: profile.id,
          name: data.displayName || data.name || "Unknown",
          profileImageURL: data.profileImageURL,
          preferredCategories: data.eventPreferences?.categories || [],
          mutualFriendsCount: mutualCount,
          isOnline: data.isOnline || false,
          lastSeen: data.lastSeen?.toDate()
        });
      }
    }
    
    return friends;
  } catch (error: any) {
    logger.error("Failed to get friends", { error: error.message, userId });
    throw error;
  }
}

/**
 * Get friend event activities
 */
export async function getFriendActivity(
  userId: string,
  limit: number = 20
): Promise<FriendEventActivity[]> {
  try {
    const friendsDoc = await db.collection("userProfiles").doc(userId).get();
    const friendIds = friendsDoc.data()?.friendIds || [];
    
    if (friendIds.length === 0) {
      return [];
    }
    
    // Get recent friend activities
    const activitiesSnapshot = await db.collection("friendEventActivities")
      .where("friendId", "in", friendIds.slice(0, 10)) // Firestore limit
      .where("isVisible", "==", true)
      .orderBy("timestamp", "desc")
      .limit(limit)
      .get();
    
    return activitiesSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    })) as FriendEventActivity[];
  } catch (error: any) {
    logger.error("Failed to get friend activity", { error: error.message });
    throw error;
  }
}

/**
 * Get events with friends attending
 */
export async function getEventsWithFriends(
  userId: string,
  eventIds: string[]
): Promise<Array<{ eventId: string; friends: EventsFriend[] }>> {
  try {
    const friendsDoc = await db.collection("userProfiles").doc(userId).get();
    const friendIds = friendsDoc.data()?.friendIds || [];
    
    if (friendIds.length === 0 || eventIds.length === 0) {
      return [];
    }
    
    const results: Array<{ eventId: string; friends: EventsFriend[] }> = [];
    
    for (const eventId of eventIds) {
      // Find friends attending this event
      const groupsSnapshot = await db.collection("attendanceGroups")
        .where("eventId", "==", eventId)
        .where("participantUserIds", "array-contains-any", friendIds.slice(0, 10))
        .get();
      
      const attendingFriendIds = new Set<string>();
      groupsSnapshot.docs.forEach(doc => {
        const group = doc.data();
        group.participantUserIds.forEach((id: string) => {
          if (friendIds.includes(id)) {
            attendingFriendIds.add(id);
          }
        });
      });
      
      // Get friend details
      const friends = await Promise.all(
        Array.from(attendingFriendIds).map(async (friendId) => {
          const profileDoc = await db.collection("userProfiles").doc(friendId).get();
          if (profileDoc.exists) {
            const data = profileDoc.data()!;
            return {
              id: friendId,
              name: data.displayName || data.name || "Unknown",
              profileImageURL: data.profileImageURL,
              preferredCategories: data.eventPreferences?.categories || [],
              mutualFriendsCount: 0, // Skip for performance
              isOnline: data.isOnline || false,
              lastSeen: data.lastSeen?.toDate()
            };
          }
          return null;
        })
      );
      
      results.push({
        eventId,
        friends: friends.filter(f => f !== null) as EventsFriend[]
      });
    }
    
    return results;
  } catch (error: any) {
    logger.error("Failed to get events with friends", { error: error.message });
    throw error;
  }
}

/**
 * Send event invitation to friends
 */
export async function sendEventInvite(
  data: {
    eventId: string;
    friendIds: string[];
    message?: string;
  },
  context: CallableContext
): Promise<void> {
  try {
    const userId = context.auth?.uid;
    if (!userId) {
      throw new Error("Authentication required");
    }
    
    // Get sender info
    const senderDoc = await db.collection("userProfiles").doc(userId).get();
    const senderName = senderDoc.data()?.displayName || senderDoc.data()?.name || "Someone";
    
    // Get event info
    const eventDoc = await db.collection("events").doc(data.eventId).get();
    if (!eventDoc.exists) {
      throw new Error("Event not found");
    }
    const event = eventDoc.data() as Event;
    
    // Create invites
    const batch = db.batch();
    const invitePromises: Promise<void>[] = [];
    
    for (const friendId of data.friendIds) {
      const inviteId = `invite_${Date.now()}_${friendId}`;
      const inviteRef = db.collection("eventInvites").doc(inviteId);
      
      const invite: EventInvite = {
        id: inviteId,
        fromUserId: userId,
        fromUserName: senderName,
        toUserId: friendId,
        eventId: data.eventId,
        eventTitle: event.title,
        message: data.message,
        createdAt: new Date(),
        response: null,
        respondedAt: null
      };
      
      batch.set(inviteRef, {
        ...invite,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Send push notification
      invitePromises.push(
        sendNotification(data.eventId, "event_invite", {
          fromName: senderName,
          eventTitle: event.title,
          message: data.message
        }, [friendId])
      );
    }
    
    await batch.commit();
    await Promise.all(invitePromises);
    
    logger.info("Event invites sent", { 
      eventId: data.eventId, 
      friendCount: data.friendIds.length 
    });
  } catch (error: any) {
    logger.error("Failed to send event invite", { error: error.message });
    throw error;
  }
}

/**
 * Get user's event invites
 */
export async function getEventInvites(userId: string): Promise<EventInvite[]> {
  try {
    const invitesSnapshot = await db.collection("eventInvites")
      .where("toUserId", "==", userId)
      .where("response", "==", null)
      .orderBy("createdAt", "desc")
      .limit(50)
      .get();
    
    return invitesSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt.toDate(),
      respondedAt: doc.data().respondedAt?.toDate()
    })) as EventInvite[];
  } catch (error: any) {
    logger.error("Failed to get event invites", { error: error.message });
    throw error;
  }
}

/**
 * Respond to event invite
 */
export async function respondToInvite(
  data: {
    inviteId: string;
    response: InviteResponse;
  },
  context: CallableContext
): Promise<void> {
  try {
    const userId = context.auth?.uid;
    if (!userId) {
      throw new Error("Authentication required");
    }
    
    const inviteRef = db.collection("eventInvites").doc(data.inviteId);
    const inviteDoc = await inviteRef.get();
    
    if (!inviteDoc.exists) {
      throw new Error("Invite not found");
    }
    
    const invite = inviteDoc.data() as EventInvite;
    
    if (invite.toUserId !== userId) {
      throw new Error("Not authorized to respond to this invite");
    }
    
    // Update invite
    await inviteRef.update({
      response: data.response,
      respondedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // If accepted, create activity record
    if (data.response === InviteResponse.ACCEPTED) {
      await recordFriendActivity({
        friendId: userId,
        friendName: "You", // Will be updated by the system
        eventId: invite.eventId,
        eventTitle: invite.eventTitle,
        activityType: FriendActivityType.INTERESTED
      });
    }
    
    // Notify sender
    await sendNotification(invite.eventId, "invite_response", {
      responseType: data.response,
      eventTitle: invite.eventTitle
    }, [invite.fromUserId]);
    
    logger.info("Invite response recorded", { 
      inviteId: data.inviteId, 
      response: data.response 
    });
  } catch (error: any) {
    logger.error("Failed to respond to invite", { error: error.message });
    throw error;
  }
}

/**
 * Record friend activity
 */
export async function recordFriendActivity(
  activity: Omit<FriendEventActivity, "id" | "timestamp">
): Promise<void> {
  try {
    await db.collection("friendEventActivities").add({
      ...activity,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
  } catch (error: any) {
    logger.error("Failed to record friend activity", { error: error.message });
  }
}

// Helper functions

async function getMutualFriendsCount(userId: string, friendId: string): Promise<number> {
  try {
    const [userDoc, friendDoc] = await Promise.all([
      db.collection("userProfiles").doc(userId).get(),
      db.collection("userProfiles").doc(friendId).get()
    ]);
    
    const userFriends = new Set(userDoc.data()?.friendIds || []);
    const friendFriends = new Set(friendDoc.data()?.friendIds || []);
    
    // Count intersection
    let mutualCount = 0;
    for (const id of userFriends) {
      if (friendFriends.has(id)) {
        mutualCount++;
      }
    }
    
    return mutualCount;
  } catch (error: any) {
    logger.error("Failed to get mutual friends count", { error: error.message });
    return 0;
  }
}