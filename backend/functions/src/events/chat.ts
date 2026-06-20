import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import { CallableContext } from "firebase-functions/v2/https";
import { sendNotification } from "./notifications";
import {
  GroupChatMessage,
  ChatMessageType,
  AttendanceGroup
} from "./types";

const db = admin.firestore();

/**
 * Get or create group chat ID
 */
export async function getGroupChatId(groupId: string): Promise<string | null> {
  try {
    const groupDoc = await db.collection("attendanceGroups").doc(groupId).get();
    if (!groupDoc.exists) {
      throw new Error("Group not found");
    }
    
    const group = groupDoc.data() as AttendanceGroup;
    return group.chatId || null;
  } catch (error: any) {
    logger.error("Failed to get group chat ID", { error: error.message });
    throw error;
  }
}

/**
 * Create group chat
 */
export async function createGroupChat(
  data: { groupId: string },
  context: CallableContext
): Promise<string> {
  try {
    const userId = context.auth?.uid;
    if (!userId) {
      throw new Error("Authentication required");
    }
    
    const groupRef = db.collection("attendanceGroups").doc(data.groupId);
    const groupDoc = await groupRef.get();
    
    if (!groupDoc.exists) {
      throw new Error("Group not found");
    }
    
    const group = groupDoc.data() as AttendanceGroup;
    
    // Check if user is in group
    if (!group.participantUserIds.includes(userId) && group.organizerUserId !== userId) {
      throw new Error("Not authorized to create chat for this group");
    }
    
    // Check if chat already exists
    if (group.chatId) {
      return group.chatId;
    }
    
    // Create chat
    const chatId = `chat_${data.groupId}_${Date.now()}`;
    const chatRef = db.collection("groupChats").doc(chatId);
    
    const batch = db.batch();
    
    // Create chat document
    batch.set(chatRef, {
      id: chatId,
      groupId: data.groupId,
      eventId: group.eventId,
      participantUserIds: group.participantUserIds,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Update group with chat ID
    batch.update(groupRef, {
      chatId: chatId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Add system message
    const welcomeMessageRef = db.collection("groupChatMessages").doc();
    batch.set(welcomeMessageRef, {
      id: welcomeMessageRef.id,
      chatId: chatId,
      userId: "system",
      userName: "System",
      userAvatarURL: null,
      content: `Chat created for ${group.name}! Say hello to coordinate your plans.`,
      messageType: ChatMessageType.SYSTEM,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      readBy: [],
      isSystemMessage: true,
      replyToId: null
    });
    
    await batch.commit();
    
    logger.info("Group chat created", { groupId: data.groupId, chatId });
    return chatId;
  } catch (error: any) {
    logger.error("Failed to create group chat", { error: error.message });
    throw error;
  }
}

/**
 * Send group message
 */
export async function sendGroupMessage(
  data: {
    chatId: string;
    content: string;
    messageType?: ChatMessageType;
    replyToId?: string;
  },
  context: CallableContext
): Promise<void> {
  try {
    const userId = context.auth?.uid;
    if (!userId) {
      throw new Error("Authentication required");
    }
    
    // Verify chat exists and user has access
    const chatDoc = await db.collection("groupChats").doc(data.chatId).get();
    if (!chatDoc.exists) {
      throw new Error("Chat not found");
    }
    
    const chat = chatDoc.data()!;
    if (!chat.participantUserIds.includes(userId)) {
      throw new Error("Not authorized to send messages to this chat");
    }
    
    // Get user info
    const userDoc = await db.collection("userProfiles").doc(userId).get();
    const userData = userDoc.data();
    const userName = userData?.displayName || userData?.name || "Unknown";
    const userAvatarURL = userData?.profileImageURL;
    
    // Create message
    const messageRef = db.collection("groupChatMessages").doc();
    const message: Partial<GroupChatMessage> = {
      id: messageRef.id,
      chatId: data.chatId,
      userId,
      userName,
      userAvatarURL,
      content: data.content,
      messageType: data.messageType || ChatMessageType.TEXT,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      readBy: [userId], // Mark as read by sender
      isSystemMessage: false,
      replyToId: data.replyToId
    };
    
    const batch = db.batch();
    
    // Add message
    batch.set(messageRef, message);
    
    // Update chat last activity
    batch.update(db.collection("groupChats").doc(data.chatId), {
      lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
      lastMessageContent: data.content.substring(0, 100),
      lastMessageUserId: userId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    await batch.commit();
    
    // Send push notifications to other participants
    const otherParticipants = chat.participantUserIds.filter((id: string) => id !== userId);
    if (otherParticipants.length > 0) {
      await sendNotification(chat.eventId, "group_message", {
        senderName: userName,
        message: data.content,
        groupName: chat.groupName || "Event Group"
      }, otherParticipants);
    }
    
    logger.info("Group message sent", { chatId: data.chatId, userId });
  } catch (error: any) {
    logger.error("Failed to send group message", { error: error.message });
    throw error;
  }
}

/**
 * Get group messages
 */
export async function getGroupMessages(
  data: {
    chatId: string;
    limit?: number;
    before?: Date;
  },
  context: CallableContext
): Promise<GroupChatMessage[]> {
  try {
    const userId = context.auth?.uid;
    if (!userId) {
      throw new Error("Authentication required");
    }
    
    // Verify access
    const chatDoc = await db.collection("groupChats").doc(data.chatId).get();
    if (!chatDoc.exists) {
      throw new Error("Chat not found");
    }
    
    const chat = chatDoc.data()!;
    if (!chat.participantUserIds.includes(userId)) {
      throw new Error("Not authorized to view this chat");
    }
    
    // Build query
    let query = db.collection("groupChatMessages")
      .where("chatId", "==", data.chatId)
      .orderBy("timestamp", "desc")
      .limit(data.limit || 50);
    
    if (data.before) {
      query = query.where("timestamp", "<", admin.firestore.Timestamp.fromDate(data.before));
    }
    
    const snapshot = await query.get();
    
    const messages = snapshot.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        ...data,
        timestamp: data.timestamp.toDate()
      };
    }) as GroupChatMessage[];
    
    return messages.reverse(); // Return in chronological order
  } catch (error: any) {
    logger.error("Failed to get group messages", { error: error.message });
    throw error;
  }
}

/**
 * Mark messages as read
 */
export async function markMessagesRead(
  data: {
    chatId: string;
    messageIds: string[];
  },
  context: CallableContext
): Promise<void> {
  try {
    const userId = context.auth?.uid;
    if (!userId) {
      throw new Error("Authentication required");
    }
    
    // Verify access
    const chatDoc = await db.collection("groupChats").doc(data.chatId).get();
    if (!chatDoc.exists) {
      throw new Error("Chat not found");
    }
    
    const chat = chatDoc.data()!;
    if (!chat.participantUserIds.includes(userId)) {
      throw new Error("Not authorized to access this chat");
    }
    
    const batch = db.batch();
    
    for (const messageId of data.messageIds) {
      const messageRef = db.collection("groupChatMessages").doc(messageId);
      batch.update(messageRef, {
        readBy: admin.firestore.FieldValue.arrayUnion(userId)
      });
    }
    
    await batch.commit();
    
    logger.info("Messages marked as read", { 
      chatId: data.chatId, 
      messageCount: data.messageIds.length,
      userId 
    });
  } catch (error: any) {
    logger.error("Failed to mark messages as read", { error: error.message });
    throw error;
  }
}

/**
 * Add ride sharing context message
 */
export async function addRideContextMessage(
  chatId: string,
  rideDetails: {
    pickupLocation: string;
    dropoffLocation: string;
    departureTime: Date;
    estimatedFare: number;
    availableSeats: number;
  }
): Promise<void> {
  try {
    const messageRef = db.collection("groupChatMessages").doc();
    const content = `🚗 Ride Share Available\n📍 From: ${rideDetails.pickupLocation}\n📍 To: ${rideDetails.dropoffLocation}\n⏰ Departure: ${rideDetails.departureTime.toLocaleString()}\n💰 Est. cost: ${rideDetails.estimatedFare} MAD per person\n👥 ${rideDetails.availableSeats} seats available`;
    
    const message: Partial<GroupChatMessage> = {
      id: messageRef.id,
      chatId: chatId,
      userId: "system",
      userName: "Ride Assistant",
      userAvatarURL: null,
      content: content,
      messageType: ChatMessageType.RIDE_DETAILS,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      readBy: [],
      isSystemMessage: true,
      replyToId: null
    };
    
    await messageRef.set(message);
    
    logger.info("Ride context message added", { chatId });
  } catch (error: any) {
    logger.error("Failed to add ride context message", { error: error.message });
  }
}

/**
 * Add event update message
 */
export async function addEventUpdateMessage(
  chatId: string,
  updateType: string,
  details: any
): Promise<void> {
  try {
    const messageRef = db.collection("groupChatMessages").doc();
    
    let content: string;
    switch (updateType) {
      case "venue_change":
        content = `📍 Venue Update: The event location has changed to ${details.newVenue}`;
        break;
      case "time_change":
        content = `⏰ Time Update: The event time has changed to ${new Date(details.newTime).toLocaleString()}`;
        break;
      case "cancellation":
        content = `❌ Event Cancelled: ${details.reason || "The event has been cancelled"}`;
        break;
      case "reminder":
        content = `⏰ Reminder: The event starts in ${details.timeUntil}. Don't forget to get ready!`;
        break;
      default:
        content = `ℹ️ Event Update: ${details.message}`;
    }
    
    const message: Partial<GroupChatMessage> = {
      id: messageRef.id,
      chatId: chatId,
      userId: "system",
      userName: "Event Assistant",
      userAvatarURL: null,
      content: content,
      messageType: ChatMessageType.EVENT_DETAILS,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      readBy: [],
      isSystemMessage: true,
      replyToId: null
    };
    
    await messageRef.set(message);
    
    logger.info("Event update message added", { chatId, updateType });
  } catch (error: any) {
    logger.error("Failed to add event update message", { error: error.message });
  }
}