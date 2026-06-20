import * as admin from "firebase-admin";
import { logger } from "firebase-functions/v2";

interface AnalyticsEvent {
  userId: string | null;
  name: string;
  metadata: Record<string, any>;
  createdAt: admin.firestore.FieldValue;
  category?: string;
  source?: string;
  platform?: string;
}

export async function logEvent(userId: string | null, name: string, metadata?: Record<string, any>): Promise<void> {
  try {
    const payload: AnalyticsEvent = {
      userId: userId || null,
      name,
      metadata: metadata || {},
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    await admin.firestore().collection("analyticsEvents").add(payload);
  } catch (e) {
    console.error("Failed to write analytics event", { name, error: (e as any)?.message });
  }
}

// Enhanced analytics service for marketplace
export const analytics = {
  async track(eventName: string, properties: Record<string, any> = {}): Promise<void> {
    try {
      const payload: AnalyticsEvent = {
        userId: properties.userId || properties.buyerId || properties.sellerId || null,
        name: eventName,
        metadata: {
          ...properties,
          timestamp: Date.now(),
          source: 'marketplace',
          platform: 'ios'
        },
        category: getEventCategory(eventName),
        source: 'marketplace',
        platform: 'ios',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      await admin.firestore().collection("analyticsEvents").add(payload);
      
      // Also log to console for debugging
      logger.info(`Analytics: ${eventName}`, properties);
      
    } catch (error: any) {
      logger.error("Failed to track analytics event", {
        eventName,
        properties,
        error: error.message
      });
    }
  },

  async batchTrack(events: Array<{ name: string; properties: Record<string, any> }>): Promise<void> {
    try {
      const batch = admin.firestore().batch();
      const collection = admin.firestore().collection("analyticsEvents");

      events.forEach(event => {
        const docRef = collection.doc();
        const payload: AnalyticsEvent = {
          userId: event.properties.userId || event.properties.buyerId || event.properties.sellerId || null,
          name: event.name,
          metadata: {
            ...event.properties,
            timestamp: Date.now(),
            source: 'marketplace',
            platform: 'ios'
          },
          category: getEventCategory(event.name),
          source: 'marketplace',
          platform: 'ios',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        batch.set(docRef, payload);
      });

      await batch.commit();
      logger.info(`Batch tracked ${events.length} analytics events`);
      
    } catch (error: any) {
      logger.error("Failed to batch track analytics events", {
        eventCount: events.length,
        error: error.message
      });
    }
  },

  async trackUserJourney(userId: string, journeyStage: string, metadata: Record<string, any> = {}): Promise<void> {
    await this.track('user_journey_stage', {
      userId,
      journeyStage,
      ...metadata
    });
  },

  async trackConversionFunnel(userId: string, funnelStep: string, funnelName: string, metadata: Record<string, any> = {}): Promise<void> {
    await this.track('conversion_funnel', {
      userId,
      funnelStep,
      funnelName,
      ...metadata
    });
  },

  async trackBusinessMetric(metric: string, value: number, dimensions: Record<string, any> = {}): Promise<void> {
    await this.track('business_metric', {
      metric,
      value,
      ...dimensions
    });
  }
};

function getEventCategory(eventName: string): string {
  if (eventName.includes('listing')) return 'listings';
  if (eventName.includes('search')) return 'search';
  if (eventName.includes('message') || eventName.includes('conversation')) return 'messaging';
  if (eventName.includes('offer')) return 'offers';
  if (eventName.includes('reservation') || eventName.includes('meetup')) return 'reservations';
  if (eventName.includes('payment') || eventName.includes('cod') || eventName.includes('escrow')) return 'payments';
  if (eventName.includes('report') || eventName.includes('moderat') || eventName.includes('trust')) return 'moderation';
  if (eventName.includes('ai') || eventName.includes('assistant') || eventName.includes('plugin')) return 'ai';
  if (eventName.includes('user_journey') || eventName.includes('conversion')) return 'analytics';
  return 'general';
}










