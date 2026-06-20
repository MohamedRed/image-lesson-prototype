import * as admin from "firebase-admin";
import { onCall } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { analytics } from "../shared/analytics";
import * as crypto from "crypto";

const db = admin.firestore();

interface HashContactsData {
  phoneNumbers: string[];
}

interface FindByPhoneData {
  hashedPhone: string;
}

// Server-side salt for phone number hashing (should be in environment variables)
const PHONE_HASH_SALT = process.env.PHONE_HASH_SALT || "default-salt-change-in-production";

// Hash phone number with server-side salt for privacy
function hashPhoneNumber(phoneNumber: string): string {
  // Normalize phone number (remove spaces, dashes, etc.)
  const normalized = phoneNumber.replace(/[\s\-\(\)]/g, '');
  
  // Add server-side salt and hash
  return crypto
    .createHash('sha256')
    .update(normalized + PHONE_HASH_SALT)
    .digest('hex');
}

// Hash contacts (server-side to protect against rainbow tables)
export const hashContacts = onCall(async (request) => {
  const { data, auth } = request;
  const { phoneNumbers } = data as HashContactsData;

  if (!auth?.uid) {
    throw new Error("Authentication required");
  }

  if (!phoneNumbers || !Array.isArray(phoneNumbers)) {
    throw new Error("Phone numbers array required");
  }

  // Limit for privacy and performance
  if (phoneNumbers.length > 2000) {
    throw new Error("Too many phone numbers (max 2000)");
  }

  try {
    // Hash phone numbers server-side
    const hashedPhones = phoneNumbers.map(phone => {
      try {
        return hashPhoneNumber(phone);
      } catch (error) {
        return null; // Invalid phone number
      }
    }).filter(hash => hash !== null);

    // Track analytics (without storing actual phone numbers)
    await analytics.track("contacts_hashed", {
      userId: auth.uid,
      totalContacts: phoneNumbers.length,
      validContacts: hashedPhones.length
    });

    return { hashedPhones };

  } catch (error: any) {
    logger.error("Error hashing contacts", { 
      error: error.message, 
      userId: auth.uid,
      contactCount: phoneNumbers.length 
    });
    throw new Error("Failed to hash contacts");
  }
});

// Find users by hashed phone numbers
export const findUsersByHashedPhone = onCall(async (request) => {
  const { data, auth } = request;
  const { hashedPhones } = data as { hashedPhones: string[] };

  if (!auth?.uid) {
    throw new Error("Authentication required");
  }

  if (!hashedPhones || !Array.isArray(hashedPhones)) {
    throw new Error("Hashed phone numbers required");
  }

  if (hashedPhones.length > 1000) {
    throw new Error("Too many hashed phones (max 1000)");
  }

  try {
    const matches: any[] = [];
    const batchSize = 10; // Firestore 'in' query limit

    // Process in batches due to Firestore limitations
    for (let i = 0; i < hashedPhones.length; i += batchSize) {
      const batch = hashedPhones.slice(i, i + batchSize);
      
      const query = db.collection("users")
        .where("profile.hashedPhone", "in", batch)
        .select("profile.displayName", "profile.photoURL", "profile.hashedPhone");
      
      const results = await query.get();
      
      for (const doc of results.docs) {
        const userData = doc.data();
        
        // Don't include the requesting user
        if (doc.id === auth.uid) continue;

        // Check if already blocked
        const userDoc = await db.collection("users").doc(auth.uid).get();
        const blockedUsers = userDoc.data()?.blocks || [];
        
        if (blockedUsers.includes(doc.id)) continue;

        // Check friendship status
        const friendshipId = auth.uid < doc.id ? 
          `${auth.uid}_${doc.id}` : 
          `${doc.id}_${auth.uid}`;
        
        const friendship = await db.collection("friendships").doc(friendshipId).get();
        const friendshipStatus = friendship.exists ? friendship.data()?.status : 'none';

        matches.push({
          userId: doc.id,
          displayName: userData.profile?.displayName || "Unknown",
          photoURL: userData.profile?.photoURL || null,
          hashedPhone: userData.profile?.hashedPhone,
          friendshipStatus
        });
      }
    }

    // Track analytics
    await analytics.track("users_found_by_contacts", {
      userId: auth.uid,
      searchedContacts: hashedPhones.length,
      foundUsers: matches.length,
      alreadyFriends: matches.filter(m => m.friendshipStatus === 'accepted').length
    });

    return { matches };

  } catch (error: any) {
    logger.error("Error finding users by phone", { 
      error: error.message, 
      userId: auth.uid,
      hashedPhoneCount: hashedPhones.length 
    });
    throw new Error("Failed to find users");
  }
});

// Search users by handle/email (for direct search)
export const searchUsers = onCall(async (request) => {
  const { data, auth } = request;
  const { query, limit = 20 } = data;

  if (!auth?.uid) {
    throw new Error("Authentication required");
  }

  if (!query || typeof query !== 'string') {
    throw new Error("Search query required");
  }

  if (query.length < 3) {
    throw new Error("Query must be at least 3 characters");
  }

  if (limit > 50) {
    throw new Error("Limit too high (max 50)");
  }

  try {
    const results: any[] = [];

    // Search by display name (case-insensitive prefix)
    const nameQuery = db.collection("users")
      .where("profile.displayNameLower", ">=", query.toLowerCase())
      .where("profile.displayNameLower", "<=", query.toLowerCase() + '\uf8ff')
      .limit(limit);

    const nameResults = await nameQuery.get();

    // Search by username/handle if it exists
    const handleQuery = db.collection("users")
      .where("profile.handle", ">=", query.toLowerCase())
      .where("profile.handle", "<=", query.toLowerCase() + '\uf8ff')
      .limit(limit);

    const handleResults = await handleQuery.get();

    // Combine and deduplicate results
    const seenIds = new Set<string>();
    
    const processResults = async (queryResults: admin.firestore.QuerySnapshot) => {
      for (const doc of queryResults.docs) {
        if (doc.id === auth.uid) continue; // Don't include self
        if (seenIds.has(doc.id)) continue; // Deduplicate
        
        seenIds.add(doc.id);
        
        const userData = doc.data();
        
        // Check if user is blocked
        const userDoc = await db.collection("users").doc(auth.uid).get();
        const blockedUsers = userDoc.data()?.blocks || [];
        
        if (blockedUsers.includes(doc.id)) continue;

        // Get friendship status
        const friendshipId = auth.uid < doc.id ? 
          `${auth.uid}_${doc.id}` : 
          `${doc.id}_${auth.uid}`;
        
        const friendship = await db.collection("friendships").doc(friendshipId).get();
        const friendshipStatus = friendship.exists ? friendship.data()?.status : 'none';

        results.push({
          userId: doc.id,
          displayName: userData.profile?.displayName || "Unknown",
          handle: userData.profile?.handle || null,
          photoURL: userData.profile?.photoURL || null,
          city: userData.profile?.city || null,
          friendshipStatus
        });
      }
    };

    await processResults(nameResults);
    await processResults(handleResults);

    // Sort by friendship status (friends first, then by name)
    results.sort((a, b) => {
      if (a.friendshipStatus === 'accepted' && b.friendshipStatus !== 'accepted') return -1;
      if (b.friendshipStatus === 'accepted' && a.friendshipStatus !== 'accepted') return 1;
      return a.displayName.localeCompare(b.displayName);
    });

    // Track analytics
    await analytics.track("users_searched", {
      userId: auth.uid,
      query: query.substring(0, 10), // Only log first 10 chars for privacy
      resultsCount: results.length
    });

    return { 
      results: results.slice(0, limit),
      hasMore: results.length >= limit
    };

  } catch (error: any) {
    logger.error("Error searching users", { 
      error: error.message, 
      userId: auth.uid,
      queryLength: query?.length 
    });
    throw new Error("Failed to search users");
  }
});

// Get mutual friends between two users
export const getMutualFriends = onCall(async (request) => {
  const { data, auth } = request;
  const { targetUserId, limit = 10 } = data;

  if (!auth?.uid) {
    throw new Error("Authentication required");
  }

  if (!targetUserId) {
    throw new Error("Target user ID required");
  }

  if (targetUserId === auth.uid) {
    throw new Error("Cannot get mutual friends with yourself");
  }

  try {
    // Get friendships for both users
    const currentUserFriendsQuery = db.collection("friendships")
      .where("users", "array-contains", auth.uid)
      .where("status", "==", "accepted");

    const targetUserFriendsQuery = db.collection("friendships")
      .where("users", "array-contains", targetUserId)
      .where("status", "==", "accepted");

    const [currentUserFriends, targetUserFriends] = await Promise.all([
      currentUserFriendsQuery.get(),
      targetUserFriendsQuery.get()
    ]);

    // Find mutual friend IDs
    const currentUserFriendIds = new Set<string>();
    currentUserFriends.docs.forEach(doc => {
      const users = doc.data().users;
      const friendId = users.find((id: string) => id !== auth.uid);
      if (friendId) currentUserFriendIds.add(friendId);
    });

    const mutualFriendIds: string[] = [];
    targetUserFriends.docs.forEach(doc => {
      const users = doc.data().users;
      const friendId = users.find((id: string) => id !== targetUserId);
      if (friendId && currentUserFriendIds.has(friendId)) {
        mutualFriendIds.push(friendId);
      }
    });

    // Get mutual friend profiles
    const mutualFriends: any[] = [];
    const limitedIds = mutualFriendIds.slice(0, limit);

    for (const friendId of limitedIds) {
      const friendDoc = await db.collection("users").doc(friendId).get();
      if (friendDoc.exists) {
        const friendData = friendDoc.data()!;
        mutualFriends.push({
          userId: friendId,
          displayName: friendData.profile?.displayName || "Unknown",
          photoURL: friendData.profile?.photoURL || null
        });
      }
    }

    return {
      mutualFriends,
      totalCount: mutualFriendIds.length,
      hasMore: mutualFriendIds.length > limit
    };

  } catch (error: any) {
    logger.error("Error getting mutual friends", { 
      error: error.message, 
      userId: auth.uid,
      targetUserId 
    });
    throw new Error("Failed to get mutual friends");
  }
});