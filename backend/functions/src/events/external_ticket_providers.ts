import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import { CallableContext } from "firebase-functions/v2/https";
import {
  ExternalTicketProvider,
  ExternalTicketIntegration,
  ExternalTicketSync,
  ExternalTicketOrder,
  TicketProviderType
} from "./types";

const db = admin.firestore();

/**
 * Connect external ticket provider
 */
export async function connectExternalProvider(
  data: {
    provider: TicketProviderType;
    apiKey?: string;
    accessToken?: string;
    organizationId?: string;
    webhookSecret?: string;
  },
  context: CallableContext
): Promise<{ integrationId: string }> {
  try {
    const userId = context.auth?.uid;
    if (!userId) {
      throw new Error("Authentication required");
    }

    // Validate provider credentials
    await validateProviderCredentials(data.provider, {
      apiKey: data.apiKey,
      accessToken: data.accessToken,
      organizationId: data.organizationId
    });

    const integrationId = `integration_${Date.now()}_${userId.substr(0, 8)}`;
    
    const integration: ExternalTicketIntegration = {
      id: integrationId,
      userId,
      provider: data.provider,
      credentials: {
        apiKey: data.apiKey,
        accessToken: data.accessToken,
        organizationId: data.organizationId,
        webhookSecret: data.webhookSecret
      },
      status: "active",
      lastSync: null,
      createdAt: new Date(),
      updatedAt: new Date()
    };

    await db.collection("externalTicketIntegrations").doc(integrationId).set({
      ...integration,
      // Don't store raw credentials - encrypt or use secure storage
      credentials: await encryptCredentials(integration.credentials),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    logger.info("External provider connected", { integrationId, provider: data.provider });
    return { integrationId };
  } catch (error: any) {
    logger.error("Failed to connect external provider", { error: error.message });
    throw error;
  }
}

/**
 * Sync events from external provider
 */
export async function syncExternalEvents(
  integrationId: string,
  context: CallableContext
): Promise<{ syncId: string; eventCount: number }> {
  try {
    const userId = context.auth?.uid;
    if (!userId) {
      throw new Error("Authentication required");
    }

    // Get integration
    const integrationDoc = await db.collection("externalTicketIntegrations").doc(integrationId).get();
    if (!integrationDoc.exists) {
      throw new Error("Integration not found");
    }

    const integration = {
      id: integrationDoc.id,
      ...integrationDoc.data(),
      createdAt: integrationDoc.data()!.createdAt.toDate(),
      updatedAt: integrationDoc.data()!.updatedAt.toDate()
    } as ExternalTicketIntegration;

    if (integration.userId !== userId) {
      throw new Error("Not authorized to sync this integration");
    }

    const syncId = `sync_${Date.now()}_${integrationId}`;
    
    // Create sync record
    const sync: ExternalTicketSync = {
      id: syncId,
      integrationId,
      provider: integration.provider,
      status: "running",
      startedAt: new Date(),
      completedAt: null,
      eventsProcessed: 0,
      errors: []
    };

    await db.collection("externalTicketSyncs").doc(syncId).set({
      ...sync,
      startedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Perform sync based on provider
    const eventCount = await performProviderSync(integration, syncId);

    // Update sync status
    await db.collection("externalTicketSyncs").doc(syncId).update({
      status: "completed",
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      eventsProcessed: eventCount
    });

    // Update integration last sync
    await db.collection("externalTicketIntegrations").doc(integrationId).update({
      lastSync: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    logger.info("External events sync completed", { syncId, eventCount });
    return { syncId, eventCount };
  } catch (error: any) {
    logger.error("Failed to sync external events", { error: error.message });
    throw error;
  }
}

/**
 * Import specific event from external provider
 */
export async function importExternalEvent(
  data: {
    integrationId: string;
    externalEventId: string;
    importTickets?: boolean;
  },
  context: CallableContext
): Promise<{ eventId: string }> {
  try {
    const userId = context.auth?.uid;
    if (!userId) {
      throw new Error("Authentication required");
    }

    // Get integration
    const integrationDoc = await db.collection("externalTicketIntegrations").doc(data.integrationId).get();
    if (!integrationDoc.exists) {
      throw new Error("Integration not found");
    }

    const integration = {
      id: integrationDoc.id,
      ...integrationDoc.data()
    } as ExternalTicketIntegration;

    if (integration.userId !== userId) {
      throw new Error("Not authorized to use this integration");
    }

    // Fetch event from external provider
    const externalEvent = await fetchEventFromProvider(
      integration.provider,
      await decryptCredentials(integration.credentials),
      data.externalEventId
    );

    // Convert to internal event format
    const eventId = `external_${integration.provider}_${data.externalEventId}`;
    const event = await convertExternalEvent(externalEvent, integration.provider);

    // Save event
    await db.collection("events").doc(eventId).set({
      ...event,
      id: eventId,
      promoterId: userId,
      externalProvider: integration.provider,
      externalEventId: data.externalEventId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Import tickets if requested
    if (data.importTickets) {
      await importEventTickets(eventId, integration, data.externalEventId);
    }

    logger.info("External event imported", { eventId, provider: integration.provider });
    return { eventId };
  } catch (error: any) {
    logger.error("Failed to import external event", { error: error.message });
    throw error;
  }
}

/**
 * Sync ticket orders from external provider
 */
export async function syncExternalOrders(
  data: {
    integrationId: string;
    eventId: string;
  },
  context: CallableContext
): Promise<{ orderCount: number }> {
  try {
    const userId = context.auth?.uid;
    if (!userId) {
      throw new Error("Authentication required");
    }

    // Get integration and event
    const [integrationDoc, eventDoc] = await Promise.all([
      db.collection("externalTicketIntegrations").doc(data.integrationId).get(),
      db.collection("events").doc(data.eventId).get()
    ]);

    if (!integrationDoc.exists || !eventDoc.exists) {
      throw new Error("Integration or event not found");
    }

    const integration = integrationDoc.data() as ExternalTicketIntegration;
    const event = eventDoc.data();

    if (integration.userId !== userId) {
      throw new Error("Not authorized to use this integration");
    }

    if (!event!.externalEventId) {
      throw new Error("Event is not linked to external provider");
    }

    // Fetch orders from external provider
    const externalOrders = await fetchOrdersFromProvider(
      integration.provider,
      await decryptCredentials(integration.credentials),
      event!.externalEventId
    );

    // Convert and save orders
    let orderCount = 0;
    const batch = db.batch();

    for (const externalOrder of externalOrders) {
      const orderId = `external_order_${integration.provider}_${externalOrder.id}`;
      const convertedOrder = await convertExternalOrder(externalOrder, data.eventId, integration.provider);
      
      const orderRef = db.collection("externalTicketOrders").doc(orderId);
      batch.set(orderRef, {
        ...convertedOrder,
        id: orderId,
        eventId: data.eventId,
        provider: integration.provider,
        externalOrderId: externalOrder.id,
        syncedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      orderCount++;
    }

    if (orderCount > 0) {
      await batch.commit();
    }

    logger.info("External orders synced", { eventId: data.eventId, orderCount });
    return { orderCount };
  } catch (error: any) {
    logger.error("Failed to sync external orders", { error: error.message });
    throw error;
  }
}

/**
 * Handle webhook from external provider
 */
export async function handleExternalWebhook(
  provider: TicketProviderType,
  payload: any,
  signature: string
): Promise<void> {
  try {
    // Verify webhook signature
    const integration = await findIntegrationByProvider(provider);
    if (!integration) {
      throw new Error(`No integration found for provider: ${provider}`);
    }

    const isValid = await verifyWebhookSignature(
      provider,
      payload,
      signature,
      integration.credentials.webhookSecret
    );

    if (!isValid) {
      throw new Error("Invalid webhook signature");
    }

    // Process webhook based on provider and event type
    await processWebhookPayload(provider, payload, integration);

    logger.info("External webhook processed", { provider });
  } catch (error: any) {
    logger.error("Failed to handle external webhook", { error: error.message });
    throw error;
  }
}

// Provider-specific implementations

async function performProviderSync(
  integration: ExternalTicketIntegration,
  syncId: string
): Promise<number> {
  const credentials = await decryptCredentials(integration.credentials);
  
  switch (integration.provider) {
    case TicketProviderType.EVENTBRITE:
      return await syncEventbriteEvents(credentials, syncId);
    case TicketProviderType.TICKETMASTER:
      return await syncTicketmasterEvents(credentials, syncId);
    case TicketProviderType.UNIVERSE:
      return await syncUniverseEvents(credentials, syncId);
    case TicketProviderType.BILLETTO:
      return await syncBillettoEvents(credentials, syncId);
    default:
      throw new Error(`Unsupported provider: ${integration.provider}`);
  }
}

async function syncEventbriteEvents(credentials: any, syncId: string): Promise<number> {
  try {
    // Eventbrite API integration
    const response = await fetch(`https://www.eventbriteapi.com/v3/users/me/events/`, {
      headers: {
        'Authorization': `Bearer ${credentials.accessToken}`,
        'Content-Type': 'application/json'
      }
    });

    if (!response.ok) {
      throw new Error(`Eventbrite API error: ${response.status}`);
    }

    const data = await response.json();
    const events = data.events || [];

    // Process each event
    for (const event of events) {
      await processEventbriteEvent(event, syncId);
    }

    return events.length;
  } catch (error: any) {
    logger.error("Failed to sync Eventbrite events", { error: error.message });
    throw error;
  }
}

async function syncTicketmasterEvents(credentials: any, syncId: string): Promise<number> {
  try {
    // Ticketmaster API integration
    const response = await fetch(`https://app.ticketmaster.com/discovery/v2/events.json?apikey=${credentials.apiKey}&size=200`, {
      headers: {
        'Content-Type': 'application/json'
      }
    });

    if (!response.ok) {
      throw new Error(`Ticketmaster API error: ${response.status}`);
    }

    const data = await response.json();
    const events = data._embedded?.events || [];

    // Process each event
    for (const event of events) {
      await processTicketmasterEvent(event, syncId);
    }

    return events.length;
  } catch (error: any) {
    logger.error("Failed to sync Ticketmaster events", { error: error.message });
    throw error;
  }
}

async function syncUniverseEvents(credentials: any, syncId: string): Promise<number> {
  try {
    // Universe API integration
    const response = await fetch(`https://www.universe.com/api/v2/events`, {
      headers: {
        'Authorization': `Bearer ${credentials.accessToken}`,
        'Content-Type': 'application/json'
      }
    });

    if (!response.ok) {
      throw new Error(`Universe API error: ${response.status}`);
    }

    const data = await response.json();
    const events = data.events || [];

    // Process each event
    for (const event of events) {
      await processUniverseEvent(event, syncId);
    }

    return events.length;
  } catch (error: any) {
    logger.error("Failed to sync Universe events", { error: error.message });
    throw error;
  }
}

async function syncBillettoEvents(credentials: any, syncId: string): Promise<number> {
  try {
    // Billetto API integration
    const response = await fetch(`https://billetto.com/api/v1/events`, {
      headers: {
        'Authorization': `Bearer ${credentials.accessToken}`,
        'Content-Type': 'application/json'
      }
    });

    if (!response.ok) {
      throw new Error(`Billetto API error: ${response.status}`);
    }

    const data = await response.json();
    const events = data.events || [];

    // Process each event
    for (const event of events) {
      await processBillettoEvent(event, syncId);
    }

    return events.length;
  } catch (error: any) {
    logger.error("Failed to sync Billetto events", { error: error.message });
    throw error;
  }
}

// Helper functions

async function validateProviderCredentials(
  provider: TicketProviderType,
  credentials: any
): Promise<void> {
  switch (provider) {
    case TicketProviderType.EVENTBRITE:
      if (!credentials.accessToken) {
        throw new Error("Eventbrite access token is required");
      }
      // Test API call
      const response = await fetch(`https://www.eventbriteapi.com/v3/users/me/`, {
        headers: { 'Authorization': `Bearer ${credentials.accessToken}` }
      });
      if (!response.ok) {
        throw new Error("Invalid Eventbrite credentials");
      }
      break;
      
    case TicketProviderType.TICKETMASTER:
      if (!credentials.apiKey) {
        throw new Error("Ticketmaster API key is required");
      }
      break;
      
    default:
      throw new Error(`Validation not implemented for provider: ${provider}`);
  }
}

async function encryptCredentials(credentials: any): Promise<any> {
  // In production, implement proper encryption
  // For now, just return as-is (would use Google KMS or similar)
  return credentials;
}

async function decryptCredentials(credentials: any): Promise<any> {
  // In production, implement proper decryption
  return credentials;
}

async function fetchEventFromProvider(
  provider: TicketProviderType,
  credentials: any,
  externalEventId: string
): Promise<any> {
  switch (provider) {
    case TicketProviderType.EVENTBRITE:
      const response = await fetch(`https://www.eventbriteapi.com/v3/events/${externalEventId}/`, {
        headers: { 'Authorization': `Bearer ${credentials.accessToken}` }
      });
      return await response.json();
      
    default:
      throw new Error(`Fetch not implemented for provider: ${provider}`);
  }
}

async function convertExternalEvent(externalEvent: any, provider: TicketProviderType): Promise<any> {
  // Convert external event format to internal Event format
  // This would be provider-specific
  const baseEvent = {
    title: externalEvent.name?.text || externalEvent.title || "Imported Event",
    description: externalEvent.description?.text || externalEvent.description || "",
    status: "published",
    // More conversion logic based on provider...
  };

  return baseEvent;
}

async function convertExternalOrder(
  externalOrder: any,
  eventId: string,
  provider: TicketProviderType
): Promise<ExternalTicketOrder> {
  return {
    id: `external_${provider}_${externalOrder.id}`,
    eventId,
    provider,
    externalOrderId: externalOrder.id,
    customerEmail: externalOrder.email || externalOrder.attendee?.email,
    customerName: externalOrder.name || externalOrder.attendee?.name,
    totalAmount: parseFloat(externalOrder.total || externalOrder.cost?.total || "0"),
    currency: externalOrder.currency || "MAD",
    status: mapExternalOrderStatus(externalOrder.status, provider),
    ticketCount: parseInt(externalOrder.quantity || "1"),
    purchaseDate: new Date(externalOrder.created || externalOrder.purchase_date || Date.now()),
    syncedAt: new Date()
  };
}

function mapExternalOrderStatus(externalStatus: string, provider: TicketProviderType): string {
  // Map external provider status to internal status
  const statusMap: { [key: string]: string } = {
    // Eventbrite
    "placed": "confirmed",
    "refunded": "cancelled",
    
    // Ticketmaster
    "confirmed": "confirmed",
    "cancelled": "cancelled",
    
    // Default
    "default": "pending"
  };

  return statusMap[externalStatus] || "pending";
}

async function findIntegrationByProvider(provider: TicketProviderType): Promise<ExternalTicketIntegration | null> {
  const snapshot = await db.collection("externalTicketIntegrations")
    .where("provider", "==", provider)
    .where("status", "==", "active")
    .limit(1)
    .get();

  if (snapshot.empty) {
    return null;
  }

  const doc = snapshot.docs[0];
  return {
    id: doc.id,
    ...doc.data()
  } as ExternalTicketIntegration;
}

async function verifyWebhookSignature(
  provider: TicketProviderType,
  payload: any,
  signature: string,
  secret?: string
): Promise<boolean> {
  // Implement provider-specific signature verification
  // This is crucial for security
  return true; // Placeholder
}

async function processWebhookPayload(
  provider: TicketProviderType,
  payload: any,
  integration: ExternalTicketIntegration
): Promise<void> {
  // Process webhook events like order updates, event changes, etc.
  logger.info("Processing webhook payload", { provider, type: payload.type });
}

// Event processing functions
async function processEventbriteEvent(event: any, syncId: string): Promise<void> {
  // Process individual Eventbrite event
  logger.info("Processing Eventbrite event", { eventId: event.id, syncId });
}

async function processTicketmasterEvent(event: any, syncId: string): Promise<void> {
  // Process individual Ticketmaster event
  logger.info("Processing Ticketmaster event", { eventId: event.id, syncId });
}

async function processUniverseEvent(event: any, syncId: string): Promise<void> {
  // Process individual Universe event
  logger.info("Processing Universe event", { eventId: event.id, syncId });
}

async function processBillettoEvent(event: any, syncId: string): Promise<void> {
  // Process individual Billetto event
  logger.info("Processing Billetto event", { eventId: event.id, syncId });
}

async function importEventTickets(
  eventId: string,
  integration: ExternalTicketIntegration,
  externalEventId: string
): Promise<void> {
  // Import ticket tiers and availability from external provider
  logger.info("Importing event tickets", { eventId, provider: integration.provider });
}

async function fetchOrdersFromProvider(
  provider: TicketProviderType,
  credentials: any,
  externalEventId: string
): Promise<any[]> {
  // Fetch orders from external provider
  return [];
}