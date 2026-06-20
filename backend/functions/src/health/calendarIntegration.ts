import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { Firestore, FieldValue, Timestamp } from '@google-cloud/firestore';
import { logger } from 'firebase-functions';
import axios from 'axios';

const firestore = new Firestore();

export interface CalendlyEvent {
  uri: string;
  name: string;
  status: string;
  start_time: string;
  end_time: string;
  created_at: string;
  updated_at: string;
  event_type: string;
  location: {
    type: string;
    location?: string;
    join_url?: string;
  };
  invitees_counter: {
    total: number;
    active: number;
    limit: number;
  };
  event_memberships: Array<{
    user: string;
    user_email: string;
  }>;
  event_guests: Array<{
    email: string;
    created_at: string;
  }>;
}

export interface GoogleCalendarEvent {
  id: string;
  summary: string;
  description?: string;
  start: {
    dateTime: string;
    timeZone: string;
  };
  end: {
    dateTime: string;
    timeZone: string;
  };
  attendees?: Array<{
    email: string;
    displayName?: string;
    responseStatus: string;
  }>;
  conferenceData?: {
    conferenceSolution: {
      key: {
        type: string;
      };
    };
    createRequest: {
      requestId: string;
      conferenceSolutionKey: {
        type: string;
      };
    };
  };
  location?: string;
  status: string;
}

export interface HealthAppointment {
  id: string;
  userId: string;
  professionalId: string;
  professionalInfo: {
    name: string;
    title: string;
    specialty: string;
    email: string;
  };
  type: 'consultation' | 'follow_up' | 'assessment' | 'therapy' | 'coaching';
  status: 'scheduled' | 'confirmed' | 'completed' | 'cancelled' | 'no_show';
  scheduledFor: Date;
  duration: number; // minutes
  notes?: string;
  preparation?: string[];
  meetingDetails: {
    platform: 'calendly' | 'google_meet' | 'zoom' | 'in_person';
    joinUrl?: string;
    location?: string;
    meetingId?: string;
  };
  reminders: Array<{
    type: 'email' | 'push' | 'sms';
    sentAt?: Date;
    scheduledFor: Date;
  }>;
  createdAt: Date;
  updatedAt: Date;
  cancellationReason?: string;
  followUpRequired?: boolean;
}

export interface ProfessionalAvailability {
  professionalId: string;
  timezone: string;
  availableSlots: Array<{
    start: Date;
    end: Date;
    type: 'consultation' | 'follow_up' | 'assessment';
    maxDuration: number;
  }>;
  calendlyEventTypeUri?: string;
  googleCalendarId?: string;
  lastUpdated: Date;
}

/**
 * Get available appointment slots for a professional
 */
export const getAvailableSlots = onCall<{
  professionalId: string;
  startDate: string;
  endDate: string;
  appointmentType?: string;
}, { slots: Array<{ start: string; end: string; duration: number; type: string }> }>(async (request) => {
  const { professionalId, startDate, endDate, appointmentType } = request.data;

  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  try {
    const slots = await getProfessionalAvailability(
      professionalId, 
      new Date(startDate), 
      new Date(endDate),
      appointmentType
    );

    return { slots };
  } catch (error) {
    logger.error('Get available slots failed:', error);
    throw new HttpsError('internal', 'Failed to get availability');
  }
});

/**
 * Schedule an appointment with a health professional
 */
export const scheduleAppointment = onCall<{
  professionalId: string;
  appointmentType: 'consultation' | 'follow_up' | 'assessment' | 'therapy' | 'coaching';
  scheduledFor: string;
  duration: number;
  notes?: string;
  preferredPlatform?: 'calendly' | 'google_meet' | 'zoom' | 'in_person';
}, { appointmentId: string; meetingDetails: any }>(async (request) => {
  const { professionalId, appointmentType, scheduledFor, duration, notes, preferredPlatform } = request.data;

  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  try {
    const appointment = await createHealthAppointment({
      userId: request.auth.uid,
      professionalId,
      appointmentType,
      scheduledFor: new Date(scheduledFor),
      duration,
      notes,
      preferredPlatform: preferredPlatform || 'google_meet'
    });

    return { 
      appointmentId: appointment.id,
      meetingDetails: appointment.meetingDetails
    };
  } catch (error) {
    logger.error('Schedule appointment failed:', error);
    throw new HttpsError('internal', 'Failed to schedule appointment');
  }
});

/**
 * Update appointment status (confirm, cancel, etc.)
 */
export const updateAppointmentStatus = onCall<{
  appointmentId: string;
  status: 'confirmed' | 'cancelled' | 'completed' | 'no_show';
  notes?: string;
  cancellationReason?: string;
  followUpRequired?: boolean;
}, { success: boolean }>(async (request) => {
  const { appointmentId, status, notes, cancellationReason, followUpRequired } = request.data;

  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  try {
    await updateAppointment(appointmentId, {
      status,
      notes,
      cancellationReason,
      followUpRequired,
      updatedBy: request.auth.uid
    });

    return { success: true };
  } catch (error) {
    logger.error('Update appointment status failed:', error);
    throw new HttpsError('internal', 'Failed to update appointment');
  }
});

/**
 * Get user's appointments
 */
export const getUserAppointments = onCall<{
  status?: string;
  limit?: number;
}, { appointments: HealthAppointment[] }>(async (request) => {
  const { status, limit = 10 } = request.data;

  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  try {
    let query = firestore
      .collection('healthAppointments')
      .where('userId', '==', request.auth.uid)
      .orderBy('scheduledFor', 'desc')
      .limit(limit);

    if (status) {
      query = query.where('status', '==', status);
    }

    const snapshot = await query.get();
    const appointments = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    })) as HealthAppointment[];

    return { appointments };
  } catch (error) {
    logger.error('Get user appointments failed:', error);
    throw new HttpsError('internal', 'Failed to get appointments');
  }
});

/**
 * Reschedule an appointment
 */
export const rescheduleAppointment = onCall<{
  appointmentId: string;
  newDateTime: string;
  reason?: string;
}, { success: boolean; newMeetingDetails?: any }>(async (request) => {
  const { appointmentId, newDateTime, reason } = request.data;

  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  try {
    const result = await rescheduleHealthAppointment(
      appointmentId, 
      new Date(newDateTime), 
      request.auth.uid,
      reason
    );

    return { 
      success: true, 
      newMeetingDetails: result.meetingDetails 
    };
  } catch (error) {
    logger.error('Reschedule appointment failed:', error);
    throw new HttpsError('internal', 'Failed to reschedule appointment');
  }
});

/**
 * Get professional availability from various calendar systems
 */
async function getProfessionalAvailability(
  professionalId: string,
  startDate: Date,
  endDate: Date,
  appointmentType?: string
): Promise<Array<{ start: string; end: string; duration: number; type: string }>> {
  
  // Get professional's calendar configuration
  const professionalDoc = await firestore
    .collection('healthProfessionals')
    .doc(professionalId)
    .get();

  if (!professionalDoc.exists) {
    throw new Error('Professional not found');
  }

  const professional = professionalDoc.data();
  const availabilityDoc = await firestore
    .collection('professionalAvailability')
    .doc(professionalId)
    .get();

  if (!availabilityDoc.exists) {
    throw new Error('Professional availability not configured');
  }

  const availability = availabilityDoc.data() as ProfessionalAvailability;
  
  let slots: Array<{ start: string; end: string; duration: number; type: string }> = [];

  // Get availability from Calendly
  if (availability.calendlyEventTypeUri) {
    const calendlySlots = await getCalendlyAvailability(
      availability.calendlyEventTypeUri,
      startDate,
      endDate
    );
    slots.push(...calendlySlots);
  }

  // Get availability from Google Calendar
  if (availability.googleCalendarId) {
    const googleSlots = await getGoogleCalendarAvailability(
      availability.googleCalendarId,
      startDate,
      endDate,
      professional.googleCalendarToken
    );
    slots.push(...googleSlots);
  }

  // Filter by appointment type if specified
  if (appointmentType) {
    slots = slots.filter(slot => slot.type === appointmentType);
  }

  // Remove already booked slots
  const bookedSlots = await getBookedSlots(professionalId, startDate, endDate);
  slots = slots.filter(slot => 
    !bookedSlots.some(booked => 
      isTimeOverlapping(
        new Date(slot.start), 
        new Date(slot.end),
        booked.start,
        booked.end
      )
    )
  );

  return slots.sort((a, b) => new Date(a.start).getTime() - new Date(b.start).getTime());
}

/**
 * Get available slots from Calendly
 */
async function getCalendlyAvailability(
  eventTypeUri: string,
  startDate: Date,
  endDate: Date
): Promise<Array<{ start: string; end: string; duration: number; type: string }>> {
  
  const calendlyApiToken = process.env.CALENDLY_API_TOKEN;
  if (!calendlyApiToken) {
    logger.warn('Calendly API token not configured');
    return [];
  }

  try {
    const response = await axios.get(
      `https://api.calendly.com/event_type_available_times`,
      {
        headers: {
          'Authorization': `Bearer ${calendlyApiToken}`,
          'Content-Type': 'application/json'
        },
        params: {
          event_type: eventTypeUri,
          start_time: startDate.toISOString(),
          end_time: endDate.toISOString()
        }
      }
    );

    return response.data.collection.map((slot: any) => ({
      start: slot.start_time,
      end: slot.end_time,
      duration: 30, // Default 30 minutes
      type: 'consultation'
    }));
  } catch (error) {
    logger.error('Calendly availability fetch failed:', error);
    return [];
  }
}

/**
 * Get available slots from Google Calendar
 */
async function getGoogleCalendarAvailability(
  calendarId: string,
  startDate: Date,
  endDate: Date,
  accessToken: string
): Promise<Array<{ start: string; end: string; duration: number; type: string }>> {
  
  if (!accessToken) {
    logger.warn('Google Calendar access token not available');
    return [];
  }

  try {
    // Get busy times from Google Calendar
    const response = await axios.post(
      `https://www.googleapis.com/calendar/v3/freeBusy`,
      {
        timeMin: startDate.toISOString(),
        timeMax: endDate.toISOString(),
        items: [{ id: calendarId }]
      },
      {
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        }
      }
    );

    const busyTimes = response.data.calendars[calendarId]?.busy || [];
    
    // Generate available slots (simple implementation)
    // In production, this would be more sophisticated
    const availableSlots = [];
    const businessHours = { start: 9, end: 17 }; // 9 AM to 5 PM
    
    for (let date = new Date(startDate); date <= endDate; date.setDate(date.getDate() + 1)) {
      // Skip weekends
      if (date.getDay() === 0 || date.getDay() === 6) continue;
      
      for (let hour = businessHours.start; hour < businessHours.end; hour++) {
        const slotStart = new Date(date);
        slotStart.setHours(hour, 0, 0, 0);
        
        const slotEnd = new Date(slotStart);
        slotEnd.setHours(hour + 1, 0, 0, 0);
        
        // Check if slot conflicts with busy times
        const isConflict = busyTimes.some((busy: any) => 
          isTimeOverlapping(
            slotStart,
            slotEnd,
            new Date(busy.start),
            new Date(busy.end)
          )
        );
        
        if (!isConflict) {
          availableSlots.push({
            start: slotStart.toISOString(),
            end: slotEnd.toISOString(),
            duration: 60,
            type: 'consultation'
          });
        }
      }
    }
    
    return availableSlots;
  } catch (error) {
    logger.error('Google Calendar availability fetch failed:', error);
    return [];
  }
}

/**
 * Get already booked appointment slots
 */
async function getBookedSlots(
  professionalId: string,
  startDate: Date,
  endDate: Date
): Promise<Array<{ start: Date; end: Date }>> {
  
  const snapshot = await firestore
    .collection('healthAppointments')
    .where('professionalId', '==', professionalId)
    .where('scheduledFor', '>=', startDate)
    .where('scheduledFor', '<=', endDate)
    .where('status', 'in', ['scheduled', 'confirmed'])
    .get();

  return snapshot.docs.map(doc => {
    const data = doc.data();
    const start = data.scheduledFor.toDate();
    const end = new Date(start.getTime() + data.duration * 60000); // duration in minutes
    
    return { start, end };
  });
}

/**
 * Create a new health appointment
 */
async function createHealthAppointment(params: {
  userId: string;
  professionalId: string;
  appointmentType: string;
  scheduledFor: Date;
  duration: number;
  notes?: string;
  preferredPlatform: string;
}): Promise<HealthAppointment> {
  
  // Get professional info
  const professionalDoc = await firestore
    .collection('healthProfessionals')
    .doc(params.professionalId)
    .get();

  if (!professionalDoc.exists) {
    throw new Error('Professional not found');
  }

  const professional = professionalDoc.data();
  
  // Generate meeting details based on platform
  const meetingDetails = await generateMeetingDetails(
    params.preferredPlatform,
    params.scheduledFor,
    params.duration,
    professional
  );

  const appointment: HealthAppointment = {
    id: '', // Will be set by Firestore
    userId: params.userId,
    professionalId: params.professionalId,
    professionalInfo: {
      name: professional.profile?.name || 'Unknown',
      title: professional.profile?.title || '',
      specialty: professional.verification?.specialty || '',
      email: professional.email || ''
    },
    type: params.appointmentType as any,
    status: 'scheduled',
    scheduledFor: params.scheduledFor,
    duration: params.duration,
    notes: params.notes,
    meetingDetails,
    reminders: [
      {
        type: 'email',
        scheduledFor: new Date(params.scheduledFor.getTime() - 24 * 60 * 60 * 1000) // 24 hours before
      },
      {
        type: 'push',
        scheduledFor: new Date(params.scheduledFor.getTime() - 60 * 60 * 1000) // 1 hour before
      }
    ],
    createdAt: new Date(),
    updatedAt: new Date()
  };

  // Save to Firestore
  const appointmentRef = await firestore
    .collection('healthAppointments')
    .add(appointment);

  appointment.id = appointmentRef.id;

  // Update the document with the ID
  await appointmentRef.update({ id: appointment.id });

  // Schedule in external calendar if needed
  if (params.preferredPlatform === 'calendly' && professional.calendlyEventTypeUri) {
    await scheduleCalendlyEvent(professional.calendlyEventTypeUri, appointment);
  } else if (params.preferredPlatform === 'google_meet' && professional.googleCalendarId) {
    await scheduleGoogleCalendarEvent(professional.googleCalendarId, appointment, professional.googleCalendarToken);
  }

  return appointment;
}

/**
 * Generate meeting details based on platform
 */
async function generateMeetingDetails(
  platform: string,
  scheduledFor: Date,
  duration: number,
  professional: any
): Promise<any> {
  
  switch (platform) {
    case 'google_meet':
      return {
        platform: 'google_meet',
        joinUrl: `https://meet.google.com/${generateMeetingId()}`,
        meetingId: generateMeetingId()
      };
      
    case 'zoom':
      return {
        platform: 'zoom',
        joinUrl: 'https://zoom.us/j/placeholder', // Would integrate with Zoom API
        meetingId: 'placeholder'
      };
      
    case 'in_person':
      return {
        platform: 'in_person',
        location: professional.officeAddress || 'Office location TBD'
      };
      
    case 'calendly':
    default:
      return {
        platform: 'calendly',
        joinUrl: 'TBD' // Will be set when Calendly event is created
      };
  }
}

/**
 * Generate a random meeting ID
 */
function generateMeetingId(): string {
  return Math.random().toString(36).substring(2, 15);
}

/**
 * Schedule event in Calendly
 */
async function scheduleCalendlyEvent(eventTypeUri: string, appointment: HealthAppointment): Promise<void> {
  const calendlyApiToken = process.env.CALENDLY_API_TOKEN;
  if (!calendlyApiToken) {
    logger.warn('Calendly API token not configured');
    return;
  }

  try {
    const response = await axios.post(
      'https://api.calendly.com/scheduled_events',
      {
        event_type: eventTypeUri,
        start_time: appointment.scheduledFor.toISOString(),
        invitee: {
          email: 'user@example.com', // Would get from user profile
          name: 'Health App User'
        }
      },
      {
        headers: {
          'Authorization': `Bearer ${calendlyApiToken}`,
          'Content-Type': 'application/json'
        }
      }
    );

    // Update appointment with Calendly details
    await firestore
      .collection('healthAppointments')
      .doc(appointment.id)
      .update({
        'meetingDetails.joinUrl': response.data.resource.location.join_url,
        'meetingDetails.calendlyEventUri': response.data.resource.uri
      });

  } catch (error) {
    logger.error('Calendly event scheduling failed:', error);
  }
}

/**
 * Schedule event in Google Calendar
 */
async function scheduleGoogleCalendarEvent(
  calendarId: string, 
  appointment: HealthAppointment,
  accessToken: string
): Promise<void> {
  
  if (!accessToken) {
    logger.warn('Google Calendar access token not available');
    return;
  }

  try {
    const event: GoogleCalendarEvent = {
      id: appointment.id,
      summary: `Health Consultation - ${appointment.professionalInfo.name}`,
      description: `Health appointment with ${appointment.professionalInfo.name}\n\nType: ${appointment.type}\nNotes: ${appointment.notes || 'None'}`,
      start: {
        dateTime: appointment.scheduledFor.toISOString(),
        timeZone: 'UTC'
      },
      end: {
        dateTime: new Date(appointment.scheduledFor.getTime() + appointment.duration * 60000).toISOString(),
        timeZone: 'UTC'
      },
      attendees: [
        {
          email: appointment.professionalInfo.email,
          displayName: appointment.professionalInfo.name,
          responseStatus: 'accepted'
        }
      ],
      conferenceData: {
        conferenceSolution: {
          key: { type: 'hangoutsMeet' }
        },
        createRequest: {
          requestId: appointment.id,
          conferenceSolutionKey: { type: 'hangoutsMeet' }
        }
      },
      status: 'confirmed'
    };

    const response = await axios.post(
      `https://www.googleapis.com/calendar/v3/calendars/${calendarId}/events?conferenceDataVersion=1`,
      event,
      {
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        }
      }
    );

    // Update appointment with Google Calendar details
    await firestore
      .collection('healthAppointments')
      .doc(appointment.id)
      .update({
        'meetingDetails.joinUrl': response.data.hangoutLink,
        'meetingDetails.googleEventId': response.data.id
      });

  } catch (error) {
    logger.error('Google Calendar event scheduling failed:', error);
  }
}

/**
 * Update appointment details
 */
async function updateAppointment(appointmentId: string, updates: any): Promise<void> {
  await firestore
    .collection('healthAppointments')
    .doc(appointmentId)
    .update({
      ...updates,
      updatedAt: new Date()
    });
}

/**
 * Reschedule an appointment
 */
async function rescheduleHealthAppointment(
  appointmentId: string,
  newDateTime: Date,
  userId: string,
  reason?: string
): Promise<{ success: boolean; meetingDetails?: any }> {
  
  // Get current appointment
  const appointmentDoc = await firestore
    .collection('healthAppointments')
    .doc(appointmentId)
    .get();

  if (!appointmentDoc.exists) {
    throw new Error('Appointment not found');
  }

  const appointment = appointmentDoc.data() as HealthAppointment;

  // Verify user has permission to reschedule
  if (appointment.userId !== userId) {
    throw new Error('Permission denied');
  }

  // Update appointment
  await firestore
    .collection('healthAppointments')
    .doc(appointmentId)
    .update({
      scheduledFor: newDateTime,
      status: 'scheduled',
      updatedAt: new Date(),
      rescheduleReason: reason
    });

  // Update external calendar events if needed
  if (appointment.meetingDetails.googleEventId) {
    // Would update Google Calendar event here
  }

  return { 
    success: true,
    meetingDetails: appointment.meetingDetails
  };
}

/**
 * Check if two time periods overlap
 */
function isTimeOverlapping(
  start1: Date,
  end1: Date,
  start2: Date,
  end2: Date
): boolean {
  return start1 < end2 && end1 > start2;
}