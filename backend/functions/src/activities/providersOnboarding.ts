import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { logger } from 'firebase-functions';
import { onRequest } from 'firebase-functions/v2/https';
import { 
  ActivityProvider,
  Activity,
  ActivitySession,
  ProviderType,
  ProviderApplication,
  ProviderVerificationTier,
  ActivityCategory,
  SkillLevel,
  WeatherDependency
} from './models';
import { incrementCounter } from '../shared/metrics';
import { getStripeClient } from '../services/payments/stripeService';
import { sendNotification } from '../services/notifications/fcmService';

const db = admin.firestore();

// Provider application submission
export const submitProviderApplication = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const application = data as ProviderApplication;
  const { 
    businessName, 
    businessType, 
    contactInfo, 
    location, 
    description, 
    categories,
    businessLicense,
    taxId 
  } = application;

  // Validate required fields
  if (!businessName || !businessType || !contactInfo?.email || !location) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }

  try {
    // Check if user already has a pending/approved application
    const existingApp = await db.collection('providerApplications')
      .where('applicantUserId', '==', context.auth.uid)
      .where('status', 'in', ['pending', 'approved'])
      .get();

    if (!existingApp.empty) {
      throw new functions.https.HttpsError('already-exists', 'Application already exists');
    }

    // Create application
    const applicationDoc = await db.collection('providerApplications').add({
      applicantUserId: context.auth.uid,
      businessName,
      businessType,
      contactInfo,
      location,
      description,
      categories: categories || [],
      businessLicense,
      taxId,
      status: 'pending',
      verificationTier: 'unverified' as ProviderVerificationTier,
      submittedAt: admin.firestore.FieldValue.serverTimestamp(),
      reviewedAt: null,
      reviewedBy: null,
      rejectionReason: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    await incrementCounter('activities_provider_applications_submitted', 1);

    logger.info('Provider application submitted', {
      applicationId: applicationDoc.id,
      userId: context.auth.uid,
      businessName
    });

    return { applicationId: applicationDoc.id };

  } catch (error) {
    logger.error('Error submitting provider application:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to submit application');
  }
});

// Get provider application status
export const getProviderApplicationStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  try {
    const applicationSnapshot = await db.collection('providerApplications')
      .where('applicantUserId', '==', context.auth.uid)
      .orderBy('submittedAt', 'desc')
      .limit(1)
      .get();

    if (applicationSnapshot.empty) {
      return { application: null };
    }

    const application = { 
      id: applicationSnapshot.docs[0].id, 
      ...applicationSnapshot.docs[0].data() 
    };

    return { application };

  } catch (error) {
    logger.error('Error getting application status:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get application status');
  }
});

// Provider profile management (once approved)
export const updateProviderProfile = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { providerId, updates } = data;

  if (!providerId) {
    throw new functions.https.HttpsError('invalid-argument', 'Provider ID required');
  }

  try {
    // Verify ownership
    const providerDoc = await db.collection('activitiesProviders').doc(providerId).get();
    if (!providerDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Provider not found');
    }

    const provider = providerDoc.data() as ActivityProvider;
    if (provider.ownerId !== context.auth.uid) {
      throw new functions.https.HttpsError('permission-denied', 'Not authorized');
    }

    // Update provider
    await db.collection('activitiesProviders').doc(providerId).update({
      ...updates,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    await incrementCounter('activities_provider_profiles_updated', 1);

    return { success: true };

  } catch (error) {
    logger.error('Error updating provider profile:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to update profile');
  }
});

// Create activity (provider self-serve)
export const createProviderActivity = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const activityData = data;
  const { providerId, title, category, description, location, priceRange, skillLevels } = activityData;

  if (!providerId || !title || !category || !description) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }

  try {
    // Verify provider ownership
    const providerDoc = await db.collection('activitiesProviders').doc(providerId).get();
    if (!providerDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Provider not found');
    }

    const provider = providerDoc.data() as ActivityProvider;
    if (provider.ownerId !== context.auth.uid) {
      throw new functions.https.HttpsError('permission-denied', 'Not authorized');
    }

    if (!provider.isActive || provider.verificationTier === 'unverified') {
      throw new functions.https.HttpsError('failed-precondition', 'Provider not verified');
    }

    // Create activity
    const activity: Omit<Activity, 'id'> = {
      providerId,
      title,
      category: category as ActivityCategory,
      description,
      location,
      images: activityData.images || [],
      priceRange,
      skillLevels: (skillLevels || []).map((level: string) => level as SkillLevel),
      duration: activityData.duration,
      maxParticipants: activityData.maxParticipants,
      equipment: activityData.equipment || [],
      requirements: activityData.requirements || [],
      tags: activityData.tags || [],
      rating: null,
      reviewCount: 0,
      isActive: true,
      features: activityData.features || [],
      weatherDependency: activityData.weatherDependency as WeatherDependency,
      accessibilityFeatures: activityData.accessibilityFeatures || [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    const activityDoc = await db.collection('activities').add(activity);

    await incrementCounter('activities_created_by_providers', 1);

    logger.info('Activity created by provider', {
      activityId: activityDoc.id,
      providerId,
      userId: context.auth.uid,
      title
    });

    return { activityId: activityDoc.id };

  } catch (error) {
    logger.error('Error creating provider activity:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to create activity');
  }
});

// Update activity (provider self-serve)
export const updateProviderActivity = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { activityId, updates } = data;

  if (!activityId) {
    throw new functions.https.HttpsError('invalid-argument', 'Activity ID required');
  }

  try {
    // Verify ownership through provider
    const activityDoc = await db.collection('activities').doc(activityId).get();
    if (!activityDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Activity not found');
    }

    const activity = activityDoc.data() as Activity;
    const providerDoc = await db.collection('activitiesProviders').doc(activity.providerId).get();
    
    if (!providerDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Provider not found');
    }

    const provider = providerDoc.data() as ActivityProvider;
    if (provider.ownerId !== context.auth.uid) {
      throw new functions.https.HttpsError('permission-denied', 'Not authorized');
    }

    // Update activity
    await db.collection('activities').doc(activityId).update({
      ...updates,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return { success: true };

  } catch (error) {
    logger.error('Error updating provider activity:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to update activity');
  }
});

// Create session (provider self-serve)
export const createProviderSession = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const sessionData = data;
  const { activityId, startTime, endTime, maxParticipants, pricePerPerson } = sessionData;

  if (!activityId || !startTime || !endTime) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }

  try {
    // Verify ownership
    const activityDoc = await db.collection('activities').doc(activityId).get();
    if (!activityDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Activity not found');
    }

    const activity = activityDoc.data() as Activity;
    const providerDoc = await db.collection('activitiesProviders').doc(activity.providerId).get();
    
    if (!providerDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Provider not found');
    }

    const provider = providerDoc.data() as ActivityProvider;
    if (provider.ownerId !== context.auth.uid) {
      throw new functions.https.HttpsError('permission-denied', 'Not authorized');
    }

    // Create session
    const session: Omit<ActivitySession, 'id'> = {
      activityId,
      startTime: admin.firestore.Timestamp.fromDate(new Date(startTime)),
      endTime: admin.firestore.Timestamp.fromDate(new Date(endTime)),
      maxParticipants,
      currentParticipants: 0,
      pricePerPerson,
      statusRaw: 'available',
      instructorId: sessionData.instructorId,
      instructorName: sessionData.instructorName,
      specialRequirements: sessionData.specialRequirements || [],
      equipment: sessionData.equipment || [],
      weatherRequirements: sessionData.weatherRequirements || [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    const sessionDoc = await db.collection('activitySessions').add(session);

    await incrementCounter('activities_sessions_created_by_providers', 1);

    logger.info('Session created by provider', {
      sessionId: sessionDoc.id,
      activityId,
      providerId: activity.providerId,
      userId: context.auth.uid
    });

    return { sessionId: sessionDoc.id };

  } catch (error) {
    logger.error('Error creating provider session:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to create session');
  }
});

// Get provider dashboard data
export const getProviderDashboard = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  try {
    // Get provider
    const providerSnapshot = await db.collection('activitiesProviders')
      .where('ownerId', '==', context.auth.uid)
      .limit(1)
      .get();

    if (providerSnapshot.empty) {
      throw new functions.https.HttpsError('not-found', 'Provider not found');
    }

    const provider = { id: providerSnapshot.docs[0].id, ...providerSnapshot.docs[0].data() };

    // Get activities
    const activitiesSnapshot = await db.collection('activities')
      .where('providerId', '==', provider.id)
      .get();

    const activities = activitiesSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    // Get recent bookings
    const bookingsSnapshot = await db.collection('bookings')
      .where('providerId', '==', provider.id)
      .orderBy('createdAt', 'desc')
      .limit(50)
      .get();

    const bookings = bookingsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    // Calculate stats
    const totalBookings = bookings.length;
    const confirmedBookings = bookings.filter(b => b.status === 'confirmed').length;
    const totalRevenue = bookings
      .filter(b => b.status === 'confirmed')
      .reduce((sum, b) => sum + (b.totalAmount || 0), 0);

    const stats = {
      totalActivities: activities.length,
      activeActivities: activities.filter(a => a.isActive).length,
      totalBookings,
      confirmedBookings,
      totalRevenue,
      averageRating: provider.rating || 0,
      reviewCount: provider.reviewCount || 0
    };

    return {
      provider,
      activities: activities.slice(0, 10), // Limit for dashboard
      recentBookings: bookings.slice(0, 10),
      stats
    };

  } catch (error) {
    logger.error('Error getting provider dashboard:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to get dashboard data');
  }
});

// Stripe Connect onboarding for providers
export const createProviderStripeAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { providerId, country = 'MA' } = data;

  if (!providerId) {
    throw new functions.https.HttpsError('invalid-argument', 'Provider ID required');
  }

  try {
    // Verify provider ownership
    const providerDoc = await db.collection('activitiesProviders').doc(providerId).get();
    if (!providerDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Provider not found');
    }

    const provider = providerDoc.data() as ActivityProvider;
    if (provider.ownerId !== context.auth.uid) {
      throw new functions.https.HttpsError('permission-denied', 'Not authorized');
    }

    if (provider.stripeAccountId) {
      throw new functions.https.HttpsError('already-exists', 'Stripe account already exists');
    }

    // Create Stripe Connect account
    const stripe = getStripeClient();
    const account = await stripe.accounts.create({
      type: 'express',
      country: country,
      email: provider.contactInfo?.email,
      business_profile: {
        name: provider.name,
        url: provider.contactInfo?.website,
        support_email: provider.contactInfo?.email,
      },
      metadata: {
        providerId: providerId,
        userId: context.auth.uid
      }
    });

    // Update provider with Stripe account ID
    await db.collection('activitiesProviders').doc(providerId).update({
      stripeAccountId: account.id,
      payoutEnabled: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Create account link for onboarding
    const accountLink = await stripe.accountLinks.create({
      account: account.id,
      refresh_url: `${data.baseUrl}/provider/stripe/refresh`,
      return_url: `${data.baseUrl}/provider/stripe/return`,
      type: 'account_onboarding',
    });

    await incrementCounter('activities_stripe_accounts_created', 1);

    logger.info('Stripe Connect account created', {
      providerId,
      stripeAccountId: account.id,
      userId: context.auth.uid
    });

    return { 
      accountId: account.id,
      onboardingUrl: accountLink.url
    };

  } catch (error) {
    logger.error('Error creating Stripe account:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to create Stripe account');
  }
});

// Admin functions for reviewing applications
export const reviewProviderApplication = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  // TODO: Add admin role check
  const { applicationId, action, rejectionReason } = data;

  if (!applicationId || !['approve', 'reject'].includes(action)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid parameters');
  }

  try {
    await db.runTransaction(async (transaction) => {
      const appRef = db.collection('providerApplications').doc(applicationId);
      const appDoc = await transaction.get(appRef);

      if (!appDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Application not found');
      }

      const application = appDoc.data() as ProviderApplication;

      if (application.status !== 'pending') {
        throw new functions.https.HttpsError('failed-precondition', 'Application already reviewed');
      }

      if (action === 'approve') {
        // Create provider account
        const provider: Omit<ActivityProvider, 'id'> = {
          ownerId: application.applicantUserId,
          name: application.businessName,
          type: application.businessType as ProviderType,
          description: application.description,
          logo: null,
          coverImage: null,
          contactInfo: application.contactInfo,
          location: application.location,
          rating: null,
          reviewCount: 0,
          certifications: [],
          specialties: application.categories || [],
          isVerified: true,
          isActive: true,
          verificationTier: 'basic' as ProviderVerificationTier,
          stripeAccountId: null,
          payoutEnabled: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };

        const providerRef = db.collection('activitiesProviders').doc();
        transaction.set(providerRef, provider);

        // Update application
        transaction.update(appRef, {
          status: 'approved',
          providerId: providerRef.id,
          reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
          reviewedBy: context.auth.uid,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // Send approval notification
        await sendProviderApprovalNotification(application.applicantUserId, application.businessName);

      } else {
        // Reject application
        transaction.update(appRef, {
          status: 'rejected',
          rejectionReason: rejectionReason || 'Application does not meet requirements',
          reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
          reviewedBy: context.auth.uid,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // Send rejection notification
        await sendProviderRejectionNotification(
          application.applicantUserId, 
          application.businessName,
          rejectionReason
        );
      }
    });

    await incrementCounter(`activities_provider_applications_${action}d`, 1);

    return { success: true };

  } catch (error) {
    logger.error('Error reviewing provider application:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to review application');
  }
});

// Notification helpers
async function sendProviderApprovalNotification(userId: string, businessName: string): Promise<void> {
  await sendNotification(userId, {
    title: 'Application Approved! 🎉',
    body: `Your provider application for "${businessName}" has been approved`,
    data: {
      type: 'provider_approved',
      businessName: businessName
    }
  });
}

async function sendProviderRejectionNotification(userId: string, businessName: string, reason?: string): Promise<void> {
  await sendNotification(userId, {
    title: 'Application Update',
    body: `Your provider application for "${businessName}" needs revision`,
    data: {
      type: 'provider_rejected',
      businessName: businessName,
      reason: reason || 'Please review requirements'
    }
  });
}