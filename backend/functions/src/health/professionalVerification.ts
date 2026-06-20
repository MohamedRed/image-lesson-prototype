import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import { logger } from 'firebase-functions';
import { getStorage } from 'firebase-admin/storage';

const db = getFirestore();
const auth = getAuth();
const storage = getStorage();

interface ProfessionalApplication {
  id: string;
  applicantEmail: string;
  personalInfo: {
    firstName: string;
    lastName: string;
    phoneNumber: string;
    dateOfBirth: string;
    address: {
      street: string;
      city: string;
      state: string;
      postalCode: string;
      country: string;
    };
  };
  professionalInfo: {
    type: 'doctor' | 'nurse' | 'therapist' | 'nutritionist' | 'trainer' | 'psychologist';
    specialties: string[];
    licenseNumber: string;
    licenseState: string;
    licenseExpiry: string;
    education: Array<{
      degree: string;
      institution: string;
      graduationYear: number;
    }>;
    experience: {
      yearsOfPractice: number;
      currentEmployer?: string;
      previousPositions: Array<{
        title: string;
        organization: string;
        startDate: string;
        endDate: string;
      }>;
    };
    certifications: Array<{
      name: string;
      issuingBody: string;
      issueDate: string;
      expiryDate?: string;
    }>;
  };
  serviceOfferings: {
    consultationTypes: ('telehealth' | 'in_person' | 'both')[];
    languages: string[];
    availableHours: {
      timezone: string;
      schedule: Record<string, { start: string; end: string; available: boolean }>;
    };
    pricingModel: {
      consultationFee: number;
      followupFee?: number;
      packageDeals?: Array<{
        name: string;
        sessions: number;
        price: number;
        description: string;
      }>;
    };
    insuranceAccepted: string[];
  };
  documents: {
    licenseDocument: string; // Storage path
    degreeCertificates: string[];
    professionalHeadshot: string;
    malpracticeInsurance?: string;
    backgroundCheck?: string;
  };
  verification: {
    status: 'pending' | 'under_review' | 'approved' | 'rejected' | 'additional_info_required';
    submittedAt: string;
    reviewedAt?: string;
    reviewedBy?: string;
    verificationSteps: {
      identityVerified: boolean;
      licenseVerified: boolean;
      educationVerified: boolean;
      backgroundCheckPassed: boolean;
      malpracticeInsuranceVerified: boolean;
      platformTrainingCompleted: boolean;
    };
    rejectionReason?: string;
    additionalInfoRequested?: string;
    verificationScore: number; // 0-100
  };
}

interface VerificationChecklist {
  stepName: string;
  description: string;
  status: 'pending' | 'in_progress' | 'completed' | 'failed';
  verifiedBy?: string;
  verifiedAt?: string;
  notes?: string;
  documents?: string[];
}

// Submit professional application
export const submitProfessionalApplication = onCall<{
  application: Omit<ProfessionalApplication, 'id' | 'verification'>
}, { applicationId: string; status: string }>(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request: CallableRequest<any>): Promise<{ applicationId: string; status: string }> => {
    try {
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const { application } = request.data;

      // Validate required fields
      if (!application.personalInfo?.firstName || !application.personalInfo?.lastName ||
          !application.professionalInfo?.licenseNumber || !application.documents?.licenseDocument) {
        throw new HttpsError('invalid-argument', 'Missing required application fields');
      }

      logger.info(`Processing professional application for ${application.applicantEmail}`);

      // Create application with initial verification status
      const applicationData: ProfessionalApplication = {
        ...application,
        id: '', // Will be set by Firestore
        verification: {
          status: 'pending',
          submittedAt: new Date().toISOString(),
          verificationSteps: {
            identityVerified: false,
            licenseVerified: false,
            educationVerified: false,
            backgroundCheckPassed: false,
            malpracticeInsuranceVerified: false,
            platformTrainingCompleted: false
          },
          verificationScore: 0
        }
      };

      // Store application
      const appRef = await db.collection('professionalApplications').add({
        ...applicationData,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp()
      });

      applicationData.id = appRef.id;

      // Create verification checklist
      await createVerificationChecklist(appRef.id, applicationData);

      // Trigger automated verification checks
      await triggerAutomatedVerification(appRef.id, applicationData);

      // Send confirmation email to applicant
      await sendApplicationConfirmation(application.applicantEmail, appRef.id);

      // Notify verification team
      await notifyVerificationTeam(appRef.id, applicationData);

      logger.info(`Professional application submitted: ${appRef.id}`);

      return {
        applicationId: appRef.id,
        status: 'submitted'
      };

    } catch (error) {
      logger.error('Error submitting professional application:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to submit professional application');
    }
  }
);

// Admin function to review professional applications
export const reviewProfessionalApplication = onCall<{
  applicationId: string;
  action: 'approve' | 'reject' | 'request_info';
  notes?: string;
  verificationUpdates?: Record<string, boolean>;
}, { success: boolean }>(
  {
    cors: true, // Admin only - authentication handled separately
  },
  async (request: CallableRequest<any>): Promise<{ success: boolean }> => {
    try {
      // Check if user has admin privileges
      const isAdmin = await checkAdminPrivileges(request.auth?.uid);
      if (!isAdmin) {
        throw new HttpsError('permission-denied', 'Admin privileges required');
      }

      const { applicationId, action, notes, verificationUpdates } = request.data;
      const reviewerId = request.auth!.uid;

      logger.info(`Admin ${reviewerId} reviewing application ${applicationId}: ${action}`);

      const appRef = db.collection('professionalApplications').doc(applicationId);
      const appDoc = await appRef.get();

      if (!appDoc.exists) {
        throw new HttpsError('not-found', 'Application not found');
      }

      const application = appDoc.data() as ProfessionalApplication;

      // Update verification steps if provided
      if (verificationUpdates) {
        await updateVerificationSteps(applicationId, verificationUpdates, reviewerId);
      }

      let newStatus: ProfessionalApplication['verification']['status'];
      let additionalUpdates: any = {
        'verification.reviewedAt': new Date().toISOString(),
        'verification.reviewedBy': reviewerId,
        updatedAt: FieldValue.serverTimestamp()
      };

      switch (action) {
        case 'approve':
          newStatus = 'approved';
          // Create professional profile
          await createProfessionalProfile(application);
          // Send approval email
          await sendApprovalNotification(application.applicantEmail, applicationId);
          break;

        case 'reject':
          newStatus = 'rejected';
          additionalUpdates['verification.rejectionReason'] = notes || 'Application does not meet requirements';
          // Send rejection email
          await sendRejectionNotification(application.applicantEmail, applicationId, notes);
          break;

        case 'request_info':
          newStatus = 'additional_info_required';
          additionalUpdates['verification.additionalInfoRequested'] = notes || 'Additional information required';
          // Send info request email
          await sendAdditionalInfoRequest(application.applicantEmail, applicationId, notes);
          break;

        default:
          throw new HttpsError('invalid-argument', 'Invalid review action');
      }

      // Update application status
      await appRef.update({
        'verification.status': newStatus,
        ...additionalUpdates
      });

      // Log review action
      await db.collection('verificationLog').add({
        applicationId,
        reviewerId,
        action,
        notes,
        timestamp: FieldValue.serverTimestamp()
      });

      logger.info(`Application ${applicationId} ${action} by admin ${reviewerId}`);

      return { success: true };

    } catch (error) {
      logger.error('Error reviewing professional application:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to review application');
    }
  }
);

// Get pending applications for admin review
export const getPendingApplications = onCall<{
  limit?: number;
  status?: string;
}, { applications: any[] }>(
  {
    cors: true,
  },
  async (request: CallableRequest<any>): Promise<{ applications: any[] }> => {
    try {
      // Check admin privileges
      const isAdmin = await checkAdminPrivileges(request.auth?.uid);
      if (!isAdmin) {
        throw new HttpsError('permission-denied', 'Admin privileges required');
      }

      const { limit = 50, status = 'pending' } = request.data;

      let query = db.collection('professionalApplications')
        .where('verification.status', '==', status)
        .orderBy('verification.submittedAt', 'desc')
        .limit(limit);

      const snapshot = await query.get();

      const applications = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
        // Remove sensitive information for admin list view
        documents: undefined
      }));

      return { applications };

    } catch (error) {
      logger.error('Error getting pending applications:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to get pending applications');
    }
  }
);

// Automated verification trigger
export const onApplicationSubmission = onDocumentWritten(
  'professionalApplications/{applicationId}',
  async (event) => {
    try {
      const snapshot = event.data;
      if (!snapshot || !snapshot.after.exists) return;

      const application = snapshot.after.data() as ProfessionalApplication;
      
      // Only run on new applications
      if (snapshot.before.exists) return;

      logger.info(`Starting automated verification for application ${application.id}`);

      // Run automated verification checks
      await runAutomatedVerificationChecks(application.id, application);

    } catch (error) {
      logger.error('Error in application submission trigger:', error);
    }
  }
);

// Helper functions
async function createVerificationChecklist(applicationId: string, application: ProfessionalApplication): Promise<void> {
  const checklist: VerificationChecklist[] = [
    {
      stepName: 'identity_verification',
      description: 'Verify applicant identity matches provided documents',
      status: 'pending'
    },
    {
      stepName: 'license_verification',
      description: 'Verify professional license with state board',
      status: 'pending',
      documents: [application.documents.licenseDocument]
    },
    {
      stepName: 'education_verification',
      description: 'Verify educational credentials',
      status: 'pending',
      documents: application.documents.degreeCertificates
    },
    {
      stepName: 'background_check',
      description: 'Conduct criminal background check',
      status: 'pending'
    },
    {
      stepName: 'malpractice_insurance',
      description: 'Verify current malpractice insurance coverage',
      status: application.documents.malpracticeInsurance ? 'pending' : 'failed'
    },
    {
      stepName: 'platform_training',
      description: 'Complete platform orientation and training',
      status: 'pending'
    }
  ];

  const batch = db.batch();
  
  checklist.forEach((item, index) => {
    const checklistRef = db
      .collection('professionalApplications')
      .doc(applicationId)
      .collection('verificationChecklist')
      .doc(`step_${index + 1}`);
    
    batch.set(checklistRef, {
      ...item,
      createdAt: FieldValue.serverTimestamp()
    });
  });

  await batch.commit();
}

async function triggerAutomatedVerification(applicationId: string, application: ProfessionalApplication): Promise<void> {
  // Queue automated verification tasks
  const tasks = [
    { type: 'license_check', applicationId, licenseNumber: application.professionalInfo.licenseNumber, state: application.professionalInfo.licenseState },
    { type: 'identity_verification', applicationId, documentPath: application.documents.licenseDocument },
    { type: 'education_check', applicationId, degrees: application.professionalInfo.education }
  ];

  // In production, these would be queued as Cloud Tasks
  for (const task of tasks) {
    await db.collection('verificationTasks').add({
      ...task,
      status: 'queued',
      createdAt: FieldValue.serverTimestamp()
    });
  }

  logger.info(`Queued ${tasks.length} automated verification tasks for ${applicationId}`);
}

async function runAutomatedVerificationChecks(applicationId: string, application: ProfessionalApplication): Promise<void> {
  try {
    // Basic document validation
    await validateUploadedDocuments(applicationId, application.documents);
    
    // License format validation
    const licenseValid = validateLicenseFormat(
      application.professionalInfo.licenseNumber, 
      application.professionalInfo.type,
      application.professionalInfo.licenseState
    );

    // Update verification scores
    let verificationScore = 0;
    
    if (licenseValid) {
      verificationScore += 20;
      await updateVerificationStep(applicationId, 'license_verification', true, 'Automated license format validation passed');
    }

    // Check document completeness
    const requiredDocs = ['licenseDocument', 'degreeCertificates', 'professionalHeadshot'];
    const docsComplete = requiredDocs.every(doc => application.documents[doc as keyof typeof application.documents]);
    
    if (docsComplete) {
      verificationScore += 15;
    }

    // Update overall verification score
    await db.collection('professionalApplications').doc(applicationId).update({
      'verification.verificationScore': verificationScore,
      'verification.status': verificationScore >= 50 ? 'under_review' : 'pending'
    });

  } catch (error) {
    logger.error(`Automated verification failed for ${applicationId}: ${error}`);
  }
}

async function validateUploadedDocuments(applicationId: string, documents: ProfessionalApplication['documents']): Promise<boolean> {
  try {
    const bucket = storage.bucket();
    
    for (const [docType, path] of Object.entries(documents)) {
      if (typeof path === 'string') {
        const file = bucket.file(path);
        const [exists] = await file.exists();
        
        if (!exists) {
          logger.warn(`Document ${docType} not found at path: ${path}`);
          return false;
        }

        // Check file size and type
        const [metadata] = await file.getMetadata();
        const fileSizeMB = metadata.size / (1024 * 1024);
        
        if (fileSizeMB > 10) { // 10MB limit
          logger.warn(`Document ${docType} exceeds size limit: ${fileSizeMB}MB`);
          return false;
        }
      }
    }

    return true;

  } catch (error) {
    logger.error(`Document validation error: ${error}`);
    return false;
  }
}

function validateLicenseFormat(licenseNumber: string, professionalType: string, state: string): boolean {
  // Basic format validation - in production, this would be more sophisticated
  if (!licenseNumber || licenseNumber.length < 5) {
    return false;
  }

  // State-specific license format validation could be added here
  const commonPatterns: Record<string, RegExp> = {
    'doctor': /^[A-Z]{1,3}\d{4,8}$/,
    'nurse': /^RN\d{4,6}$/,
    'therapist': /^[A-Z]{2}\d{4,6}$/,
    'nutritionist': /^[A-Z]{1,2}\d{4,6}$/
  };

  const pattern = commonPatterns[professionalType];
  return pattern ? pattern.test(licenseNumber.toUpperCase()) : true;
}

async function updateVerificationStep(applicationId: string, stepName: string, passed: boolean, notes?: string): Promise<void> {
  const checklistQuery = await db
    .collection('professionalApplications')
    .doc(applicationId)
    .collection('verificationChecklist')
    .where('stepName', '==', stepName)
    .limit(1)
    .get();

  if (!checklistQuery.empty) {
    const stepDoc = checklistQuery.docs[0];
    await stepDoc.ref.update({
      status: passed ? 'completed' : 'failed',
      notes,
      verifiedAt: new Date().toISOString(),
      verifiedBy: 'system'
    });
  }
}

async function updateVerificationSteps(applicationId: string, updates: Record<string, boolean>, reviewerId: string): Promise<void> {
  const appRef = db.collection('professionalApplications').doc(applicationId);
  
  const updateFields: Record<string, any> = {};
  
  for (const [step, passed] of Object.entries(updates)) {
    updateFields[`verification.verificationSteps.${step}`] = passed;
  }

  await appRef.update(updateFields);

  // Update checklist items
  for (const [step, passed] of Object.entries(updates)) {
    await updateVerificationStep(applicationId, step, passed, `Manually verified by admin ${reviewerId}`);
  }
}

async function createProfessionalProfile(application: ProfessionalApplication): Promise<void> {
  // Create Firebase Auth user for the professional
  const userRecord = await auth.createUser({
    email: application.applicantEmail,
    emailVerified: true,
    displayName: `${application.personalInfo.firstName} ${application.personalInfo.lastName}`,
  });

  // Create professional profile in health system
  const professionalProfile = {
    userId: userRecord.uid,
    type: application.professionalInfo.type,
    name: `${application.personalInfo.firstName} ${application.personalInfo.lastName}`,
    credentials: application.professionalInfo.certifications.map(c => c.name),
    specialties: application.professionalInfo.specialties,
    bio: `${application.professionalInfo.experience.yearsOfPractice} years of experience in ${application.professionalInfo.specialties.join(', ')}`,
    licenseNumber: application.professionalInfo.licenseNumber,
    licenseState: application.professionalInfo.licenseState,
    profileImageUrl: application.documents.professionalHeadshot,
    isVerified: true,
    isAvailable: true,
    rating: 5.0, // Initial rating
    reviewCount: 0,
    consultationTypes: application.serviceOfferings.consultationTypes,
    languages: application.serviceOfferings.languages,
    services: application.serviceOfferings.pricingModel.packageDeals?.map(pkg => ({
      id: pkg.name.toLowerCase().replace(/\s+/g, '_'),
      name: pkg.name,
      description: pkg.description,
      price: pkg.price / pkg.sessions, // Per session price
      duration: 60, // Default 60 minutes
      category: 'consultation'
    })) || [],
    availability: application.serviceOfferings.availableHours,
    verifiedAt: new Date().toISOString(),
    applicationId: application.id
  };

  await db.collection('healthProfessionals').doc(userRecord.uid).set({
    ...professionalProfile,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp()
  });

  logger.info(`Created professional profile for ${application.applicantEmail}`);
}

async function checkAdminPrivileges(uid?: string): Promise<boolean> {
  if (!uid) return false;

  try {
    const userRecord = await auth.getUser(uid);
    return userRecord.customClaims?.admin === true;
  } catch (error) {
    logger.error(`Error checking admin privileges for ${uid}: ${error}`);
    return false;
  }
}

// Notification functions (simplified - would integrate with email service)
async function sendApplicationConfirmation(email: string, applicationId: string): Promise<void> {
  logger.info(`Sending application confirmation to ${email} for application ${applicationId}`);
  // In production, integrate with email service (SendGrid, etc.)
}

async function sendApprovalNotification(email: string, applicationId: string): Promise<void> {
  logger.info(`Sending approval notification to ${email} for application ${applicationId}`);
}

async function sendRejectionNotification(email: string, applicationId: string, reason?: string): Promise<void> {
  logger.info(`Sending rejection notification to ${email} for application ${applicationId}: ${reason}`);
}

async function sendAdditionalInfoRequest(email: string, applicationId: string, request?: string): Promise<void> {
  logger.info(`Sending additional info request to ${email} for application ${applicationId}: ${request}`);
}

async function notifyVerificationTeam(applicationId: string, application: ProfessionalApplication): Promise<void> {
  logger.info(`Notifying verification team of new application ${applicationId} from ${application.applicantEmail}`);
  
  // Create notification for admin dashboard
  await db.collection('adminNotifications').add({
    type: 'new_professional_application',
    applicationId,
    applicantName: `${application.personalInfo.firstName} ${application.personalInfo.lastName}`,
    professionalType: application.professionalInfo.type,
    priority: 'normal',
    isRead: false,
    createdAt: FieldValue.serverTimestamp()
  });
}