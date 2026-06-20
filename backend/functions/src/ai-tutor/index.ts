import * as admin from "firebase-admin";
import { onCall, onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { analytics } from "../shared/analytics";

const db = admin.firestore();
const storage = admin.storage();

// MARK: - Episode Management

interface ListEpisodesData {
  domain?: string;
  difficulty?: string;
  limit?: number;
}

export const listEpisodesHttp = onRequest(async (req, res) => {
  try {
    const { domain, difficulty, limit = 20 } = req.query as any;
    
    let query = db.collection("aiTutorEpisodes")
      .where("published", "==", true)
      .orderBy("createdAt", "desc")
      .limit(parseInt(limit));
    
    if (domain) {
      query = query.where("domain", "==", domain);
    }
    
    if (difficulty) {
      query = query.where("difficulty", "==", difficulty);
    }
    
    const snapshot = await query.get();
    const episodes = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    
    await analytics.track("ai_tutor_episodes_listed", {
      count: episodes.length,
      domain,
      difficulty
    });
    
    res.json({ episodes });
  } catch (error) {
    logger.error("Error listing episodes:", error);
    res.status(500).json({ error: "Failed to list episodes" });
  }
});

interface GetEpisodeConfigData {
  episodeId: string;
}

export const getEpisodeConfigHttp = onRequest(async (req, res) => {
  try {
    const { episodeId } = req.query as any;
    
    if (!episodeId) {
      res.status(400).json({ error: "episodeId is required" });
      return;
    }
    
    // Get episode metadata
    const episodeDoc = await db.collection("aiTutorEpisodes").doc(episodeId).get();
    
    if (!episodeDoc.exists) {
      res.status(404).json({ error: "Episode not found" });
      return;
    }
    
    const episodeData = episodeDoc.data()!;
    
    if (!episodeData.published) {
      res.status(403).json({ error: "Episode not published" });
      return;
    }
    
    // Generate signed URLs for asset bundles
    const bundles = await Promise.all(
      (episodeData.bundles || []).map(async (bundle: any) => {
        const file = storage.bucket().file(`ai-tutor/episodes/${episodeId}/v${episodeData.version}/${bundle.filename}`);
        const [url] = await file.getSignedUrl({
          action: 'read',
          expires: Date.now() + 3600000, // 1 hour
        });
        
        return {
          ...bundle,
          url
        };
      })
    );
    
    // Generate signed URL for manifest
    const manifestFile = storage.bucket().file(`ai-tutor/episodes/${episodeId}/v${episodeData.version}/manifest.json`);
    const [manifestURL] = await manifestFile.getSignedUrl({
      action: 'read',
      expires: Date.now() + 3600000,
    });
    
    const config = {
      id: episodeId,
      manifestURL,
      bundles,
      artifacts: episodeData.artifacts || [],
      npcs: episodeData.npcs || [],
      scenes: episodeData.scenes || [],
      constraints: episodeData.constraints || {},
      assessment: episodeData.assessment || {}
    };
    
    await analytics.track("ai_tutor_episode_config_fetched", {
      episodeId,
      version: episodeData.version
    });
    
    res.json(config);
  } catch (error) {
    logger.error("Error getting episode config:", error);
    res.status(500).json({ error: "Failed to get episode config" });
  }
});

// MARK: - RAG Query

interface RAGQueryData {
  episodeId: string;
  npcId: string;
  prompt: string;
  context?: {
    previousExchanges: Array<{
      speaker: string;
      text: string;
      timestamp: number;
    }>;
    currentScene: string;
    evidencePresented: string[];
  };
}

export const ragQueryHttp = onRequest(async (req, res) => {
  try {
    const { episodeId, npcId, prompt, context } = req.body as RAGQueryData;
    
    if (!episodeId || !npcId || !prompt) {
      res.status(400).json({ error: "episodeId, npcId, and prompt are required" });
      return;
    }
    
    // Get episode and NPC configuration
    const episodeDoc = await db.collection("aiTutorEpisodes").doc(episodeId).get();
    
    if (!episodeDoc.exists) {
      res.status(404).json({ error: "Episode not found" });
      return;
    }
    
    const episodeData = episodeDoc.data()!;
    const npc = episodeData.npcs?.find((n: any) => n.id === npcId);
    
    if (!npc) {
      res.status(404).json({ error: "NPC not found" });
      return;
    }
    
    // Retrieve relevant knowledge base documents
    const knowledgeChunks = await retrieveKnowledgeChunks(
      episodeId,
      npc.knowledgeBase || [],
      prompt,
      context?.currentScene
    );
    
    // Generate response using RAG
    const response = await generateRAGResponse(
      prompt,
      knowledgeChunks,
      npc,
      context
    );
    
    // Log the interaction
    await analytics.track("ai_tutor_rag_query", {
      episodeId,
      npcId,
      promptLength: prompt.length,
      responseLength: response.response.length,
      citationCount: response.citations.length,
      confidence: response.confidence
    });
    
    res.json(response);
  } catch (error) {
    logger.error("Error processing RAG query:", error);
    res.status(500).json({ error: "Failed to process query" });
  }
});

// MARK: - Telemetry

interface TelemetryEvent {
  sessionId: string;
  episodeId: string;
  timestamp: number;
  type: string;
  data: any;
}

interface LogTelemetryData {
  events: TelemetryEvent[];
}

export const logTelemetryHttp = onRequest(async (req, res) => {
  try {
    const { events } = req.body as LogTelemetryData;
    
    if (!events || !Array.isArray(events)) {
      res.status(400).json({ error: "events array is required" });
      return;
    }
    
    // Validate events
    for (const event of events) {
      if (!event.sessionId || !event.episodeId || !event.type) {
        res.status(400).json({ error: "Invalid event data" });
        return;
      }
    }
    
    // Batch write to Firestore
    const batch = db.batch();
    const dateShard = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
    
    for (const event of events) {
      const docRef = db.collection("aiTutorTelemetry")
        .doc(dateShard)
        .collection("events")
        .doc(`${event.sessionId}_${event.timestamp}`);
      
      batch.set(docRef, {
        ...event,
        receivedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
    
    await batch.commit();
    
    // Track aggregated analytics
    await analytics.track("ai_tutor_telemetry_batch", {
      eventCount: events.length,
      sessionIds: [...new Set(events.map(e => e.sessionId))].length,
      episodeIds: [...new Set(events.map(e => e.episodeId))],
      eventTypes: [...new Set(events.map(e => e.type))]
    });
    
    res.json({ success: true });
  } catch (error) {
    logger.error("Error logging telemetry:", error);
    res.status(500).json({ error: "Failed to log telemetry" });
  }
});

// MARK: - Admin Functions

export const validateEpisodeCallable = onCall(async (request) => {
  const { data, auth } = request;
  const { episodeId } = data;
  
  // Check admin privileges
  if (!auth?.uid) {
    throw new Error("Authentication required");
  }
  
  const userDoc = await db.collection("users").doc(auth.uid).get();
  if (!userDoc.exists || !userDoc.data()?.isAdmin) {
    throw new Error("Admin privileges required");
  }
  
  try {
    const episodeDoc = await db.collection("aiTutorEpisodes").doc(episodeId).get();
    
    if (!episodeDoc.exists) {
      throw new Error("Episode not found");
    }
    
    const episode = episodeDoc.data()!;
    const validationResults = await validateEpisodeData(episode);
    
    return {
      valid: validationResults.every(r => r.valid),
      results: validationResults
    };
  } catch (error) {
    logger.error("Error validating episode:", error);
    throw error;
  }
});

// MARK: - Helper Functions

async function retrieveKnowledgeChunks(
  episodeId: string,
  knowledgeBase: string[],
  query: string,
  scene?: string
): Promise<any[]> {
  // In a production system, this would use vector search
  // For now, return mock knowledge chunks
  
  const chunks = [
    {
      source: "al-Tabari",
      text: "The Patriarch Sophronius met Omar at the gates of Jerusalem, ensuring the safety of the Christian population.",
      confidence: 0.9,
      page: "Vol 12, p. 191"
    },
    {
      source: "The Covenant of Omar",
      text: "Omar guaranteed protection of churches and Christian worship practices.",
      confidence: 0.85,
      page: "Article 2"
    }
  ];
  
  return chunks.filter(chunk => 
    knowledgeBase.some(kb => chunk.source.toLowerCase().includes(kb.toLowerCase()))
  );
}

async function generateRAGResponse(
  prompt: string,
  knowledgeChunks: any[],
  npc: any,
  context?: any
): Promise<any> {
  // In production, this would use a proper LLM with RAG
  // For now, return a mock response based on NPC persona
  
  const citations = knowledgeChunks.map(chunk => ({
    source: chunk.source,
    text: chunk.text,
    confidence: chunk.confidence,
    page: chunk.page
  }));
  
  let response: string;
  
  if (npc.persona?.includes("cautious")) {
    response = "We must proceed carefully, ensuring all parties are protected. The sources confirm our approach should be measured.";
  } else if (npc.persona?.includes("strategic")) {
    response = "From a tactical perspective, we should secure our positions first. Historical precedent supports this approach.";
  } else {
    response = "Based on the available evidence, this appears to be the most reasonable course of action.";
  }
  
  return {
    response,
    citations,
    confidence: 0.8,
    contested: false
  };
}

async function validateEpisodeData(episode: any): Promise<any[]> {
  const results = [];
  
  // Check required fields
  const requiredFields = ['title', 'domain', 'summary', 'learningObjectives'];
  for (const field of requiredFields) {
    results.push({
      rule: `required_field_${field}`,
      valid: !!episode[field],
      message: episode[field] ? "Field present" : `Missing required field: ${field}`
    });
  }
  
  // Check citations
  if (episode.artifacts) {
    for (const artifact of episode.artifacts) {
      results.push({
        rule: `citation_${artifact.id}`,
        valid: !!artifact.citation,
        message: artifact.citation ? "Citation present" : `Missing citation for artifact: ${artifact.id}`
      });
    }
  }
  
  // Check bundle integrity
  if (episode.bundles) {
    for (const bundle of episode.bundles) {
      const file = storage.bucket().file(`ai-tutor/episodes/${episode.id}/v${episode.version}/${bundle.filename}`);
      const [exists] = await file.exists();
      
      results.push({
        rule: `bundle_exists_${bundle.id}`,
        valid: exists,
        message: exists ? "Bundle file exists" : `Missing bundle file: ${bundle.filename}`
      });
    }
  }
  
  return results;
}