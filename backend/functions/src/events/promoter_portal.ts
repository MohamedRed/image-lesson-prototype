import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import { CallableContext } from "firebase-functions/v2/https";
import { sendNotification } from "./notifications";
import {
  Event,
  EventStatus,
  EventPromoter,
  PromoterApplication,
  PromoterMetrics,
  EventDraft
} from "./types";

const db = admin.firestore();

/**
 * Apply to become an event promoter
 */
export async function applyForPromoterStatus(
  data: {
    businessName: string;
    contactName: string;
    email: string;
    phone: string;
    businessType: string;
    description: string;
    previousExperience?: string;
    socialMediaLinks?: string[];
    businessRegistration?: string;
  },
  context: CallableContext
): Promise<{ applicationId: string }> {
  try {
    const userId = context.auth?.uid;
    if (!userId) {
      throw new Error("Authentication required");
    }

    // Check if user already has pending/approved application
    const existingApp = await db.collection("promoterApplications")
      .where("userId", "==", userId)
      .where("status", "in", ["pending", "approved"])
      .get();

    if (!existingApp.empty) {
      throw new Error("You already have an active promoter application");
    }

    const applicationId = `app_${Date.now()}_${userId}`;
    const application: PromoterApplication = {
      id: applicationId,
      userId,
      businessName: data.businessName,
      contactName: data.contactName,
      email: data.email,
      phone: data.phone,
      businessType: data.businessType,
      description: data.description,
      previousExperience: data.previousExperience,
      socialMediaLinks: data.socialMediaLinks || [],
      businessRegistration: data.businessRegistration,
      status: "pending",
      submittedAt: new Date(),
      reviewedAt: null,
      reviewedBy: null,
      reviewNotes: null
    };

    await db.collection("promoterApplications").doc(applicationId).set({
      ...application,
      submittedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Notify admin team
    await notifyAdminTeam("new_promoter_application", {
      applicationId,
      businessName: data.businessName,
      contactName: data.contactName
    });

    logger.info("Promoter application submitted", { applicationId, userId });
    return { applicationId };
  } catch (error: any) {
    logger.error("Failed to submit promoter application", { error: error.message });
    throw error;
  }
}

/**
 * Get promoter application status
 */
export async function getPromoterApplicationStatus(
  userId: string
): Promise<PromoterApplication | null> {
  try {
    const snapshot = await db.collection("promoterApplications")
      .where("userId", "==", userId)
      .orderBy("submittedAt", "desc")
      .limit(1)
      .get();

    if (snapshot.empty) {
      return null;
    }

    const doc = snapshot.docs[0];
    return {
      id: doc.id,
      ...doc.data(),
      submittedAt: doc.data().submittedAt.toDate(),
      reviewedAt: doc.data().reviewedAt?.toDate()
    } as PromoterApplication;
  } catch (error: any) {
    logger.error("Failed to get promoter application status", { error: error.message });
    throw error;
  }
}

/**
 * Create event draft (for promoters)
 */
export async function createEventDraft(
  data: EventDraft,
  context: CallableContext
): Promise<{ eventId: string }> {
  try {
    const userId = context.auth?.uid;
    if (!userId) {
      throw new Error("Authentication required");
    }

    // Verify user is approved promoter
    const promoter = await getPromoterByUserId(userId);
    if (!promoter || promoter.status !== "active") {
      throw new Error("Only approved promoters can create events");
    }

    // Generate unique event ID
    const eventId = `event_${Date.now()}_${userId.substr(0, 8)}`;

    const event: Partial<Event> = {
      id: eventId,
      promoterId: promoter.id!,
      title: data.title,
      category: data.category,
      description: data.description,
      images: data.images || [],
      rules: data.rules || [],
      priceTiers: data.priceTiers || [],
      location: new admin.firestore.GeoPoint(data.location.latitude, data.location.longitude),
      venueName: data.venueName,
      neighborhood: data.neighborhood,
      startAt: admin.firestore.Timestamp.fromDate(data.startAt),
      endAt: admin.firestore.Timestamp.fromDate(data.endAt),
      indoor: data.indoor,
      tags: data.tags || [],
      seating: data.seating || { hasSeatMap: false, generalAdmission: true },
      status: EventStatus.DRAFT,
      cityId: data.cityId || "casablanca",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    await db.collection("events").doc(eventId).set(event);

    logger.info("Event draft created", { eventId, promoterId: promoter.id });
    return { eventId };
  } catch (error: any) {
    logger.error("Failed to create event draft", { error: error.message });
    throw error;
  }
}

/**
 * Update event draft
 */
export async function updateEventDraft(
  eventId: string,
  updates: Partial<EventDraft>,
  context: CallableContext
): Promise<void> {
  try {
    const userId = context.auth?.uid;
    if (!userId) {
      throw new Error("Authentication required");
    }

    // Get event and verify ownership
    const eventDoc = await db.collection("events").doc(eventId).get();
    if (!eventDoc.exists) {
      throw new Error("Event not found");
    }

    const event = eventDoc.data() as Event;
    const promoter = await getPromoterByUserId(userId);
    
    if (!promoter || event.promoterId !== promoter.id) {
      throw new Error("Not authorized to update this event");
    }

    if (event.status !== EventStatus.DRAFT && event.status !== EventStatus.UNDER_REVIEW) {
      throw new Error("Can only update draft or under-review events");
    }

    // Prepare updates
    const updateData: any = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    if (updates.title) updateData.title = updates.title;
    if (updates.description) updateData.description = updates.description;
    if (updates.category) updateData.category = updates.category;
    if (updates.images) updateData.images = updates.images;
    if (updates.rules) updateData.rules = updates.rules;
    if (updates.priceTiers) updateData.priceTiers = updates.priceTiers;
    if (updates.venueName) updateData.venueName = updates.venueName;
    if (updates.neighborhood) updateData.neighborhood = updates.neighborhood;
    if (updates.tags) updateData.tags = updates.tags;
    if (updates.seating) updateData.seating = updates.seating;
    if (updates.indoor !== undefined) updateData.indoor = updates.indoor;

    if (updates.location) {
      updateData.location = new admin.firestore.GeoPoint(
        updates.location.latitude, 
        updates.location.longitude
      );
    }

    if (updates.startAt) {
      updateData.startAt = admin.firestore.Timestamp.fromDate(updates.startAt);
    }

    if (updates.endAt) {
      updateData.endAt = admin.firestore.Timestamp.fromDate(updates.endAt);
    }

    await db.collection("events").doc(eventId).update(updateData);

    logger.info("Event draft updated", { eventId, promoterId: promoter.id });
  } catch (error: any) {
    logger.error("Failed to update event draft", { error: error.message });
    throw error;
  }
}

/**
 * Submit event for review
 */
export async function submitEventForReview(
  eventId: string,
  context: CallableContext
): Promise<void> {
  try {
    const userId = context.auth?.uid;
    if (!userId) {
      throw new Error("Authentication required");
    }

    // Get event and verify ownership
    const eventDoc = await db.collection("events").doc(eventId).get();
    if (!eventDoc.exists) {
      throw new Error("Event not found");
    }

    const event = eventDoc.data() as Event;
    const promoter = await getPromoterByUserId(userId);
    
    if (!promoter || event.promoterId !== promoter.id) {
      throw new Error("Not authorized to submit this event");
    }

    if (event.status !== EventStatus.DRAFT) {
      throw new Error("Only draft events can be submitted for review");
    }

    // Validate event completeness
    validateEventForSubmission(event);

    await db.collection("events").doc(eventId).update({
      status: EventStatus.UNDER_REVIEW,
      submittedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Notify admin team
    await notifyAdminTeam("event_submitted_for_review", {
      eventId,
      eventTitle: event.title,
      promoterName: promoter.businessName
    });

    logger.info("Event submitted for review", { eventId, promoterId: promoter.id });
  } catch (error: any) {
    logger.error("Failed to submit event for review", { error: error.message });
    throw error;
  }
}

/**
 * Get promoter's events
 */
export async function getPromoterEvents(
  userId: string,
  status?: EventStatus
): Promise<Event[]> {
  try {
    const promoter = await getPromoterByUserId(userId);
    if (!promoter) {
      throw new Error("User is not a promoter");
    }

    let query = db.collection("events").where("promoterId", "==", promoter.id);
    
    if (status) {
      query = query.where("status", "==", status);
    }

    const snapshot = await query.orderBy("createdAt", "desc").get();

    return snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      startAt: doc.data().startAt.toDate(),
      endAt: doc.data().endAt.toDate(),
      createdAt: doc.data().createdAt.toDate(),
      updatedAt: doc.data().updatedAt.toDate()
    })) as Event[];
  } catch (error: any) {
    logger.error("Failed to get promoter events", { error: error.message });
    throw error;
  }
}

/**
 * Get promoter metrics
 */
export async function getPromoterMetrics(
  userId: string,
  timeRange?: { start: Date; end: Date }
): Promise<PromoterMetrics> {
  try {
    const promoter = await getPromoterByUserId(userId);
    if (!promoter) {
      throw new Error("User is not a promoter");
    }

    // Get events in time range
    let eventsQuery = db.collection("events").where("promoterId", "==", promoter.id);
    
    if (timeRange) {
      eventsQuery = eventsQuery
        .where("startAt", ">=", admin.firestore.Timestamp.fromDate(timeRange.start))
        .where("startAt", "<=", admin.firestore.Timestamp.fromDate(timeRange.end));
    }

    const eventsSnapshot = await eventsQuery.get();
    const eventIds = eventsSnapshot.docs.map(doc => doc.id);

    // Get ticket sales metrics
    const [ordersSnapshot, groupsSnapshot] = await Promise.all([
      eventIds.length > 0 
        ? db.collection("ticketOrders")
            .where("eventId", "in", eventIds.slice(0, 10)) // Firestore limit
            .where("status", "==", "confirmed")
            .get()
        : Promise.resolve({ docs: [] } as any),
      eventIds.length > 0
        ? db.collection("attendanceGroups")
            .where("eventId", "in", eventIds.slice(0, 10))
            .where("status", "==", "confirmed")
            .get()
        : Promise.resolve({ docs: [] } as any)
    ]);

    // Calculate metrics
    const totalEvents = eventsSnapshot.size;
    const publishedEvents = eventsSnapshot.docs.filter(doc => 
      doc.data().status === EventStatus.PUBLISHED
    ).length;
    
    const totalTicketsSold = ordersSnapshot.docs.reduce((sum: number, doc: any) => {
      return sum + doc.data().lineItems.reduce((itemSum: number, item: any) => 
        itemSum + item.quantity, 0
      );
    }, 0);

    const totalRevenue = ordersSnapshot.docs.reduce((sum: number, doc: any) => {
      return sum + doc.data().totalAmount;
    }, 0);

    const totalAttendees = groupsSnapshot.docs.reduce((sum: number, doc: any) => {
      return sum + doc.data().participantUserIds.length;
    }, 0);

    const averageAttendanceRate = publishedEvents > 0 
      ? (totalAttendees / publishedEvents) 
      : 0;

    const metrics: PromoterMetrics = {
      totalEvents,
      publishedEvents,
      totalTicketsSold,
      totalRevenue,
      totalAttendees,
      averageAttendanceRate,
      topPerformingEvents: await getTopPerformingEvents(promoter.id!, 5),
      recentActivity: await getRecentPromoterActivity(promoter.id!, 10)
    };

    return metrics;
  } catch (error: any) {
    logger.error("Failed to get promoter metrics", { error: error.message });
    throw error;
  }
}

// Helper functions

async function getPromoterByUserId(userId: string): Promise<EventPromoter | null> {
  try {
    const snapshot = await db.collection("eventPromoters")
      .where("userId", "==", userId)
      .limit(1)
      .get();

    if (snapshot.empty) {
      return null;
    }

    const doc = snapshot.docs[0];
    return {
      id: doc.id,
      ...doc.data()
    } as EventPromoter;
  } catch (error: any) {
    logger.error("Failed to get promoter by user ID", { error: error.message });
    return null;
  }
}

function validateEventForSubmission(event: Event): void {
  if (!event.title?.trim()) {
    throw new Error("Event title is required");
  }
  
  if (!event.description?.trim()) {
    throw new Error("Event description is required");
  }
  
  if (!event.venueName?.trim()) {
    throw new Error("Venue name is required");
  }
  
  if (!event.priceTiers || event.priceTiers.length === 0) {
    throw new Error("At least one price tier is required");
  }
  
  if (!event.startAt || !event.endAt) {
    throw new Error("Start and end dates are required");
  }
  
  if (event.startAt >= event.endAt) {
    throw new Error("Start date must be before end date");
  }
  
  if (event.startAt.toDate() <= new Date()) {
    throw new Error("Event must be scheduled for a future date");
  }
}

async function notifyAdminTeam(type: string, data: any): Promise<void> {
  try {
    // Get admin users
    const adminsSnapshot = await db.collection("userProfiles")
      .where("role", "==", "admin")
      .get();

    const adminIds = adminsSnapshot.docs.map(doc => doc.id);

    if (adminIds.length > 0) {
      await sendNotification("system", type, data, adminIds);
    }
  } catch (error: any) {
    logger.error("Failed to notify admin team", { error: error.message });
  }
}

async function getTopPerformingEvents(
  promoterId: string, 
  limit: number
): Promise<Array<{ eventId: string; eventTitle: string; attendees: number; revenue: number }>> {
  try {
    const eventsSnapshot = await db.collection("events")
      .where("promoterId", "==", promoterId)
      .where("status", "==", EventStatus.PUBLISHED)
      .orderBy("createdAt", "desc")
      .limit(limit * 2)
      .get();

    const results = [];
    
    for (const eventDoc of eventsSnapshot.docs) {
      const event = eventDoc.data();
      
      // Get attendance and revenue for this event
      const [ordersSnapshot, groupsSnapshot] = await Promise.all([
        db.collection("ticketOrders")
          .where("eventId", "==", eventDoc.id)
          .where("status", "==", "confirmed")
          .get(),
        db.collection("attendanceGroups")
          .where("eventId", "==", eventDoc.id)
          .where("status", "==", "confirmed")
          .get()
      ]);

      const revenue = ordersSnapshot.docs.reduce((sum, doc) => 
        sum + doc.data().totalAmount, 0
      );
      
      const attendees = groupsSnapshot.docs.reduce((sum, doc) => 
        sum + doc.data().participantUserIds.length, 0
      );

      results.push({
        eventId: eventDoc.id,
        eventTitle: event.title,
        attendees,
        revenue
      });
    }

    return results
      .sort((a, b) => b.revenue - a.revenue)
      .slice(0, limit);
  } catch (error: any) {
    logger.error("Failed to get top performing events", { error: error.message });
    return [];
  }
}

async function getRecentPromoterActivity(
  promoterId: string,
  limit: number
): Promise<Array<{ timestamp: Date; activity: string; details: any }>> {
  try {
    // This would track promoter activities like event creations, updates, etc.
    // For now, return recent events as activity
    const eventsSnapshot = await db.collection("events")
      .where("promoterId", "==", promoterId)
      .orderBy("updatedAt", "desc")
      .limit(limit)
      .get();

    return eventsSnapshot.docs.map(doc => {
      const event = doc.data();
      return {
        timestamp: event.updatedAt.toDate(),
        activity: `Event ${event.status}`,
        details: {
          eventId: doc.id,
          eventTitle: event.title,
          status: event.status
        }
      };
    });
  } catch (error: any) {
    logger.error("Failed to get recent promoter activity", { error: error.message });
    return [];
  }
}