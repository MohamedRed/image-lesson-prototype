import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { Firestore, FieldValue, Timestamp } from '@google-cloud/firestore';
import { logger } from 'firebase-functions';
import axios from 'axios';
import { AccessToken, RoomServiceClient } from 'livekit-server-sdk';

const firestore = new Firestore();

export interface TelehealthSession {
  id: string;
  appointmentId: string;
  userId: string;
  professionalId: string;
  status: 'waiting' | 'in_progress' | 'completed' | 'cancelled' | 'failed';
  roomName: string;
  roomConfig: {
    maxParticipants: number;
    enableRecording: boolean;
    enableScreenShare: boolean;
    enableChat: boolean;
    sessionTimeout: number; // minutes
  };
  participants: Array<{
    userId: string;
    role: 'patient' | 'professional' | 'observer';
    joinedAt?: Date;
    leftAt?: Date;
    connectionQuality?: 'poor' | 'fair' | 'good' | 'excellent';
  }>;
  sessionMetrics: {
    startTime?: Date;
    endTime?: Date;
    duration?: number;
    averageQuality?: string;
    connectionIssues: number;
    reconnectionAttempts: number;
  };
  recordings?: Array<{
    recordingId: string;
    startTime: Date;
    duration: number;
    size: number;
    status: 'processing' | 'ready' | 'failed';
    downloadUrl?: string;
    expiresAt: Date;
  }>;
  chatMessages?: Array<{
    senderId: string;
    senderRole: string;
    message: string;
    timestamp: Date;
    type: 'text' | 'file' | 'system';
  }>;
  technicalNotes?: string;
  followUpActions?: string[];
  createdAt: Date;
  updatedAt: Date;
}

export interface VideoConsultationRequest {
  appointmentId: string;
  requestedBy: 'patient' | 'professional';
  urgencyLevel: 'low' | 'medium' | 'high' | 'emergency';
  estimatedDuration: number; // minutes
  specialRequirements?: string[];
  preSessionChecklist?: boolean;
}

/**
 * Create a telehealth video session room
 */
export const createTelehealthSession = onCall<{
  appointmentId: string;
  enableRecording?: boolean;
  enableScreenShare?: boolean;
  maxDuration?: number;
}, { sessionId: string; roomName: string; patientToken: string; professionalToken: string }>(async (request) => {
  const { appointmentId, enableRecording = true, enableScreenShare = true, maxDuration = 60 } = request.data;

  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  try {
    // Get appointment details
    const appointmentDoc = await firestore
      .collection('healthAppointments')
      .doc(appointmentId)
      .get();

    if (!appointmentDoc.exists) {
      throw new HttpsError('not-found', 'Appointment not found');
    }

    const appointment = appointmentDoc.data();
    
    // Verify user has permission
    if (appointment.userId !== request.auth.uid && 
        appointment.professionalId !== request.auth.uid &&
        !request.auth.token?.admin) {
      throw new HttpsError('permission-denied', 'Access denied');
    }

    // Create LiveKit room and session
    const session = await createLiveKitTelehealthRoom(appointment, {
      enableRecording,
      enableScreenShare,
      maxDuration
    });

    // Generate access tokens
    const patientToken = await generatePatientAccessToken(session.roomName, appointment.userId);
    const professionalToken = await generateProfessionalAccessToken(session.roomName, appointment.professionalId);

    return {
      sessionId: session.id,
      roomName: session.roomName,
      patientToken,
      professionalToken
    };
  } catch (error) {
    logger.error('Create telehealth session failed:', error);
    throw new HttpsError('internal', 'Failed to create session');
  }
});

/**
 * Join a telehealth session
 */
export const joinTelehealthSession = onCall<{
  sessionId: string;
  role?: 'patient' | 'professional' | 'observer';
}, { accessToken: string; roomUrl: string; sessionDetails: any }>(async (request) => {
  const { sessionId, role = 'patient' } = request.data;

  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  try {
    // Get session details
    const sessionDoc = await firestore
      .collection('telehealthSessions')
      .doc(sessionId)
      .get();

    if (!sessionDoc.exists) {
      throw new HttpsError('not-found', 'Session not found');
    }

    const session = sessionDoc.data() as TelehealthSession;

    // Verify user has permission to join
    const canJoin = await verifySessionAccess(session, request.auth.uid, role);
    if (!canJoin) {
      throw new HttpsError('permission-denied', 'Access denied');
    }

    // Generate appropriate access token
    let accessToken: string;
    if (role === 'professional') {
      accessToken = await generateProfessionalAccessToken(session.roomName, request.auth.uid);
    } else {
      accessToken = await generatePatientAccessToken(session.roomName, request.auth.uid);
    }

    // Update session with participant info
    await updateSessionParticipant(sessionId, request.auth.uid, role, 'joined');

    // Get LiveKit server URL
    const roomUrl = process.env.LIVEKIT_URL || 'wss://your-livekit-server.com';

    return {
      accessToken,
      roomUrl,
      sessionDetails: {
        roomName: session.roomName,
        enableScreenShare: session.roomConfig.enableScreenShare,
        enableChat: session.roomConfig.enableChat,
        enableRecording: session.roomConfig.enableRecording
      }
    };
  } catch (error) {
    logger.error('Join telehealth session failed:', error);
    throw new HttpsError('internal', 'Failed to join session');
  }
});

/**
 * End a telehealth session
 */
export const endTelehealthSession = onCall<{
  sessionId: string;
  sessionSummary?: string;
  followUpActions?: string[];
  technicalNotes?: string;
}, { success: boolean; sessionMetrics: any }>(async (request) => {
  const { sessionId, sessionSummary, followUpActions, technicalNotes } = request.data;

  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  try {
    const sessionDoc = await firestore
      .collection('telehealthSessions')
      .doc(sessionId)
      .get();

    if (!sessionDoc.exists) {
      throw new HttpsError('not-found', 'Session not found');
    }

    const session = sessionDoc.data() as TelehealthSession;

    // Verify user can end session (professional or admin)
    if (session.professionalId !== request.auth.uid && !request.auth.token?.admin) {
      throw new HttpsError('permission-denied', 'Only the professional can end the session');
    }

    // End LiveKit room
    await endLiveKitRoom(session.roomName);

    // Calculate session metrics
    const endTime = new Date();
    const duration = session.sessionMetrics.startTime 
      ? Math.floor((endTime.getTime() - session.sessionMetrics.startTime.getTime()) / 1000 / 60) 
      : 0;

    const sessionMetrics = {
      ...session.sessionMetrics,
      endTime,
      duration
    };

    // Update session status
    await firestore
      .collection('telehealthSessions')
      .doc(sessionId)
      .update({
        status: 'completed',
        sessionMetrics,
        followUpActions: followUpActions || [],
        technicalNotes,
        updatedAt: endTime
      });

    // Update appointment status
    if (session.appointmentId) {
      await firestore
        .collection('healthAppointments')
        .doc(session.appointmentId)
        .update({
          status: 'completed',
          sessionSummary,
          updatedAt: endTime
        });
    }

    return {
      success: true,
      sessionMetrics
    };
  } catch (error) {
    logger.error('End telehealth session failed:', error);
    throw new HttpsError('internal', 'Failed to end session');
  }
});

/**
 * Get session recordings
 */
export const getSessionRecordings = onCall<{
  sessionId: string;
}, { recordings: Array<any> }>(async (request) => {
  const { sessionId } = request.data;

  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  try {
    const sessionDoc = await firestore
      .collection('telehealthSessions')
      .doc(sessionId)
      .get();

    if (!sessionDoc.exists) {
      throw new HttpsError('not-found', 'Session not found');
    }

    const session = sessionDoc.data() as TelehealthSession;

    // Verify user has access to recordings
    if (session.userId !== request.auth.uid && 
        session.professionalId !== request.auth.uid &&
        !request.auth.token?.admin) {
      throw new HttpsError('permission-denied', 'Access denied');
    }

    // Get recording information from LiveKit
    const recordings = await getLiveKitRecordings(session.roomName);

    return { recordings };
  } catch (error) {
    logger.error('Get session recordings failed:', error);
    throw new HttpsError('internal', 'Failed to get recordings');
  }
});

/**
 * Update session quality metrics
 */
export const updateSessionMetrics = onCall<{
  sessionId: string;
  participantId: string;
  metrics: {
    connectionQuality?: string;
    audioQuality?: number;
    videoQuality?: number;
    packetLoss?: number;
    latency?: number;
  };
}, { success: boolean }>(async (request) => {
  const { sessionId, participantId, metrics } = request.data;

  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  try {
    // Update participant metrics
    await firestore
      .collection('telehealthSessions')
      .doc(sessionId)
      .update({
        [`participants.${participantId}.metrics`]: metrics,
        updatedAt: new Date()
      });

    return { success: true };
  } catch (error) {
    logger.error('Update session metrics failed:', error);
    throw new HttpsError('internal', 'Failed to update metrics');
  }
});

/**
 * Send chat message in telehealth session
 */
export const sendSessionChatMessage = onCall<{
  sessionId: string;
  message: string;
  type?: 'text' | 'file';
}, { success: boolean; messageId: string }>(async (request) => {
  const { sessionId, message, type = 'text' } = request.data;

  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  try {
    const sessionDoc = await firestore
      .collection('telehealthSessions')
      .doc(sessionId)
      .get();

    if (!sessionDoc.exists) {
      throw new HttpsError('not-found', 'Session not found');
    }

    const session = sessionDoc.data() as TelehealthSession;
    
    // Verify user is participant
    const participant = session.participants.find(p => p.userId === request.auth.uid);
    if (!participant) {
      throw new HttpsError('permission-denied', 'Not a session participant');
    }

    const chatMessage = {
      id: firestore.collection('temp').doc().id,
      senderId: request.auth.uid,
      senderRole: participant.role,
      message,
      type,
      timestamp: new Date()
    };

    // Add message to session
    await firestore
      .collection('telehealthSessions')
      .doc(sessionId)
      .update({
        chatMessages: FieldValue.arrayUnion(chatMessage),
        updatedAt: new Date()
      });

    return {
      success: true,
      messageId: chatMessage.id
    };
  } catch (error) {
    logger.error('Send chat message failed:', error);
    throw new HttpsError('internal', 'Failed to send message');
  }
});

/**
 * Handle session participant events
 */
export const handleParticipantEvent = onDocumentUpdated(
  'telehealthSessions/{sessionId}',
  async (event) => {
    const sessionData = event.data?.after.data() as TelehealthSession;
    const previousData = event.data?.before.data() as TelehealthSession;

    if (!sessionData) return;

    try {
      // Check if session just started
      if (sessionData.status === 'in_progress' && previousData.status === 'waiting') {
        await handleSessionStart(sessionData);
      }

      // Check if session ended
      if (sessionData.status === 'completed' && previousData.status === 'in_progress') {
        await handleSessionEnd(sessionData);
      }

      // Check for participant changes
      if (sessionData.participants.length !== previousData.participants.length) {
        await handleParticipantChange(sessionData, previousData);
      }

    } catch (error) {
      logger.error('Handle participant event failed:', error);
    }
  }
);

/**
 * Create LiveKit room for telehealth session
 */
async function createLiveKitTelehealthRoom(
  appointment: any,
  options: {
    enableRecording: boolean;
    enableScreenShare: boolean;
    maxDuration: number;
  }
): Promise<TelehealthSession> {
  
  const roomName = `telehealth_${appointment.id}_${Date.now()}`;
  
  // Create room using LiveKit Room Service
  const roomService = new RoomServiceClient(
    process.env.LIVEKIT_URL!,
    process.env.LIVEKIT_API_KEY!,
    process.env.LIVEKIT_SECRET!
  );

  await roomService.createRoom({
    name: roomName,
    maxParticipants: 5, // Patient, professional, up to 3 observers
    emptyTimeout: options.maxDuration * 60, // Convert minutes to seconds
    metadata: JSON.stringify({
      type: 'telehealth',
      appointmentId: appointment.id
    })
  });

  const session: TelehealthSession = {
    id: firestore.collection('temp').doc().id,
    appointmentId: appointment.id,
    userId: appointment.userId,
    professionalId: appointment.professionalId,
    status: 'waiting',
    roomName,
    roomConfig: {
      maxParticipants: 5,
      enableRecording: options.enableRecording,
      enableScreenShare: options.enableScreenShare,
      enableChat: true,
      sessionTimeout: options.maxDuration
    },
    participants: [],
    sessionMetrics: {
      connectionIssues: 0,
      reconnectionAttempts: 0
    },
    createdAt: new Date(),
    updatedAt: new Date()
  };

  // Save session to Firestore
  await firestore
    .collection('telehealthSessions')
    .doc(session.id)
    .set(session);

  return session;
}

/**
 * Generate access token for patient
 */
async function generatePatientAccessToken(roomName: string, userId: string): Promise<string> {
  const at = new AccessToken(
    process.env.LIVEKIT_API_KEY!,
    process.env.LIVEKIT_SECRET!,
    {
      identity: userId,
      name: 'Patient',
    }
  );

  at.addGrant({
    roomJoin: true,
    room: roomName,
    canPublish: true,
    canSubscribe: true,
    canPublishData: true
  });

  return at.toJwt();
}

/**
 * Generate access token for professional
 */
async function generateProfessionalAccessToken(roomName: string, professionalId: string): Promise<string> {
  const at = new AccessToken(
    process.env.LIVEKIT_API_KEY!,
    process.env.LIVEKIT_SECRET!,
    {
      identity: professionalId,
      name: 'Healthcare Professional',
    }
  );

  at.addGrant({
    roomJoin: true,
    room: roomName,
    canPublish: true,
    canSubscribe: true,
    canPublishData: true,
    roomAdmin: true, // Professionals can moderate
    roomRecord: true // Can start/stop recordings
  });

  return at.toJwt();
}

/**
 * Verify user has access to session
 */
async function verifySessionAccess(
  session: TelehealthSession,
  userId: string,
  role: string
): Promise<boolean> {
  
  // Check if user is authorized participant
  if (session.userId === userId && role === 'patient') return true;
  if (session.professionalId === userId && role === 'professional') return true;
  
  // Check if user is an approved observer (would need additional logic)
  if (role === 'observer') {
    // In a real implementation, check observer permissions
    return false;
  }

  return false;
}

/**
 * Update session participant status
 */
async function updateSessionParticipant(
  sessionId: string,
  userId: string,
  role: string,
  action: 'joined' | 'left'
): Promise<void> {
  
  const sessionRef = firestore.collection('telehealthSessions').doc(sessionId);
  
  await firestore.runTransaction(async (transaction) => {
    const sessionDoc = await transaction.get(sessionRef);
    const session = sessionDoc.data() as TelehealthSession;
    
    let participants = session.participants || [];
    const existingIndex = participants.findIndex(p => p.userId === userId);
    
    if (action === 'joined') {
      if (existingIndex >= 0) {
        participants[existingIndex].joinedAt = new Date();
        delete participants[existingIndex].leftAt;
      } else {
        participants.push({
          userId,
          role: role as any,
          joinedAt: new Date()
        });
      }
      
      // Start session if both patient and professional have joined
      const hasPatient = participants.some(p => p.role === 'patient' && p.joinedAt && !p.leftAt);
      const hasProfessional = participants.some(p => p.role === 'professional' && p.joinedAt && !p.leftAt);
      
      if (hasPatient && hasProfessional && session.status === 'waiting') {
        session.status = 'in_progress';
        session.sessionMetrics.startTime = new Date();
      }
    } else if (action === 'left') {
      if (existingIndex >= 0) {
        participants[existingIndex].leftAt = new Date();
      }
    }
    
    transaction.update(sessionRef, {
      participants,
      status: session.status,
      sessionMetrics: session.sessionMetrics,
      updatedAt: new Date()
    });
  });
}

/**
 * End LiveKit room
 */
async function endLiveKitRoom(roomName: string): Promise<void> {
  const roomService = new RoomServiceClient(
    process.env.LIVEKIT_URL!,
    process.env.LIVEKIT_API_KEY!,
    process.env.LIVEKIT_SECRET!
  );

  try {
    await roomService.deleteRoom(roomName);
    logger.info(`LiveKit room ${roomName} ended`);
  } catch (error) {
    logger.warn(`Failed to end LiveKit room ${roomName}:`, error);
  }
}

/**
 * Get LiveKit recordings
 */
async function getLiveKitRecordings(roomName: string): Promise<any[]> {
  // This would integrate with LiveKit's recording service
  // For now, return placeholder
  return [];
}

/**
 * Handle session start
 */
async function handleSessionStart(session: TelehealthSession): Promise<void> {
  logger.info(`Telehealth session ${session.id} started`);
  
  // Could trigger notifications, start recording, etc.
}

/**
 * Handle session end
 */
async function handleSessionEnd(session: TelehealthSession): Promise<void> {
  logger.info(`Telehealth session ${session.id} ended`);
  
  // Process recordings, send notifications, update analytics, etc.
}

/**
 * Handle participant changes
 */
async function handleParticipantChange(
  session: TelehealthSession,
  previousSession: TelehealthSession
): Promise<void> {
  
  const currentCount = session.participants.filter(p => p.joinedAt && !p.leftAt).length;
  const previousCount = previousSession.participants.filter(p => p.joinedAt && !p.leftAt).length;
  
  if (currentCount > previousCount) {
    logger.info(`Participant joined session ${session.id}`);
  } else if (currentCount < previousCount) {
    logger.info(`Participant left session ${session.id}`);
  }
}