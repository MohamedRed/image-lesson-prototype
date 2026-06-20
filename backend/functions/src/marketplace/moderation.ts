import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { trace } from '../shared/trace';
import { analytics } from '../shared/analytics';
import { fcmService } from '../services/notifications/fcmService';
import { templates } from '../services/notifications/templates';

const db = getFirestore();

interface ReportData {
  entityType: 'listing' | 'user' | 'conversation' | 'message';
  entityId: string;
  reason: string;
  description?: string;
  evidence?: string[];
}

interface ModerationAction {
  entityType: string;
  entityId: string;
  action: 'approve' | 'remove' | 'suspend' | 'warn' | 'flag';
  reason: string;
  duration?: number; // For suspensions (hours)
}

interface UserVerificationData {
  verificationType: 'phone' | 'email' | 'id_document';
  verificationData: any;
}

/**
 * Report content or user
 * Per Section 14 - Moderation & Trust/Safety
 */
export const reportContent = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.reportContent', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const data = request.data as ReportData;
      const reporterId = request.auth.uid;

      if (!data.entityType || !data.entityId || !data.reason) {
        throw new HttpsError('invalid-argument', 'Entity type, ID, and reason are required');
      }

      try {
        // Check rate limiting - max 10 reports per day
        const todayStart = new Date();
        todayStart.setHours(0, 0, 0, 0);

        const todayReports = await db.collection('reports')
          .where('reporterId', '==', reporterId)
          .where('createdAt', '>=', todayStart)
          .get();

        if (todayReports.size >= 10) {
          throw new HttpsError('resource-exhausted', 'Daily report limit exceeded');
        }

        // Check for duplicate reports
        const existingReport = await db.collection('reports')
          .where('reporterId', '==', reporterId)
          .where('entityType', '==', data.entityType)
          .where('entityId', '==', data.entityId)
          .where('status', 'in', ['pending', 'under_review'])
          .get();

        if (!existingReport.empty) {
          throw new HttpsError('already-exists', 'You have already reported this content');
        }

        // Create report
        const reportRef = db.collection('reports').doc();
        const report = {
          id: reportRef.id,
          reporterId,
          entityType: data.entityType,
          entityId: data.entityId,
          reason: data.reason,
          description: data.description || '',
          evidence: data.evidence || [],
          status: 'pending',
          priority: calculateReportPriority(data.reason),
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp()
        };

        await reportRef.set(report);

        // Auto-moderation for high-priority issues
        if (report.priority === 'high') {
          await takeImmediateModerationAction(data.entityType, data.entityId, data.reason);
        }

        // Update entity flags
        await updateEntityFlags(data.entityType, data.entityId, data.reason);

        // Analytics
        await analytics.track('marketplace_content_reported', {
          reporterId,
          entityType: data.entityType,
          entityId: data.entityId,
          reason: data.reason,
          priority: report.priority,
          hasEvidence: data.evidence && data.evidence.length > 0
        });

        return { success: true, reportId: reportRef.id };

      } catch (error) {
        logger.error('Error reporting content', { reporterId, entityType: data.entityType, entityId: data.entityId, error });
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', 'Failed to report content');
      }
    });
  }
);

/**
 * Block or unblock a user
 */
export const blockUser = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.blockUser', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const { userId: targetUserId, block } = request.data;
      const blockerId = request.auth.uid;

      if (!targetUserId || targetUserId === blockerId) {
        throw new HttpsError('invalid-argument', 'Valid user ID required, cannot block yourself');
      }

      try {
        const userRef = db.collection('users').doc(blockerId);
        
        if (block) {
          // Add to blocked users list
          await userRef.update({
            'marketplace.blockedUsers': FieldValue.arrayUnion(targetUserId),
            'marketplace.lastBlockedAt': FieldValue.serverTimestamp()
          });

          // Remove from any active conversations
          await endConversationsWithUser(blockerId, targetUserId);

        } else {
          // Remove from blocked users list
          await userRef.update({
            'marketplace.blockedUsers': FieldValue.arrayRemove(targetUserId)
          });
        }

        // Analytics
        await analytics.track('marketplace_user_blocked', {
          blockerId,
          targetUserId,
          action: block ? 'block' : 'unblock'
        });

        return { success: true };

      } catch (error) {
        logger.error('Error blocking/unblocking user', { blockerId, targetUserId, block, error });
        throw new HttpsError('internal', 'Failed to update block status');
      }
    });
  }
);

/**
 * Verify user identity
 */
export const verifyUserIdentity = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.verifyUserIdentity', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const data = request.data as UserVerificationData;
      const userId = request.auth.uid;

      if (!data.verificationType || !data.verificationData) {
        throw new HttpsError('invalid-argument', 'Verification type and data are required');
      }

      try {
        // Create verification request
        const verificationRef = db.collection('verifications').doc();
        const verification = {
          id: verificationRef.id,
          userId,
          type: data.verificationType,
          status: 'pending',
          data: data.verificationData,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp()
        };

        await verificationRef.set(verification);

        // Process verification based on type
        let result;
        switch (data.verificationType) {
          case 'phone':
            result = await processPhoneVerification(userId, data.verificationData);
            break;
          case 'email':
            result = await processEmailVerification(userId, data.verificationData);
            break;
          case 'id_document':
            result = await processIDVerification(userId, data.verificationData);
            break;
          default:
            throw new HttpsError('invalid-argument', 'Unsupported verification type');
        }

        // Update verification with result
        await verificationRef.update({
          status: result.verified ? 'verified' : 'failed',
          verifiedAt: result.verified ? FieldValue.serverTimestamp() : null,
          failureReason: result.failureReason || null,
          updatedAt: FieldValue.serverTimestamp()
        });

        // Update user verification status
        if (result.verified) {
          await db.collection('users').doc(userId).update({
            [`marketplace.verification.${data.verificationType}`]: {
              verified: true,
              verifiedAt: FieldValue.serverTimestamp(),
              method: data.verificationType
            },
            'marketplace.trustScore': FieldValue.increment(result.trustScoreBonus || 10)
          });
        }

        // Analytics
        await analytics.track('marketplace_user_verification_attempted', {
          userId,
          verificationType: data.verificationType,
          verified: result.verified,
          failureReason: result.failureReason
        });

        return {
          success: true,
          verified: result.verified,
          verificationId: verificationRef.id,
          failureReason: result.failureReason
        };

      } catch (error) {
        logger.error('Error verifying user identity', { userId, verificationType: data.verificationType, error });
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', 'Failed to verify user identity');
      }
    });
  }
);

/**
 * Calculate user trust score
 */
export const calculateTrustScore = onCall(
  { cors: true, enforceAppCheck: true },
  async (request) => {
    return trace('marketplace.calculateTrustScore', request.auth?.uid || 'anonymous', async () => {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const userId = request.auth.uid;

      try {
        const userDoc = await db.collection('users').doc(userId).get();
        if (!userDoc.exists) {
          throw new HttpsError('not-found', 'User not found');
        }

        const userData = userDoc.data();
        const trustScore = await computeTrustScore(userId, userData);

        // Update user's trust score
        await db.collection('users').doc(userId).update({
          'marketplace.trustScore': trustScore.score,
          'marketplace.trustScoreUpdatedAt': FieldValue.serverTimestamp(),
          'marketplace.trustFactors': trustScore.factors
        });

        // Analytics
        await analytics.track('marketplace_trust_score_calculated', {
          userId,
          trustScore: trustScore.score,
          factors: Object.keys(trustScore.factors)
        });

        return {
          success: true,
          trustScore: trustScore.score,
          factors: trustScore.factors,
          recommendations: trustScore.recommendations
        };

      } catch (error) {
        logger.error('Error calculating trust score', { userId, error });
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', 'Failed to calculate trust score');
      }
    });
  }
);

/**
 * Administrative moderation action
 */
export const moderateContent = onCall(
  { cors: true, invoker: 'private' },
  async (request) => {
    return trace('marketplace.moderateContent', 'admin', async () => {
      const data = request.data as ModerationAction;

      if (!data.entityType || !data.entityId || !data.action) {
        throw new HttpsError('invalid-argument', 'Entity type, ID, and action are required');
      }

      try {
        const result = await applyModerationAction(data);

        // Log moderation action
        const actionRef = db.collection('moderation_actions').doc();
        await actionRef.set({
          id: actionRef.id,
          ...data,
          moderatedBy: 'admin',
          result,
          createdAt: FieldValue.serverTimestamp()
        });

        // Analytics
        await analytics.track('marketplace_content_moderated', {
          entityType: data.entityType,
          entityId: data.entityId,
          action: data.action,
          moderatedBy: 'admin'
        });

        return { success: true, ...result };

      } catch (error) {
        logger.error('Error moderating content', { entityType: data.entityType, entityId: data.entityId, action: data.action, error });
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', 'Failed to moderate content');
      }
    });
  }
);

/**
 * Trigger: Auto-moderate new content
 */
export const onContentCreated = onDocumentCreated(
  '{collection}/{docId}',
  async (event) => {
    const collection = event.params.collection;
    const docId = event.params.docId;
    const data = event.data?.data();

    if (!data || !['listings', 'messages'].includes(collection)) return;

    try {
      // Auto-moderation based on content
      const moderationResult = await autoModerateContent(collection, docId, data);

      if (moderationResult.flagged) {
        // Flag for manual review
        await db.collection(collection).doc(docId).update({
          'moderation.autoFlagged': true,
          'moderation.flagReason': moderationResult.reason,
          'moderation.confidence': moderationResult.confidence,
          'moderation.reviewRequired': true
        });

        // Create automatic report if high confidence
        if (moderationResult.confidence > 0.8) {
          const reportRef = db.collection('reports').doc();
          await reportRef.set({
            id: reportRef.id,
            reporterId: 'system',
            entityType: collection.slice(0, -1), // Remove 's' from collection name
            entityId: docId,
            reason: moderationResult.reason,
            description: `Auto-flagged with ${moderationResult.confidence} confidence`,
            status: 'pending',
            priority: 'high',
            createdAt: FieldValue.serverTimestamp()
          });
        }

        // Analytics
        await analytics.track('marketplace_content_auto_flagged', {
          entityType: collection,
          entityId: docId,
          reason: moderationResult.reason,
          confidence: moderationResult.confidence
        });
      }

    } catch (error) {
      logger.error('Error in auto-moderation', { collection, docId, error });
    }
  }
);

/**
 * Background task: Review flagged content
 */
export const reviewFlaggedContent = onCall(
  { invoker: 'private' },
  async () => {
    return trace('marketplace.reviewFlaggedContent', 'system', async () => {
      try {
        // Find content flagged for review
        const flaggedReports = await db.collection('reports')
          .where('status', '==', 'pending')
          .where('priority', '==', 'high')
          .orderBy('createdAt', 'asc')
          .limit(50)
          .get();

        let reviewedCount = 0;

        for (const doc of flaggedReports.docs) {
          const report = doc.data();

          try {
            // Auto-review based on patterns and ML
            const reviewResult = await autoReviewContent(report);

            if (reviewResult.action) {
              await applyModerationAction({
                entityType: report.entityType,
                entityId: report.entityId,
                action: reviewResult.action,
                reason: reviewResult.reason
              });

              // Update report status
              await doc.ref.update({
                status: 'resolved',
                resolution: reviewResult.action,
                reviewedBy: 'auto_system',
                reviewedAt: FieldValue.serverTimestamp()
              });

              reviewedCount++;
            }

          } catch (error) {
            logger.error('Error auto-reviewing report', { reportId: doc.id, error });
          }
        }

        logger.info(`Auto-reviewed ${reviewedCount} flagged reports`);
        return { reviewedCount };

      } catch (error) {
        logger.error('Error in reviewFlaggedContent', { error });
        throw new HttpsError('internal', 'Failed to review flagged content');
      }
    });
  }
);

// Helper functions

function calculateReportPriority(reason: string): 'low' | 'medium' | 'high' {
  const highPriorityReasons = ['fraud', 'harassment', 'illegal_content', 'spam'];
  const mediumPriorityReasons = ['inappropriate_content', 'fake_listing', 'price_manipulation'];
  
  if (highPriorityReasons.includes(reason)) return 'high';
  if (mediumPriorityReasons.includes(reason)) return 'medium';
  return 'low';
}

async function takeImmediateModerationAction(entityType: string, entityId: string, reason: string) {
  switch (reason) {
    case 'fraud':
    case 'illegal_content':
      await applyModerationAction({
        entityType,
        entityId,
        action: 'remove',
        reason: `Auto-removed for ${reason}`
      });
      break;
    
    case 'spam':
      await applyModerationAction({
        entityType,
        entityId,
        action: 'flag',
        reason: 'Auto-flagged for spam'
      });
      break;
  }
}

async function updateEntityFlags(entityType: string, entityId: string, reason: string) {
  const collection = entityType === 'listing' ? 'listings' : 
                   entityType === 'user' ? 'users' : 
                   entityType === 'conversation' ? 'conversations' : 'messages';

  await db.collection(collection).doc(entityId).update({
    'moderation.reportCount': FieldValue.increment(1),
    'moderation.lastReportedAt': FieldValue.serverTimestamp(),
    'moderation.reasons': FieldValue.arrayUnion(reason)
  });
}

async function endConversationsWithUser(blockerId: string, blockedUserId: string) {
  const conversations = await db.collection('conversations')
    .where('participants', 'array-contains', blockerId)
    .get();

  const batch = db.batch();

  conversations.docs.forEach(doc => {
    const conversation = doc.data();
    if (conversation.participants.includes(blockedUserId)) {
      batch.update(doc.ref, {
        status: 'blocked',
        blockedBy: blockerId,
        blockedAt: FieldValue.serverTimestamp()
      });
    }
  });

  if (conversations.size > 0) {
    await batch.commit();
  }
}

async function processPhoneVerification(userId: string, phoneData: any): Promise<any> {
  // Mock phone verification - in production would integrate with SMS service
  return {
    verified: true,
    trustScoreBonus: 15,
    method: 'sms_code'
  };
}

async function processEmailVerification(userId: string, emailData: any): Promise<any> {
  // Mock email verification - in production would send verification email
  return {
    verified: true,
    trustScoreBonus: 10,
    method: 'email_link'
  };
}

async function processIDVerification(userId: string, idData: any): Promise<any> {
  // Mock ID verification - in production would integrate with ID verification service
  return {
    verified: Math.random() > 0.1, // 90% success rate
    trustScoreBonus: 25,
    method: 'document_scan',
    failureReason: Math.random() > 0.9 ? 'document_unclear' : undefined
  };
}

async function computeTrustScore(userId: string, userData: any): Promise<any> {
  let score = 50; // Base score
  const factors: any = {};

  // Account age
  const accountAge = Date.now() - userData.createdAt?.toMillis() || 0;
  const ageBonus = Math.min(20, Math.floor(accountAge / (30 * 24 * 60 * 60 * 1000)) * 5); // 5 points per month, max 20
  score += ageBonus;
  factors.accountAge = ageBonus;

  // Verification status
  const verification = userData.marketplace?.verification || {};
  if (verification.phone?.verified) {
    score += 15;
    factors.phoneVerified = 15;
  }
  if (verification.email?.verified) {
    score += 10;
    factors.emailVerified = 10;
  }
  if (verification.id_document?.verified) {
    score += 25;
    factors.idVerified = 25;
  }

  // Transaction history
  const stats = userData.marketplace?.stats || {};
  const transactionBonus = Math.min(30, (stats.saleCount || 0) * 2 + (stats.purchaseCount || 0) * 1);
  score += transactionBonus;
  factors.transactions = transactionBonus;

  // Rating
  const rating = userData.marketplace?.rating || 0;
  if (rating > 0) {
    const ratingBonus = Math.floor((rating - 3) * 10); // -20 to +20 based on rating
    score += ratingBonus;
    factors.rating = ratingBonus;
  }

  // Penalties
  const reportCount = userData.marketplace?.reportCount || 0;
  const reportPenalty = Math.min(50, reportCount * 5);
  score -= reportPenalty;
  factors.reports = -reportPenalty;

  // Ensure score is between 0 and 100
  score = Math.max(0, Math.min(100, score));

  const recommendations = [];
  if (!verification.phone?.verified) recommendations.push('verify_phone');
  if (!verification.email?.verified) recommendations.push('verify_email');
  if (!verification.id_document?.verified) recommendations.push('verify_id');
  if (stats.saleCount === 0) recommendations.push('complete_first_sale');

  return { score, factors, recommendations };
}

async function autoModerateContent(collection: string, docId: string, data: any): Promise<any> {
  const content = data.title ? `${data.title} ${data.description}` : data.content || '';
  
  // Check for prohibited content
  const prohibitedPatterns = [
    /\b(drugs?|cocaine|heroin|marijuana)\b/i,
    /\b(weapons?|guns?|firearms?)\b/i,
    /\b(stolen|illegal|counterfeit)\b/i,
    /\b(fraud|scam|fake)\b/i,
    /\b(contact me outside|whatsapp|telegram)\b/i
  ];

  for (const pattern of prohibitedPatterns) {
    if (pattern.test(content)) {
      return {
        flagged: true,
        reason: 'prohibited_content',
        confidence: 0.9,
        pattern: pattern.source
      };
    }
  }

  // Check for spam patterns
  const spamIndicators = [
    /(.)\1{10,}/, // Repeated characters
    /[A-Z]{20,}/, // Excessive caps
    /\b(buy now|limited time|act fast)\b/gi
  ];

  let spamScore = 0;
  spamIndicators.forEach(pattern => {
    if (pattern.test(content)) spamScore += 0.3;
  });

  if (spamScore >= 0.6) {
    return {
      flagged: true,
      reason: 'spam',
      confidence: spamScore,
      indicators: spamIndicators.length
    };
  }

  return { flagged: false };
}

async function autoReviewContent(report: any): Promise<any> {
  // Simple auto-review logic - in production would use ML models
  if (report.reason === 'spam' && (report.createdAt?.toDate().getTime() || 0) < Date.now() - 24 * 60 * 60 * 1000) {
    return {
      action: 'remove',
      reason: 'Auto-removed spam after 24h review period'
    };
  }

  if (report.priority === 'high' && Math.random() > 0.7) {
    return {
      action: 'flag',
      reason: 'Flagged for manual review'
    };
  }

  return { action: null };
}

async function applyModerationAction(action: ModerationAction): Promise<any> {
  const collection = action.entityType === 'listing' ? 'listings' : 
                   action.entityType === 'user' ? 'users' : 
                   action.entityType === 'conversation' ? 'conversations' : 'messages';

  const updateData: any = {
    'moderation.action': action.action,
    'moderation.reason': action.reason,
    'moderation.moderatedAt': FieldValue.serverTimestamp()
  };

  switch (action.action) {
    case 'remove':
      updateData.status = 'removed';
      updateData.removedAt = FieldValue.serverTimestamp();
      break;
    
    case 'suspend':
      updateData.status = 'suspended';
      updateData.suspendedUntil = new Date(Date.now() + (action.duration || 24) * 60 * 60 * 1000);
      break;
    
    case 'flag':
      updateData['moderation.flagged'] = true;
      break;
    
    case 'approve':
      updateData['moderation.approved'] = true;
      updateData['moderation.reviewRequired'] = false;
      break;
  }

  await db.collection(collection).doc(action.entityId).update(updateData);

  return { applied: true, updates: Object.keys(updateData) };
}