import * as admin from "firebase-admin";
import { onCall } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { analytics } from "../shared/analytics";
import * as crypto from "crypto";

const db = admin.firestore();

interface CreateInviteData {
  context?: {
    source: string;
    featureId?: string;
    metadata?: any;
  };
  maxUses?: number;
  expiresInDays?: number;
}

interface ResolveInviteData {
  code: string;
}

interface ImportContactsData {
  hashedPhones: string[];
}

// Generate secure invite code
function generateInviteCode(): string {
  return crypto.randomBytes(8).toString('hex').toLowerCase();
}

// Create invite link
export const createInvite = onCall(async (request) => {
  const { data, auth } = request;
  const { context, maxUses = 10, expiresInDays = 30 } = data as CreateInviteData;

  if (!auth?.uid) {
    throw new Error("Authentication required");
  }

  if (maxUses > 100) {
    throw new Error("Max uses cannot exceed 100");
  }

  if (expiresInDays > 365) {
    throw new Error("Invite cannot expire more than 365 days from now");
  }

  try {
    const code = generateInviteCode();
    const expiresAt = new Date(Date.now() + expiresInDays * 24 * 60 * 60 * 1000);

    const inviteData = {
      inviterId: auth.uid,
      code,
      maxUses,
      usedBy: [],
      usageCount: 0,
      context: context || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt
    };

    const inviteRef = db.collection("invites").doc(code);
    await inviteRef.set(inviteData);

    // Track analytics
    await analytics.track("invite_created", {
      userId: auth.uid,
      code,
      maxUses,
      expiresInDays,
      context: context?.source || "general"
    });

    logger.info(`Invite created: ${code} by ${auth.uid}`);

    // Return the deep link URL
    const inviteUrl = `https://liive.app/invite/${code}`;

    return { 
      code,
      url: inviteUrl,
      expiresAt: expiresAt.toISOString()
    };

  } catch (error: any) {
    logger.error("Error creating invite", { 
      error: error.message, 
      userId: auth.uid 
    });
    throw new Error(error.message || "Failed to create invite");
  }
});

// Resolve invite code
export const resolveInvite = onCall(async (request) => {
  const { data, auth } = request;
  const { code } = data as ResolveInviteData;

  if (!auth?.uid) {
    throw new Error("Authentication required");
  }

  if (!code) {
    throw new Error("Invite code required");
  }

  try {
    const inviteRef = db.collection("invites").doc(code);
    const invite = await inviteRef.get();

    if (!invite.exists) {
      throw new Error("Invite not found");
    }

    const inviteData = invite.data()!;

    // Check if invite is expired
    if (inviteData.expiresAt.toDate() < new Date()) {
      throw new Error("Invite has expired");
    }

    // Check if invite has reached max uses
    if (inviteData.usageCount >= inviteData.maxUses) {
      throw new Error("Invite has reached maximum uses");
    }

    // Check if user has already used this invite
    if (inviteData.usedBy.includes(auth.uid)) {
      throw new Error("You have already used this invite");
    }

    // Can't use your own invite
    if (inviteData.inviterId === auth.uid) {
      throw new Error("Cannot use your own invite");
    }

    // Get inviter information
    const inviterRef = db.collection("users").doc(inviteData.inviterId);
    const inviter = await inviterRef.get();

    if (!inviter.exists) {
      throw new Error("Inviter not found");
    }

    const inviterData = inviter.data()!;

    // Check if already friends
    const friendshipId = auth.uid < inviteData.inviterId ? 
      `${auth.uid}_${inviteData.inviterId}` : 
      `${inviteData.inviterId}_${auth.uid}`;
    
    const existingFriendship = await db.collection("friendships").doc(friendshipId).get();
    
    let friendshipStatus = 'none';
    if (existingFriendship.exists) {
      friendshipStatus = existingFriendship.data()?.status || 'none';
    }

    // Update invite usage
    await inviteRef.update({
      usedBy: admin.firestore.FieldValue.arrayUnion(auth.uid),
      usageCount: admin.firestore.FieldValue.increment(1)
    });

    // Track analytics
    await analytics.track("invite_resolved", {
      userId: auth.uid,
      inviterId: inviteData.inviterId,
      code,
      friendshipStatus,
      context: inviteData.context?.source || "general"
    });

    logger.info(`Invite resolved: ${code} by ${auth.uid}`);

    return {
      inviter: {
        id: inviteData.inviterId,
        displayName: inviterData.profile?.displayName || "Unknown",
        photoURL: inviterData.profile?.photoURL || null
      },
      friendshipStatus,
      context: inviteData.context
    };

  } catch (error: any) {
    logger.error("Error resolving invite", { 
      error: error.message, 
      userId: auth.uid, 
      code 
    });
    throw new Error(error.message || "Failed to resolve invite");
  }
});

// Import contacts (hashed phone numbers)
export const importContacts = onCall(async (request) => {
  const { data, auth } = request;
  const { hashedPhones } = data as ImportContactsData;

  if (!auth?.uid) {
    throw new Error("Authentication required");
  }

  if (!hashedPhones || !Array.isArray(hashedPhones) || hashedPhones.length === 0) {
    throw new Error("Hashed phone numbers required");
  }

  // Limit batch size for performance
  if (hashedPhones.length > 1000) {
    throw new Error("Too many contacts (max 1000 per request)");
  }

  try {
    // Query users collection for matching hashed phone numbers
    // Note: This assumes phone numbers are hashed and stored in user profiles
    const matchedUsers: any[] = [];
    const batchSize = 10; // Firestore 'in' query limit
    
    for (let i = 0; i < hashedPhones.length; i += batchSize) {
      const batch = hashedPhones.slice(i, i + batchSize);
      
      const query = db.collection("users")
        .where("profile.hashedPhone", "in", batch)
        .limit(batchSize);
      
      const results = await query.get();
      
      results.docs.forEach(doc => {
        const userData = doc.data();
        // Don't return the user's own profile
        if (doc.id !== auth.uid) {
          matchedUsers.push({
            id: doc.id,
            displayName: userData.profile?.displayName || "Unknown",
            photoURL: userData.profile?.photoURL || null,
            hashedPhone: userData.profile?.hashedPhone
          });
        }
      });
    }

    // Check existing friendships to provide context
    const friendshipPromises = matchedUsers.map(async (user) => {
      const friendshipId = auth.uid < user.id ? 
        `${auth.uid}_${user.id}` : 
        `${user.id}_${auth.uid}`;
      
      const friendship = await db.collection("friendships").doc(friendshipId).get();
      
      return {
        ...user,
        friendshipStatus: friendship.exists ? friendship.data()?.status : 'none'
      };
    });

    const usersWithFriendshipStatus = await Promise.all(friendshipPromises);

    // Track analytics
    await analytics.track("contacts_imported", {
      userId: auth.uid,
      totalContacts: hashedPhones.length,
      matchedContacts: matchedUsers.length,
      alreadyFriends: usersWithFriendshipStatus.filter(u => u.friendshipStatus === 'accepted').length
    });

    logger.info(`Contacts imported for ${auth.uid}: ${matchedUsers.length} matches from ${hashedPhones.length} contacts`);

    return {
      matches: usersWithFriendshipStatus,
      totalMatches: matchedUsers.length
    };

  } catch (error: any) {
    logger.error("Error importing contacts", { 
      error: error.message, 
      userId: auth.uid, 
      contactCount: hashedPhones.length 
    });
    throw new Error(error.message || "Failed to import contacts");
  }
});

// Get invite statistics for user
export const getInviteStats = onCall(async (request) => {
  const { auth } = request;

  if (!auth?.uid) {
    throw new Error("Authentication required");
  }

  try {
    // Get user's invites
    const invitesQuery = db.collection("invites")
      .where("inviterId", "==", auth.uid)
      .orderBy("createdAt", "desc")
      .limit(50);

    const invites = await invitesQuery.get();
    
    let totalInvites = 0;
    let totalUses = 0;
    let activeInvites = 0;

    const now = new Date();

    invites.docs.forEach(doc => {
      const data = doc.data();
      totalInvites++;
      totalUses += data.usageCount || 0;
      
      if (data.expiresAt.toDate() > now && data.usageCount < data.maxUses) {
        activeInvites++;
      }
    });

    return {
      totalInvites,
      totalUses,
      activeInvites,
      conversionRate: totalInvites > 0 ? (totalUses / totalInvites) : 0
    };

  } catch (error: any) {
    logger.error("Error getting invite stats", { 
      error: error.message, 
      userId: auth.uid 
    });
    throw new Error(error.message || "Failed to get invite statistics");
  }
});