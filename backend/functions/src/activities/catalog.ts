import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { logger } from 'firebase-functions';
import { 
  Activity, 
  ActivityProvider, 
  ActivitySession, 
  ActivitiesError, 
  ErrorCodes 
} from './models';
import { incrementCounter } from '../shared/metrics';
import { withTrace } from '../shared/trace';

const db = admin.firestore();

// Provider Management
export const createProvider = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { name, type, contact, geo, amenities = [] } = data;

  if (!name || !type || !geo) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }

  try {
    const provider: Omit<ActivityProvider, 'id'> = {
      name,
      type,
      contact: contact || {},
      geo: {
        lat: geo.lat,
        lng: geo.lng,
        city: geo.city,
        neighborhood: geo.neighborhood,
        address: geo.address,
      },
      amenities,
      verificationTier: 'unverified',
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const doc = await db.collection('activitiesProviders').add(provider);
    await incrementCounter('activities_providers_created', 1);

    logger.info(`Created provider: ${doc.id}`, { providerId: doc.id, userId: context.auth.uid });

    return { providerId: doc.id };
  } catch (error) {
    logger.error('Error creating provider:', error);
    throw new functions.https.HttpsError('internal', 'Failed to create provider');
  }
});

export const updateProvider = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { providerId, updates } = data;

  if (!providerId) {
    throw new functions.https.HttpsError('invalid-argument', 'Provider ID required');
  }

  try {
    // TODO: Add authorization check - user owns provider
    const providerRef = db.collection('activitiesProviders').doc(providerId);
    
    await providerRef.update({
      ...updates,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await incrementCounter('activities_providers_updated', 1);

    return { success: true };
  } catch (error) {
    logger.error('Error updating provider:', error);
    throw new functions.https.HttpsError('internal', 'Failed to update provider');
  }
});

export const getProvider = functions.https.onCall(async (data, context) => {
  const { providerId } = data;

  if (!providerId) {
    throw new functions.https.HttpsError('invalid-argument', 'Provider ID required');
  }

  try {
    const doc = await db.collection('activitiesProviders').doc(providerId).get();
    
    if (!doc.exists) {
      throw new functions.https.HttpsError('not-found', 'Provider not found');
    }

    return {
      id: doc.id,
      ...doc.data()
    };
  } catch (error) {
    logger.error('Error getting provider:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get provider');
  }
});

// Activity Management
export const createActivity = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const {
    providerId,
    title,
    category,
    description,
    images = [],
    rules = [],
    minParticipants,
    maxParticipants,
    pricePerUnit,
    unit,
    durationMinutes,
    location,
    tags = [],
    ageRestrictions,
    skillLevel,
    equipmentNeeded = [],
  } = data;

  if (!providerId || !title || !category || !minParticipants || !maxParticipants || !pricePerUnit || !unit || !durationMinutes || !location) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }

  try {
    // Verify provider exists
    const providerDoc = await db.collection('activitiesProviders').doc(providerId).get();
    if (!providerDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Provider not found');
    }

    const activity: Omit<Activity, 'id'> = {
      providerId,
      title,
      category,
      description,
      images,
      rules,
      minParticipants,
      maxParticipants,
      pricePerUnit,
      unit,
      durationMinutes,
      location: {
        lat: location.lat,
        lng: location.lng,
        address: location.address,
        neighborhood: location.neighborhood,
      },
      tags,
      ageRestrictions,
      skillLevel,
      equipmentNeeded,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const doc = await db.collection('activities').add(activity);
    await incrementCounter('activities_created', 1);

    logger.info(`Created activity: ${doc.id}`, { activityId: doc.id, providerId, userId: context.auth.uid });

    return { activityId: doc.id };
  } catch (error) {
    logger.error('Error creating activity:', error);
    throw new functions.https.HttpsError('internal', 'Failed to create activity');
  }
});

export const updateActivity = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { activityId, updates } = data;

  if (!activityId) {
    throw new functions.https.HttpsError('invalid-argument', 'Activity ID required');
  }

  try {
    // TODO: Add authorization check - user owns provider that owns activity
    const activityRef = db.collection('activities').doc(activityId);
    
    await activityRef.update({
      ...updates,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await incrementCounter('activities_updated', 1);

    return { success: true };
  } catch (error) {
    logger.error('Error updating activity:', error);
    throw new functions.https.HttpsError('internal', 'Failed to update activity');
  }
});

export const getActivity = functions.https.onCall(async (data, context) => {
  const { activityId } = data;

  if (!activityId) {
    throw new functions.https.HttpsError('invalid-argument', 'Activity ID required');
  }

  try {
    const doc = await db.collection('activities').doc(activityId).get();
    
    if (!doc.exists) {
      throw new functions.https.HttpsError('not-found', 'Activity not found');
    }

    const activity = {
      id: doc.id,
      ...doc.data()
    };

    // Track view interaction if user is authenticated
    if (context.auth) {
      await db.collection('interactions').add({
        userId: context.auth.uid,
        type: 'view',
        entityId: activityId,
        entityType: 'activity',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return activity;
  } catch (error) {
    logger.error('Error getting activity:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get activity');
  }
});

// Session Management
export const createSession = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const {
    activityId,
    startAt,
    endAt,
    capacity,
    priceOverride,
    bookingWindow,
  } = data;

  if (!activityId || !startAt || !endAt || !capacity) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }

  try {
    // Verify activity exists
    const activityDoc = await db.collection('activities').doc(activityId).get();
    if (!activityDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Activity not found');
    }

    const startDate = new Date(startAt);
    const endDate = new Date(endAt);

    const session: Omit<ActivitySession, 'id'> = {
      activityId,
      startAt: admin.firestore.Timestamp.fromDate(startDate),
      endAt: admin.firestore.Timestamp.fromDate(endDate),
      capacity,
      bookedCount: 0,
      priceOverride,
      bookingWindow: bookingWindow ? {
        opensAt: admin.firestore.Timestamp.fromDate(new Date(bookingWindow.opensAt)),
        closesAt: admin.firestore.Timestamp.fromDate(new Date(bookingWindow.closesAt)),
      } : {
        opensAt: admin.firestore.Timestamp.now(),
        closesAt: admin.firestore.Timestamp.fromDate(startDate),
      },
      status: 'open',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const doc = await db.collection('activitySessions').add(session);
    await incrementCounter('activity_sessions_created', 1);

    logger.info(`Created session: ${doc.id}`, { sessionId: doc.id, activityId, userId: context.auth.uid });

    return { sessionId: doc.id };
  } catch (error) {
    logger.error('Error creating session:', error);
    throw new functions.https.HttpsError('internal', 'Failed to create session');
  }
});

export const listAvailability = functions.https.onCall(async (data, context) => {
  const { activityId, from, to } = data;

  if (!activityId) {
    throw new functions.https.HttpsError('invalid-argument', 'Activity ID required');
  }

  try {
    const fromDate = from ? admin.firestore.Timestamp.fromDate(new Date(from)) : admin.firestore.Timestamp.now();
    const toDate = to ? admin.firestore.Timestamp.fromDate(new Date(to)) : admin.firestore.Timestamp.fromDate(new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)); // 30 days

    const sessionsSnapshot = await db.collection('activitySessions')
      .where('activityId', '==', activityId)
      .where('startAt', '>=', fromDate)
      .where('startAt', '<=', toDate)
      .where('status', 'in', ['open', 'limited'])
      .orderBy('startAt')
      .limit(50)
      .get();

    const sessions = sessionsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      // Convert timestamps back to ISO strings for client
      startAt: doc.data().startAt.toDate().toISOString(),
      endAt: doc.data().endAt.toDate().toISOString(),
      bookingWindow: {
        opensAt: doc.data().bookingWindow.opensAt.toDate().toISOString(),
        closesAt: doc.data().bookingWindow.closesAt.toDate().toISOString(),
      }
    }));

    return { sessions };
  } catch (error) {
    logger.error('Error listing availability:', error);
    throw new functions.https.HttpsError('internal', 'Failed to list availability');
  }
});

// Bulk operations and ingestion
export const ingestFromUrl = functions
  .runWith({
    timeoutSeconds: 300,
    memory: '1GB'
  })
  .https.onRequest(async (req, res) => {
    // Admin-only endpoint for bulk ingestion
    // TODO: Add proper admin authentication
    
    if (req.method !== 'POST') {
      res.status(405).send('Method not allowed');
      return;
    }

    try {
      const { url, providerId } = req.body;

      if (!url || !providerId) {
        res.status(400).send('Missing required fields');
        return;
      }

      // Verify provider exists
      const providerDoc = await db.collection('activitiesProviders').doc(providerId).get();
      if (!providerDoc.exists) {
        res.status(404).send('Provider not found');
        return;
      }

      // TODO: Implement actual web scraping/API ingestion
      // This is a placeholder for the ingestion logic
      logger.info(`Ingestion requested for URL: ${url}, Provider: ${providerId}`);

      // For now, return success
      res.json({ 
        success: true, 
        message: 'Ingestion queued for processing',
        ingestId: `ingest_${Date.now()}`
      });

    } catch (error) {
      logger.error('Error in bulk ingestion:', error);
      res.status(500).send('Internal server error');
    }
  });

// Update session status based on bookings
export const updateSessionStatus = async (sessionId: string): Promise<void> => {
  const sessionRef = db.collection('activitySessions').doc(sessionId);
  
  await db.runTransaction(async (transaction) => {
    const sessionDoc = await transaction.get(sessionRef);
    
    if (!sessionDoc.exists) {
      throw new ActivitiesError(ErrorCodes.SESSION_NOT_AVAILABLE, 'Session not found');
    }

    const sessionData = sessionDoc.data() as ActivitySession;
    const { capacity, bookedCount } = sessionData;

    let newStatus: ActivitySession['status'] = 'open';
    
    if (bookedCount >= capacity) {
      newStatus = 'full';
    } else if (bookedCount >= capacity * 0.8) { // 80% threshold for limited
      newStatus = 'limited';
    } else {
      newStatus = 'open';
    }

    if (sessionData.status !== newStatus) {
      transaction.update(sessionRef, {
        status: newStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });
};