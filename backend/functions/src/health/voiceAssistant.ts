import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { Firestore, FieldValue, Timestamp } from '@google-cloud/firestore';
import { logger } from 'firebase-functions';
import { VertexAI } from '@google-cloud/vertexai';
import axios from 'axios';

const firestore = new Firestore();
const vertexAI = new VertexAI({
  project: process.env.GOOGLE_CLOUD_PROJECT!,
  location: 'us-central1'
});

export interface VoiceInteraction {
  id: string;
  userId: string;
  sessionId: string;
  type: 'health_coaching' | 'symptom_assessment' | 'meditation_guide' | 'workout_coach' | 'nutrition_advice';
  status: 'processing' | 'completed' | 'failed';
  audioInput: {
    duration: number; // seconds
    transcript?: string;
    confidence?: number;
    language: string;
  };
  aiResponse: {
    text: string;
    audioUrl?: string;
    suggestions?: string[];
    followUpQuestions?: string[];
    healthRecommendations?: Array<{
      type: string;
      priority: 'low' | 'medium' | 'high';
      action: string;
      reason: string;
    }>;
  };
  context: {
    userHealthData?: any;
    previousInteractions?: string[];
    currentProgram?: string;
    timeOfDay: string;
    userPreferences?: any;
  };
  metrics: {
    processingTime: number;
    userSatisfaction?: number; // 1-5 rating
    followedRecommendation?: boolean;
  };
  createdAt: Date;
  updatedAt: Date;
}

export interface VoiceSession {
  id: string;
  userId: string;
  status: 'active' | 'paused' | 'completed';
  sessionType: 'coaching' | 'assessment' | 'meditation' | 'workout' | 'nutrition';
  interactions: VoiceInteraction[];
  startTime: Date;
  endTime?: Date;
  totalDuration: number; // seconds
  goals?: string[];
  achievements?: string[];
  nextSteps?: string[];
  voiceSettings: {
    preferredVoice: 'male' | 'female' | 'neutral';
    speechRate: number; // 0.5 - 2.0
    language: string;
    enableEmotionalTone: boolean;
  };
}

export interface HealthCoachingPrompt {
  userProfile: any;
  healthData: any;
  context: string;
  sessionType: string;
  previousConversation?: string[];
  goals?: string[];
}

/**
 * Start a new voice assistant session
 */
export const startVoiceSession = onCall<{
  sessionType: 'coaching' | 'assessment' | 'meditation' | 'workout' | 'nutrition';
  goals?: string[];
  voiceSettings?: any;
}, { sessionId: string; initialPrompt: string }>(async (request) => {
  const { sessionType, goals, voiceSettings } = request.data;

  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  try {
    // Get user profile and health data
    const userDoc = await firestore.collection('users').doc(request.auth.uid).get();
    const userData = userDoc.data();

    // Create voice session
    const session: VoiceSession = {
      id: firestore.collection('temp').doc().id,
      userId: request.auth.uid,
      status: 'active',
      sessionType,
      interactions: [],
      startTime: new Date(),
      totalDuration: 0,
      goals: goals || [],
      voiceSettings: {
        preferredVoice: voiceSettings?.preferredVoice || 'neutral',
        speechRate: voiceSettings?.speechRate || 1.0,
        language: voiceSettings?.language || 'en-US',
        enableEmotionalTone: voiceSettings?.enableEmotionalTone !== false
      }
    };

    // Save session
    await firestore.collection('voiceAssistantSessions').doc(session.id).set(session);

    // Generate initial coaching prompt
    const initialPrompt = await generateInitialCoachingPrompt(userData, sessionType, goals);

    return {
      sessionId: session.id,
      initialPrompt
    };
  } catch (error) {
    logger.error('Start voice session failed:', error);
    throw new HttpsError('internal', 'Failed to start voice session');
  }
});

/**
 * Process voice input and generate AI response
 */
export const processVoiceInput = onCall<{
  sessionId: string;
  audioBase64?: string;
  transcript?: string;
  duration: number;
}, { response: string; audioUrl?: string; suggestions?: string[]; recommendations?: any[] }>(async (request) => {
  const { sessionId, audioBase64, transcript, duration } = request.data;

  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  try {
    const startTime = Date.now();

    // Get session data
    const sessionDoc = await firestore.collection('voiceAssistantSessions').doc(sessionId).get();
    if (!sessionDoc.exists) {
      throw new HttpsError('not-found', 'Voice session not found');
    }

    const session = sessionDoc.data() as VoiceSession;
    
    // Verify ownership
    if (session.userId !== request.auth.uid) {
      throw new HttpsError('permission-denied', 'Access denied');
    }

    // Process audio to text if needed
    let processedTranscript = transcript;
    let confidence = 1.0;

    if (audioBase64 && !transcript) {
      const transcriptionResult = await transcribeAudio(audioBase64, session.voiceSettings.language);
      processedTranscript = transcriptionResult.transcript;
      confidence = transcriptionResult.confidence;
    }

    if (!processedTranscript) {
      throw new HttpsError('invalid-argument', 'No valid transcript provided');
    }

    // Get user context
    const userContext = await buildUserContext(request.auth.uid, session);

    // Generate AI response using existing AITutor pipeline
    const aiResponse = await generateHealthCoachingResponse({
      userProfile: userContext.profile,
      healthData: userContext.healthData,
      context: processedTranscript,
      sessionType: session.sessionType,
      previousConversation: session.interactions.slice(-5).map(i => i.aiResponse.text),
      goals: session.goals
    });

    // Generate audio response
    const audioUrl = await generateSpeechAudio(
      aiResponse.text,
      session.voiceSettings
    );

    // Create interaction record
    const interaction: VoiceInteraction = {
      id: firestore.collection('temp').doc().id,
      userId: request.auth.uid,
      sessionId,
      type: mapSessionTypeToInteractionType(session.sessionType),
      status: 'completed',
      audioInput: {
        duration,
        transcript: processedTranscript,
        confidence,
        language: session.voiceSettings.language
      },
      aiResponse: {
        text: aiResponse.text,
        audioUrl,
        suggestions: aiResponse.suggestions,
        followUpQuestions: aiResponse.followUpQuestions,
        healthRecommendations: aiResponse.recommendations
      },
      context: {
        userHealthData: userContext.healthData,
        currentProgram: userContext.currentProgram,
        timeOfDay: getTimeOfDay(),
        userPreferences: userContext.preferences
      },
      metrics: {
        processingTime: Date.now() - startTime
      },
      createdAt: new Date(),
      updatedAt: new Date()
    };

    // Save interaction and update session
    await firestore.runTransaction(async (transaction) => {
      const interactionRef = firestore.collection('voiceInteractions').doc(interaction.id);
      const sessionRef = firestore.collection('voiceAssistantSessions').doc(sessionId);

      transaction.set(interactionRef, interaction);
      transaction.update(sessionRef, {
        interactions: FieldValue.arrayUnion(interaction),
        totalDuration: FieldValue.increment(duration),
        updatedAt: new Date()
      });
    });

    return {
      response: aiResponse.text,
      audioUrl,
      suggestions: aiResponse.suggestions,
      recommendations: aiResponse.recommendations
    };
  } catch (error) {
    logger.error('Process voice input failed:', error);
    throw new HttpsError('internal', 'Failed to process voice input');
  }
});

/**
 * End voice session and provide summary
 */
export const endVoiceSession = onCall<{
  sessionId: string;
  userFeedback?: {
    rating: number;
    comments?: string;
    helpfulRecommendations?: string[];
  };
}, { summary: any; achievements: string[]; nextSteps: string[] }>(async (request) => {
  const { sessionId, userFeedback } = request.data;

  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  try {
    const sessionRef = firestore.collection('voiceAssistantSessions').doc(sessionId);
    const sessionDoc = await sessionRef.get();

    if (!sessionDoc.exists) {
      throw new HttpsError('not-found', 'Session not found');
    }

    const session = sessionDoc.data() as VoiceSession;

    if (session.userId !== request.auth.uid) {
      throw new HttpsError('permission-denied', 'Access denied');
    }

    // Generate session summary
    const summary = await generateSessionSummary(session);

    // Update session
    await sessionRef.update({
      status: 'completed',
      endTime: new Date(),
      achievements: summary.achievements,
      nextSteps: summary.nextSteps,
      userFeedback,
      updatedAt: new Date()
    });

    // Update user progress if applicable
    await updateUserProgress(request.auth.uid, session, summary);

    return {
      summary: summary.overview,
      achievements: summary.achievements,
      nextSteps: summary.nextSteps
    };
  } catch (error) {
    logger.error('End voice session failed:', error);
    throw new HttpsError('internal', 'Failed to end session');
  }
});

/**
 * Get user's voice session history
 */
export const getVoiceSessionHistory = onCall<{
  limit?: number;
  sessionType?: string;
}, { sessions: VoiceSession[] }>(async (request) => {
  const { limit = 10, sessionType } = request.data;

  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  try {
    let query = firestore
      .collection('voiceAssistantSessions')
      .where('userId', '==', request.auth.uid)
      .orderBy('startTime', 'desc')
      .limit(limit);

    if (sessionType) {
      query = query.where('sessionType', '==', sessionType);
    }

    const snapshot = await query.get();
    const sessions = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    })) as VoiceSession[];

    return { sessions };
  } catch (error) {
    logger.error('Get voice session history failed:', error);
    throw new HttpsError('internal', 'Failed to get session history');
  }
});

/**
 * Auto-trigger voice coaching based on health data changes
 */
export const triggerContextualVoiceCoaching = onDocumentCreated(
  'users/{userId}/healthObservations/{observationId}',
  async (event) => {
    const observation = event.data?.data();
    const userId = event.params.userId;

    if (!observation) return;

    try {
      // Check if we should trigger voice coaching
      const shouldTrigger = await shouldTriggerVoiceCoaching(userId, observation);
      
      if (shouldTrigger.trigger) {
        await scheduleVoiceCoachingNotification(userId, shouldTrigger);
      }
    } catch (error) {
      logger.error('Auto voice coaching trigger failed:', error);
    }
  }
);

/**
 * Transcribe audio using Google Cloud Speech-to-Text
 */
async function transcribeAudio(audioBase64: string, language: string): Promise<{
  transcript: string;
  confidence: number;
}> {
  try {
    // In a real implementation, this would use Google Cloud Speech-to-Text API
    // For now, return a placeholder
    return {
      transcript: "Placeholder transcript",
      confidence: 0.95
    };
  } catch (error) {
    logger.error('Audio transcription failed:', error);
    throw new Error('Transcription failed');
  }
}

/**
 * Build comprehensive user context for AI coaching
 */
async function buildUserContext(userId: string, session: VoiceSession): Promise<any> {
  // Get user profile
  const userDoc = await firestore.collection('users').doc(userId).get();
  const userData = userDoc.data() || {};

  // Get recent health data
  const recentHealthData = await firestore
    .collection('users')
    .doc(userId)
    .collection('healthObservations')
    .where('effectiveDateTime', '>=', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000))
    .orderBy('effectiveDateTime', 'desc')
    .limit(20)
    .get();

  const healthData = recentHealthData.docs.map(doc => doc.data());

  // Get current programs
  const programsSnapshot = await firestore
    .collection('users')
    .doc(userId)
    .collection('healthPrograms')
    .where('status', '==', 'active')
    .get();

  const currentPrograms = programsSnapshot.docs.map(doc => doc.data());

  return {
    profile: userData.profile || {},
    healthData,
    currentProgram: currentPrograms[0]?.name,
    preferences: userData.preferences || {},
    goals: userData.health?.goals || []
  };
}

/**
 * Generate health coaching response using Vertex AI
 */
async function generateHealthCoachingResponse(prompt: HealthCoachingPrompt): Promise<{
  text: string;
  suggestions: string[];
  followUpQuestions: string[];
  recommendations: Array<{
    type: string;
    priority: string;
    action: string;
    reason: string;
  }>;
}> {
  try {
    const model = vertexAI.getGenerativeModel({
      model: 'gemini-1.5-pro'
    });

    const systemPrompt = `You are a certified health coach and wellness expert. You provide personalized, evidence-based health advice through voice interactions. 

User Profile: ${JSON.stringify(prompt.userProfile)}
Recent Health Data: ${JSON.stringify(prompt.healthData)}
Session Type: ${prompt.sessionType}
User Goals: ${JSON.stringify(prompt.goals)}
Previous Conversation: ${prompt.previousConversation?.join('\n')}

Current User Input: ${prompt.context}

Provide a supportive, encouraging response that:
1. Acknowledges the user's input empathetically
2. Offers specific, actionable health advice
3. References their health data where relevant
4. Stays focused on the session type (${prompt.sessionType})
5. Uses a conversational, friendly tone suitable for voice interaction

Format your response as JSON with:
- text: Main response text (conversational, under 200 words)
- suggestions: Array of 2-3 quick actionable tips
- followUpQuestions: Array of 1-2 engaging questions to continue conversation
- recommendations: Array of specific health recommendations with priority levels`;

    const result = await model.generateContent(systemPrompt);
    const response = result.response;
    const text = response.text();

    try {
      const parsedResponse = JSON.parse(text);
      return parsedResponse;
    } catch (parseError) {
      // Fallback if JSON parsing fails
      return {
        text: text || "I'm here to help you with your health journey. Could you tell me more about what you'd like to focus on today?",
        suggestions: ["Take a moment to breathe deeply", "Consider your current goals"],
        followUpQuestions: ["What would you like to work on first?"],
        recommendations: []
      };
    }
  } catch (error) {
    logger.error('Health coaching response generation failed:', error);
    throw new Error('Failed to generate response');
  }
}

/**
 * Generate speech audio using Text-to-Speech
 */
async function generateSpeechAudio(text: string, voiceSettings: any): Promise<string> {
  try {
    // In a real implementation, this would use Google Cloud Text-to-Speech API
    // For now, return a placeholder URL
    return `https://example.com/audio/${Date.now()}.mp3`;
  } catch (error) {
    logger.error('Speech audio generation failed:', error);
    return '';
  }
}

/**
 * Map session type to interaction type
 */
function mapSessionTypeToInteractionType(sessionType: string): any {
  const mapping: { [key: string]: any } = {
    'coaching': 'health_coaching',
    'assessment': 'symptom_assessment',
    'meditation': 'meditation_guide',
    'workout': 'workout_coach',
    'nutrition': 'nutrition_advice'
  };
  
  return mapping[sessionType] || 'health_coaching';
}

/**
 * Get time of day for context
 */
function getTimeOfDay(): string {
  const hour = new Date().getHours();
  
  if (hour < 6) return 'early_morning';
  if (hour < 12) return 'morning';
  if (hour < 17) return 'afternoon';
  if (hour < 21) return 'evening';
  return 'night';
}

/**
 * Generate session summary
 */
async function generateSessionSummary(session: VoiceSession): Promise<{
  overview: string;
  achievements: string[];
  nextSteps: string[];
}> {
  
  const interactions = session.interactions || [];
  const totalInteractions = interactions.length;
  const sessionDurationMinutes = Math.round(session.totalDuration / 60);

  // Analyze interactions for achievements
  const achievements: string[] = [];
  const nextSteps: string[] = [];

  if (totalInteractions >= 5) {
    achievements.push('Had an engaged conversation with your health coach');
  }

  if (sessionDurationMinutes >= 10) {
    achievements.push('Spent quality time focusing on your health');
  }

  // Extract recommendations from interactions
  const allRecommendations = interactions
    .flatMap(i => i.aiResponse.healthRecommendations || [])
    .filter(r => r.priority === 'high' || r.priority === 'medium');

  nextSteps.push(...allRecommendations.slice(0, 3).map(r => r.action));

  const overview = `You had a ${sessionDurationMinutes}-minute ${session.sessionType} session with ${totalInteractions} interactions. Great job taking time for your health!`;

  return {
    overview,
    achievements,
    nextSteps
  };
}

/**
 * Update user progress based on voice session
 */
async function updateUserProgress(userId: string, session: VoiceSession, summary: any): Promise<void> {
  try {
    // Update user's health progress
    await firestore.collection('users').doc(userId).update({
      'health.lastVoiceSessionAt': new Date(),
      'health.totalVoiceSessions': FieldValue.increment(1),
      'health.voiceSessionMinutes': FieldValue.increment(Math.round(session.totalDuration / 60)),
      updatedAt: new Date()
    });

    // Add achievements to user profile if significant
    if (summary.achievements.length > 0) {
      await firestore.collection('users').doc(userId).update({
        'health.recentAchievements': FieldValue.arrayUnion(...summary.achievements.slice(0, 2))
      });
    }
  } catch (error) {
    logger.warn('Update user progress failed:', error);
  }
}

/**
 * Determine if voice coaching should be triggered
 */
async function shouldTriggerVoiceCoaching(userId: string, observation: any): Promise<{
  trigger: boolean;
  reason?: string;
  urgency?: string;
}> {
  
  // Get user preferences
  const userDoc = await firestore.collection('users').doc(userId).get();
  const userData = userDoc.data() || {};
  const preferences = userData.preferences || {};

  // Don't trigger if user has disabled voice coaching
  if (preferences.disableVoiceCoaching) {
    return { trigger: false };
  }

  // Trigger scenarios
  if (observation.type === 'sleep' && observation.value?.numeric < 5 * 3600) {
    return {
      trigger: true,
      reason: 'Poor sleep detected',
      urgency: 'medium'
    };
  }

  if (observation.type === 'steps' && observation.value?.numeric < 2000) {
    return {
      trigger: true,
      reason: 'Low activity level',
      urgency: 'low'
    };
  }

  if (observation.type === 'heart_rate' && observation.value?.numeric > 120) {
    return {
      trigger: true,
      reason: 'Elevated heart rate',
      urgency: 'medium'
    };
  }

  return { trigger: false };
}

/**
 * Schedule voice coaching notification
 */
async function scheduleVoiceCoachingNotification(
  userId: string, 
  triggerInfo: { reason: string; urgency: string }
): Promise<void> {
  
  // Create notification record
  await firestore.collection('notifications').add({
    userId,
    type: 'voice_coaching_suggestion',
    title: 'Your Health Coach is Ready to Help',
    body: `I noticed ${triggerInfo.reason.toLowerCase()}. Would you like to chat about it?`,
    data: {
      action: 'start_voice_session',
      sessionType: 'coaching',
      reason: triggerInfo.reason,
      urgency: triggerInfo.urgency
    },
    scheduledFor: new Date(),
    status: 'pending',
    createdAt: new Date()
  });

  logger.info(`Voice coaching notification scheduled for user ${userId}: ${triggerInfo.reason}`);
}