import { onCall } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { withMetrics } from "../shared/metrics";
import { VertexAI } from "@google-cloud/vertexai";

try { admin.app(); } catch { admin.initializeApp(); }

const db = admin.firestore();
const storage = admin.storage();

// Initialize Vertex AI
const vertexAI = new VertexAI({
  project: process.env.GCLOUD_PROJECT || 'liive-casablanca',
  location: 'us-central1',
});

const model = vertexAI.getGenerativeModel({
  model: 'gemini-1.5-flash',
  generationConfig: {
    maxOutputTokens: 2048,
    temperature: 0.7,
    topP: 0.95,
  },
});

// Utility
function requireAuth(context: any): string {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new Error("Authentication required");
  }
  return uid;
}

/**
 * AI-powered scope description from photos
 * Takes photos and returns normalized scope JSON with title, description, and budget estimate
 */
export const aiDescribeScope = withMetrics("aiDescribeScope:onCall",
  onCall(async (request) => {
    const uid = requireAuth(request);
    const { photoUrls, categoryId, userNotes } = request.data || {};
    
    if (!photoUrls || photoUrls.length === 0) {
      throw new Error("At least one photo URL is required");
    }

    try {
      // Get category info for context
      let categoryName = "";
      if (categoryId) {
        const categoryDoc = await db.collection('serviceCategories').doc(categoryId).get();
        if (categoryDoc.exists) {
          categoryName = categoryDoc.data()?.name || "";
        }
      }

      // Download and convert images to base64 for Vertex AI
      const imagePrompts = await Promise.all(
        photoUrls.slice(0, 3).map(async (url: string) => {
          try {
            // Download image from Firebase Storage URL
            const response = await fetch(url);
            const buffer = await response.arrayBuffer();
            const base64 = Buffer.from(buffer).toString('base64');
            return {
              inlineData: {
                mimeType: 'image/jpeg',
                data: base64
              }
            };
          } catch (error) {
            logger.warn("Failed to download image", { url, error });
            return null;
          }
        })
      );

      const validImages = imagePrompts.filter(img => img !== null);
      if (validImages.length === 0) {
        throw new Error("Could not process any of the provided images");
      }

      // Build AI prompt
      const prompt = `You are a home services expert in Morocco. Analyze these photos to help create a service request.

Category: ${categoryName || 'General home service'}
User notes: ${userNotes || 'None provided'}

Based on the images, provide a structured service request in JSON format:
{
  "title": "Brief, clear title for the job (max 60 chars)",
  "description": "Detailed description of work needed, materials, specific requirements (2-3 sentences)",
  "estimatedBudget": {
    "min": number in MAD,
    "max": number in MAD,
    "confidence": "low" | "medium" | "high"
  },
  "scope": {
    "roomCount": number if applicable,
    "squareMeters": number if estimable,
    "urgency": "asap" | "flexible" | "scheduled",
    "complexity": "simple" | "moderate" | "complex"
  },
  "suggestedSkills": ["skill1", "skill2"],
  "materials": {
    "required": ["material1", "material2"],
    "optional": ["material3"]
  },
  "estimatedDuration": {
    "days": number,
    "confidence": "low" | "medium" | "high"
  },
  "clarifyingQuestions": ["question1", "question2"] // max 3 questions
}

Consider Moroccan market prices and local practices. Be specific about what you can see in the images.`;

      // Call Vertex AI
      const contents = [
        { role: 'user', parts: [...validImages, { text: prompt }] }
      ];

      const result = await model.generateContent({ contents });
      const response = result.response;
      const text = response.candidates?.[0]?.content?.parts?.[0]?.text || '{}';
      
      // Parse JSON response
      let scopeData;
      try {
        // Extract JSON from potential markdown code block
        const jsonMatch = text.match(/```json\n?([\s\S]*?)\n?```/) || text.match(/{[\s\S]*}/);
        scopeData = JSON.parse(jsonMatch?.[1] || jsonMatch?.[0] || '{}');
      } catch (parseError) {
        logger.error("Failed to parse AI response", { text, parseError });
        throw new Error("Could not parse AI response");
      }

      // Validate and sanitize response
      const sanitized = {
        title: (scopeData.title || "").substring(0, 60),
        description: (scopeData.description || "").substring(0, 500),
        estimatedBudget: {
          min: Math.max(0, scopeData.estimatedBudget?.min || 100),
          max: Math.max(0, scopeData.estimatedBudget?.max || 1000),
          confidence: scopeData.estimatedBudget?.confidence || 'low'
        },
        scope: scopeData.scope || {},
        suggestedSkills: (scopeData.suggestedSkills || []).slice(0, 5),
        materials: scopeData.materials || {},
        estimatedDuration: scopeData.estimatedDuration || { days: 1, confidence: 'low' },
        clarifyingQuestions: (scopeData.clarifyingQuestions || []).slice(0, 3)
      };

      logger.info("Callable:aiDescribeScope", { uid, photoCount: photoUrls.length, categoryId });
      return sanitized;

    } catch (error: any) {
      logger.error("AI scope description failed", { error: error?.message, uid });
      throw new Error("Failed to analyze images: " + (error?.message || "Unknown error"));
    }
  })
);

/**
 * AI-powered job estimation
 * Takes text description and optional media, returns price range and duration
 */
export const aiEstimateJob = withMetrics("aiEstimateJob:onCall",
  onCall(async (request) => {
    const uid = requireAuth(request);
    const { description, categoryId, location, urgency, photoUrls } = request.data || {};
    
    if (!description) {
      throw new Error("Job description is required");
    }

    try {
      // Get category and location context
      let categoryName = "";
      if (categoryId) {
        const categoryDoc = await db.collection('serviceCategories').doc(categoryId).get();
        if (categoryDoc.exists) {
          categoryName = categoryDoc.data()?.name || "";
        }
      }

      // Get recent similar jobs for price reference
      const similarJobs = await db.collection('contracts')
        .where('agreedScope.categoryId', '==', categoryId)
        .where('status', '==', 'completed')
        .orderBy('completedAt', 'desc')
        .limit(10)
        .get();

      const priceReferences = similarJobs.docs.map(doc => {
        const data = doc.data();
        return {
          price: data.priceMAD,
          scope: data.agreedScope?.title || '',
        };
      });

      // Build estimation prompt
      const prompt = `You are an experienced home services estimator in Morocco. Provide a cost and time estimate for this job.

Category: ${categoryName || 'General service'}
Location: ${location?.city || 'Casablanca'}
Description: ${description}
Urgency: ${urgency || 'flexible'}

Recent similar jobs in the area:
${priceReferences.map(ref => `- ${ref.scope}: ${ref.price} MAD`).join('\n') || 'No recent data'}

Provide your estimate in JSON format:
{
  "priceRange": {
    "min": number in MAD,
    "max": number in MAD,
    "confidence": "low" | "medium" | "high",
    "breakdown": {
      "labor": number in MAD,
      "materials": number in MAD,
      "margin": number in MAD
    }
  },
  "duration": {
    "minDays": number,
    "maxDays": number,
    "confidence": "low" | "medium" | "high",
    "phases": [
      {
        "name": "phase name",
        "days": number
      }
    ]
  },
  "factors": {
    "increasing": ["factor1", "factor2"], // factors that increase cost
    "decreasing": ["factor3"], // factors that decrease cost
    "assumptions": ["assumption1", "assumption2"]
  },
  "recommendations": [
    "recommendation1",
    "recommendation2"
  ],
  "alternativeOptions": [
    {
      "description": "option description",
      "priceImpact": "percentage change like -20%",
      "qualityImpact": "description of quality impact"
    }
  ]
}

Consider:
- Moroccan labor rates and material costs
- Local market conditions
- Seasonal factors
- Quality expectations for the price range
- Include margin for professional service`;

      // Add images if provided
      const parts: any[] = [{ text: prompt }];
      if (photoUrls && photoUrls.length > 0) {
        const imageData = await Promise.all(
          photoUrls.slice(0, 2).map(async (url: string) => {
            try {
              const response = await fetch(url);
              const buffer = await response.arrayBuffer();
              const base64 = Buffer.from(buffer).toString('base64');
              return {
                inlineData: {
                  mimeType: 'image/jpeg',
                  data: base64
                }
              };
            } catch {
              return null;
            }
          })
        );
        parts.unshift(...imageData.filter(img => img !== null));
      }

      // Call Vertex AI
      const contents = [{ role: 'user', parts }];
      const result = await model.generateContent({ contents });
      const response = result.response;
      const text = response.candidates?.[0]?.content?.parts?.[0]?.text || '{}';
      
      // Parse response
      let estimateData;
      try {
        const jsonMatch = text.match(/```json\n?([\s\S]*?)\n?```/) || text.match(/{[\s\S]*}/);
        estimateData = JSON.parse(jsonMatch?.[1] || jsonMatch?.[0] || '{}');
      } catch (parseError) {
        logger.error("Failed to parse AI estimation", { text, parseError });
        throw new Error("Could not parse estimation");
      }

      // Validate and return
      const sanitized = {
        priceRange: {
          min: Math.max(0, estimateData.priceRange?.min || 100),
          max: Math.max(0, estimateData.priceRange?.max || 1000),
          confidence: estimateData.priceRange?.confidence || 'low',
          breakdown: estimateData.priceRange?.breakdown || {}
        },
        duration: {
          minDays: Math.max(1, estimateData.duration?.minDays || 1),
          maxDays: Math.max(1, estimateData.duration?.maxDays || 3),
          confidence: estimateData.duration?.confidence || 'low',
          phases: estimateData.duration?.phases || []
        },
        factors: estimateData.factors || {},
        recommendations: (estimateData.recommendations || []).slice(0, 3),
        alternativeOptions: (estimateData.alternativeOptions || []).slice(0, 2)
      };

      logger.info("Callable:aiEstimateJob", { uid, categoryId, hasPhotos: !!photoUrls?.length });
      return sanitized;

    } catch (error: any) {
      logger.error("AI job estimation failed", { error: error?.message, uid });
      throw new Error("Failed to estimate job: " + (error?.message || "Unknown error"));
    }
  })
);

/**
 * AI-powered pro matching enhancement
 * Analyzes RFQ and pro profiles to suggest best matches
 */
export const aiMatchPros = withMetrics("aiMatchPros:onCall",
  onCall(async (request) => {
    const uid = requireAuth(request);
    const { rfqId, limit = 5 } = request.data || {};
    
    if (!rfqId) {
      throw new Error("RFQ ID is required");
    }

    try {
      // Get RFQ details
      const rfqDoc = await db.collection('rfqs').doc(rfqId).get();
      if (!rfqDoc.exists) {
        throw new Error("RFQ not found");
      }
      const rfq = rfqDoc.data()!;
      
      // Get available pros in the city
      const prosSnapshot = await db.collection('proProfiles')
        .where('serviceArea.city', '==', rfq.location.city)
        .where('skills', 'array-contains', rfq.categoryId)
        .where('isVerified', '==', true)
        .limit(20)
        .get();

      if (prosSnapshot.empty) {
        return { matches: [], message: "No verified professionals available in your area" };
      }

      // Build matching prompt
      const prosData = prosSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
        portfolio: undefined, // Remove large fields
      }));

      const prompt = `Analyze this service request and rank the best professional matches.

Service Request:
- Title: ${rfq.scope.title}
- Description: ${rfq.scope.description}
- Budget: ${rfq.budgetRange ? `${rfq.budgetRange.minMAD}-${rfq.budgetRange.maxMAD} MAD` : 'Not specified'}
- Urgency: ${rfq.scope.urgency}
- Location: ${rfq.location.city}

Available Professionals:
${prosData.map((pro, idx) => `
${idx + 1}. ${pro.name}
- Skills: ${pro.skills.join(', ')}
- Experience: ${pro.experienceYears} years
- Rating: ${pro.rating}/5 (${pro.reviewsCount} reviews)
- Jobs completed: ${pro.jobsCount}
- Languages: ${pro.languages?.join(', ') || 'Not specified'}
- Badges: ${pro.badges?.join(', ') || 'None'}
`).join('\n')}

Return a JSON array of the top ${limit} matches:
[
  {
    "proId": "professional ID",
    "matchScore": number from 0-100,
    "reasons": ["reason1", "reason2", "reason3"],
    "concerns": ["concern1"] or [],
    "estimatedResponseTime": "hours or days"
  }
]

Consider: skills match, experience level, rating, availability, language match, and job history.`;

      // Call AI for matching
      const contents = [{ role: 'user', parts: [{ text: prompt }] }];
      const result = await model.generateContent({ contents });
      const response = result.response;
      const text = response.candidates?.[0]?.content?.parts?.[0]?.text || '[]';
      
      // Parse matches
      let matches;
      try {
        const jsonMatch = text.match(/```json\n?([\s\S]*?)\n?```/) || text.match(/\[[\s\S]*\]/);
        matches = JSON.parse(jsonMatch?.[1] || jsonMatch?.[0] || '[]');
      } catch {
        logger.error("Failed to parse AI matches", { text });
        // Fallback to simple sorting
        matches = prosData
          .sort((a, b) => (b.rating * b.jobsCount) - (a.rating * a.jobsCount))
          .slice(0, limit)
          .map(pro => ({
            proId: pro.id,
            matchScore: Math.round(pro.rating * 20),
            reasons: ["Experienced professional", "Good ratings"],
            concerns: [],
            estimatedResponseTime: "1-2 hours"
          }));
      }

      logger.info("Callable:aiMatchPros", { uid, rfqId, matchCount: matches.length });
      return { matches: matches.slice(0, limit) };

    } catch (error: any) {
      logger.error("AI pro matching failed", { error: error?.message, uid });
      throw new Error("Failed to match professionals: " + (error?.message || "Unknown error"));
    }
  })
);