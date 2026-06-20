import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { 
  createOrUpdateEvent,
  createEventSession,
  getEventWithSessions,
  cancelEvent
} from "./catalog";
import {
  searchEvents,
  getTrendingEvents
} from "./search";
import {
  createAttendanceGroup,
  inviteFriendsToGroup,
  updateRSVP,
  leaveGroup,
  getGroupDetails
} from "./groups";
import {
  createTicketOrder,
  linkExternalTickets,
  confirmOrder,
  cancelOrder
} from "./tickets";
import {
  createSplitIntent,
  paySplit,
  getSplitStatus
} from "./splitPayments";
import {
  sendNotification,
  markNotificationRead
} from "./notifications";
import {
  getFriends,
  getFriendActivity,
  getEventsWithFriends,
  sendEventInvite,
  getEventInvites,
  respondToInvite
} from "./friends";
import {
  getGroupChatId,
  createGroupChat,
  sendGroupMessage,
  getGroupMessages,
  markMessagesRead
} from "./chat";
import {
  getRideQuote,
  bookEventRide,
  getEventRideBookings
} from "./ride_integration";
import {
  applyForPromoterStatus,
  getPromoterApplicationStatus,
  createEventDraft,
  updateEventDraft,
  submitEventForReview,
  getPromoterEvents,
  getPromoterMetrics
} from "./promoter_portal";
import {
  connectExternalProvider,
  syncExternalEvents,
  importExternalEvent,
  syncExternalOrders,
  handleExternalWebhook
} from "./external_ticket_providers";

// ============ CATALOG FUNCTIONS ============

export const eventsCreateOrUpdate = onCall(async (request) => {
  try {
    return await createOrUpdateEvent(request.data, request);
  } catch (error: any) {
    logger.error("eventsCreateOrUpdate error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsGetWithSessions = onCall(async (request) => {
  try {
    const { eventId } = request.data;
    if (!eventId) {
      throw new HttpsError("invalid-argument", "eventId is required");
    }
    return await getEventWithSessions(eventId);
  } catch (error: any) {
    logger.error("eventsGetWithSessions error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsCancel = onCall(async (request) => {
  try {
    const { eventId, reason } = request.data;
    if (!eventId) {
      throw new HttpsError("invalid-argument", "eventId is required");
    }
    await cancelEvent(eventId, reason || "Event cancelled", request);
    return { success: true };
  } catch (error: any) {
    logger.error("eventsCancel error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

// ============ SEARCH FUNCTIONS ============

export const eventsSearch = onCall(async (request) => {
  try {
    const { query, filters } = request.data;
    const searchQuery = {
      query: query || "",
      filters: filters || {},
      userId: request.auth?.uid,
      limit: 50
    };
    return await searchEvents(searchQuery, request);
  } catch (error: any) {
    logger.error("eventsSearch error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsTrending = onCall(async (request) => {
  try {
    const { cityId, limit } = request.data;
    if (!cityId) {
      throw new HttpsError("invalid-argument", "cityId is required");
    }
    return await getTrendingEvents(cityId, limit || 10);
  } catch (error: any) {
    logger.error("eventsTrending error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

// ============ GROUP FUNCTIONS ============

export const eventsGroupsCreate = onCall(async (request) => {
  try {
    return await createAttendanceGroup(request.data, request);
  } catch (error: any) {
    logger.error("eventsGroupsCreate error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsGroupsInvite = onCall(async (request) => {
  try {
    await inviteFriendsToGroup(request.data, request);
    return { success: true };
  } catch (error: any) {
    logger.error("eventsGroupsInvite error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsGroupsRsvp = onCall(async (request) => {
  try {
    await updateRSVP(request.data, request);
    return { success: true };
  } catch (error: any) {
    logger.error("eventsGroupsRsvp error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsGroupsLeave = onCall(async (request) => {
  try {
    await leaveGroup(request.data, request);
    return { success: true };
  } catch (error: any) {
    logger.error("eventsGroupsLeave error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsGroupsGet = onCall(async (request) => {
  try {
    const { groupId } = request.data;
    if (!groupId) {
      throw new HttpsError("invalid-argument", "groupId is required");
    }
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    return await getGroupDetails(groupId, request.auth.uid);
  } catch (error: any) {
    logger.error("eventsGroupsGet error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

// ============ TICKET/ORDER FUNCTIONS ============

export const eventsOrdersCreate = onCall(async (request) => {
  try {
    return await createTicketOrder(request.data, request);
  } catch (error: any) {
    logger.error("eventsOrdersCreate error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsTicketsLink = onCall(async (request) => {
  try {
    return await linkExternalTickets(request.data, request);
  } catch (error: any) {
    logger.error("eventsTicketsLink error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsOrdersConfirm = onCall(async (request) => {
  try {
    const { orderId } = request.data;
    if (!orderId) {
      throw new HttpsError("invalid-argument", "orderId is required");
    }
    return await confirmOrder(orderId);
  } catch (error: any) {
    logger.error("eventsOrdersConfirm error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsOrdersCancel = onCall(async (request) => {
  try {
    await cancelOrder(request.data, request);
    return { success: true };
  } catch (error: any) {
    logger.error("eventsOrdersCancel error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

// ============ SPLIT PAYMENT FUNCTIONS ============

export const eventsSplitsCreateIntent = onCall(async (request) => {
  try {
    return await createSplitIntent(request.data, request);
  } catch (error: any) {
    logger.error("eventsSplitsCreateIntent error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsSplitsPay = onCall(async (request) => {
  try {
    return await paySplit(request.data, request);
  } catch (error: any) {
    logger.error("eventsSplitsPay error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsSplitsStatus = onCall(async (request) => {
  try {
    const { splitId } = request.data;
    if (!splitId) {
      throw new HttpsError("invalid-argument", "splitId is required");
    }
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    return await getSplitStatus(splitId, request.auth.uid);
  } catch (error: any) {
    logger.error("eventsSplitsStatus error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

// ============ NOTIFICATION FUNCTIONS ============

export const eventsNotificationsMarkRead = onCall(async (request) => {
  try {
    const { notificationId } = request.data;
    if (!notificationId) {
      throw new HttpsError("invalid-argument", "notificationId is required");
    }
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    await markNotificationRead(notificationId, request.auth.uid);
    return { success: true };
  } catch (error: any) {
    logger.error("eventsNotificationsMarkRead error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

// ============ FRIENDS & SOCIAL FUNCTIONS ============

export const eventsFriendsGet = onCall(async (request) => {
  try {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    return await getFriends(request.auth.uid);
  } catch (error: any) {
    logger.error("eventsFriendsGet error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsFriendActivityGet = onCall(async (request) => {
  try {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    const { limit } = request.data || {};
    return await getFriendActivity(request.auth.uid, limit);
  } catch (error: any) {
    logger.error("eventsFriendActivityGet error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsWithFriendsGet = onCall(async (request) => {
  try {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    const { eventIds } = request.data;
    if (!eventIds || !Array.isArray(eventIds)) {
      throw new HttpsError("invalid-argument", "eventIds array is required");
    }
    return await getEventsWithFriends(request.auth.uid, eventIds);
  } catch (error: any) {
    logger.error("eventsWithFriendsGet error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsInviteSend = onCall(async (request) => {
  try {
    await sendEventInvite(request.data, request);
    return { success: true };
  } catch (error: any) {
    logger.error("eventsInviteSend error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsInvitesGet = onCall(async (request) => {
  try {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    return await getEventInvites(request.auth.uid);
  } catch (error: any) {
    logger.error("eventsInvitesGet error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsInviteRespond = onCall(async (request) => {
  try {
    await respondToInvite(request.data, request);
    return { success: true };
  } catch (error: any) {
    logger.error("eventsInviteRespond error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

// ============ CHAT FUNCTIONS ============

export const eventsGroupChatIdGet = onCall(async (request) => {
  try {
    const { groupId } = request.data;
    if (!groupId) {
      throw new HttpsError("invalid-argument", "groupId is required");
    }
    return { chatId: await getGroupChatId(groupId) };
  } catch (error: any) {
    logger.error("eventsGroupChatIdGet error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsGroupChatCreate = onCall(async (request) => {
  try {
    const chatId = await createGroupChat(request.data, request);
    return { chatId };
  } catch (error: any) {
    logger.error("eventsGroupChatCreate error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsGroupMessageSend = onCall(async (request) => {
  try {
    await sendGroupMessage(request.data, request);
    return { success: true };
  } catch (error: any) {
    logger.error("eventsGroupMessageSend error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsGroupMessagesGet = onCall(async (request) => {
  try {
    return await getGroupMessages(request.data, request);
  } catch (error: any) {
    logger.error("eventsGroupMessagesGet error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsGroupMessagesMarkRead = onCall(async (request) => {
  try {
    await markMessagesRead(request.data, request);
    return { success: true };
  } catch (error: any) {
    logger.error("eventsGroupMessagesMarkRead error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

// ============ RIDE INTEGRATION FUNCTIONS ============

export const eventsRideQuoteGet = onCall(async (request) => {
  try {
    return await getRideQuote(request.data, request);
  } catch (error: any) {
    logger.error("eventsRideQuoteGet error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsRideBook = onCall(async (request) => {
  try {
    return await bookEventRide(request.data, request);
  } catch (error: any) {
    logger.error("eventsRideBook error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsRideBookingsGet = onCall(async (request) => {
  try {
    const { eventId } = request.data;
    if (!eventId) {
      throw new HttpsError("invalid-argument", "eventId is required");
    }
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    return await getEventRideBookings(eventId, request.auth.uid);
  } catch (error: any) {
    logger.error("eventsRideBookingsGet error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

// ============ PROMOTER PORTAL FUNCTIONS ============

export const eventsPromoterApply = onCall(async (request) => {
  try {
    return await applyForPromoterStatus(request.data, request);
  } catch (error: any) {
    logger.error("eventsPromoterApply error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsPromoterApplicationStatusGet = onCall(async (request) => {
  try {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    return await getPromoterApplicationStatus(request.auth.uid);
  } catch (error: any) {
    logger.error("eventsPromoterApplicationStatusGet error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsPromoterEventDraftCreate = onCall(async (request) => {
  try {
    return await createEventDraft(request.data, request);
  } catch (error: any) {
    logger.error("eventsPromoterEventDraftCreate error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsPromoterEventDraftUpdate = onCall(async (request) => {
  try {
    const { eventId, ...updates } = request.data;
    if (!eventId) {
      throw new HttpsError("invalid-argument", "eventId is required");
    }
    await updateEventDraft(eventId, updates, request);
    return { success: true };
  } catch (error: any) {
    logger.error("eventsPromoterEventDraftUpdate error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsPromoterEventSubmitForReview = onCall(async (request) => {
  try {
    const { eventId } = request.data;
    if (!eventId) {
      throw new HttpsError("invalid-argument", "eventId is required");
    }
    await submitEventForReview(eventId, request);
    return { success: true };
  } catch (error: any) {
    logger.error("eventsPromoterEventSubmitForReview error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsPromoterEventsGet = onCall(async (request) => {
  try {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    const { status } = request.data || {};
    return await getPromoterEvents(request.auth.uid, status);
  } catch (error: any) {
    logger.error("eventsPromoterEventsGet error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsPromoterMetricsGet = onCall(async (request) => {
  try {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    const { timeRange } = request.data || {};
    const parsedTimeRange = timeRange ? {
      start: new Date(timeRange.start),
      end: new Date(timeRange.end)
    } : undefined;
    return await getPromoterMetrics(request.auth.uid, parsedTimeRange);
  } catch (error: any) {
    logger.error("eventsPromoterMetricsGet error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

// ============ EXTERNAL TICKET PROVIDER FUNCTIONS ============

export const eventsExternalProviderConnect = onCall(async (request) => {
  try {
    return await connectExternalProvider(request.data, request);
  } catch (error: any) {
    logger.error("eventsExternalProviderConnect error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsExternalEventsSync = onCall(async (request) => {
  try {
    const { integrationId } = request.data;
    if (!integrationId) {
      throw new HttpsError("invalid-argument", "integrationId is required");
    }
    return await syncExternalEvents(integrationId, request);
  } catch (error: any) {
    logger.error("eventsExternalEventsSync error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsExternalEventImport = onCall(async (request) => {
  try {
    return await importExternalEvent(request.data, request);
  } catch (error: any) {
    logger.error("eventsExternalEventImport error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsExternalOrdersSync = onCall(async (request) => {
  try {
    return await syncExternalOrders(request.data, request);
  } catch (error: any) {
    logger.error("eventsExternalOrdersSync error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsExternalWebhook = onCall(async (request) => {
  try {
    const { provider, payload, signature } = request.data;
    if (!provider || !payload) {
      throw new HttpsError("invalid-argument", "provider and payload are required");
    }
    await handleExternalWebhook(provider, payload, signature);
    return { success: true };
  } catch (error: any) {
    logger.error("eventsExternalWebhook error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

// ============ AI ASSISTANT FUNCTIONS ============

import { processAIQuery } from "./ai_orchestrator";

// Export scheduled functions
export * from "./scheduled_functions";

export const eventsAiAnswer = onCall(async (request) => {
  try {
    const { query, context, conversationId } = request.data;
    if (!query) {
      throw new HttpsError("invalid-argument", "query is required");
    }

    return await processAIQuery({ query, context, conversationId }, request);
  } catch (error: any) {
    logger.error("eventsAiAnswer error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

export const eventsAiCreateWatcher = onCall(async (request) => {
  try {
    const { criteria } = request.data;
    if (!criteria) {
      throw new HttpsError("invalid-argument", "criteria is required");
    }
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    // Create alert/watcher document
    const alertId = `alert_${Date.now()}`;
    // TODO: Store in database and set up monitoring
    
    return alertId;
  } catch (error: any) {
    logger.error("eventsAiCreateWatcher error", { error: error.message });
    throw new HttpsError("internal", error.message);
  }
});

// Helper function for MVP AI responses
function generateSimpleAIResponse(query: string): string {
  const lowerQuery = query.toLowerCase();
  
  if (lowerQuery.includes("jazz") || lowerQuery.includes("music")) {
    return "I found several jazz and music events happening this week. Jazz nights are popular in Casablanca, especially at venues like Blue Note and Le Studio.";
  }
  
  if (lowerQuery.includes("family") || lowerQuery.includes("kids")) {
    return "Here are some family-friendly events perfect for kids and parents. These activities are designed to be engaging for all ages.";
  }
  
  if (lowerQuery.includes("weekend") || lowerQuery.includes("saturday") || lowerQuery.includes("sunday")) {
    return "This weekend has some great events lined up! I've found activities ranging from cultural events to outdoor concerts.";
  }
  
  if (lowerQuery.includes("cheap") || lowerQuery.includes("budget") || lowerQuery.includes("free")) {
    return "I've found several budget-friendly events for you. Many cultural centers and parks host free events, especially during weekends.";
  }
  
  return "I found several interesting events that might match what you're looking for. Let me show you some options based on your preferences.";
}