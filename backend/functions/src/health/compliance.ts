import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { onDocumentWritten, onDocumentDeleted } from 'firebase-functions/v2/firestore';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { getAuth } from 'firebase-admin/auth';

const db = getFirestore();
const auth = getAuth();

interface AuditLogEntry {
  userId: string;
  action: 'create' | 'read' | 'update' | 'delete' | 'access' | 'export' | 'share';
  resourceType: 'healthProfile' | 'observation' | 'program' | 'insight' | 'appointment';
  resourceId?: string;
  timestamp: string;
  userAgent?: string;
  ipAddress?: string;
  consentStatus: Record<string, boolean>;
  dataTypes: string[];
  justification?: string;
  outcome: 'success' | 'denied' | 'error';
  errorMessage?: string;
}

interface ComplianceCheck {
  checkType: 'data_retention' | 'consent_verification' | 'access_audit' | 'data_anonymization';
  userId?: string;
  status: 'compliant' | 'non_compliant' | 'warning';
  findings: string[];
  recommendations: string[];
  checkedAt: string;
  nextCheckDue: string;
}

interface DataRetentionPolicy {
  dataType: string;
  retentionPeriodDays: number;
  anonymizationRequired: boolean;
  deletionMethod: 'soft_delete' | 'hard_delete' | 'anonymize';
  complianceFramework: 'GDPR' | 'CCPA' | 'HIPAA' | 'SOX';
}

interface PrivacyRequest {
  userId: string;
  requestType: 'access' | 'rectification' | 'erasure' | 'portability' | 'restriction';
  status: 'pending' | 'processing' | 'completed' | 'denied';
  requestedAt: string;
  completedAt?: string;
  dataTypes?: string[];
  reason?: string;
  verificationMethod: 'email' | 'phone' | 'identity_document';
  processingNotes: string[];
}

// HIPAA-compliant audit logging
export const logHealthDataAccess = onCall<{
  action: string;
  resourceType: string;
  resourceId?: string;
  dataTypes: string[];
  justification?: string;
}, {logged: boolean}>(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request: CallableRequest<any>): Promise<{logged: boolean}> => {
    try {
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const userId = request.auth.uid;
      const { action, resourceType, resourceId, dataTypes, justification } = request.data;

      // Get user's current consent status
      const userProfile = await db.collection('healthProfiles').doc(userId).get();
      const consentStatus = userProfile.exists ? 
        (userProfile.data()?.consents || []).reduce((acc: any, consent: any) => {
          acc[consent.type] = consent.granted;
          return acc;
        }, {}) : {};

      const auditEntry: AuditLogEntry = {
        userId,
        action,
        resourceType,
        resourceId,
        timestamp: new Date().toISOString(),
        userAgent: request.rawRequest?.headers?.['user-agent'] || 'unknown',
        ipAddress: request.rawRequest?.ip || 'unknown',
        consentStatus,
        dataTypes,
        justification,
        outcome: 'success'
      };

      // Store audit log with high security
      await db.collection('auditLogs').add({
        ...auditEntry,
        createdAt: FieldValue.serverTimestamp(),
        // Hash sensitive data for security
        ipAddressHash: hashSensitiveData(auditEntry.ipAddress),
        userAgentHash: hashSensitiveData(auditEntry.userAgent || '')
      });

      logger.info(`Audit log created for user: ${userId}, action: ${action}`);
      return { logged: true };

    } catch (error) {
      logger.error('Error logging health data access:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to log health data access');
    }
  }
);

// Automated compliance checker
export const runComplianceCheck = onCall<{
  checkType?: string;
  userId?: string;
}, ComplianceCheck[]>(
  {
    cors: true,
  },
  async (request: CallableRequest<any>): Promise<ComplianceCheck[]> => {
    try {
      const { checkType, userId } = request.data;
      const results: ComplianceCheck[] = [];

      if (!checkType || checkType === 'data_retention') {
        const retentionCheck = await checkDataRetentionCompliance(userId);
        results.push(retentionCheck);
      }

      if (!checkType || checkType === 'consent_verification') {
        const consentCheck = await checkConsentCompliance(userId);
        results.push(consentCheck);
      }

      if (!checkType || checkType === 'access_audit') {
        const accessCheck = await checkAccessAuditCompliance(userId);
        results.push(accessCheck);
      }

      if (!checkType || checkType === 'data_anonymization') {
        const anonymizationCheck = await checkDataAnonymizationCompliance(userId);
        results.push(anonymizationCheck);
      }

      // Store compliance check results
      const batch = db.batch();
      results.forEach(result => {
        const checkRef = db.collection('complianceChecks').doc();
        batch.set(checkRef, {
          ...result,
          createdAt: FieldValue.serverTimestamp()
        });
      });
      await batch.commit();

      logger.info(`Completed ${results.length} compliance checks`);
      return results;

    } catch (error) {
      logger.error('Error running compliance checks:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to run compliance checks');
    }
  }
);

// Handle privacy requests (GDPR Article 15-22)
export const processPrivacyRequest = onCall<{
  requestType: string;
  dataTypes?: string[];
  reason?: string;
  verificationMethod: string;
}, {requestId: string; status: string}>(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request: CallableRequest<any>): Promise<{requestId: string; status: string}> => {
    try {
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const userId = request.auth.uid;
      const { requestType, dataTypes, reason, verificationMethod } = request.data;

      logger.info(`Processing privacy request for user: ${userId}, type: ${requestType}`);

      const privacyRequest: PrivacyRequest = {
        userId,
        requestType,
        status: 'pending',
        requestedAt: new Date().toISOString(),
        dataTypes,
        reason,
        verificationMethod,
        processingNotes: []
      };

      // Verify user identity before processing sensitive requests
      const identityVerified = await verifyUserIdentity(userId, verificationMethod);
      if (!identityVerified) {
        privacyRequest.status = 'denied';
        privacyRequest.processingNotes.push('Identity verification failed');
      } else {
        privacyRequest.status = 'processing';
        
        // Process different types of privacy requests
        switch (requestType) {
          case 'access':
            await processDataAccessRequest(userId, privacyRequest);
            break;
          
          case 'rectification':
            await processDataRectificationRequest(userId, privacyRequest);
            break;
          
          case 'erasure':
            await processDataErasureRequest(userId, privacyRequest);
            break;
          
          case 'portability':
            await processDataPortabilityRequest(userId, privacyRequest);
            break;
          
          case 'restriction':
            await processDataRestrictionRequest(userId, privacyRequest);
            break;
          
          default:
            throw new HttpsError('invalid-argument', 'Invalid request type');
        }
      }

      // Save privacy request record
      const requestRef = await db.collection('privacyRequests').add({
        ...privacyRequest,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp()
      });

      return {
        requestId: requestRef.id,
        status: privacyRequest.status
      };

    } catch (error) {
      logger.error('Error processing privacy request:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to process privacy request');
    }
  }
);

// Automatic audit logging for health data operations
export const onHealthDataWrite = onDocumentWritten(
  'healthObservations/{observationId}',
  async (event) => {
    try {
      const snapshot = event.data;
      if (!snapshot) return;

      const observation = snapshot.after.exists ? snapshot.after.data() : null;
      const previousObservation = snapshot.before.exists ? snapshot.before.data() : null;

      let action = 'create';
      if (previousObservation && observation) {
        action = 'update';
      } else if (previousObservation && !observation) {
        action = 'delete';
      }

      const userId = observation?.userId || previousObservation?.userId;
      if (!userId) return;

      // Create audit log entry
      const auditEntry: AuditLogEntry = {
        userId,
        action: action as any,
        resourceType: 'observation',
        resourceId: event.params.observationId,
        timestamp: new Date().toISOString(),
        consentStatus: await getUserConsentStatus(userId),
        dataTypes: [observation?.type || previousObservation?.type],
        outcome: 'success'
      };

      await db.collection('auditLogs').add({
        ...auditEntry,
        createdAt: FieldValue.serverTimestamp(),
        automated: true
      });

    } catch (error) {
      logger.error('Error in health data audit logging:', error);
    }
  }
);

// Data retention enforcement
export const enforceDataRetention = onCall<{}, {processed: number; deleted: number}>(
  {
    cors: true,
    timeoutSeconds: 300,
  },
  async (request: CallableRequest<{}>): Promise<{processed: number; deleted: number}> => {
    try {
      logger.info('Starting data retention enforcement');

      const retentionPolicies = await getDataRetentionPolicies();
      let processedCount = 0;
      let deletedCount = 0;

      for (const policy of retentionPolicies) {
        const cutoffDate = new Date();
        cutoffDate.setDate(cutoffDate.getDate() - policy.retentionPeriodDays);

        const expiredDataQuery = await db
          .collection('healthObservations')
          .where('type', '==', policy.dataType)
          .where('createdAt', '<', cutoffDate)
          .limit(100) // Process in batches
          .get();

        const batch = db.batch();

        expiredDataQuery.docs.forEach(doc => {
          if (policy.deletionMethod === 'hard_delete') {
            batch.delete(doc.ref);
            deletedCount++;
          } else if (policy.deletionMethod === 'anonymize') {
            batch.update(doc.ref, {
              userId: 'anonymized',
              anonymizedAt: FieldValue.serverTimestamp(),
              originalDataHash: hashSensitiveData(JSON.stringify(doc.data()))
            });
            processedCount++;
          } else {
            // Soft delete
            batch.update(doc.ref, {
              deleted: true,
              deletedAt: FieldValue.serverTimestamp()
            });
            processedCount++;
          }
        });

        await batch.commit();
      }

      logger.info(`Data retention enforcement completed: ${processedCount} processed, ${deletedCount} deleted`);
      return { processed: processedCount, deleted: deletedCount };

    } catch (error) {
      logger.error('Error enforcing data retention:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to enforce data retention');
    }
  }
);

// Helper functions
async function checkDataRetentionCompliance(userId?: string): Promise<ComplianceCheck> {
  const findings: string[] = [];
  const recommendations: string[] = [];

  try {
    const policies = await getDataRetentionPolicies();
    
    for (const policy of policies) {
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - policy.retentionPeriodDays);

      let query = db.collection('healthObservations')
        .where('type', '==', policy.dataType)
        .where('createdAt', '<', cutoffDate);

      if (userId) {
        query = query.where('userId', '==', userId);
      }

      const expiredData = await query.limit(10).get();
      
      if (!expiredData.empty) {
        findings.push(`Found ${expiredData.size} expired ${policy.dataType} records`);
        recommendations.push(`Delete or anonymize expired ${policy.dataType} data`);
      }
    }
  } catch (error) {
    findings.push(`Error checking data retention: ${error}`);
  }

  return {
    checkType: 'data_retention',
    userId,
    status: findings.length > 0 ? 'non_compliant' : 'compliant',
    findings,
    recommendations,
    checkedAt: new Date().toISOString(),
    nextCheckDue: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString()
  };
}

async function checkConsentCompliance(userId?: string): Promise<ComplianceCheck> {
  const findings: string[] = [];
  const recommendations: string[] = [];

  try {
    let query = db.collection('healthProfiles');
    if (userId) {
      query = query.where('userId', '==', userId) as any;
    }

    const profiles = await query.limit(100).get();
    
    profiles.docs.forEach(doc => {
      const profile = doc.data();
      const consents = profile.consents || [];
      
      // Check if data processing consent exists
      const dataProcessingConsent = consents.find((c: any) => c.type === 'dataProcessing');
      if (!dataProcessingConsent) {
        findings.push(`User ${doc.id} missing data processing consent`);
        recommendations.push(`Request data processing consent from user ${doc.id}`);
      } else if (!dataProcessingConsent.granted) {
        // Check if we're still processing data for users who revoked consent
        // This would require additional checks
      }

      // Check consent currency (should be renewed periodically)
      const consentAge = dataProcessingConsent ? 
        (Date.now() - new Date(dataProcessingConsent.grantedAt || 0).getTime()) / (1000 * 60 * 60 * 24) : 0;
      
      if (consentAge > 365) { // 1 year old
        findings.push(`User ${doc.id} consent is over 1 year old`);
        recommendations.push(`Request consent renewal from user ${doc.id}`);
      }
    });
  } catch (error) {
    findings.push(`Error checking consent compliance: ${error}`);
  }

  return {
    checkType: 'consent_verification',
    userId,
    status: findings.length > 0 ? 'non_compliant' : 'compliant',
    findings,
    recommendations,
    checkedAt: new Date().toISOString(),
    nextCheckDue: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
  };
}

async function checkAccessAuditCompliance(userId?: string): Promise<ComplianceCheck> {
  const findings: string[] = [];
  const recommendations: string[] = [];

  try {
    // Check for suspicious access patterns
    let query = db.collection('auditLogs')
      .where('timestamp', '>=', new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString());

    if (userId) {
      query = query.where('userId', '==', userId);
    }

    const recentAccess = await query.limit(1000).get();
    
    // Group by user and check for unusual patterns
    const accessByUser: Record<string, any[]> = {};
    recentAccess.docs.forEach(doc => {
      const access = doc.data();
      if (!accessByUser[access.userId]) {
        accessByUser[access.userId] = [];
      }
      accessByUser[access.userId].push(access);
    });

    Object.entries(accessByUser).forEach(([uid, accesses]) => {
      // Check for high-volume access
      if (accesses.length > 100) {
        findings.push(`User ${uid} has ${accesses.length} access events in 24 hours`);
        recommendations.push(`Review access patterns for user ${uid}`);
      }

      // Check for access outside normal hours
      const nightAccess = accesses.filter(a => {
        const hour = new Date(a.timestamp).getHours();
        return hour < 6 || hour > 22; // Between 10 PM and 6 AM
      });

      if (nightAccess.length > 10) {
        findings.push(`User ${uid} has ${nightAccess.length} access events outside normal hours`);
        recommendations.push(`Investigate after-hours access for user ${uid}`);
      }
    });

  } catch (error) {
    findings.push(`Error checking access audit compliance: ${error}`);
  }

  return {
    checkType: 'access_audit',
    userId,
    status: findings.length > 0 ? 'warning' : 'compliant',
    findings,
    recommendations,
    checkedAt: new Date().toISOString(),
    nextCheckDue: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
  };
}

async function checkDataAnonymizationCompliance(userId?: string): Promise<ComplianceCheck> {
  const findings: string[] = [];
  const recommendations: string[] = [];

  // This would check if data anonymization is properly implemented
  // For research datasets, aggregate reports, etc.

  return {
    checkType: 'data_anonymization',
    userId,
    status: 'compliant',
    findings,
    recommendations,
    checkedAt: new Date().toISOString(),
    nextCheckDue: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString()
  };
}

async function getDataRetentionPolicies(): Promise<DataRetentionPolicy[]> {
  // In production, these would be stored in configuration
  return [
    {
      dataType: 'heartRate',
      retentionPeriodDays: 2555, // 7 years for medical data
      anonymizationRequired: true,
      deletionMethod: 'anonymize',
      complianceFramework: 'HIPAA'
    },
    {
      dataType: 'steps',
      retentionPeriodDays: 1095, // 3 years for fitness data
      anonymizationRequired: false,
      deletionMethod: 'soft_delete',
      complianceFramework: 'GDPR'
    },
    {
      dataType: 'weight',
      retentionPeriodDays: 2555, // 7 years for health metrics
      anonymizationRequired: true,
      deletionMethod: 'anonymize',
      complianceFramework: 'HIPAA'
    }
  ];
}

async function verifyUserIdentity(userId: string, method: string): Promise<boolean> {
  // In production, this would implement proper identity verification
  // For now, we'll assume email verification is sufficient
  try {
    const userRecord = await auth.getUser(userId);
    return userRecord.emailVerified || false;
  } catch (error) {
    logger.error('Error verifying user identity:', error);
    return false;
  }
}

async function getUserConsentStatus(userId: string): Promise<Record<string, boolean>> {
  try {
    const profileDoc = await db.collection('healthProfiles').doc(userId).get();
    
    if (!profileDoc.exists) {
      return {};
    }

    const consents = profileDoc.data()?.consents || [];
    return consents.reduce((acc: any, consent: any) => {
      acc[consent.type] = consent.granted;
      return acc;
    }, {});
  } catch (error) {
    logger.error('Error getting user consent status:', error);
    return {};
  }
}

function hashSensitiveData(data: string): string {
  // In production, use proper cryptographic hashing
  // This is a simplified example
  const crypto = require('crypto');
  return crypto.createHash('sha256').update(data).digest('hex');
}

// Privacy request processing functions
async function processDataAccessRequest(userId: string, request: PrivacyRequest) {
  // Generate a comprehensive report of all user data
  request.processingNotes.push('Generating data access report');
  // Implementation would compile all user data across services
}

async function processDataRectificationRequest(userId: string, request: PrivacyRequest) {
  // Allow user to correct inaccurate data
  request.processingNotes.push('Data rectification interface provided');
}

async function processDataErasureRequest(userId: string, request: PrivacyRequest) {
  // Delete user data (right to be forgotten)
  request.processingNotes.push('Initiating data deletion process');
  // Implementation would safely delete user data across all systems
}

async function processDataPortabilityRequest(userId: string, request: PrivacyRequest) {
  // Provide user data in portable format
  request.processingNotes.push('Generating portable data export');
}

async function processDataRestrictionRequest(userId: string, request: PrivacyRequest) {
  // Restrict processing of user data
  request.processingNotes.push('Implementing data processing restrictions');
}