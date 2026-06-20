import { onDocumentCreated, onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { getSecret, secretPath, SECRET_IDS } from "../shared/secretManager";

const db = admin.firestore();

// Mock fact-checking service - replace with actual Grok API
async function checkFactWithGrok(claim: string, historicalDate: string, sources: string[]): Promise<{
  status: string;
  explanation: string;
  confidence: number;
  verifiedSources: string[];
}> {
  // In production, this would call the Grok API
  // For now, return mock results based on simple heuristics
  
  const lowerClaim = claim.toLowerCase();
  
  // Simulate fact-checking logic
  if (lowerClaim.includes("declaration of independence") && historicalDate === "1776-07-04") {
    return {
      status: "verified",
      explanation: "The Declaration of Independence was indeed adopted on July 4, 1776.",
      confidence: 0.95,
      verifiedSources: ["National Archives", "Library of Congress"]
    };
  }
  
  if (sources.length === 0) {
    return {
      status: "needsSource",
      explanation: "No sources provided for verification.",
      confidence: 0.3,
      verifiedSources: []
    };
  }
  
  // Default to pending more research
  return {
    status: "pending",
    explanation: "Fact-checking in progress. Additional verification needed.",
    confidence: 0.5,
    verifiedSources: sources
  };
}

/**
 * Fact-check timeline events when they are created or updated
 */
export const factCheckTimelineEvent = onDocumentWritten(
  "debates/{debateId}/timeline/{eventId}",
  async (event) => {
    const debateId = event.params.debateId;
    const eventId = event.params.eventId;
    const data = event.data?.after.data();
    
    if (!data) return;
    
    // Only process if fact-check is requested or status is pending
    if (!data.requestFactCheck && data.factCheckStatus !== "pending") {
      return;
    }
    
    try {
      logger.info(`Fact-checking event ${eventId} in debate ${debateId}`);
      
      // Extract claim details
      const claim = `${data.title}: ${data.description}`;
      const historicalDate = data.historicalDate;
      const sources = data.sources || [];
      
      // Perform fact-checking
      const result = await checkFactWithGrok(claim, historicalDate, sources);
      
      // Update the timeline event with fact-check status
      await db.collection("debates").doc(debateId)
        .collection("timeline").doc(eventId)
        .update({
          factCheckStatus: result.status,
          factCheckConfidence: result.confidence,
          factCheckUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          requestFactCheck: false
        });
      
      // Store detailed fact-check result
      await db.collection("debates").doc(debateId)
        .collection("factChecks").doc(eventId)
        .set({
          eventId,
          status: result.status,
          explanation: result.explanation,
          confidence: result.confidence,
          sources: result.verifiedSources,
          checkedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      
      logger.info(`Fact-check completed for event ${eventId}: ${result.status}`);
      
    } catch (err: any) {
      logger.error(`Fact-check failed for event ${eventId}`, err);
      
      // Mark as unknown if fact-checking fails
      await db.collection("debates").doc(debateId)
        .collection("timeline").doc(eventId)
        .update({
          factCheckStatus: "unknown",
          factCheckError: err.message,
          requestFactCheck: false
        });
    }
  }
);

/**
 * Batch fact-check multiple claims periodically
 */
export const batchFactCheck = onDocumentWritten(
  "debates/{debateId}",
  async (event) => {
    const debateId = event.params.debateId;
    const data = event.data?.after.data();
    
    if (!data?.isLive) return;
    
    try {
      // Get all pending fact-checks for this debate
      const pendingEvents = await db.collection("debates").doc(debateId)
        .collection("timeline")
        .where("factCheckStatus", "==", "pending")
        .limit(10) // Process up to 10 at a time
        .get();
      
      if (pendingEvents.empty) return;
      
      logger.info(`Batch fact-checking ${pendingEvents.size} events for debate ${debateId}`);
      
      // Process each event
      const promises = pendingEvents.docs.map(async (doc) => {
        const eventData = doc.data();
        const claim = `${eventData.title}: ${eventData.description}`;
        const result = await checkFactWithGrok(
          claim,
          eventData.historicalDate,
          eventData.sources || []
        );
        
        // Update both timeline event and fact-check collection
        await Promise.all([
          doc.ref.update({
            factCheckStatus: result.status,
            factCheckConfidence: result.confidence,
            factCheckUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
          }),
          db.collection("debates").doc(debateId)
            .collection("factChecks").doc(doc.id)
            .set({
              eventId: doc.id,
              status: result.status,
              explanation: result.explanation,
              confidence: result.confidence,
              sources: result.verifiedSources,
              checkedAt: admin.firestore.FieldValue.serverTimestamp()
            })
        ]);
      });
      
      await Promise.all(promises);
      
      logger.info(`Batch fact-check completed for debate ${debateId}`);
      
    } catch (err: any) {
      logger.error(`Batch fact-check failed for debate ${debateId}`, err);
    }
  }
);