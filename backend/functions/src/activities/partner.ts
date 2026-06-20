import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { logger } from 'firebase-functions';
import { 
  PartnerRequest,
  PartnerRequestDraft,
  PartnerCandidate,
  UserTraits,
  ActivitiesError,
  ErrorCodes,
  ActivityCategory
} from './models';
import { incrementCounter } from '../shared/metrics';
import { haversineKm } from '../shared/geoHelpers';
import { sendNotification } from '../services/notifications/fcmService';

const db = admin.firestore();

// Create partner request
export const createPartnerRequest = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const draft: PartnerRequestDraft = data;
  const { 
    activityCategory, 
    cityId, 
    neighborhood, 
    skillLevel, 
    message, 
    desiredWindow, 
    preferredDays,
    frequency 
  } = draft;

  if (!activityCategory || !cityId || !message || !desiredWindow) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }

  try {
    // Rate limiting - check recent partner requests from user
    const recentRequests = await db.collection('partnerRequests')
      .where('organizerId', '==', context.auth.uid)
      .where('createdAt', '>', admin.firestore.Timestamp.fromDate(new Date(Date.now() - 60 * 60 * 1000))) // Last hour
      .get();

    if (recentRequests.size >= 5) { // Max 5 requests per hour
      throw new functions.https.HttpsError('resource-exhausted', 'Too many partner requests. Please wait before creating another.');
    }

    // Create partner request
    const partnerRequest: Omit<PartnerRequest, 'id'> = {
      organizerId: context.auth.uid,
      activityCategory,
      cityId,
      neighborhood,
      skillLevel,
      message,
      desiredWindow: {
        from: admin.firestore.Timestamp.fromDate(new Date(desiredWindow.from)),
        to: admin.firestore.Timestamp.fromDate(new Date(desiredWindow.to)),
      },
      preferredDays,
      frequency,
      status: 'open',
      interestedUserIds: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const doc = await db.collection('partnerRequests').add(partnerRequest);

    // Track interaction
    await db.collection('interactions').add({
      userId: context.auth.uid,
      type: 'invite',
      entityId: doc.id,
      entityType: 'partnerRequest',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      context: { category: activityCategory, cityId }
    });

    await incrementCounter('activities_partner_requests_created', 1);

    logger.info(`Partner request created: ${doc.id}`, {
      requestId: doc.id,
      organizerId: context.auth.uid,
      category: activityCategory,
      cityId
    });

    return { requestId: doc.id };

  } catch (error) {
    logger.error('Error creating partner request:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to create partner request');
  }
});

// List partner requests
export const listPartnerRequests = functions.https.onCall(async (data, context) => {
  const { cityId, category, limit = 20, neighborhood } = data;

  if (!cityId) {
    throw new functions.https.HttpsError('invalid-argument', 'City ID required');
  }

  try {
    let query = db.collection('partnerRequests')
      .where('cityId', '==', cityId)
      .where('status', '==', 'open')
      .orderBy('createdAt', 'desc')
      .limit(limit);

    if (category) {
      query = query.where('activityCategory', '==', category);
    }

    if (neighborhood) {
      query = query.where('neighborhood', '==', neighborhood);
    }

    const snapshot = await query.get();

    const requests = await Promise.all(snapshot.docs.map(async (doc) => {
      const requestData = { id: doc.id, ...doc.data() } as PartnerRequest;

      // Don't show user's own requests in the list
      if (context.auth && requestData.organizerId === context.auth.uid) {
        return null;
      }

      // Get organizer info (basic details only)
      try {
        const organizerRecord = await admin.auth().getUser(requestData.organizerId);
        (requestData as any).organizerName = organizerRecord.displayName || 'Anonymous';
        (requestData as any).organizerPhoto = organizerRecord.photoURL;
      } catch (error) {
        (requestData as any).organizerName = 'Anonymous';
      }

      // Hide sensitive info
      delete (requestData as any).organizerId;

      return requestData;
    }));

    return { 
      requests: requests.filter(r => r !== null),
      total: requests.length 
    };

  } catch (error) {
    logger.error('Error listing partner requests:', error);
    throw new functions.https.HttpsError('internal', 'Failed to list partner requests');
  }
});

// Express interest in partner request
export const expressInterest = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { requestId } = data;

  if (!requestId) {
    throw new functions.https.HttpsError('invalid-argument', 'Request ID required');
  }

  try {
    await db.runTransaction(async (transaction) => {
      const requestRef = db.collection('partnerRequests').doc(requestId);
      const requestDoc = await transaction.get(requestRef);

      if (!requestDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Partner request not found');
      }

      const requestData = requestDoc.data() as PartnerRequest;

      // Can't express interest in own request
      if (requestData.organizerId === context.auth!.uid) {
        throw new functions.https.HttpsError('invalid-argument', 'Cannot express interest in own request');
      }

      // Can't express interest if request is closed
      if (requestData.status !== 'open') {
        throw new functions.https.HttpsError('failed-precondition', 'Request is no longer open');
      }

      // Check if already interested
      if (requestData.interestedUserIds?.includes(context.auth!.uid)) {
        throw new functions.https.HttpsError('already-exists', 'Already expressed interest');
      }

      // Add user to interested list
      transaction.update(requestRef, {
        interestedUserIds: admin.firestore.FieldValue.arrayUnion(context.auth!.uid),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    // Get request details for notification
    const requestDoc = await db.collection('partnerRequests').doc(requestId).get();
    const requestData = requestDoc.data() as PartnerRequest;

    // Notify organizer
    await notifyPartnerInterest(requestData.organizerId, requestId, context.auth.uid);

    await incrementCounter('activities_partner_interests', 1);

    return { success: true };

  } catch (error) {
    logger.error('Error expressing interest:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to express interest');
  }
});

// Match partners based on request
export const matchPartners = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { requestId } = data;

  if (!requestId) {
    throw new functions.https.HttpsError('invalid-argument', 'Request ID required');
  }

  try {
    const requestDoc = await db.collection('partnerRequests').doc(requestId).get();

    if (!requestDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Partner request not found');
    }

    const requestData = requestDoc.data() as PartnerRequest;

    // Only organizer can match partners
    if (requestData.organizerId !== context.auth.uid) {
      throw new functions.https.HttpsError('permission-denied', 'Only request organizer can match partners');
    }

    // Get candidates based on interests and compatibility
    const candidates = await findPartnerCandidates(requestData);

    return { candidates };

  } catch (error) {
    logger.error('Error matching partners:', error);
    throw new functions.https.HttpsError('internal', 'Failed to match partners');
  }
});

// Accept partner and create group
export const acceptPartner = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { requestId, partnerUserId, groupName } = data;

  if (!requestId || !partnerUserId) {
    throw new functions.https.HttpsError('invalid-argument', 'Request ID and partner user ID required');
  }

  try {
    const result = await db.runTransaction(async (transaction) => {
      const requestRef = db.collection('partnerRequests').doc(requestId);
      const requestDoc = await transaction.get(requestRef);

      if (!requestDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Partner request not found');
      }

      const requestData = requestDoc.data() as PartnerRequest;

      // Only organizer can accept partners
      if (requestData.organizerId !== context.auth!.uid) {
        throw new functions.https.HttpsError('permission-denied', 'Only request organizer can accept partners');
      }

      // Check if partner expressed interest
      if (!requestData.interestedUserIds?.includes(partnerUserId)) {
        throw new functions.https.HttpsError('invalid-argument', 'Partner did not express interest');
      }

      // Create group for the matched partners
      const group = {
        organizerId: context.auth!.uid,
        name: groupName || `${requestData.activityCategory} Group`,
        cityId: requestData.cityId,
        status: 'planning',
        preferences: {
          categories: [requestData.activityCategory],
          skillLevel: requestData.skillLevel,
          timeBands: requestData.preferredDays,
        },
        invitedUserIds: [],
        participantUserIds: [context.auth!.uid, partnerUserId],
        partnerRequestId: requestId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      const groupRef = db.collection('groups').doc();
      transaction.set(groupRef, group);

      // Update partner request status
      transaction.update(requestRef, {
        status: 'matched',
        matchedGroupId: groupRef.id,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { groupId: groupRef.id };
    });

    // Notify accepted partner
    await notifyPartnerAccepted(partnerUserId, requestId, result.groupId);

    await incrementCounter('activities_partners_matched', 1);

    logger.info(`Partners matched: ${requestId}`, {
      requestId,
      groupId: result.groupId,
      organizerId: context.auth.uid,
      partnerId: partnerUserId
    });

    return { success: true, groupId: result.groupId };

  } catch (error) {
    logger.error('Error accepting partner:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to accept partner');
  }
});

// Close partner request
export const closePartnerRequest = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { requestId } = data;

  if (!requestId) {
    throw new functions.https.HttpsError('invalid-argument', 'Request ID required');
  }

  try {
    await db.runTransaction(async (transaction) => {
      const requestRef = db.collection('partnerRequests').doc(requestId);
      const requestDoc = await transaction.get(requestRef);

      if (!requestDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Partner request not found');
      }

      const requestData = requestDoc.data() as PartnerRequest;

      // Only organizer can close request
      if (requestData.organizerId !== context.auth!.uid) {
        throw new functions.https.HttpsError('permission-denied', 'Only request organizer can close request');
      }

      transaction.update(requestRef, {
        status: 'closed',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return { success: true };

  } catch (error) {
    logger.error('Error closing partner request:', error);
    throw new functions.https.HttpsError('internal', 'Failed to close partner request');
  }
});

// Helper function to find partner candidates
async function findPartnerCandidates(request: PartnerRequest): Promise<PartnerCandidate[]> {
  try {
    const candidates: PartnerCandidate[] = [];

    // Get users who expressed interest
    if (request.interestedUserIds && request.interestedUserIds.length > 0) {
      const interestedUsers = await Promise.all(
        request.interestedUserIds.map(async (userId) => {
          try {
            const userRecord = await admin.auth().getUser(userId);
            const matchScore = await calculateMatchScore(userId, request);
            
            return {
              userId,
              userName: userRecord.displayName || 'User',
              matchScore,
              reasonCodes: ['Expressed interest'],
            };
          } catch (error) {
            logger.warn(`Failed to get user info for ${userId}:`, error);
            return null;
          }
        })
      );

      candidates.push(...interestedUsers.filter(u => u !== null) as PartnerCandidate[]);
    }

    // Sort by match score
    candidates.sort((a, b) => b.matchScore - a.matchScore);

    return candidates.slice(0, 10); // Return top 10 candidates

  } catch (error) {
    logger.error('Error finding partner candidates:', error);
    return [];
  }
}

// Helper function to calculate match score
async function calculateMatchScore(userId: string, request: PartnerRequest): Promise<number> {
  let score = 50; // Base score

  try {
    // Get user traits if available
    const userTraitsDoc = await db.collection('userTraits').doc(userId).get();
    if (userTraitsDoc.exists) {
      const traits = userTraitsDoc.data() as UserTraits;

      // Match on favorite sports/activities
      if (traits.traits.favoriteSports?.includes(request.activityCategory)) {
        score += 20;
      }

      // Match on skill level
      if (traits.traits.skillLevels?.[request.activityCategory] === request.skillLevel) {
        score += 15;
      }

      // Match on preferred days
      if (request.preferredDays && traits.traits.preferredDays) {
        const commonDays = request.preferredDays.filter(day => 
          traits.traits.preferredDays!.includes(day)
        ).length;
        score += commonDays * 5;
      }
    }

    // Get user's recent activities in same category
    const recentActivities = await db.collection('interactions')
      .where('userId', '==', userId)
      .where('entityType', '==', 'activity')
      .where('type', 'in', ['view', 'book'])
      .orderBy('timestamp', 'desc')
      .limit(10)
      .get();

    // Check if user has engaged with similar activities
    for (const doc of recentActivities.docs) {
      const interaction = doc.data();
      const activityDoc = await db.collection('activities').doc(interaction.entityId).get();
      
      if (activityDoc.exists && activityDoc.data()!.category === request.activityCategory) {
        score += 10;
        break; // Only count once
      }
    }

  } catch (error) {
    logger.warn(`Error calculating match score for ${userId}:`, error);
  }

  return Math.min(score, 100); // Cap at 100
}

// Helper function to notify about partner interest
async function notifyPartnerInterest(
  organizerId: string, 
  requestId: string, 
  interestedUserId: string
): Promise<void> {
  try {
    const interestedUser = await admin.auth().getUser(interestedUserId);
    const userName = interestedUser.displayName || 'Someone';

    await sendNotification(organizerId, {
      title: 'New Partner Interest',
      body: `${userName} is interested in your activity partner request`,
      data: {
        type: 'partner_interest',
        requestId: requestId,
        interestedUserId: interestedUserId,
      }
    });
  } catch (error) {
    logger.warn('Failed to send partner interest notification:', error);
  }
}

// Helper function to notify about partner acceptance
async function notifyPartnerAccepted(
  partnerId: string, 
  requestId: string, 
  groupId: string
): Promise<void> {
  try {
    await sendNotification(partnerId, {
      title: 'Partner Match! 🎉',
      body: 'You have been matched with an activity partner',
      data: {
        type: 'partner_matched',
        requestId: requestId,
        groupId: groupId,
      }
    });
  } catch (error) {
    logger.warn('Failed to send partner acceptance notification:', error);
  }
}