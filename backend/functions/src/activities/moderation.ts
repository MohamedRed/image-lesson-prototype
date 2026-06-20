import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { logger } from 'firebase-functions';
import { 
  Activity,
  ActivityProvider,
  ProviderApplication,
  ActivitySession
} from './models';
import { incrementCounter } from '../shared/metrics';

const db = admin.firestore();

// Automated content moderation when activity is created/updated
export const moderateActivityContent = functions.firestore
  .document('activities/{activityId}')
  .onWrite(async (change, context) => {
    const after = change.after.data();
    const activityId = context.params.activityId;

    if (!after) {
      return; // Activity deleted
    }

    const activity = after as Activity;

    try {
      // Run content moderation checks
      const moderationResults = await performContentModeration(activity);

      // Calculate overall risk score
      const riskScore = calculateRiskScore(moderationResults);

      // Determine action based on risk score
      let status = 'approved';
      let requiresReview = false;
      
      if (riskScore >= 0.8) {
        status = 'rejected';
        await notifyProviderOfRejection(activity.providerId, moderationResults);
      } else if (riskScore >= 0.4) {
        status = 'pending_review';
        requiresReview = true;
        await createModerationTask(activityId, moderationResults, 'medium');
      } else if (riskScore >= 0.2) {
        status = 'approved';
        requiresReview = true;
        await createModerationTask(activityId, moderationResults, 'low');
      }

      // Update activity with moderation results
      await db.collection('activities').doc(activityId).update({
        moderationStatus: status,
        moderationScore: riskScore,
        moderationResults: moderationResults,
        isActive: status === 'approved',
        lastModerated: admin.firestore.FieldValue.serverTimestamp()
      });

      // Log moderation action
      logger.info('Activity moderated', {
        activityId,
        providerId: activity.providerId,
        riskScore,
        status,
        requiresReview
      });

      await incrementCounter('activities_moderated', 1);
      await incrementCounter(`activities_moderation_${status}`, 1);

    } catch (error) {
      logger.error('Error moderating activity content:', error);
      
      // On error, mark for manual review
      await createModerationTask(activityId, { error: error.message }, 'high');
    }
  });

// Moderate provider applications
export const moderateProviderApplication = functions.firestore
  .document('providerApplications/{applicationId}')
  .onWrite(async (change, context) => {
    const after = change.after.data();
    const applicationId = context.params.applicationId;

    if (!after || after.status !== 'pending') {
      return;
    }

    const application = after as ProviderApplication;

    try {
      // Check business information
      const businessChecks = await performBusinessVerification(application);
      
      // Check location and contact details
      const contactChecks = await performContactVerification(application);
      
      // Combine all checks
      const allChecks = { ...businessChecks, ...contactChecks };
      const riskScore = calculateApplicationRiskScore(allChecks);

      let status = 'approved';
      let requiresReview = false;

      if (riskScore >= 0.7) {
        status = 'rejected';
        await notifyApplicantOfRejection(application.applicantUserId, allChecks);
      } else if (riskScore >= 0.3) {
        status = 'pending';
        requiresReview = true;
        await createApplicationReviewTask(applicationId, allChecks, 'medium');
      } else {
        status = 'approved';
        // Auto-approve low risk applications
        await autoApproveProvider(application);
      }

      // Update application status
      await db.collection('providerApplications').doc(applicationId).update({
        status,
        moderationScore: riskScore,
        moderationResults: allChecks,
        reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
        reviewedBy: 'automated_system'
      });

      logger.info('Provider application moderated', {
        applicationId,
        applicantId: application.applicantUserId,
        riskScore,
        status
      });

      await incrementCounter('provider_applications_moderated', 1);
      await incrementCounter(`provider_applications_${status}`, 1);

    } catch (error) {
      logger.error('Error moderating provider application:', error);
      
      // On error, mark for manual review
      await createApplicationReviewTask(applicationId, { error: error.message }, 'high');
    }
  });

// Manual review interface for moderators
export const submitModerationReview = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  // Check if user is a moderator
  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  const userData = userDoc.data();
  
  if (!userData || !userData.roles?.includes('moderator')) {
    throw new functions.https.HttpsError('permission-denied', 'Moderator role required');
  }

  const { taskId, decision, reason, additionalNotes } = data;

  if (!taskId || !decision) {
    throw new functions.https.HttpsError('invalid-argument', 'Task ID and decision required');
  }

  try {
    // Get moderation task
    const taskDoc = await db.collection('moderationTasks').doc(taskId).get();
    if (!taskDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Moderation task not found');
    }

    const task = taskDoc.data()!;

    // Apply moderation decision
    if (task.entityType === 'activity') {
      await applyActivityModerationDecision(task.entityId, decision, reason, context.auth.uid);
    } else if (task.entityType === 'provider_application') {
      await applyApplicationModerationDecision(task.entityId, decision, reason, context.auth.uid);
    }

    // Update task as completed
    await db.collection('moderationTasks').doc(taskId).update({
      status: 'completed',
      decision,
      reason,
      additionalNotes,
      reviewedBy: context.auth.uid,
      reviewedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    await incrementCounter('moderation_reviews_completed', 1);

    return { success: true };

  } catch (error) {
    logger.error('Error submitting moderation review:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to submit review');
  }
});

// Get pending moderation tasks for moderators
export const getModerationTasks = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  // Check if user is a moderator
  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  const userData = userDoc.data();
  
  if (!userData || !userData.roles?.includes('moderator')) {
    throw new functions.https.HttpsError('permission-denied', 'Moderator role required');
  }

  const { status = 'pending', priority, limit = 20 } = data;

  try {
    let query = db.collection('moderationTasks')
      .where('status', '==', status)
      .orderBy('priority', 'desc')
      .orderBy('createdAt', 'asc');

    if (priority) {
      query = query.where('priority', '==', priority);
    }

    const tasksSnapshot = await query.limit(limit).get();
    const tasks = tasksSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    return { tasks };

  } catch (error) {
    logger.error('Error getting moderation tasks:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get tasks');
  }
});

// Helper functions for content moderation
async function performContentModeration(activity: Activity): Promise<any> {
  const results: any = {
    profanityCheck: false,
    spamCheck: false,
    qualityCheck: true,
    imageCheck: true,
    priceCheck: true
  };

  // Check for profanity in title and description
  const profanityPattern = /\b(spam|scam|fake|illegal|drugs|violence)\b/i;
  if (profanityPattern.test(activity.title) || profanityPattern.test(activity.description)) {
    results.profanityCheck = true;
  }

  // Check for spam patterns
  const spamPatterns = [
    /contact.*outside.*app/i,
    /whatsapp|telegram|email.*direct/i,
    /money.*transfer|wire.*money|western.*union/i,
    /guarantee.*profit|make.*money.*fast/i
  ];
  
  const fullText = `${activity.title} ${activity.description}`;
  results.spamCheck = spamPatterns.some(pattern => pattern.test(fullText));

  // Quality checks
  results.qualityCheck = activity.title.length >= 10 && activity.description.length >= 50;

  // Price reasonableness check
  results.priceCheck = activity.pricePerUnit >= 5 && activity.pricePerUnit <= 5000;

  // Image content check (simplified - would use actual image moderation API)
  if (activity.images && activity.images.length > 0) {
    results.imageCheck = activity.images.length <= 10; // Basic limit check
  }

  return results;
}

function calculateRiskScore(moderationResults: any): number {
  let score = 0;

  if (moderationResults.profanityCheck) score += 0.4;
  if (moderationResults.spamCheck) score += 0.5;
  if (!moderationResults.qualityCheck) score += 0.2;
  if (!moderationResults.imageCheck) score += 0.3;
  if (!moderationResults.priceCheck) score += 0.2;

  return Math.min(score, 1.0);
}

async function performBusinessVerification(application: ProviderApplication): Promise<any> {
  const results: any = {
    businessNameCheck: true,
    locationCheck: true,
    contactCheck: true,
    licenseCheck: true
  };

  // Business name checks
  const suspiciousPatterns = /\b(scam|fake|test|admin)\b/i;
  results.businessNameCheck = !suspiciousPatterns.test(application.businessName);

  // Location verification (simplified)
  const location = application.location;
  results.locationCheck = location.lat >= -90 && location.lat <= 90 && 
                         location.lng >= -180 && location.lng <= 180 &&
                         location.address.length >= 10;

  // Contact verification
  const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  results.contactCheck = emailPattern.test(application.contactInfo.email);

  // License check (simplified - would integrate with business registry APIs)
  results.licenseCheck = !application.businessLicense || application.businessLicense.length >= 5;

  return results;
}

async function performContactVerification(application: ProviderApplication): Promise<any> {
  return {
    emailValid: /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(application.contactInfo.email),
    phoneValid: !application.contactInfo.phone || application.contactInfo.phone.length >= 10
  };
}

function calculateApplicationRiskScore(checks: any): number {
  let score = 0;

  if (!checks.businessNameCheck) score += 0.3;
  if (!checks.locationCheck) score += 0.2;
  if (!checks.contactCheck) score += 0.2;
  if (!checks.licenseCheck) score += 0.2;
  if (!checks.emailValid) score += 0.2;
  if (!checks.phoneValid) score += 0.1;

  return Math.min(score, 1.0);
}

async function createModerationTask(entityId: string, results: any, priority: string): Promise<void> {
  await db.collection('moderationTasks').add({
    entityType: 'activity',
    entityId,
    priority,
    moderationResults: results,
    status: 'pending',
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
}

async function createApplicationReviewTask(entityId: string, results: any, priority: string): Promise<void> {
  await db.collection('moderationTasks').add({
    entityType: 'provider_application',
    entityId,
    priority,
    moderationResults: results,
    status: 'pending',
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
}

async function notifyProviderOfRejection(providerId: string, results: any): Promise<void> {
  // Get provider details
  const providerDoc = await db.collection('activityProviders').doc(providerId).get();
  if (!providerDoc.exists) return;

  const provider = providerDoc.data() as ActivityProvider;
  
  // Create notification
  await db.collection('notifications').add({
    userId: provider.ownerId,
    type: 'activity_rejected',
    title: 'Activity Rejected',
    message: 'Your activity was rejected due to policy violations. Please review and resubmit.',
    data: {
      providerId,
      moderationResults: results
    },
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
}

async function notifyApplicantOfRejection(applicantId: string, results: any): Promise<void> {
  await db.collection('notifications').add({
    userId: applicantId,
    type: 'application_rejected',
    title: 'Provider Application Rejected',
    message: 'Your provider application was rejected. Please review the requirements and resubmit.',
    data: {
      moderationResults: results
    },
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
}

async function autoApproveProvider(application: ProviderApplication): Promise<void> {
  // Create provider account
  const providerData: Omit<ActivityProvider, 'id'> = {
    ownerId: application.applicantUserId,
    name: application.businessName,
    type: application.businessType,
    contact: application.contactInfo,
    geo: {
      lat: application.location.lat,
      lng: application.location.lng,
      city: application.location.city,
      neighborhood: application.location.neighborhood,
      address: application.location.address
    },
    amenities: [],
    verificationTier: application.verificationTier,
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  const providerRef = await db.collection('activityProviders').add(providerData);

  // Update application with provider ID
  await db.collection('providerApplications').doc(application.id).update({
    providerId: providerRef.id,
    status: 'approved'
  });

  // Notify applicant of approval
  await db.collection('notifications').add({
    userId: application.applicantUserId,
    type: 'application_approved',
    title: 'Provider Application Approved',
    message: 'Congratulations! Your provider application has been approved. You can now create activities.',
    data: {
      providerId: providerRef.id
    },
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
}

async function applyActivityModerationDecision(activityId: string, decision: string, reason: string, reviewerId: string): Promise<void> {
  const updates: any = {
    moderationStatus: decision,
    isActive: decision === 'approved',
    moderationReason: reason,
    reviewedBy: reviewerId,
    reviewedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  await db.collection('activities').doc(activityId).update(updates);

  // Notify provider
  const activityDoc = await db.collection('activities').doc(activityId).get();
  if (activityDoc.exists) {
    const activity = activityDoc.data() as Activity;
    
    if (decision === 'rejected') {
      await notifyProviderOfRejection(activity.providerId, { reason });
    }
  }
}

async function applyApplicationModerationDecision(applicationId: string, decision: string, reason: string, reviewerId: string): Promise<void> {
  const updates: any = {
    status: decision,
    rejectionReason: decision === 'rejected' ? reason : undefined,
    reviewedBy: reviewerId,
    reviewedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  await db.collection('providerApplications').doc(applicationId).update(updates);

  // Get application data
  const appDoc = await db.collection('providerApplications').doc(applicationId).get();
  if (appDoc.exists) {
    const application = appDoc.data() as ProviderApplication;
    
    if (decision === 'approved') {
      await autoApproveProvider({ ...application, id: applicationId });
    } else if (decision === 'rejected') {
      await notifyApplicantOfRejection(application.applicantUserId, { reason });
    }
  }
}

// Periodic cleanup of completed moderation tasks
export const cleanupModerationTasks = functions.pubsub
  .schedule('every 7 days')
  .onRun(async (context) => {
    try {
      const cutoff = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) // 30 days ago
      );

      const completedTasks = await db.collection('moderationTasks')
        .where('status', '==', 'completed')
        .where('reviewedAt', '<', cutoff)
        .limit(100)
        .get();

      const batch = db.batch();
      completedTasks.docs.forEach(doc => {
        batch.delete(doc.ref);
      });

      await batch.commit();

      logger.info(`Cleaned up ${completedTasks.size} completed moderation tasks`);
      return { cleaned: completedTasks.size };
    } catch (error) {
      logger.error('Error cleaning up moderation tasks:', error);
      throw error;
    }
  });