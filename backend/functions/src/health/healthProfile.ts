import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';

const db = getFirestore();

interface HealthProfile {
  id?: string;
  userId: string;
  demographics?: {
    age?: number;
    height?: number;
    biologicalSex?: 'male' | 'female' | 'other' | 'notSet';
    bloodType?: string;
  };
  consents: HealthConsent[];
  goals: HealthGoal[];
  measurementPreferences: {
    weightUnit: 'kg' | 'lbs';
    heightUnit: 'cm' | 'ft';
    temperatureUnit: 'celsius' | 'fahrenheit';
    distanceUnit: 'km' | 'miles';
  };
  conditions: HealthCondition[];
  emergencyContacts: EmergencyContact[];
  createdAt?: string;
  updatedAt?: string;
}

interface HealthConsent {
  type: 'dataProcessing' | 'research' | 'marketing' | 'thirdPartySharing';
  granted: boolean;
  grantedAt?: string;
  version: string;
}

interface HealthGoal {
  id: string;
  userId: string;
  title: string;
  description: string;
  type: 'weightLoss' | 'weightGain' | 'stepsDaily' | 'exerciseMinutes' | 'sleepHours' | 'waterIntake' | 'caloriesBurned';
  targetValue: number;
  currentValue: number;
  unit: string;
  targetDate: string;
  priority: 'low' | 'medium' | 'high';
  status: 'active' | 'paused' | 'completed' | 'archived';
  createdAt: string;
  updatedAt: string;
}

interface HealthCondition {
  id: string;
  name: string;
  icd10Code?: string;
  severity: 'mild' | 'moderate' | 'severe';
  diagnosedDate?: string;
  status: 'active' | 'resolved' | 'chronic';
  notes?: string;
}

interface EmergencyContact {
  id: string;
  name: string;
  relationship: string;
  phoneNumber: string;
  isPrimary: boolean;
}

interface UpdateHealthProfileRequest {
  profile: HealthProfile;
}

interface UpdateConsentRequest {
  consent: HealthConsent;
}

// Update health profile
export const updateHealthProfile = onCall<UpdateHealthProfileRequest, HealthProfile>(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request: CallableRequest<UpdateHealthProfileRequest>): Promise<HealthProfile> => {
    try {
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const userId = request.auth.uid;
      const { profile } = request.data;

      // Validate profile data
      if (!profile || profile.userId !== userId) {
        throw new HttpsError('invalid-argument', 'Invalid profile data');
      }

      logger.info(`Updating health profile for user: ${userId}`);

      // Prepare profile data for saving
      const profileData = {
        ...profile,
        userId,
        updatedAt: FieldValue.serverTimestamp()
      };

      // Check if profile exists
      const profileRef = db.collection('healthProfiles').doc(userId);
      const existingProfile = await profileRef.get();

      if (existingProfile.exists) {
        // Update existing profile
        await profileRef.update(profileData);
      } else {
        // Create new profile
        profileData.createdAt = FieldValue.serverTimestamp();
        await profileRef.set(profileData);
      }

      // Get updated profile
      const updatedProfileDoc = await profileRef.get();
      const updatedProfile = updatedProfileDoc.data()!;

      // Convert timestamps back to ISO strings
      const response: HealthProfile = {
        ...updatedProfile,
        id: userId,
        createdAt: updatedProfile.createdAt?.toDate?.().toISOString() || new Date().toISOString(),
        updatedAt: updatedProfile.updatedAt?.toDate?.().toISOString() || new Date().toISOString()
      };

      // Update any related data based on profile changes
      await updateRelatedHealthData(userId, profile);

      logger.info(`Successfully updated health profile for user: ${userId}`);
      return response;

    } catch (error) {
      logger.error('Error updating health profile:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to update health profile');
    }
  }
);

// Update user consent
export const updateConsent = onCall<UpdateConsentRequest, HealthConsent>(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request: CallableRequest<UpdateConsentRequest>): Promise<HealthConsent> => {
    try {
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const userId = request.auth.uid;
      const { consent } = request.data;

      if (!consent || !consent.type) {
        throw new HttpsError('invalid-argument', 'Invalid consent data');
      }

      logger.info(`Updating consent for user: ${userId}, type: ${consent.type}`);

      // Get current profile
      const profileRef = db.collection('healthProfiles').doc(userId);
      const profileDoc = await profileRef.get();
      
      if (!profileDoc.exists) {
        throw new HttpsError('not-found', 'Health profile not found');
      }

      const profileData = profileDoc.data()!;
      const consents = profileData.consents || [];

      // Find existing consent or add new one
      const existingConsentIndex = consents.findIndex((c: HealthConsent) => c.type === consent.type);
      
      const updatedConsent: HealthConsent = {
        type: consent.type,
        granted: consent.granted,
        grantedAt: consent.granted ? new Date().toISOString() : consent.grantedAt,
        version: consent.version || '1.0'
      };

      if (existingConsentIndex >= 0) {
        consents[existingConsentIndex] = updatedConsent;
      } else {
        consents.push(updatedConsent);
      }

      // Update profile with new consents
      await profileRef.update({
        consents,
        updatedAt: FieldValue.serverTimestamp()
      });

      // Log consent change for audit trail
      await db.collection('consentHistory').add({
        userId,
        consentType: consent.type,
        granted: consent.granted,
        previousStatus: existingConsentIndex >= 0 ? consents[existingConsentIndex]?.granted : null,
        version: consent.version || '1.0',
        timestamp: FieldValue.serverTimestamp(),
        userAgent: request.rawRequest?.headers?.['user-agent'] || 'unknown',
        ipAddress: request.rawRequest?.ip || 'unknown'
      });

      // Handle consent-specific actions
      await handleConsentChange(userId, consent);

      logger.info(`Successfully updated consent for user: ${userId}, type: ${consent.type}, granted: ${consent.granted}`);
      return updatedConsent;

    } catch (error) {
      logger.error('Error updating consent:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to update consent');
    }
  }
);

// Handle consent-specific actions
async function handleConsentChange(userId: string, consent: HealthConsent) {
  switch (consent.type) {
    case 'dataProcessing':
      if (!consent.granted) {
        // User revoked data processing consent - pause data collection
        await pauseDataCollection(userId);
      } else {
        // User granted data processing consent - resume data collection
        await resumeDataCollection(userId);
      }
      break;

    case 'research':
      if (!consent.granted) {
        // Remove user from research cohorts
        await removeFromResearchCohorts(userId);
      } else {
        // Add user to appropriate research cohorts
        await addToResearchCohorts(userId);
      }
      break;

    case 'marketing':
      if (!consent.granted) {
        // Unsubscribe from marketing communications
        await unsubscribeFromMarketing(userId);
      } else {
        // Subscribe to relevant marketing communications
        await subscribeToMarketing(userId);
      }
      break;

    case 'thirdPartySharing':
      if (!consent.granted) {
        // Stop sharing data with third parties
        await stopThirdPartySharing(userId);
      } else {
        // Allow third party sharing with approved partners
        await enableThirdPartySharing(userId);
      }
      break;
  }
}

// Update related health data when profile changes
async function updateRelatedHealthData(userId: string, profile: HealthProfile) {
  // Update user preferences document
  await db.collection('userPreferences').doc(userId).set({
    measurementPreferences: profile.measurementPreferences,
    updatedAt: FieldValue.serverTimestamp()
  }, { merge: true });

  // Update goals if they changed
  if (profile.goals && profile.goals.length > 0) {
    const batch = db.batch();
    
    profile.goals.forEach(goal => {
      const goalRef = db.collection('healthGoals').doc(goal.id);
      batch.set(goalRef, {
        ...goal,
        userId,
        updatedAt: FieldValue.serverTimestamp()
      }, { merge: true });
    });

    await batch.commit();
  }

  // Update emergency contacts
  if (profile.emergencyContacts && profile.emergencyContacts.length > 0) {
    const contactsRef = db.collection('emergencyContacts').doc(userId);
    await contactsRef.set({
      userId,
      contacts: profile.emergencyContacts,
      updatedAt: FieldValue.serverTimestamp()
    });
  }
}

// Consent action handlers
async function pauseDataCollection(userId: string) {
  await db.collection('userPreferences').doc(userId).update({
    dataCollectionPaused: true,
    pausedAt: FieldValue.serverTimestamp()
  });
  
  logger.info(`Paused data collection for user: ${userId}`);
}

async function resumeDataCollection(userId: string) {
  await db.collection('userPreferences').doc(userId).update({
    dataCollectionPaused: false,
    resumedAt: FieldValue.serverTimestamp()
  });
  
  logger.info(`Resumed data collection for user: ${userId}`);
}

async function removeFromResearchCohorts(userId: string) {
  // Remove user from all active research studies
  const studiesQuery = await db
    .collection('researchParticipants')
    .where('userId', '==', userId)
    .where('status', '==', 'active')
    .get();

  const batch = db.batch();
  studiesQuery.docs.forEach(doc => {
    batch.update(doc.ref, {
      status: 'withdrawn',
      withdrawnAt: FieldValue.serverTimestamp(),
      withdrawnReason: 'consent_revoked'
    });
  });

  await batch.commit();
  logger.info(`Removed user ${userId} from research cohorts`);
}

async function addToResearchCohorts(userId: string) {
  // This would match user to appropriate research studies
  // Based on their health profile and eligibility criteria
  logger.info(`Evaluating research opportunities for user: ${userId}`);
}

async function unsubscribeFromMarketing(userId: string) {
  await db.collection('marketingPreferences').doc(userId).update({
    subscribed: false,
    unsubscribedAt: FieldValue.serverTimestamp()
  });
  
  logger.info(`Unsubscribed user ${userId} from marketing`);
}

async function subscribeToMarketing(userId: string) {
  await db.collection('marketingPreferences').doc(userId).set({
    userId,
    subscribed: true,
    subscribedAt: FieldValue.serverTimestamp(),
    preferences: {
      healthTips: true,
      programUpdates: true,
      researchOpportunities: false
    }
  }, { merge: true });
  
  logger.info(`Subscribed user ${userId} to marketing`);
}

async function stopThirdPartySharing(userId: string) {
  await db.collection('userPreferences').doc(userId).update({
    thirdPartySharingEnabled: false,
    thirdPartySharingDisabledAt: FieldValue.serverTimestamp()
  });
  
  // Notify third party integrations to stop data sharing
  await notifyThirdPartyIntegrations(userId, 'stop_sharing');
  
  logger.info(`Stopped third party sharing for user: ${userId}`);
}

async function enableThirdPartySharing(userId: string) {
  await db.collection('userPreferences').doc(userId).update({
    thirdPartySharingEnabled: true,
    thirdPartySharingEnabledAt: FieldValue.serverTimestamp()
  });
  
  logger.info(`Enabled third party sharing for user: ${userId}`);
}

async function notifyThirdPartyIntegrations(userId: string, action: 'start_sharing' | 'stop_sharing') {
  // This would notify integrated services about consent changes
  // For example: Fitbit, Apple Health, research partners, etc.
  
  await db.collection('integrationEvents').add({
    userId,
    action,
    timestamp: FieldValue.serverTimestamp(),
    processed: false
  });
  
  logger.info(`Queued third party integration notification for user: ${userId}, action: ${action}`);
}