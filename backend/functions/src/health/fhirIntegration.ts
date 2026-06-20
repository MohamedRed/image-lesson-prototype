import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';

const db = getFirestore();

// FHIR R4 Resource Types and Interfaces
interface FHIRBundle {
  resourceType: 'Bundle';
  id?: string;
  meta?: FHIRMeta;
  type: 'document' | 'message' | 'transaction' | 'transaction-response' | 'batch' | 'batch-response' | 'history' | 'searchset' | 'collection';
  total?: number;
  entry?: FHIRBundleEntry[];
}

interface FHIRBundleEntry {
  fullUrl?: string;
  resource?: FHIRResource;
  search?: {
    mode?: 'match' | 'include' | 'outcome';
    score?: number;
  };
  request?: FHIRBundleRequest;
  response?: FHIRBundleResponse;
}

interface FHIRBundleRequest {
  method: 'GET' | 'POST' | 'PUT' | 'DELETE';
  url: string;
}

interface FHIRBundleResponse {
  status: string;
  location?: string;
  etag?: string;
}

interface FHIRMeta {
  versionId?: string;
  lastUpdated?: string;
  source?: string;
  profile?: string[];
  security?: FHIRCoding[];
  tag?: FHIRCoding[];
}

interface FHIRCoding {
  system?: string;
  version?: string;
  code?: string;
  display?: string;
}

interface FHIRResource {
  resourceType: string;
  id?: string;
  meta?: FHIRMeta;
  implicitRules?: string;
  language?: string;
}

interface FHIRPatient extends FHIRResource {
  resourceType: 'Patient';
  identifier?: FHIRIdentifier[];
  active?: boolean;
  name?: FHIRHumanName[];
  telecom?: FHIRContactPoint[];
  gender?: 'male' | 'female' | 'other' | 'unknown';
  birthDate?: string;
  address?: FHIRAddress[];
}

interface FHIRObservation extends FHIRResource {
  resourceType: 'Observation';
  identifier?: FHIRIdentifier[];
  status: 'registered' | 'preliminary' | 'final' | 'amended' | 'corrected' | 'cancelled' | 'entered-in-error' | 'unknown';
  category?: FHIRCodeableConcept[];
  code: FHIRCodeableConcept;
  subject?: FHIRReference;
  effectiveDateTime?: string;
  effectivePeriod?: FHIRPeriod;
  issued?: string;
  performer?: FHIRReference[];
  valueQuantity?: FHIRQuantity;
  valueCodeableConcept?: FHIRCodeableConcept;
  valueString?: string;
  valueBoolean?: boolean;
  valueInteger?: number;
  valueRange?: FHIRRange;
  component?: FHIRObservationComponent[];
}

interface FHIRObservationComponent {
  code: FHIRCodeableConcept;
  valueQuantity?: FHIRQuantity;
  valueCodeableConcept?: FHIRCodeableConcept;
}

interface FHIRIdentifier {
  use?: 'usual' | 'official' | 'temp' | 'secondary' | 'old';
  type?: FHIRCodeableConcept;
  system?: string;
  value?: string;
}

interface FHIRHumanName {
  use?: 'usual' | 'official' | 'temp' | 'nickname' | 'anonymous' | 'old' | 'maiden';
  text?: string;
  family?: string;
  given?: string[];
  prefix?: string[];
  suffix?: string[];
}

interface FHIRContactPoint {
  system?: 'phone' | 'fax' | 'email' | 'pager' | 'url' | 'sms' | 'other';
  value?: string;
  use?: 'home' | 'work' | 'temp' | 'old' | 'mobile';
}

interface FHIRAddress {
  use?: 'home' | 'work' | 'temp' | 'old' | 'billing';
  text?: string;
  line?: string[];
  city?: string;
  district?: string;
  state?: string;
  postalCode?: string;
  country?: string;
}

interface FHIRCodeableConcept {
  coding?: FHIRCoding[];
  text?: string;
}

interface FHIRReference {
  reference?: string;
  type?: string;
  identifier?: FHIRIdentifier;
  display?: string;
}

interface FHIRPeriod {
  start?: string;
  end?: string;
}

interface FHIRQuantity {
  value?: number;
  comparator?: '<' | '<=' | '>=' | '>';
  unit?: string;
  system?: string;
  code?: string;
}

interface FHIRRange {
  low?: FHIRQuantity;
  high?: FHIRQuantity;
}

interface ImportFHIRBundleRequest {
  bundle: FHIRBundle;
  ehrSystemId?: string;
  mappingProfile?: string;
}

interface ExportToFHIRRequest {
  patientId: string;
  startDate?: string;
  endDate?: string;
  resourceTypes?: string[];
}

interface SyncWithEHRRequest {
  ehrSystemId: string;
  patientIdentifier: string;
  syncType: 'full' | 'incremental';
}

// Import FHIR Bundle
export const importFHIRBundle = onCall<ImportFHIRBundleRequest, {imported: number, errors: string[]}>(
  {
    enforceAppCheck: true,
    cors: true,
    timeoutSeconds: 300,
  },
  async (request: CallableRequest<ImportFHIRBundleRequest>): Promise<{imported: number, errors: string[]}> => {
    try {
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const userId = request.auth.uid;
      const { bundle, ehrSystemId, mappingProfile } = request.data;

      if (!bundle || bundle.resourceType !== 'Bundle') {
        throw new HttpsError('invalid-argument', 'Invalid FHIR Bundle');
      }

      logger.info(`Importing FHIR bundle for user: ${userId}, entries: ${bundle.entry?.length || 0}`);

      let importedCount = 0;
      const errors: string[] = [];

      if (bundle.entry && bundle.entry.length > 0) {
        const batch = db.batch();

        for (const entry of bundle.entry) {
          try {
            if (!entry.resource) continue;

            const mappedData = await mapFHIRResourceToInternalFormat(entry.resource, userId);
            if (mappedData) {
              const collectionName = getFHIRResourceCollection(entry.resource.resourceType);
              const docRef = db.collection(collectionName).doc();
              
              batch.set(docRef, {
                ...mappedData,
                fhirSource: {
                  resourceType: entry.resource.resourceType,
                  ehrSystemId,
                  mappingProfile,
                  originalResource: entry.resource,
                  importedAt: FieldValue.serverTimestamp()
                },
                createdAt: FieldValue.serverTimestamp(),
                updatedAt: FieldValue.serverTimestamp()
              });

              importedCount++;
            }
          } catch (error) {
            errors.push(`Failed to process ${entry.resource?.resourceType}: ${error}`);
            logger.warn(`Error processing FHIR resource:`, error);
          }
        }

        await batch.commit();
      }

      // Record import event
      await db.collection('fhirImportHistory').add({
        userId,
        bundleId: bundle.id,
        ehrSystemId,
        entriesProcessed: bundle.entry?.length || 0,
        entriesImported: importedCount,
        errors,
        importedAt: FieldValue.serverTimestamp()
      });

      logger.info(`FHIR import completed for user: ${userId}, imported: ${importedCount}, errors: ${errors.length}`);
      return { imported: importedCount, errors };

    } catch (error) {
      logger.error('Error importing FHIR bundle:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to import FHIR bundle');
    }
  }
);

// Export to FHIR
export const exportToFHIR = onCall<ExportToFHIRRequest, FHIRBundle>(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request: CallableRequest<ExportToFHIRRequest>): Promise<FHIRBundle> => {
    try {
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const userId = request.auth.uid;
      const { patientId, startDate, endDate, resourceTypes } = request.data;

      if (patientId !== userId) {
        throw new HttpsError('permission-denied', 'Can only export own data');
      }

      logger.info(`Exporting FHIR bundle for user: ${userId}`);

      const bundle: FHIRBundle = {
        resourceType: 'Bundle',
        id: `export-${userId}-${Date.now()}`,
        type: 'collection',
        entry: []
      };

      // Export Patient resource
      const patientResource = await createPatientResource(userId);
      if (patientResource) {
        bundle.entry!.push({
          fullUrl: `Patient/${userId}`,
          resource: patientResource
        });
      }

      // Export Observation resources
      if (!resourceTypes || resourceTypes.includes('Observation')) {
        const observations = await exportObservations(userId, startDate, endDate);
        observations.forEach(obs => {
          bundle.entry!.push({
            fullUrl: `Observation/${obs.id}`,
            resource: obs
          });
        });
      }

      bundle.total = bundle.entry!.length;

      logger.info(`FHIR export completed for user: ${userId}, resources: ${bundle.total}`);
      return bundle;

    } catch (error) {
      logger.error('Error exporting to FHIR:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to export to FHIR');
    }
  }
);

// Sync with EHR system
export const syncWithEHR = onCall<SyncWithEHRRequest, {synced: number, errors: string[]}>(
  {
    enforceAppCheck: true,
    cors: true,
    timeoutSeconds: 300,
  },
  async (request: CallableRequest<SyncWithEHRRequest>): Promise<{synced: number, errors: string[]}> => {
    try {
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const userId = request.auth.uid;
      const { ehrSystemId, patientIdentifier, syncType } = request.data;

      logger.info(`Syncing with EHR for user: ${userId}, system: ${ehrSystemId}, type: ${syncType}`);

      // This would integrate with specific EHR systems like Epic, Cerner, etc.
      // For now, we'll simulate the sync process

      const syncResult = await performEHRSync(userId, ehrSystemId, patientIdentifier, syncType);

      // Record sync event
      await db.collection('ehrSyncHistory').add({
        userId,
        ehrSystemId,
        patientIdentifier,
        syncType,
        result: syncResult,
        syncedAt: FieldValue.serverTimestamp()
      });

      return syncResult;

    } catch (error) {
      logger.error('Error syncing with EHR:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to sync with EHR');
    }
  }
);

// Map FHIR resource to internal format
async function mapFHIRResourceToInternalFormat(resource: FHIRResource, userId: string): Promise<any | null> {
  switch (resource.resourceType) {
    case 'Patient':
      return mapPatientResource(resource as FHIRPatient, userId);
    
    case 'Observation':
      return mapObservationResource(resource as FHIRObservation, userId);
    
    default:
      logger.warn(`Unsupported FHIR resource type: ${resource.resourceType}`);
      return null;
  }
}

// Map Patient resource
function mapPatientResource(patient: FHIRPatient, userId: string): any {
  const demographics: any = {};

  if (patient.gender) {
    demographics.biologicalSex = patient.gender === 'male' ? 'male' : 
                                patient.gender === 'female' ? 'female' : 'other';
  }

  if (patient.birthDate) {
    const birthDate = new Date(patient.birthDate);
    const age = Math.floor((Date.now() - birthDate.getTime()) / (365.25 * 24 * 60 * 60 * 1000));
    demographics.age = age;
  }

  return {
    userId,
    demographics,
    fhirPatientId: patient.id,
    name: patient.name?.[0],
    identifiers: patient.identifier,
    contactInfo: {
      telecom: patient.telecom,
      address: patient.address
    }
  };
}

// Map Observation resource
function mapObservationResource(observation: FHIRObservation, userId: string): any {
  if (observation.status === 'cancelled' || observation.status === 'entered-in-error') {
    return null; // Skip invalid observations
  }

  // Map FHIR observation to internal health observation format
  const internalObservation: any = {
    userId,
    source: 'fhir',
    timestamp: observation.effectiveDateTime || observation.issued || new Date().toISOString(),
    fhirObservationId: observation.id,
    status: observation.status
  };

  // Map observation code to internal type
  const observationType = mapFHIRCodeToInternalType(observation.code);
  if (observationType) {
    internalObservation.type = observationType;
  }

  // Map observation value
  if (observation.valueQuantity) {
    internalObservation.value = {
      numeric: observation.valueQuantity.value,
      unit: observation.valueQuantity.unit || observation.valueQuantity.code
    };
  } else if (observation.valueString) {
    internalObservation.value = {
      text: observation.valueString
    };
  } else if (observation.valueCodeableConcept) {
    internalObservation.value = {
      categorical: {
        value: observation.valueCodeableConcept.text || observation.valueCodeableConcept.coding?.[0]?.display,
        code: observation.valueCodeableConcept.coding?.[0]?.code
      }
    };
  } else if (observation.component && observation.component.length > 0) {
    // Handle blood pressure and other multi-component observations
    if (isBloodPressureObservation(observation)) {
      const systolic = observation.component.find(c => 
        c.code.coding?.some(coding => coding.code === '8480-6')); // Systolic BP
      const diastolic = observation.component.find(c => 
        c.code.coding?.some(coding => coding.code === '8462-4')); // Diastolic BP

      if (systolic?.valueQuantity && diastolic?.valueQuantity) {
        internalObservation.type = 'bloodPressure';
        internalObservation.value = {
          bloodPressure: {
            systolic: systolic.valueQuantity.value,
            diastolic: diastolic.valueQuantity.value,
            unit: systolic.valueQuantity.unit || 'mmHg'
          }
        };
      }
    }
  }

  return internalObservation;
}

// Map FHIR codes to internal observation types
function mapFHIRCodeToInternalType(codeableConcept: FHIRCodeableConcept): string | null {
  if (!codeableConcept.coding || codeableConcept.coding.length === 0) {
    return null;
  }

  const codeMapping: Record<string, string> = {
    // LOINC codes
    '9052-2': 'steps',           // Step count
    '8867-4': 'heartRate',       // Heart rate
    '29463-7': 'weight',         // Body weight
    '8310-5': 'temperature',     // Body temperature
    '2339-0': 'bloodSugar',      // Glucose
    '85354-9': 'bloodPressure',  // Blood pressure panel
    '8480-6': 'bloodPressure',   // Systolic BP
    '8462-4': 'bloodPressure',   // Diastolic BP
    
    // SNOMED CT codes
    '226529007': 'sleep',        // Sleep pattern
    '424393004': 'mood',         // Mood assessment
    '77176002': 'water',         // Fluid intake
  };

  for (const coding of codeableConcept.coding) {
    if (coding.code && codeMapping[coding.code]) {
      return codeMapping[coding.code];
    }
  }

  return null;
}

// Check if observation is blood pressure
function isBloodPressureObservation(observation: FHIRObservation): boolean {
  return observation.code.coding?.some(coding => 
    coding.code === '85354-9' || // Blood pressure panel
    coding.code === '75367002'   // Blood pressure (SNOMED)
  ) || false;
}

// Get Firestore collection for FHIR resource type
function getFHIRResourceCollection(resourceType: string): string {
  const collectionMapping: Record<string, string> = {
    'Patient': 'healthProfiles',
    'Observation': 'healthObservations',
    'Condition': 'healthConditions',
    'Medication': 'medications',
    'MedicationStatement': 'medicationStatements',
    'DiagnosticReport': 'diagnosticReports',
    'Procedure': 'procedures'
  };

  return collectionMapping[resourceType] || 'fhirResources';
}

// Create Patient FHIR resource from internal data
async function createPatientResource(userId: string): Promise<FHIRPatient | null> {
  try {
    const profileDoc = await db.collection('healthProfiles').doc(userId).get();
    if (!profileDoc.exists) {
      return null;
    }

    const profile = profileDoc.data()!;
    
    const patient: FHIRPatient = {
      resourceType: 'Patient',
      id: userId,
      active: true
    };

    if (profile.demographics) {
      if (profile.demographics.biologicalSex && profile.demographics.biologicalSex !== 'notSet') {
        patient.gender = profile.demographics.biologicalSex;
      }

      if (profile.demographics.age) {
        // Calculate approximate birth year
        const birthYear = new Date().getFullYear() - profile.demographics.age;
        patient.birthDate = `${birthYear}-01-01`;
      }
    }

    return patient;

  } catch (error) {
    logger.error('Error creating Patient resource:', error);
    return null;
  }
}

// Export observations as FHIR resources
async function exportObservations(userId: string, startDate?: string, endDate?: string): Promise<FHIRObservation[]> {
  let query = db.collection('healthObservations').where('userId', '==', userId);

  if (startDate) {
    query = query.where('timestamp', '>=', startDate);
  }

  if (endDate) {
    query = query.where('timestamp', '<=', endDate);
  }

  const querySnapshot = await query.limit(100).get(); // Limit for performance

  const fhirObservations: FHIRObservation[] = [];

  querySnapshot.docs.forEach(doc => {
    const data = doc.data();
    const fhirObs = convertToFHIRObservation(doc.id, data, userId);
    if (fhirObs) {
      fhirObservations.push(fhirObs);
    }
  });

  return fhirObservations;
}

// Convert internal observation to FHIR Observation
function convertToFHIRObservation(id: string, data: any, userId: string): FHIRObservation | null {
  const codeMapping: Record<string, {code: string, display: string, system: string}> = {
    'steps': {code: '9052-2', display: 'Step count', system: 'http://loinc.org'},
    'heartRate': {code: '8867-4', display: 'Heart rate', system: 'http://loinc.org'},
    'weight': {code: '29463-7', display: 'Body weight', system: 'http://loinc.org'},
    'bloodPressure': {code: '85354-9', display: 'Blood pressure panel', system: 'http://loinc.org'},
    'bloodSugar': {code: '2339-0', display: 'Glucose', system: 'http://loinc.org'},
    'temperature': {code: '8310-5', display: 'Body temperature', system: 'http://loinc.org'}
  };

  const codeInfo = codeMapping[data.type];
  if (!codeInfo) {
    return null;
  }

  const observation: FHIRObservation = {
    resourceType: 'Observation',
    id,
    status: 'final',
    code: {
      coding: [{
        system: codeInfo.system,
        code: codeInfo.code,
        display: codeInfo.display
      }]
    },
    subject: {
      reference: `Patient/${userId}`
    },
    effectiveDateTime: data.timestamp,
    issued: data.createdAt || data.timestamp
  };

  // Map value based on type
  if (data.value?.numeric !== undefined) {
    observation.valueQuantity = {
      value: data.value.numeric,
      unit: data.value.unit
    };
  } else if (data.value?.bloodPressure) {
    observation.component = [
      {
        code: {
          coding: [{
            system: 'http://loinc.org',
            code: '8480-6',
            display: 'Systolic blood pressure'
          }]
        },
        valueQuantity: {
          value: data.value.bloodPressure.systolic,
          unit: data.value.bloodPressure.unit || 'mmHg'
        }
      },
      {
        code: {
          coding: [{
            system: 'http://loinc.org',
            code: '8462-4',
            display: 'Diastolic blood pressure'
          }]
        },
        valueQuantity: {
          value: data.value.bloodPressure.diastolic,
          unit: data.value.bloodPressure.unit || 'mmHg'
        }
      }
    ];
  } else if (data.value?.text) {
    observation.valueString = data.value.text;
  }

  return observation;
}

// Simulate EHR sync (would integrate with actual EHR systems)
async function performEHRSync(userId: string, ehrSystemId: string, patientIdentifier: string, syncType: string): Promise<{synced: number, errors: string[]}> {
  // This is a placeholder for actual EHR integration
  // In production, this would:
  // 1. Authenticate with EHR system
  // 2. Fetch patient data using FHIR APIs
  // 3. Transform and import the data
  // 4. Handle errors and conflicts

  logger.info(`Performing ${syncType} sync with EHR ${ehrSystemId} for patient ${patientIdentifier}`);
  
  return {
    synced: 0,
    errors: ['EHR integration not yet implemented']
  };
}