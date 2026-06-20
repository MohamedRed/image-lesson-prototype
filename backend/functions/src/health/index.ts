// Health API Functions - Export all health-related Cloud Functions

// Overview and Profile
export { getHealthOverview } from './healthOverview';
export { updateHealthProfile, updateConsent } from './healthProfile';

// Observations and Data
export { 
  saveObservation, 
  getObservations, 
  importHealthKitData 
} from './healthObservations';

// Programs and Goals
export { 
  createProgram, 
  getPrograms,
  updateProgramProgress,
  pauseProgram,
  resumeProgram 
} from './healthPrograms';

// Insights and Analytics
export { 
  getInsights,
  markInsightRead,
  dismissInsight,
  generateInsights
} from './healthInsights';

// Leaderboards and Competitions
export { 
  getLeaderboard,
  getChallenges,
  joinChallenge,
  updateLeaderboardEntry
} from './healthLeaderboards';

// Professionals and Appointments
export { 
  searchProfessionals,
  getProfessional,
  bookAppointment,
  getAppointments,
  cancelAppointment
} from './healthProfessionals';

// News and Content
export { 
  getHealthNews,
  getHealthNewsCategories
} from './healthNews';

// Voice Assistant
export { interpretVoiceInput } from './voiceAssistant';

// Medications and Incidents
export { 
  getMedications,
  saveMedication,
  updateMedicationAdherence,
  getIncidents,
  saveIncident
} from './medicationsIncidents';

// FHIR Integration
export { 
  importFHIRBundle,
  exportToFHIR,
  syncWithEHR
} from './fhirIntegration';

// Background Jobs and Triggers
export { 
  processHealthDataBatch,
  calculateDailyMetrics,
  generatePersonalizedInsights,
  updateLeaderboards
} from './backgroundJobs';