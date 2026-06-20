import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import fetch from 'node-fetch';
import { getSecret } from '../shared/secretManager';

const db = admin.firestore();

interface EnrichmentRequest {
  eventId: string;
  articles: any[];
  event: any;
}

interface PerspectiveOutput {
  id: string;
  label: string;
  axes: {
    geography?: string;
    ideology?: string;
    stakeholder?: string;
  };
  summary: string;
  citations: Array<{ title: string; url: string }>;
  confidence: number;
}

interface HistoricalContextOutput {
  text: string;
  citations: Array<{ title: string; url: string }>;
  confidence: number;
}

interface SolutionOutput {
  title: string;
  description: string;
  feasibility: string;
  citations: Array<{ title: string; url: string }>;
}

// Generate historical context for event
async function generateHistoricalContext(
  event: any,
  articles: any[]
): Promise<HistoricalContextOutput> {
  const prompt = `
    Provide neutral historical context for this news event:
    Title: ${event.title}
    Summary: ${event.summary}
    
    Articles:
    ${articles.slice(0, 5).map(a => `- ${a.title} (${a.sourceName})`).join('\n')}
    
    Requirements:
    1. Provide factual historical background (3-5 sentences)
    2. Include timeline of related events if relevant
    3. Cite sources from the articles when possible
    4. State what is known and unknown
    5. Avoid speculation
    
    Output JSON format:
    {
      "text": "historical context text",
      "citations": [{"title": "source title", "url": "source url"}],
      "confidence": 0.0-1.0
    }
  `;

  try {
    // For MVP, use a simple template-based approach
    // In production, integrate with LLM API (GPT-4, Claude, etc.)
    const context: HistoricalContextOutput = {
      text: `This event relates to ongoing developments in ${event.tags[0] || 'current affairs'}. ` +
            `Similar events have occurred in the past, showing a pattern of ${event.goodness === 'good' ? 'progress' : 'challenges'} in this area. ` +
            `Historical precedents suggest various outcomes are possible depending on response measures.`,
      citations: articles.slice(0, 2).map(a => ({
        title: a.title,
        url: a.url
      })),
      confidence: 0.75
    };

    return context;
  } catch (error) {
    console.error('Error generating historical context:', error);
    throw error;
  }
}

// Generate multiple perspectives
async function generatePerspectives(
  event: any,
  articles: any[]
): Promise<PerspectiveOutput[]> {
  const perspectiveTaxonomy = [
    { 
      id: 'western',
      label: 'Western Perspective',
      axes: { geography: 'Western' }
    },
    {
      id: 'eastern',
      label: 'Eastern Perspective',
      axes: { geography: 'East Asia' }
    },
    {
      id: 'government',
      label: 'Government Perspective',
      axes: { stakeholder: 'Government' }
    },
    {
      id: 'civil_society',
      label: 'Civil Society Perspective',
      axes: { stakeholder: 'NGO' }
    },
    {
      id: 'industry',
      label: 'Industry Perspective',
      axes: { stakeholder: 'Industry' }
    }
  ];

  const perspectives: PerspectiveOutput[] = [];

  for (const taxonomy of perspectiveTaxonomy.slice(0, 3)) {
    const prompt = `
      Generate a perspective on this news event from the viewpoint of ${taxonomy.label}:
      Event: ${event.title}
      
      Requirements:
      1. Summarize how this group views the event (2-3 sentences)
      2. Include their main concerns and priorities
      3. Be balanced and avoid stereotypes
      4. Cite relevant sources
      
      Output JSON format:
      {
        "summary": "perspective summary",
        "citations": [{"title": "source", "url": "url"}],
        "confidence": 0.0-1.0
      }
    `;

    try {
      // For MVP, use template-based generation
      // In production, use LLM API
      const perspective: PerspectiveOutput = {
        id: taxonomy.id,
        label: taxonomy.label,
        axes: taxonomy.axes,
        summary: `From the ${taxonomy.label}, this event represents ` +
                `${event.goodness === 'good' ? 'a positive development' : 'a significant challenge'} ` +
                `that requires ${taxonomy.axes.stakeholder === 'Government' ? 'policy response' : 'careful consideration'}. ` +
                `Key considerations include impact on ${taxonomy.axes.geography || taxonomy.axes.stakeholder || 'stakeholders'}.`,
        citations: articles.slice(0, 1).map(a => ({
          title: a.title,
          url: a.url
        })),
        confidence: 0.7
      };

      perspectives.push(perspective);
    } catch (error) {
      console.error(`Error generating perspective ${taxonomy.id}:`, error);
    }
  }

  return perspectives;
}

// Classify event as good/challenging/neutral
async function classifyGoodness(event: any, articles: any[]): Promise<string> {
  // Simple keyword-based classification for MVP
  // In production, use LLM or trained classifier
  
  const positiveKeywords = [
    'breakthrough', 'success', 'achievement', 'progress', 'solution',
    'improvement', 'growth', 'recovery', 'innovation', 'record high'
  ];
  
  const negativeKeywords = [
    'crisis', 'threat', 'risk', 'danger', 'decline', 'failure',
    'shortage', 'conflict', 'disaster', 'emergency', 'record low'
  ];

  const text = `${event.title} ${event.summary}`.toLowerCase();
  
  const positiveCount = positiveKeywords.filter(kw => text.includes(kw)).length;
  const negativeCount = negativeKeywords.filter(kw => text.includes(kw)).length;
  
  if (positiveCount > negativeCount + 1) return 'good';
  if (negativeCount > positiveCount + 1) return 'challenging';
  return 'neutral';
}

// Generate solutions for challenging news
async function generateSolutions(
  event: any,
  articles: any[]
): Promise<SolutionOutput[]> {
  if (event.goodness !== 'challenging') return [];

  const solutions: SolutionOutput[] = [
    {
      title: 'Policy Reform',
      description: 'Implement targeted policy changes to address root causes of the issue.',
      feasibility: 'Medium',
      citations: articles.slice(0, 1).map(a => ({
        title: a.title,
        url: a.url
      }))
    },
    {
      title: 'Community Action',
      description: 'Mobilize local communities to take direct action and support affected populations.',
      feasibility: 'High',
      citations: []
    },
    {
      title: 'Technology Innovation',
      description: 'Develop new technologies or adapt existing ones to mitigate the problem.',
      feasibility: 'Low',
      citations: []
    }
  ];

  return solutions.slice(0, 2); // Return top 2 solutions
}

// Extract impact metrics
function extractImpact(event: any, articles: any[]): any {
  // Simple extraction based on numbers in text
  // In production, use NER and more sophisticated extraction
  
  const text = `${event.title} ${event.summary}`.toLowerCase();
  const numbers = text.match(/\d+[\s,]*(?:million|billion|thousand)?/gi);
  
  let peopleAffected = null;
  if (numbers && numbers.length > 0) {
    const num = numbers[0];
    if (num.includes('million')) {
      peopleAffected = parseInt(num) * 1000000;
    } else if (num.includes('billion')) {
      peopleAffected = parseInt(num) * 1000000000;
    } else if (num.includes('thousand')) {
      peopleAffected = parseInt(num) * 1000;
    }
  }

  return {
    peopleAffected,
    regions: event.regions,
    domains: event.tags
  };
}

// Main enrichment function
export async function enrichNewsEvent(eventId: string): Promise<void> {
  try {
    const eventRef = db.collection('newsEvents').doc(eventId);
    const eventDoc = await eventRef.get();
    
    if (!eventDoc.exists) {
      throw new Error(`Event ${eventId} not found`);
    }
    
    const event = eventDoc.data()!;
    
    // Get articles
    const articlesSnapshot = await eventRef.collection('articles')
      .orderBy('publishedAt', 'desc')
      .limit(10)
      .get();
    
    const articles = articlesSnapshot.docs.map(d => d.data());
    
    if (articles.length === 0) {
      console.log(`No articles found for event ${eventId}`);
      return;
    }

    // Generate enrichments
    const [historicalContext, perspectives, goodness] = await Promise.all([
      generateHistoricalContext(event, articles),
      generatePerspectives(event, articles),
      classifyGoodness(event, articles)
    ]);

    const solutions = await generateSolutions(
      { ...event, goodness },
      articles
    );

    const impact = extractImpact(event, articles);

    // Update event document
    await eventRef.update({
      historicalContext: {
        ...historicalContext,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        model: 'template_v1' // In production: 'gpt-4' or actual model
      },
      perspectives,
      goodness,
      solutions,
      impact,
      enrichedAt: admin.firestore.FieldValue.serverTimestamp(),
      provenance: {
        ...event.provenance,
        method: 'llm_enrich_v1'
      }
    });

    console.log(`Successfully enriched event ${eventId}`);
  } catch (error) {
    console.error(`Error enriching event ${eventId}:`, error);
    throw error;
  }
}

// Trigger enrichment when new events are created
export const enrichmentWorker = functions
  .runWith({
    timeoutSeconds: 300,
    memory: '1GB'
  })
  .firestore
  .document('enrichmentQueue/{queueId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    
    if (data.type !== 'news_event' || data.status !== 'pending') {
      return;
    }

    try {
      await enrichNewsEvent(data.eventId);
      
      await snap.ref.update({
        status: 'completed',
        completedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    } catch (error) {
      console.error('Enrichment error:', error);
      
      await snap.ref.update({
        status: 'failed',
        error: error.message,
        failedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
  });

// Manual enrichment trigger
export const enrichEvent = functions
  .runWith({
    timeoutSeconds: 300,
    memory: '1GB'
  })
  .https
  .onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    const { eventId } = data;
    
    if (!eventId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Event ID is required'
      );
    }

    await enrichNewsEvent(eventId);
    
    return { success: true, eventId };
  });