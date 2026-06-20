import { onRequest } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { withMetrics } from "../shared/metrics";

try { admin.app(); } catch { admin.initializeApp(); }

const db = admin.firestore();
const storage = admin.storage();

/**
 * Submit KYC documents for verification
 * POST /home/verification/submit
 */
export const submitKYCDocuments = withMetrics("submitKYCDocuments",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const { documents, personalInfo } = req.body;
      
      if (!documents || !Array.isArray(documents) || documents.length === 0) {
        res.status(400).json({ error: "At least one document is required" });
        return;
      }

      // Validate required personal information
      const requiredFields = ['firstName', 'lastName', 'dateOfBirth', 'nationalId', 'address'];
      const missingFields = requiredFields.filter(field => !personalInfo[field]);
      
      if (missingFields.length > 0) {
        res.status(400).json({ 
          error: "Missing required personal information", 
          missingFields 
        });
        return;
      }

      // Check if verification already exists
      const existingVerification = await db.collection('verifications')
        .where('userId', '==', userId)
        .where('status', 'in', ['pending', 'approved'])
        .limit(1)
        .get();

      if (!existingVerification.empty) {
        res.status(400).json({ error: "Verification already in progress or completed" });
        return;
      }

      const verificationData = {
        userId,
        personalInfo: {
          firstName: personalInfo.firstName,
          lastName: personalInfo.lastName,
          dateOfBirth: personalInfo.dateOfBirth,
          nationalId: personalInfo.nationalId,
          address: personalInfo.address,
          phone: personalInfo.phone || null,
          email: personalInfo.email || null
        },
        documents: documents.map(doc => ({
          type: doc.type, // 'national_id', 'passport', 'business_license', 'insurance'
          fileName: doc.fileName,
          fileUrl: doc.fileUrl,
          uploadedAt: admin.firestore.FieldValue.serverTimestamp()
        })),
        status: 'pending',
        tier: 'basic', // 'basic', 'business', 'premium'
        submittedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        // AI verification results (to be populated by automated checks)
        aiVerification: {
          nationalIdCheck: null,
          faceMatch: null,
          documentAuthenticity: null,
          addressVerification: null
        },
        // Manual review fields
        reviewNotes: null,
        reviewedBy: null,
        reviewedAt: null
      };

      const verificationRef = await db.collection('verifications').add(verificationData);

      // Trigger automated verification checks
      await triggerAutomatedVerification(verificationRef.id, verificationData);

      logger.info("KYC documents submitted", { 
        verificationId: verificationRef.id,
        userId, 
        documentCount: documents.length 
      });

      res.json({ 
        verificationId: verificationRef.id,
        status: 'pending',
        estimatedReviewTime: '24-48 hours'
      });
    } catch (error: any) {
      logger.error("Failed to submit KYC documents", { error: error.message });
      res.status(500).json({ error: "Failed to submit documents" });
    }
  })
);

/**
 * Get verification status for a user
 * GET /home/verification/status
 */
export const getVerificationStatus = withMetrics("getVerificationStatus",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId) {
        res.status(401).json({ error: "Authentication required" });
        return;
      }

      const verificationSnapshot = await db.collection('verifications')
        .where('userId', '==', userId)
        .orderBy('createdAt', 'desc')
        .limit(1)
        .get();

      if (verificationSnapshot.empty) {
        res.json({ 
          status: 'not_started',
          tier: null,
          canSubmit: true
        });
        return;
      }

      const verification = verificationSnapshot.docs[0].data();
      
      res.json({
        verificationId: verificationSnapshot.docs[0].id,
        status: verification.status,
        tier: verification.tier,
        submittedAt: verification.submittedAt,
        reviewedAt: verification.reviewedAt,
        estimatedCompletionTime: calculateEstimatedCompletion(verification),
        canSubmit: verification.status === 'rejected' || verification.status === 'expired',
        // Don't expose sensitive personal info in response
        documentsSubmitted: verification.documents?.length || 0
      });
    } catch (error: any) {
      logger.error("Failed to get verification status", { error: error.message });
      res.status(500).json({ error: "Failed to get verification status" });
    }
  })
);

/**
 * Admin: Review and approve/reject verification
 * POST /home/verification/:id/review
 */
export const reviewVerification = withMetrics("reviewVerification",
  onRequest({ cors: true }, async (req, res) => {
    try {
      const userId = req.auth?.token?.uid;
      if (!userId || !req.auth?.token?.admin) {
        res.status(403).json({ error: "Admin access required" });
        return;
      }

      const { verificationId } = req.query;
      const { action, notes, tier } = req.body;
      
      if (!verificationId || !action) {
        res.status(400).json({ error: "Verification ID and action are required" });
        return;
      }

      if (!['approve', 'reject', 'request_additional'].includes(action)) {
        res.status(400).json({ error: "Invalid action" });
        return;
      }

      const verificationRef = db.collection('verifications').doc(verificationId as string);
      const verificationDoc = await verificationRef.get();
      
      if (!verificationDoc.exists) {
        res.status(404).json({ error: "Verification not found" });
        return;
      }

      const verificationData = verificationDoc.data()!;
      
      if (verificationData.status !== 'pending') {
        res.status(400).json({ error: "Verification is not pending review" });
        return;
      }

      const updateData: any = {
        reviewedBy: userId,
        reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
        reviewNotes: notes || null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      if (action === 'approve') {
        updateData.status = 'approved';
        updateData.approvedAt = admin.firestore.FieldValue.serverTimestamp();
        if (tier) {
          updateData.tier = tier;
        }
        
        // Update professional profile verification status
        await updateProfessionalVerificationStatus(verificationData.userId, true, tier || verificationData.tier);
        
      } else if (action === 'reject') {
        updateData.status = 'rejected';
        updateData.rejectedAt = admin.firestore.FieldValue.serverTimestamp();
        
        // Update professional profile
        await updateProfessionalVerificationStatus(verificationData.userId, false, null);
        
      } else if (action === 'request_additional') {
        updateData.status = 'additional_required';
        updateData.additionalRequestedAt = admin.firestore.FieldValue.serverTimestamp();
      }

      await verificationRef.update(updateData);

      // Send notification to user
      await sendVerificationNotification(verificationData.userId, action, notes);

      logger.info("Verification reviewed", { 
        verificationId, 
        action, 
        reviewedBy: userId,
        userId: verificationData.userId
      });

      res.json({ success: true });
    } catch (error: any) {
      logger.error("Failed to review verification", { error: error.message });
      res.status(500).json({ error: "Failed to review verification" });
    }
  })
);

/**
 * Get pending verifications for admin review
 * GET /home/verification/pending
 */
export const getPendingVerifications = withMetrics("getPendingVerifications",
  onRequest({ cors: true }, async (req, res) => {
    try {
      if (!req.auth?.token?.admin) {
        res.status(403).json({ error: "Admin access required" });
        return;
      }

      const { limit = 20, status = 'pending' } = req.query;

      const verificationSnapshot = await db.collection('verifications')
        .where('status', '==', status)
        .orderBy('submittedAt', 'asc') // Oldest first for fairness
        .limit(Number(limit))
        .get();

      const verifications = verificationSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
        // Don't expose full personal info in list view
        personalInfo: {
          firstName: doc.data().personalInfo?.firstName,
          lastName: doc.data().personalInfo?.lastName,
          // Other fields omitted for privacy
        }
      }));

      res.json({ verifications });
    } catch (error: any) {
      logger.error("Failed to get pending verifications", { error: error.message });
      res.status(500).json({ error: "Failed to get pending verifications" });
    }
  })
);

/**
 * Get detailed verification for admin review
 * GET /home/verification/:id/details
 */
export const getVerificationDetails = withMetrics("getVerificationDetails",
  onRequest({ cors: true }, async (req, res) => {
    try {
      if (!req.auth?.token?.admin) {
        res.status(403).json({ error: "Admin access required" });
        return;
      }

      const { verificationId } = req.query;
      
      if (!verificationId) {
        res.status(400).json({ error: "Verification ID is required" });
        return;
      }

      const verificationDoc = await db.collection('verifications').doc(verificationId as string).get();
      
      if (!verificationDoc.exists) {
        res.status(404).json({ error: "Verification not found" });
        return;
      }

      const verification = { id: verificationDoc.id, ...verificationDoc.data() };

      // Get professional profile for context
      const proProfile = await db.collection('proProfiles').doc(verification.userId).get();
      
      res.json({
        verification,
        professionalProfile: proProfile.exists ? { id: proProfile.id, ...proProfile.data() } : null
      });
    } catch (error: any) {
      logger.error("Failed to get verification details", { error: error.message });
      res.status(500).json({ error: "Failed to get verification details" });
    }
  })
);

/**
 * Automatic processing when verification is submitted
 */
export const processVerificationSubmission = withMetrics("processVerificationSubmission",
  onDocumentCreated("verifications/{verificationId}", async (event) => {
    const verificationData = event.data?.data();
    if (!verificationData) return;

    const verificationId = event.params.verificationId;

    try {
      // Run automated checks
      const aiResults = await runAutomatedVerificationChecks(verificationData);

      // Update verification with AI results
      await db.collection('verifications').doc(verificationId).update({
        aiVerification: aiResults,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Auto-approve if all checks pass and meets criteria
      if (shouldAutoApprove(aiResults, verificationData)) {
        await autoApproveVerification(verificationId, verificationData);
      }

      logger.info("Verification processed automatically", { 
        verificationId,
        aiResults: Object.keys(aiResults)
      });

    } catch (error: any) {
      logger.error("Failed to process verification", { 
        verificationId, 
        error: error.message 
      });
    }
  })
);

// Helper Functions

async function triggerAutomatedVerification(verificationId: string, verificationData: any) {
  // In production, this would trigger external KYC services
  // For now, simulate the process
  
  setTimeout(async () => {
    try {
      const aiResults = await runAutomatedVerificationChecks(verificationData);
      
      await db.collection('verifications').doc(verificationId).update({
        aiVerification: aiResults,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      if (shouldAutoApprove(aiResults, verificationData)) {
        await autoApproveVerification(verificationId, verificationData);
      }
    } catch (error) {
      logger.error("Automated verification failed", { verificationId, error });
    }
  }, 5000); // 5 second delay to simulate processing
}

async function runAutomatedVerificationChecks(verificationData: any) {
  // Simulate AI verification checks
  // In production, integrate with services like Jumio, Onfido, etc.
  
  const results = {
    nationalIdCheck: {
      status: Math.random() > 0.1 ? 'passed' : 'failed',
      confidence: Math.random() * 0.3 + 0.7, // 0.7 to 1.0
      details: 'National ID format and checksum validation'
    },
    faceMatch: {
      status: Math.random() > 0.05 ? 'passed' : 'failed',
      confidence: Math.random() * 0.2 + 0.8, // 0.8 to 1.0
      details: 'Face matching between selfie and ID document'
    },
    documentAuthenticity: {
      status: Math.random() > 0.15 ? 'passed' : 'failed',
      confidence: Math.random() * 0.25 + 0.75, // 0.75 to 1.0
      details: 'Document security features and authenticity'
    },
    addressVerification: {
      status: Math.random() > 0.2 ? 'passed' : 'failed',
      confidence: Math.random() * 0.3 + 0.6, // 0.6 to 0.9
      details: 'Address validation against official records'
    }
  };

  return results;
}

function shouldAutoApprove(aiResults: any, verificationData: any): boolean {
  // Auto-approve if all AI checks pass with high confidence
  const checks = Object.values(aiResults);
  const allPassed = checks.every((check: any) => check.status === 'passed');
  const highConfidence = checks.every((check: any) => check.confidence >= 0.8);
  
  // Additional criteria for auto-approval
  const hasRequiredDocs = verificationData.documents?.length >= 2;
  const basicTier = verificationData.tier === 'basic';
  
  return allPassed && highConfidence && hasRequiredDocs && basicTier;
}

async function autoApproveVerification(verificationId: string, verificationData: any) {
  await db.collection('verifications').doc(verificationId).update({
    status: 'approved',
    approvedAt: admin.firestore.FieldValue.serverTimestamp(),
    reviewedBy: 'system_auto_approval',
    reviewNotes: 'Automatically approved based on AI verification results',
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });

  // Update professional profile
  await updateProfessionalVerificationStatus(verificationData.userId, true, verificationData.tier);

  // Send notification
  await sendVerificationNotification(verificationData.userId, 'approve', 'Automatically verified');

  logger.info("Verification auto-approved", { 
    verificationId, 
    userId: verificationData.userId 
  });
}

async function updateProfessionalVerificationStatus(userId: string, isVerified: boolean, tier: string | null) {
  try {
    const updateData: any = {
      'verification.isVerified': isVerified,
      'verification.verifiedAt': isVerified ? admin.firestore.FieldValue.serverTimestamp() : null,
      'verification.tier': tier,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    // Add verification badge based on tier
    if (isVerified && tier) {
      updateData['verification.badges'] = [`verified_${tier}`];
    }

    await db.collection('proProfiles').doc(userId).update(updateData);
  } catch (error) {
    logger.error("Failed to update professional verification status", { userId, error });
  }
}

async function sendVerificationNotification(userId: string, action: string, notes: string | null) {
  try {
    const notificationData = {
      userId,
      type: 'verification_update',
      title: getNotificationTitle(action),
      message: getNotificationMessage(action, notes),
      data: {
        action,
        notes
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false
    };

    await db.collection('notifications').add(notificationData);

    // In production, also send FCM notification
    logger.info("Verification notification sent", { userId, action });
  } catch (error) {
    logger.error("Failed to send verification notification", { userId, error });
  }
}

function getNotificationTitle(action: string): string {
  switch (action) {
    case 'approve':
      return 'Verification Approved ✅';
    case 'reject':
      return 'Verification Rejected ❌';
    case 'request_additional':
      return 'Additional Documents Required 📄';
    default:
      return 'Verification Update';
  }
}

function getNotificationMessage(action: string, notes: string | null): string {
  const baseMessages = {
    approve: 'Your identity has been verified! You can now offer services as a verified professional.',
    reject: 'Your verification was not approved. Please review the feedback and resubmit.',
    request_additional: 'Additional documents are required to complete your verification.'
  };

  let message = baseMessages[action as keyof typeof baseMessages] || 'Your verification status has been updated.';
  
  if (notes) {
    message += ` Note: ${notes}`;
  }
  
  return message;
}

function calculateEstimatedCompletion(verification: any): string | null {
  if (verification.status !== 'pending') return null;
  
  const submittedAt = verification.submittedAt?.toDate();
  if (!submittedAt) return null;
  
  // Estimate 24-48 hours for manual review
  const hoursElapsed = (Date.now() - submittedAt.getTime()) / (1000 * 60 * 60);
  const remainingHours = Math.max(0, 48 - hoursElapsed);
  
  if (remainingHours < 1) {
    return 'Soon';
  } else if (remainingHours < 24) {
    return `${Math.ceil(remainingHours)} hours`;
  } else {
    return `${Math.ceil(remainingHours / 24)} days`;
  }
}