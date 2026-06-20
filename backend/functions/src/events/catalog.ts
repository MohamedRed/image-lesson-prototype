import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import { CallableContext } from "firebase-functions/v2/https";
import { 
  Event, 
  EventSession, 
  EventPromoter, 
  EventCategory,
  EventStatus,
  SessionStatus,
  VerificationTier,
  PriceTier,
  SeatingInfo,
  RecurrenceRule
} from "./types";

const db = admin.firestore();

/**
 * Create or update an event in the catalog
 * Requires promoter authorization
 */
export async function createOrUpdateEvent(
  data: {
    eventId?: string;
    promoterId: string;
    title: string;
    category: EventCategory;
    description: string;
    images?: string[];
    rules?: string[];
    priceTiers: PriceTier[];
    location: admin.firestore.GeoPoint;
    venueName: string;
    neighborhood?: string;
    startAt: string;
    endAt: string;
    recurrence?: RecurrenceRule;
    ageRestrictions?: { minimumAge?: number; requiresGuardian?: boolean };
    indoor?: boolean;
    tags?: string[];
    seating?: SeatingInfo;
  },
  context: CallableContext
): Promise<Event> {
  try {
    // Verify user is authorized for this promoter
    if (!context.auth) {
      throw new Error("Authentication required");
    }

    const promoterDoc = await db.collection("eventPromoters").doc(data.promoterId).get();
    if (!promoterDoc.exists) {
      throw new Error("Promoter not found");
    }

    const promoter = promoterDoc.data() as EventPromoter;
    if (!promoter.isActive) {
      throw new Error("Promoter account is not active");
    }

    // Validate price tiers
    if (!data.priceTiers || data.priceTiers.length === 0) {
      throw new Error("At least one price tier is required");
    }

    // Prepare event data
    const eventData: Partial<Event> = {
      promoterId: data.promoterId,
      title: data.title,
      category: data.category,
      description: data.description,
      images: data.images || [],
      rules: data.rules || [],
      priceTiers: data.priceTiers,
      location: data.location,
      venueName: data.venueName,
      neighborhood: data.neighborhood,
      startAt: admin.firestore.Timestamp.fromDate(new Date(data.startAt)),
      endAt: admin.firestore.Timestamp.fromDate(new Date(data.endAt)),
      recurrence: data.recurrence,
      ageRestrictions: data.ageRestrictions,
      indoor: data.indoor ?? true,
      tags: data.tags || [],
      seating: data.seating || { hasSeatMap: false, generalAdmission: true },
      status: EventStatus.PUBLISHED,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    let eventRef: admin.firestore.DocumentReference;
    
    if (data.eventId) {
      // Update existing event
      eventRef = db.collection("events").doc(data.eventId);
      await eventRef.update(eventData);
      logger.info("Event updated", { eventId: data.eventId });
    } else {
      // Create new event
      eventData.createdAt = admin.firestore.FieldValue.serverTimestamp();
      eventRef = await db.collection("events").add(eventData as any);
      logger.info("Event created", { eventId: eventRef.id });
      
      // Create initial session if not recurring
      if (!data.recurrence) {
        await createEventSession({
          eventId: eventRef.id,
          startAt: data.startAt,
          endAt: data.endAt,
          capacityByTier: calculateInitialCapacity(data.priceTiers, data.seating),
        });
      } else {
        // Generate recurring sessions
        await generateRecurringSessions(eventRef.id, data);
      }
    }

    const updatedDoc = await eventRef.get();
    return { id: eventRef.id, ...updatedDoc.data() } as Event;
    
  } catch (error: any) {
    logger.error("Failed to create/update event", { error: error.message });
    throw error;
  }
}

/**
 * Create an event session
 */
export async function createEventSession(data: {
  eventId: string;
  startAt: string;
  endAt: string;
  capacityByTier: { [tierName: string]: number };
}): Promise<EventSession> {
  try {
    const sessionData = {
      eventId: data.eventId,
      startAt: admin.firestore.Timestamp.fromDate(new Date(data.startAt)),
      endAt: admin.firestore.Timestamp.fromDate(new Date(data.endAt)),
      capacityByTier: data.capacityByTier,
      status: SessionStatus.SCHEDULED,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const sessionRef = await db.collection("eventSessions").add(sessionData);
    logger.info("Session created", { sessionId: sessionRef.id, eventId: data.eventId });

    return { id: sessionRef.id, ...sessionData } as EventSession;
    
  } catch (error: any) {
    logger.error("Failed to create session", { error: error.message });
    throw error;
  }
}

/**
 * Update session capacity and status
 */
export async function updateSessionCapacity(
  sessionId: string,
  updates: {
    capacityByTier?: { [tierName: string]: number };
    status?: SessionStatus;
  }
): Promise<void> {
  try {
    const sessionRef = db.collection("eventSessions").doc(sessionId);
    await sessionRef.update({
      ...updates,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    logger.info("Session capacity updated", { sessionId, updates });
  } catch (error: any) {
    logger.error("Failed to update session capacity", { error: error.message });
    throw error;
  }
}

/**
 * Get event with sessions
 */
export async function getEventWithSessions(eventId: string): Promise<{
  event: Event;
  sessions: EventSession[];
}> {
  try {
    const eventDoc = await db.collection("events").doc(eventId).get();
    if (!eventDoc.exists) {
      throw new Error("Event not found");
    }

    const sessionsSnapshot = await db
      .collection("eventSessions")
      .where("eventId", "==", eventId)
      .where("startAt", ">", admin.firestore.Timestamp.now())
      .orderBy("startAt")
      .get();

    const sessions = sessionsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    })) as EventSession[];

    return {
      event: { id: eventDoc.id, ...eventDoc.data() } as Event,
      sessions,
    };
  } catch (error: any) {
    logger.error("Failed to get event with sessions", { error: error.message });
    throw error;
  }
}

/**
 * Calculate initial capacity based on price tiers and seating info
 */
function calculateInitialCapacity(
  priceTiers: PriceTier[],
  seating?: SeatingInfo
): { [tierName: string]: number } {
  const totalCapacity = seating?.totalCapacity || 100; // Default capacity
  const tierCount = priceTiers.length;
  
  const capacityByTier: { [tierName: string]: number } = {};
  
  if (seating?.generalAdmission) {
    // Equal distribution for general admission
    const capacityPerTier = Math.floor(totalCapacity / tierCount);
    priceTiers.forEach(tier => {
      capacityByTier[tier.name] = capacityPerTier;
    });
  } else {
    // Weighted distribution based on price (cheaper tiers get more capacity)
    const sortedTiers = [...priceTiers].sort((a, b) => a.priceMAD - b.priceMAD);
    let remainingCapacity = totalCapacity;
    
    sortedTiers.forEach((tier, index) => {
      const weight = tierCount - index;
      const tierCapacity = Math.floor(totalCapacity * (weight / ((tierCount * (tierCount + 1)) / 2)));
      capacityByTier[tier.name] = tierCapacity;
      remainingCapacity -= tierCapacity;
    });
    
    // Add remaining capacity to the cheapest tier
    if (remainingCapacity > 0 && sortedTiers.length > 0) {
      capacityByTier[sortedTiers[0].name] += remainingCapacity;
    }
  }
  
  return capacityByTier;
}

/**
 * Generate recurring sessions based on recurrence rule
 */
async function generateRecurringSessions(
  eventId: string,
  eventData: any
): Promise<void> {
  const recurrence = eventData.recurrence as RecurrenceRule;
  if (!recurrence) return;

  const startDate = new Date(eventData.startAt);
  const endDate = new Date(eventData.endAt);
  const duration = endDate.getTime() - startDate.getTime();
  
  const endRecurrence = recurrence.endDate 
    ? new Date(recurrence.endDate)
    : new Date(startDate.getTime() + 90 * 24 * 60 * 60 * 1000); // 90 days default

  const sessions: Date[] = [];
  let currentDate = new Date(startDate);

  while (currentDate <= endRecurrence && sessions.length < 50) { // Limit to 50 sessions
    switch (recurrence.frequency) {
      case "daily":
        currentDate.setDate(currentDate.getDate() + recurrence.interval);
        break;
      case "weekly":
        if (recurrence.daysOfWeek && recurrence.daysOfWeek.length > 0) {
          // Find next occurrence on specified days
          let found = false;
          for (let i = 0; i < 7; i++) {
            currentDate.setDate(currentDate.getDate() + 1);
            if (recurrence.daysOfWeek.includes(currentDate.getDay())) {
              found = true;
              break;
            }
          }
          if (!found) continue;
        } else {
          currentDate.setDate(currentDate.getDate() + 7 * recurrence.interval);
        }
        break;
      case "monthly":
        currentDate.setMonth(currentDate.getMonth() + recurrence.interval);
        break;
    }

    if (currentDate <= endRecurrence) {
      sessions.push(new Date(currentDate));
    }
  }

  // Create sessions in batch
  const batch = db.batch();
  const capacityByTier = calculateInitialCapacity(eventData.priceTiers, eventData.seating);

  sessions.forEach(sessionDate => {
    const sessionRef = db.collection("eventSessions").doc();
    batch.set(sessionRef, {
      eventId,
      startAt: admin.firestore.Timestamp.fromDate(sessionDate),
      endAt: admin.firestore.Timestamp.fromDate(new Date(sessionDate.getTime() + duration)),
      capacityByTier,
      status: SessionStatus.SCHEDULED,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  await batch.commit();
  logger.info("Recurring sessions created", { eventId, count: sessions.length });
}

/**
 * Cancel an event and all its sessions
 */
export async function cancelEvent(
  eventId: string,
  reason: string,
  context: CallableContext
): Promise<void> {
  try {
    if (!context.auth) {
      throw new Error("Authentication required");
    }

    const eventDoc = await db.collection("events").doc(eventId).get();
    if (!eventDoc.exists) {
      throw new Error("Event not found");
    }

    const event = eventDoc.data() as Event;
    
    // Start transaction to cancel event and sessions
    await db.runTransaction(async (transaction) => {
      // Update event status
      transaction.update(eventDoc.ref, {
        status: EventStatus.CANCELLED,
        cancellationReason: reason,
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        cancelledBy: context.auth!.uid,
      });

      // Cancel all sessions
      const sessionsSnapshot = await db
        .collection("eventSessions")
        .where("eventId", "==", eventId)
        .get();

      sessionsSnapshot.docs.forEach(doc => {
        transaction.update(doc.ref, {
          status: SessionStatus.CANCELLED,
          cancellationReason: reason,
        });
      });

      // TODO: Trigger refund process for existing orders
      // TODO: Send cancellation notifications to attendees
    });

    logger.info("Event cancelled", { eventId, reason });
  } catch (error: any) {
    logger.error("Failed to cancel event", { error: error.message });
    throw error;
  }
}