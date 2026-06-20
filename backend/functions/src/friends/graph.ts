import * as admin from "firebase-admin";
import { onCall } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { analytics } from "../shared/analytics";

const db = admin.firestore();

interface FriendRequestData {
  targetUserId: string;
}

interface FriendResponseData {
  requestId: string;
  accept: boolean;
}

interface BlockUserData {
  targetUserId: string;
}

// Helper function to generate consistent friendship ID
function getFriendshipId(uid1: string, uid2: string): string {
  return uid1 < uid2 ? `${uid1}_${uid2}` : `${uid2}_${uid1}`;
}

// Send friend request
export const requestFriend = onCall(async (request) => {
  const { data, auth } = request;
  const { targetUserId } = data as FriendRequestData;

  if (!auth?.uid) {
    throw new Error("Authentication required");
  }

  if (auth.uid === targetUserId) {
    throw new Error("Cannot send friend request to yourself");
  }

  const friendshipId = getFriendshipId(auth.uid, targetUserId);

  try {
    // Check if friendship already exists
    const existingFriendship = await db.collection("friendships").doc(friendshipId).get();
    
    if (existingFriendship.exists) {
      const status = existingFriendship.data()?.status;
      if (status === "accepted") {
        throw new Error("Already friends");
      } else if (status === "pending") {
        throw new Error("Friend request already pending");
      }
    }

    // Check if target user exists
    const targetUser = await db.collection("users").doc(targetUserId).get();
    if (!targetUser.exists) {
      throw new Error("User not found");
    }

    // Check if user is blocked
    const targetUserData = targetUser.data();
    if (targetUserData?.blocks?.includes(auth.uid)) {
      throw new Error("Cannot send friend request");
    }

    // Create or update friendship document
    await db.collection("friendships").doc(friendshipId).set({
      users: [auth.uid, targetUserId].sort(),
      status: "pending",
      requestedBy: auth.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Update friend counts
    const batch = db.batch();
    
    // Increment pending count for requester
    const requesterRef = db.collection("users").doc(auth.uid);
    batch.update(requesterRef, {
      "friends.counts.pending": admin.firestore.FieldValue.increment(1)
    });

    // Increment pending count for target (they have a request to review)
    const targetRef = db.collection("users").doc(targetUserId);
    batch.update(targetRef, {
      "friends.counts.pending": admin.firestore.FieldValue.increment(1)
    });

    await batch.commit();

    // Send notification to target user
    // TODO: Integrate with FCM service for push notifications

    // Track analytics
    await analytics.track("friend_request_sent", {
      userId: auth.uid,
      targetUserId,
      friendshipId
    });

    logger.info(`Friend request sent from ${auth.uid} to ${targetUserId}`);

    return { friendshipId };

  } catch (error: any) {
    logger.error("Error sending friend request", { 
      error: error.message, 
      userId: auth.uid, 
      targetUserId 
    });
    throw new Error(error.message || "Failed to send friend request");
  }
});

// Respond to friend request
export const respondToFriendRequest = onCall(async (request) => {
  const { data, auth } = request;
  const { requestId, accept } = data as FriendResponseData;

  if (!auth?.uid) {
    throw new Error("Authentication required");
  }

  try {
    const friendshipRef = db.collection("friendships").doc(requestId);
    const friendship = await friendshipRef.get();

    if (!friendship.exists) {
      throw new Error("Friend request not found");
    }

    const friendshipData = friendship.data()!;
    
    // Verify user is involved in this friendship
    if (!friendshipData.users.includes(auth.uid)) {
      throw new Error("Not authorized to respond to this request");
    }

    // Verify this is a pending request
    if (friendshipData.status !== "pending") {
      throw new Error("Request is no longer pending");
    }

    // Verify user is not the requester
    if (friendshipData.requestedBy === auth.uid) {
      throw new Error("Cannot respond to your own request");
    }

    const otherUserId = friendshipData.users.find((uid: string) => uid !== auth.uid)!;
    const batch = db.batch();

    if (accept) {
      // Accept the request
      batch.update(friendshipRef, {
        status: "accepted",
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Update friend counts - decrement pending, increment total
      const userRef = db.collection("users").doc(auth.uid);
      batch.update(userRef, {
        "friends.counts.pending": admin.firestore.FieldValue.increment(-1),
        "friends.counts.total": admin.firestore.FieldValue.increment(1)
      });

      const otherUserRef = db.collection("users").doc(otherUserId);
      batch.update(otherUserRef, {
        "friends.counts.pending": admin.firestore.FieldValue.increment(-1),
        "friends.counts.total": admin.firestore.FieldValue.increment(1)
      });

      await batch.commit();

      // Track analytics
      await analytics.track("friend_request_accepted", {
        userId: auth.uid,
        requesterId: otherUserId,
        friendshipId: requestId
      });

      logger.info(`Friend request accepted: ${requestId}`);

    } else {
      // Decline the request
      batch.update(friendshipRef, {
        status: "declined",
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Update pending counts
      const userRef = db.collection("users").doc(auth.uid);
      batch.update(userRef, {
        "friends.counts.pending": admin.firestore.FieldValue.increment(-1)
      });

      const otherUserRef = db.collection("users").doc(otherUserId);
      batch.update(otherUserRef, {
        "friends.counts.pending": admin.firestore.FieldValue.increment(-1)
      });

      await batch.commit();

      // Track analytics
      await analytics.track("friend_request_declined", {
        userId: auth.uid,
        requesterId: otherUserId,
        friendshipId: requestId
      });

      logger.info(`Friend request declined: ${requestId}`);
    }

    return { success: true };

  } catch (error: any) {
    logger.error("Error responding to friend request", { 
      error: error.message, 
      userId: auth.uid, 
      requestId 
    });
    throw new Error(error.message || "Failed to respond to friend request");
  }
});

// Block user
export const blockUser = onCall(async (request) => {
  const { data, auth } = request;
  const { targetUserId } = data as BlockUserData;

  if (!auth?.uid) {
    throw new Error("Authentication required");
  }

  if (auth.uid === targetUserId) {
    throw new Error("Cannot block yourself");
  }

  try {
    const friendshipId = getFriendshipId(auth.uid, targetUserId);
    const batch = db.batch();

    // Add to blocks list
    const userRef = db.collection("users").doc(auth.uid);
    batch.update(userRef, {
      blocks: admin.firestore.FieldValue.arrayUnion(targetUserId)
    });

    // Update friendship status if exists
    const friendshipRef = db.collection("friendships").doc(friendshipId);
    const friendship = await friendshipRef.get();
    
    if (friendship.exists) {
      const friendshipData = friendship.data()!;
      
      if (friendshipData.status === "accepted") {
        // Remove from friend counts
        batch.update(userRef, {
          "friends.counts.total": admin.firestore.FieldValue.increment(-1)
        });

        const otherUserRef = db.collection("users").doc(targetUserId);
        batch.update(otherUserRef, {
          "friends.counts.total": admin.firestore.FieldValue.increment(-1)
        });
      }

      batch.update(friendshipRef, {
        status: "blocked",
        blockedBy: auth.uid,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    await batch.commit();

    // Track analytics
    await analytics.track("user_blocked", {
      userId: auth.uid,
      targetUserId,
      friendshipId
    });

    logger.info(`User blocked: ${auth.uid} blocked ${targetUserId}`);

    return { success: true };

  } catch (error: any) {
    logger.error("Error blocking user", { 
      error: error.message, 
      userId: auth.uid, 
      targetUserId 
    });
    throw new Error(error.message || "Failed to block user");
  }
});

// Unblock user
export const unblockUser = onCall(async (request) => {
  const { data, auth } = request;
  const { targetUserId } = data as BlockUserData;

  if (!auth?.uid) {
    throw new Error("Authentication required");
  }

  try {
    // Remove from blocks list
    await db.collection("users").doc(auth.uid).update({
      blocks: admin.firestore.FieldValue.arrayRemove(targetUserId)
    });

    // Track analytics
    await analytics.track("user_unblocked", {
      userId: auth.uid,
      targetUserId
    });

    logger.info(`User unblocked: ${auth.uid} unblocked ${targetUserId}`);

    return { success: true };

  } catch (error: any) {
    logger.error("Error unblocking user", { 
      error: error.message, 
      userId: auth.uid, 
      targetUserId 
    });
    throw new Error(error.message || "Failed to unblock user");
  }
});