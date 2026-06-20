import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import { CallableContext } from "firebase-functions/v2/https";
import { searchEvents } from "./search";
import { createAttendanceGroup } from "./groups";
import { createTicketOrder } from "./tickets";
import { createSplitIntent } from "./splitPayments";
import {
  Event,
  EventFilters,
  EventCategory,
  UserTraits,
  ConsentGrant,
  ConsentScope,
  AttendanceGroupDraft,
  TicketOrderRequest,
  SplitIntentRequest,
  ShareType
} from "./types";

const db = admin.firestore();

// AI Tool definitions
interface AITool {
  name: string;
  description: string;
  parameters: {
    type: string;
    properties: Record<string, any>;
    required: string[];
  };
}

const AI_TOOLS: AITool[] = [
  {
    name: "searchEvents",
    description: "Search for events based on user query with filters",
    parameters: {
      type: "object",
      properties: {
        query: { type: "string", description: "Search query text" },
        category: { type: "string", enum: Object.values(EventCategory) },
        priceMin: { type: "number", description: "Minimum price in MAD" },
        priceMax: { type: "number", description: "Maximum price in MAD" },
        dateFrom: { type: "string", format: "date" },
        dateTo: { type: "string", format: "date" },
        indoor: { type: "boolean", description: "Indoor events only" },
        limit: { type: "number", default: 10 }
      },
      required: ["query"]
    }
  },
  {
    name: "createAttendanceGroupTool",
    description: "Create an attendance group for an event",
    parameters: {
      type: "object",
      properties: {
        eventId: { type: "string", description: "Event ID" },
        groupName: { type: "string", description: "Name for the group" },
        inviteUserIds: { 
          type: "array", 
          items: { type: "string" },
          description: "User IDs to invite"
        }
      },
      required: ["eventId", "groupName"]
    }
  },
  {
    name: "proposeGroupSession",
    description: "Suggest optimal event sessions for a group based on availability",
    parameters: {
      type: "object",
      properties: {
        eventId: { type: "string", description: "Event ID" },
        groupSize: { type: "number", description: "Expected group size" },
        preferredTimes: {
          type: "array",
          items: { type: "string" },
          description: "Preferred time slots"
        }
      },
      required: ["eventId", "groupSize"]
    }
  },
  {
    name: "createTicketOrderTool",
    description: "Create a ticket order for a group",
    parameters: {
      type: "object",
      properties: {
        groupId: { type: "string", description: "Group ID" },
        eventId: { type: "string", description: "Event ID" },
        ticketTiers: {
          type: "array",
          items: {
            type: "object",
            properties: {
              tierName: { type: "string" },
              quantity: { type: "number" }
            }
          }
        }
      },
      required: ["groupId", "eventId", "ticketTiers"]
    }
  },
  {
    name: "requestRidePlan",
    description: "Get ride sharing options for an event",
    parameters: {
      type: "object",
      properties: {
        eventId: { type: "string", description: "Event ID" },
        origin: {
          type: "object",
          properties: {
            lat: { type: "number" },
            lng: { type: "number" }
          }
        },
        groupSize: { type: "number", description: "Number of people" }
      },
      required: ["eventId", "origin"]
    }
  },
  {
    name: "getUserTraitsScoped",
    description: "Get user preferences and traits with consent",
    parameters: {
      type: "object",
      properties: {
        scopes: {
          type: "array",
          items: { type: "string", enum: Object.values(ConsentScope) }
        }
      },
      required: ["scopes"]
    }
  }
];

/**
 * Advanced AI orchestrator with proper LLM integration
 */
export async function processAIQuery(
  data: {
    query: string;
    context?: { [key: string]: any };
    conversationId?: string;
  },
  context: CallableContext
): Promise<{
  answer: string;
  suggestedEvents: Event[];
  toolCalls?: any[];
  followUpPrompts: string[];
  reasonCodes: string[];
}> {
  try {
    if (!context.auth?.uid) {
      throw new Error("Authentication required");
    }

    const userId = context.auth.uid;
    const query = data.query.trim();
    
    // Get user traits and consent
    const userTraits = await getUserTraits(userId);
    const hasPersonalizationConsent = await checkUserConsent(userId, ConsentScope.PERSONALIZATION);
    const hasSocialConsent = await checkUserConsent(userId, ConsentScope.SOCIAL_SIGNALS);

    // Build enhanced context
    const enhancedContext = {
      userId,
      userTraits: hasPersonalizationConsent ? userTraits : null,
      socialSignals: hasSocialConsent,
      location: data.context?.location,
      timestamp: new Date().toISOString(),
      conversationId: data.conversationId
    };

    // Process with LLM (using OpenAI-compatible interface)
    const llmResponse = await callLLM(query, enhancedContext);
    
    // Execute any tool calls
    const toolResults = await executeToolCalls(llmResponse.toolCalls || [], context);
    
    // Generate final response
    const finalAnswer = await generateFinalResponse(query, llmResponse, toolResults);
    
    // Extract suggested events from tool results
    const suggestedEvents = extractEventsFromToolResults(toolResults);
    
    // Generate follow-up prompts
    const followUpPrompts = generateFollowUpPrompts(query, suggestedEvents, userTraits);
    
    // Generate reason codes
    const reasonCodes = generateReasonCodes(query, toolResults, userTraits);

    // Store conversation for future context
    if (data.conversationId) {
      await storeConversationTurn(data.conversationId, userId, query, finalAnswer);
    }

    logger.info("AI query processed", {
      userId,
      query: query.substring(0, 100),
      toolCallCount: llmResponse.toolCalls?.length || 0,
      eventsFound: suggestedEvents.length
    });

    return {
      answer: finalAnswer,
      suggestedEvents,
      toolCalls: llmResponse.toolCalls,
      followUpPrompts,
      reasonCodes
    };

  } catch (error: any) {
    logger.error("AI orchestrator failed", { 
      error: error.message,
      userId: context.auth?.uid 
    });
    
    // Fallback to simple response
    return {
      answer: "I'm sorry, I'm having trouble processing your request right now. Please try asking about specific events or categories.",
      suggestedEvents: [],
      followUpPrompts: [
        "Show me upcoming events",
        "Find music events this weekend", 
        "Help me plan an outing"
      ],
      reasonCodes: ["fallback_response"]
    };
  }
}

/**
 * Call LLM with function calling capabilities
 */
async function callLLM(
  query: string,
  context: any
): Promise<{
  content: string;
  toolCalls?: Array<{
    function: {
      name: string;
      arguments: string;
    };
  }>;
}> {
  // In production, this would call OpenAI GPT-4 or similar
  // For MVP, implementing rule-based response with some intelligence
  
  const lowerQuery = query.toLowerCase();
  const toolCalls: any[] = [];
  
  // Detect search intent
  if (lowerQuery.includes("find") || lowerQuery.includes("search") || lowerQuery.includes("show")) {
    const searchParams: any = { query: query.substring(0, 100) };
    
    // Extract category
    for (const category of Object.values(EventCategory)) {
      if (lowerQuery.includes(category)) {
        searchParams.category = category;
        break;
      }
    }
    
    // Extract price hints
    const priceMatches = lowerQuery.match(/(\d+)\s*(?:mad|dirham|dh)/gi);
    if (priceMatches) {
      const prices = priceMatches.map(m => parseInt(m));
      searchParams.priceMax = Math.max(...prices);
    }
    
    // Extract time hints
    if (lowerQuery.includes("today")) {
      searchParams.dateFrom = new Date().toISOString().split('T')[0];
      searchParams.dateTo = new Date().toISOString().split('T')[0];
    } else if (lowerQuery.includes("weekend") || lowerQuery.includes("saturday") || lowerQuery.includes("sunday")) {
      const now = new Date();
      const saturday = new Date(now);
      saturday.setDate(now.getDate() + (6 - now.getDay()));
      const sunday = new Date(saturday);
      sunday.setDate(saturday.getDate() + 1);
      
      searchParams.dateFrom = saturday.toISOString().split('T')[0];
      searchParams.dateTo = sunday.toISOString().split('T')[0];
    }
    
    // Extract indoor/outdoor preference
    if (lowerQuery.includes("indoor") && !lowerQuery.includes("outdoor")) {
      searchParams.indoor = true;
    }
    
    toolCalls.push({
      function: {
        name: "searchEvents",
        arguments: JSON.stringify(searchParams)
      }
    });
  }
  
  // Detect group creation intent
  if (lowerQuery.includes("create group") || lowerQuery.includes("plan together") || lowerQuery.includes("invite friends")) {
    // This would require more context about which event
    const groupParams = {
      eventId: context.lastEventId || "pending",
      groupName: extractGroupName(query) || "Event Group"
    };
    
    toolCalls.push({
      function: {
        name: "createAttendanceGroupTool", 
        arguments: JSON.stringify(groupParams)
      }
    });
  }
  
  // Detect ride planning intent
  if (lowerQuery.includes("ride") || lowerQuery.includes("transport") || lowerQuery.includes("how to get")) {
    if (context.location) {
      const rideParams = {
        eventId: context.lastEventId || "pending",
        origin: context.location,
        groupSize: 2 // Default assumption
      };
      
      toolCalls.push({
        function: {
          name: "requestRidePlan",
          arguments: JSON.stringify(rideParams)
        }
      });
    }
  }

  // Generate contextual response
  let content = generateContextualResponse(query, context, toolCalls);
  
  return { content, toolCalls: toolCalls.length > 0 ? toolCalls : undefined };
}

/**
 * Execute tool calls and return results
 */
async function executeToolCalls(
  toolCalls: any[], 
  context: CallableContext
): Promise<Array<{ toolName: string; result: any }>> {
  const results = [];
  
  for (const toolCall of toolCalls) {
    try {
      const toolName = toolCall.function.name;
      const args = JSON.parse(toolCall.function.arguments);
      
      let result;
      switch (toolName) {
        case "searchEvents":
          const filters: EventFilters = {
            categories: args.category ? [args.category] : undefined,
            priceRange: args.priceMin || args.priceMax ? {
              min: args.priceMin || 0,
              max: args.priceMax || 10000
            } : undefined,
            dateRange: args.dateFrom || args.dateTo ? {
              from: args.dateFrom || new Date().toISOString().split('T')[0],
              to: args.dateTo || new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]
            } : undefined,
            indoor: args.indoor
          };
          
          result = await searchEvents({
            query: args.query,
            filters,
            userId: context.auth?.uid,
            limit: args.limit || 10
          }, context);
          break;
          
        case "createAttendanceGroupTool":
          if (args.eventId !== "pending") {
            const draft: AttendanceGroupDraft = {
              eventId: args.eventId,
              name: args.groupName,
              invitedUserIds: args.inviteUserIds || []
            };
            result = await createAttendanceGroup(draft, context);
          } else {
            result = { pending: true, message: "Please specify which event first" };
          }
          break;
          
        case "proposeGroupSession":
          result = await proposeOptimalSessions(args.eventId, args.groupSize, args.preferredTimes);
          break;
          
        case "requestRidePlan":
          result = await generateRideOptions(args.eventId, args.origin, args.groupSize);
          break;
          
        case "getUserTraitsScoped":
          result = await getUserTraitsWithConsent(context.auth?.uid!, args.scopes);
          break;
          
        default:
          logger.warn("Unknown tool called", { toolName });
          result = { error: "Unknown tool" };
      }
      
      results.push({ toolName, result });
      
    } catch (error: any) {
      logger.error("Tool execution failed", { 
        tool: toolCall.function.name, 
        error: error.message 
      });
      results.push({ 
        toolName: toolCall.function.name, 
        result: { error: error.message } 
      });
    }
  }
  
  return results;
}

/**
 * Generate final response combining LLM and tool results
 */
async function generateFinalResponse(
  query: string,
  llmResponse: any,
  toolResults: any[]
): Promise<string> {
  let response = llmResponse.content;
  
  // Enhance response with tool results
  for (const toolResult of toolResults) {
    switch (toolResult.toolName) {
      case "searchEvents":
        const events = toolResult.result.events || [];
        if (events.length > 0) {
          response += `\n\nI found ${events.length} events that match your criteria. The top recommendations include venues like ${events.slice(0, 3).map((e: Event) => e.venueName).join(", ")}.`;
        } else {
          response += "\n\nI couldn't find any events matching those criteria. Try broadening your search or checking different dates.";
        }
        break;
        
      case "createAttendanceGroupTool":
        if (!toolResult.result.error && !toolResult.result.pending) {
          response += `\n\nI've created your group "${toolResult.result.name}" and you can now invite friends to join!`;
        }
        break;
        
      case "requestRidePlan":
        if (toolResult.result.options?.length > 0) {
          response += `\n\nFor transportation, I found ${toolResult.result.options.length} ride options with estimated costs from ${toolResult.result.minPrice}MAD.`;
        }
        break;
    }
  }
  
  return response;
}

// Helper functions
function generateContextualResponse(query: string, context: any, toolCalls: any[]): string {
  const lowerQuery = query.toLowerCase();
  
  if (toolCalls.some(tc => tc.function.name === "searchEvents")) {
    return "Let me search for events that match what you're looking for...";
  }
  
  if (lowerQuery.includes("jazz")) {
    return "Jazz events are quite popular in Casablanca! Let me find some good options for you.";
  }
  
  if (lowerQuery.includes("family") || lowerQuery.includes("kids")) {
    return "I'll look for family-friendly events that are perfect for kids and adults alike.";
  }
  
  if (lowerQuery.includes("budget") || lowerQuery.includes("cheap")) {
    return "I understand you're looking for budget-friendly options. Let me find affordable events for you.";
  }
  
  return "I'll help you discover great events based on your preferences.";
}

function extractGroupName(query: string): string | null {
  const groupPatterns = [
    /create group called "([^"]+)"/i,
    /group named "([^"]+)"/i,
    /call it "([^"]+)"/i
  ];
  
  for (const pattern of groupPatterns) {
    const match = query.match(pattern);
    if (match) return match[1];
  }
  
  return null;
}

function extractEventsFromToolResults(toolResults: any[]): Event[] {
  const events: Event[] = [];
  
  for (const result of toolResults) {
    if (result.toolName === "searchEvents" && result.result.events) {
      events.push(...result.result.events);
    }
  }
  
  return events.slice(0, 5); // Limit to top 5
}

function generateFollowUpPrompts(query: string, events: Event[], userTraits: UserTraits | null): string[] {
  const prompts = [];
  
  if (events.length > 0) {
    prompts.push("Create a group for one of these events");
    prompts.push("Find similar events");
    prompts.push("Check transportation options");
  }
  
  prompts.push("Find events this weekend");
  prompts.push("Show me concerts");
  prompts.push("Set up event alerts");
  
  return prompts.slice(0, 4);
}

function generateReasonCodes(query: string, toolResults: any[], userTraits: UserTraits | null): string[] {
  const codes = [];
  
  if (toolResults.some(r => r.toolName === "searchEvents")) {
    codes.push("event_search");
  }
  
  if (userTraits) {
    codes.push("personalized");
  }
  
  codes.push("ai_processed");
  
  return codes;
}

// Additional helper functions for tool implementations
async function proposeOptimalSessions(eventId: string, groupSize: number, preferredTimes?: string[]): Promise<any> {
  const sessionsSnapshot = await db.collection("eventSessions")
    .where("eventId", "==", eventId)
    .where("startAt", ">", admin.firestore.Timestamp.now())
    .orderBy("startAt")
    .get();
  
  const sessions = sessionsSnapshot.docs.map(doc => ({
    id: doc.id,
    ...doc.data()
  }));
  
  // Simple capacity check
  const suitableSessions = sessions.filter((session: any) => {
    const totalCapacity = Object.values(session.capacityByTier).reduce((sum: number, cap: any) => sum + cap, 0);
    const soldTickets = Object.values(session.soldByTier || {}).reduce((sum: number, sold: any) => sum + sold, 0);
    return (totalCapacity - soldTickets) >= groupSize;
  });
  
  return {
    suggestedSessions: suitableSessions.slice(0, 3),
    reasoning: `Found ${suitableSessions.length} sessions with adequate capacity for ${groupSize} people`
  };
}

async function generateRideOptions(eventId: string, origin: any, groupSize: number): Promise<any> {
  // This would integrate with the RideSharing service
  // For now, returning mock data
  return {
    options: [
      { type: "rideshare", estimatedCost: 25, duration: "15 mins" },
      { type: "taxi", estimatedCost: 40, duration: "12 mins" }
    ],
    minPrice: 25,
    deepLink: `liive://ride-sharing/request?destination=${eventId}&passengers=${groupSize}`
  };
}

async function getUserTraits(userId: string): Promise<UserTraits | null> {
  try {
    const doc = await db.collection("userTraits").doc(userId).get();
    return doc.exists ? doc.data() as UserTraits : null;
  } catch {
    return null;
  }
}

async function checkUserConsent(userId: string, scope: ConsentScope): Promise<boolean> {
  try {
    const snapshot = await db.collection("consentGrants")
      .where("userId", "==", userId)
      .where("scope", "==", scope)
      .where("granted", "==", true)
      .limit(1)
      .get();
    
    if (snapshot.empty) return false;
    
    const consent = snapshot.docs[0].data() as ConsentGrant;
    return !consent.revokedAt && (!consent.expiresAt || consent.expiresAt.toDate() > new Date());
  } catch {
    return false;
  }
}

async function getUserTraitsWithConsent(userId: string, scopes: ConsentScope[]): Promise<any> {
  const result: any = {};
  
  for (const scope of scopes) {
    const hasConsent = await checkUserConsent(userId, scope);
    if (hasConsent) {
      result[scope] = await getUserTraits(userId);
    }
  }
  
  return result;
}

async function storeConversationTurn(conversationId: string, userId: string, query: string, response: string): Promise<void> {
  try {
    await db.collection("conversations").doc(conversationId).collection("turns").add({
      userId,
      query,
      response,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
  } catch (error: any) {
    logger.error("Failed to store conversation", { error: error.message });
  }
}