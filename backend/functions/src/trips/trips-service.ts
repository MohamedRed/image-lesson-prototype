import { onRequest, onCall, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { getFirestore, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import { logger } from 'firebase-functions/v2';
import { validateTripsServiceEnv } from '../utils/validation';
import { callOpenAI } from '../utils/openai';

const db = getFirestore();

// Types
interface TripConstraints {
    budget?: {
        amount: number;
        currency: string;
    };
    mustVisit: string[];
    avoid: string[];
    travelStyle: 'budget' | 'balanced' | 'luxury';
    groupSize?: number;
    accessibility?: string[];
    dietary?: string[];
    activities?: string[];
}

interface TravelerPreferences {
    pace: 'slow' | 'moderate' | 'fast';
    interests: string[];
    activities: string[];
    accommodationType: 'hostel' | 'hotel' | 'apartment' | 'luxury' | 'mixed';
    transportPreference: 'ground' | 'air' | 'mixed';
    dietaryRestrictions: string[];
    accessibilityNeeds: string[];
}

interface TripDuration {
    type: 'fixed' | 'flexible';
    startDate?: Date;
    endDate?: Date;
    flexibleDays?: number;
}

interface PlanningOptions {
    priority: 'express' | 'balanced' | 'thorough';
    optimizeFor: ('cost' | 'time' | 'comfort' | 'experience' | 'safety' | 'sustainability')[];
    includeAlternatives: boolean;
    maxAlternatives: number;
    dryRun: boolean;
}

// HTTPS Callable Functions

/**
 * Create a new trip
 */
export const createTrip = onCall(
    {
        region: 'us-central1',
        enforceAppCheck: true,
        cors: true
    },
    async (request) => {
        try {
            // Validate authentication
            if (!request.auth) {
                throw new HttpsError('unauthenticated', 'Must be authenticated to create trips');
            }

            const { title, scope, duration, constraints } = request.data;
            const userId = request.auth.uid;

            // Validate required fields
            if (!title || !scope || !duration) {
                throw new HttpsError('invalid-argument', 'Missing required fields: title, scope, duration');
            }

            // Create trip document
            const tripData = {
                ownerId: userId,
                title,
                scope,
                duration,
                startDate: duration.startDate ? Timestamp.fromDate(new Date(duration.startDate)) : null,
                endDate: duration.endDate ? Timestamp.fromDate(new Date(duration.endDate)) : null,
                destinations: [],
                status: 'planning',
                constraints: constraints || {},
                members: [{
                    userId,
                    role: 'owner',
                    status: 'confirmed',
                    joinedAt: FieldValue.serverTimestamp()
                }],
                preferences: null,
                itineraryId: null,
                budgetPlanId: null,
                compliancePackId: null,
                createdAt: FieldValue.serverTimestamp(),
                updatedAt: FieldValue.serverTimestamp()
            };

            const tripRef = await db.collection('trips').add(tripData);
            
            logger.info('Trip created', { tripId: tripRef.id, userId });
            
            return {
                success: true,
                tripId: tripRef.id,
                trip: { id: tripRef.id, ...tripData }
            };

        } catch (error) {
            logger.error('Error creating trip', { error, userId: request.auth?.uid });
            if (error instanceof HttpsError) {
                throw error;
            }
            throw new HttpsError('internal', 'Failed to create trip');
        }
    }
);

/**
 * Get user's trips
 */
export const getUserTrips = onCall(
    {
        region: 'us-central1',
        enforceAppCheck: true,
        cors: true
    },
    async (request) => {
        try {
            if (!request.auth) {
                throw new HttpsError('unauthenticated', 'Must be authenticated');
            }

            const userId = request.auth.uid;
            const tripsSnapshot = await db.collection('trips')
                .where('members', 'array-contains', { userId, status: 'confirmed' })
                .orderBy('updatedAt', 'desc')
                .limit(50)
                .get();

            const trips = tripsSnapshot.docs.map(doc => ({
                id: doc.id,
                ...doc.data()
            }));

            return { success: true, trips };

        } catch (error) {
            logger.error('Error getting user trips', { error, userId: request.auth?.uid });
            throw new HttpsError('internal', 'Failed to get trips');
        }
    }
);

/**
 * Process intake (voice/text) for trip preferences
 */
export const processIntake = onCall(
    {
        region: 'us-central1',
        enforceAppCheck: true,
        cors: true
    },
    async (request) => {
        try {
            if (!request.auth) {
                throw new HttpsError('unauthenticated', 'Must be authenticated');
            }

            const { tripId, input, type } = request.data;
            const userId = request.auth.uid;

            // Verify trip access
            const tripDoc = await db.collection('trips').doc(tripId).get();
            if (!tripDoc.exists) {
                throw new HttpsError('not-found', 'Trip not found');
            }

            const trip = tripDoc.data()!;
            const isMember = trip.members?.some((m: any) => m.userId === userId);
            if (!isMember) {
                throw new HttpsError('permission-denied', 'Not authorized to modify this trip');
            }

            // Use AI to extract preferences from natural language
            const prompt = `
                Extract travel preferences from this input: "${input}"
                
                Return a JSON object with:
                - understood: boolean
                - extractedPreferences: { pace, interests, activities, accommodationType, transportPreference, dietaryRestrictions, accessibilityNeeds }
                - extractedConstraints: { budget, mustVisit, avoid, travelStyle }
                - suggestedDestinations: string[]
                - clarificationNeeded: string[]
                
                Focus on understanding the user's travel style, preferences, and requirements.
            `;

            const aiResponse = await callOpenAI([
                { role: 'system', content: 'You are a travel planning assistant. Extract structured data from user input.' },
                { role: 'user', content: prompt }
            ]);

            let result;
            try {
                result = JSON.parse(aiResponse);
            } catch {
                result = {
                    understood: false,
                    extractedPreferences: null,
                    extractedConstraints: null,
                    suggestedDestinations: [],
                    clarificationNeeded: ['Could not understand the input. Please try rephrasing.']
                };
            }

            // Store intake log
            await db.collection('trips').doc(tripId).collection('intakeLogs').add({
                input,
                type,
                result,
                processedBy: userId,
                createdAt: FieldValue.serverTimestamp()
            });

            return { success: true, result };

        } catch (error) {
            logger.error('Error processing intake', { error, userId: request.auth?.uid });
            if (error instanceof HttpsError) {
                throw error;
            }
            throw new HttpsError('internal', 'Failed to process intake');
        }
    }
);

/**
 * Start itinerary planning job
 */
export const planItinerary = onCall(
    {
        region: 'us-central1',
        enforceAppCheck: true,
        cors: true,
        timeoutSeconds: 300,
        memory: '2GiB'
    },
    async (request) => {
        try {
            if (!request.auth) {
                throw new HttpsError('unauthenticated', 'Must be authenticated');
            }

            const { tripId, options } = request.data;
            const userId = request.auth.uid;

            // Verify trip access
            const tripDoc = await db.collection('trips').doc(tripId).get();
            if (!tripDoc.exists) {
                throw new HttpsError('not-found', 'Trip not found');
            }

            const trip = tripDoc.data()!;
            const isMember = trip.members?.some((m: any) => m.userId === userId);
            if (!isMember) {
                throw new HttpsError('permission-denied', 'Not authorized to modify this trip');
            }

            // Create planning job
            const jobData = {
                tripId,
                userId,
                status: 'queued',
                progress: 0,
                options: options || {},
                stages: [],
                result: null,
                error: null,
                createdAt: FieldValue.serverTimestamp(),
                updatedAt: FieldValue.serverTimestamp()
            };

            const jobRef = await db.collection('planningJobs').add(jobData);

            // Start async planning process
            schedulePlanningJob(jobRef.id, trip, options || {});

            logger.info('Planning job created', { jobId: jobRef.id, tripId, userId });

            return {
                success: true,
                job: { id: jobRef.id, ...jobData }
            };

        } catch (error) {
            logger.error('Error starting planning job', { error, userId: request.auth?.uid });
            if (error instanceof HttpsError) {
                throw error;
            }
            throw new HttpsError('internal', 'Failed to start planning');
        }
    }
);

/**
 * Search destinations
 */
export const searchDestinations = onCall(
    {
        region: 'us-central1',
        enforceAppCheck: true,
        cors: true
    },
    async (request) => {
        try {
            if (!request.auth) {
                throw new HttpsError('unauthenticated', 'Must be authenticated');
            }

            const { query, filters } = request.data;

            // Use AI to enhance destination search
            const prompt = `
                Search for travel destinations matching: "${query}"
                ${filters ? `Filters: ${JSON.stringify(filters)}` : ''}
                
                Return a JSON array of destinations with:
                - name: string
                - country: string
                - region?: string
                - type: 'city' | 'beach' | 'mountain' | 'countryside' | 'island' | 'desert' | 'historic' | 'modern'
                - description: string
                - popularMonths: number[] (1-12)
                - attractions: string[]
                - avgCostPerDay?: { amount: number, currency: string }
                - safetyRating?: number (0-5)
                - tags: string[]
                
                Limit to 10 results.
            `;

            const aiResponse = await callOpenAI([
                { role: 'system', content: 'You are a knowledgeable travel expert. Provide accurate destination information.' },
                { role: 'user', content: prompt }
            ]);

            let destinations;
            try {
                destinations = JSON.parse(aiResponse);
                if (!Array.isArray(destinations)) {
                    destinations = [];
                }
            } catch {
                destinations = [];
            }

            return { success: true, destinations };

        } catch (error) {
            logger.error('Error searching destinations', { error, userId: request.auth?.uid });
            throw new HttpsError('internal', 'Failed to search destinations');
        }
    }
);

/**
 * Get compliance requirements for a trip
 */
export const getCompliance = onCall(
    {
        region: 'us-central1',
        enforceAppCheck: true,
        cors: true
    },
    async (request) => {
        try {
            if (!request.auth) {
                throw new HttpsError('unauthenticated', 'Must be authenticated');
            }

            const { tripId } = request.data;
            const userId = request.auth.uid;

            // Verify trip access
            const tripDoc = await db.collection('trips').doc(tripId).get();
            if (!tripDoc.exists) {
                throw new HttpsError('not-found', 'Trip not found');
            }

            const trip = tripDoc.data()!;
            const isMember = trip.members?.some((m: any) => m.userId === userId);
            if (!isMember) {
                throw new HttpsError('permission-denied', 'Not authorized to view this trip');
            }

            // Get or generate compliance pack
            let compliancePack;
            if (trip.compliancePackId) {
                const complianceDoc = await db.collection('compliancePacks').doc(trip.compliancePackId).get();
                if (complianceDoc.exists) {
                    compliancePack = { id: complianceDoc.id, ...complianceDoc.data() };
                }
            }

            if (!compliancePack && trip.destinations?.length > 0) {
                // Generate compliance requirements using AI
                const prompt = `
                    Generate compliance requirements for travel to: ${trip.destinations.join(', ')}
                    Travel dates: ${trip.startDate} to ${trip.endDate}
                    
                    Return JSON with:
                    - visaRequirements: array of { country, type, required, processingTime, cost, documents }
                    - checklist: array of { category, title, description, mandatory, deadline }
                    - healthRequirements: array of { type, name, required, description }
                    - localRegulations: array of { country, type, description }
                `;

                const aiResponse = await callOpenAI([
                    { role: 'system', content: 'You are a travel compliance expert. Provide accurate visa, health, and legal requirements.' },
                    { role: 'user', content: prompt }
                ]);

                try {
                    const requirements = JSON.parse(aiResponse);
                    
                    const complianceData = {
                        tripId,
                        ...requirements,
                        generatedAt: FieldValue.serverTimestamp(),
                        lastUpdatedAt: FieldValue.serverTimestamp()
                    };

                    const complianceRef = await db.collection('compliancePacks').add(complianceData);
                    
                    // Update trip with compliance pack ID
                    await db.collection('trips').doc(tripId).update({
                        compliancePackId: complianceRef.id,
                        updatedAt: FieldValue.serverTimestamp()
                    });

                    compliancePack = { id: complianceRef.id, ...complianceData };

                } catch {
                    // Fallback compliance pack
                    compliancePack = {
                        visaRequirements: [],
                        checklist: [{
                            category: 'documentation',
                            title: 'Valid Passport',
                            description: 'Ensure passport is valid for at least 6 months',
                            mandatory: true,
                            deadline: null
                        }],
                        healthRequirements: [],
                        localRegulations: []
                    };
                }
            }

            return { success: true, compliancePack };

        } catch (error) {
            logger.error('Error getting compliance', { error, userId: request.auth?.uid });
            if (error instanceof HttpsError) {
                throw error;
            }
            throw new HttpsError('internal', 'Failed to get compliance requirements');
        }
    }
);

// Document Triggers

/**
 * Handle new trip creation
 */
export const onTripCreated = onDocumentCreated('trips/{tripId}', async (event) => {
    try {
        const tripId = event.params.tripId;
        const tripData = event.data?.data();

        if (!tripData) {
            logger.warn('No trip data in created document', { tripId });
            return;
        }

        logger.info('Trip created', { tripId, ownerId: tripData.ownerId });

        // Initialize budget plan
        if (tripData.constraints?.budget) {
            const budgetData = {
                tripId,
                target: tripData.constraints.budget,
                current: { amount: 0, currency: tripData.constraints.budget.currency },
                forecast: { amount: 0, currency: tripData.constraints.budget.currency },
                allocations: [],
                expenses: [],
                alerts: [],
                createdAt: FieldValue.serverTimestamp(),
                updatedAt: FieldValue.serverTimestamp()
            };

            const budgetRef = await db.collection('budgetPlans').add(budgetData);
            
            // Update trip with budget plan ID
            await db.collection('trips').doc(tripId).update({
                budgetPlanId: budgetRef.id,
                updatedAt: FieldValue.serverTimestamp()
            });

            logger.info('Budget plan created for trip', { tripId, budgetPlanId: budgetRef.id });
        }

    } catch (error) {
        logger.error('Error handling trip creation', { error, tripId: event.params.tripId });
    }
});

/**
 * Handle trip updates
 */
export const onTripUpdated = onDocumentUpdated('trips/{tripId}', async (event) => {
    try {
        const tripId = event.params.tripId;
        const beforeData = event.data?.before.data();
        const afterData = event.data?.after.data();

        if (!beforeData || !afterData) {
            return;
        }

        // Check if destinations changed
        const destinationsChanged = JSON.stringify(beforeData.destinations) !== JSON.stringify(afterData.destinations);
        
        if (destinationsChanged && afterData.destinations?.length > 0) {
            logger.info('Trip destinations updated', { tripId, destinations: afterData.destinations });
            
            // Clear old compliance pack if destinations changed significantly
            if (afterData.compliancePackId) {
                await db.collection('compliancePacks').doc(afterData.compliancePackId).update({
                    outdated: true,
                    updatedAt: FieldValue.serverTimestamp()
                });
            }
        }

    } catch (error) {
        logger.error('Error handling trip update', { error, tripId: event.params.tripId });
    }
});

// Scheduled Functions

/**
 * Cleanup old planning jobs
 */
export const cleanupPlanningJobs = onSchedule('0 2 * * *', async (event) => {
    try {
        const cutoff = new Date();
        cutoff.setDate(cutoff.getDate() - 7); // 7 days old

        const oldJobsSnapshot = await db.collection('planningJobs')
            .where('createdAt', '<', Timestamp.fromDate(cutoff))
            .where('status', 'in', ['completed', 'failed', 'cancelled'])
            .limit(100)
            .get();

        const batch = db.batch();
        oldJobsSnapshot.docs.forEach(doc => {
            batch.delete(doc.ref);
        });

        await batch.commit();
        
        logger.info('Cleaned up old planning jobs', { count: oldJobsSnapshot.docs.length });

    } catch (error) {
        logger.error('Error cleaning up planning jobs', { error });
    }
});

/**
 * Update price tracking
 */
export const updatePriceTracking = onSchedule('0 6 * * *', async (event) => {
    try {
        const trackersSnapshot = await db.collection('priceTrackers')
            .where('lastCheckedAt', '<', Timestamp.fromDate(new Date(Date.now() - 24 * 60 * 60 * 1000)))
            .limit(50)
            .get();

        const batch = db.batch();
        
        for (const doc of trackersSnapshot.docs) {
            const tracker = doc.data();
            
            // Simulate price update (in real implementation, would call travel APIs)
            const newPrice = {
                amount: tracker.currentPrice.amount * (0.9 + Math.random() * 0.2), // ±10% variation
                currency: tracker.currentPrice.currency
            };
            
            const pricePoint = {
                price: newPrice,
                date: FieldValue.serverTimestamp(),
                availability: true
            };
            
            batch.update(doc.ref, {
                currentPrice: newPrice,
                priceHistory: FieldValue.arrayUnion(pricePoint),
                lastCheckedAt: FieldValue.serverTimestamp()
            });
        }

        await batch.commit();
        
        logger.info('Updated price tracking', { count: trackersSnapshot.docs.length });

    } catch (error) {
        logger.error('Error updating price tracking', { error });
    }
});

// Helper Functions

async function schedulePlanningJob(jobId: string, trip: any, options: PlanningOptions) {
    try {
        // Simulate async planning process
        setTimeout(async () => {
            try {
                const stages = ['initializing', 'searching_flights', 'searching_hotels', 'finding_activities', 'optimizing', 'validating', 'finalizing'];
                
                for (let i = 0; i < stages.length; i++) {
                    const stage = stages[i];
                    const progress = (i + 1) / stages.length;
                    
                    await db.collection('planningJobs').doc(jobId).update({
                        status: 'processing',
                        progress,
                        currentStage: stage,
                        updatedAt: FieldValue.serverTimestamp()
                    });
                    
                    // Simulate processing time
                    await new Promise(resolve => setTimeout(resolve, 2000));
                }
                
                // Generate mock itinerary
                const itinerary = await generateMockItinerary(trip);
                
                // Create itinerary document
                const itineraryRef = await db.collection('itineraries').add(itinerary);
                
                // Update planning job as completed
                await db.collection('planningJobs').doc(jobId).update({
                    status: 'completed',
                    progress: 1.0,
                    result: { itineraryId: itineraryRef.id },
                    completedAt: FieldValue.serverTimestamp(),
                    updatedAt: FieldValue.serverTimestamp()
                });
                
                // Update trip with itinerary
                await db.collection('trips').doc(trip.id).update({
                    itineraryId: itineraryRef.id,
                    status: 'planned',
                    updatedAt: FieldValue.serverTimestamp()
                });
                
                logger.info('Planning job completed', { jobId, itineraryId: itineraryRef.id });
                
            } catch (error) {
                logger.error('Planning job failed', { jobId, error });
                
                await db.collection('planningJobs').doc(jobId).update({
                    status: 'failed',
                    error: error instanceof Error ? error.message : 'Unknown error',
                    updatedAt: FieldValue.serverTimestamp()
                });
            }
        }, 1000);
        
    } catch (error) {
        logger.error('Error scheduling planning job', { jobId, error });
    }
}

async function generateMockItinerary(trip: any) {
    const days = [];
    const startDate = trip.startDate?.toDate() || new Date();
    const endDate = trip.endDate?.toDate() || new Date(startDate.getTime() + 7 * 24 * 60 * 60 * 1000);
    const dayCount = Math.ceil((endDate.getTime() - startDate.getTime()) / (24 * 60 * 60 * 1000));
    
    for (let i = 0; i < dayCount; i++) {
        const dayDate = new Date(startDate.getTime() + i * 24 * 60 * 60 * 1000);
        
        days.push({
            dayNumber: i + 1,
            date: Timestamp.fromDate(dayDate),
            title: `Day ${i + 1}`,
            segments: [
                {
                    id: `segment_${i}_1`,
                    type: 'activity',
                    title: 'Morning Exploration',
                    description: 'Discover local attractions and culture',
                    startTime: Timestamp.fromDate(new Date(dayDate.getTime() + 9 * 60 * 60 * 1000)),
                    endTime: Timestamp.fromDate(new Date(dayDate.getTime() + 12 * 60 * 60 * 1000)),
                    cost: { amount: 25, currency: 'USD' },
                    bookingStatus: 'optional',
                    location: {
                        latitude: 40.7128 + Math.random() * 0.1,
                        longitude: -74.0060 + Math.random() * 0.1,
                        address: 'Local Attraction'
                    }
                },
                {
                    id: `segment_${i}_2`,
                    type: 'meal',
                    title: 'Local Cuisine',
                    description: 'Authentic local dining experience',
                    startTime: Timestamp.fromDate(new Date(dayDate.getTime() + 12 * 60 * 60 * 1000)),
                    endTime: Timestamp.fromDate(new Date(dayDate.getTime() + 14 * 60 * 60 * 1000)),
                    cost: { amount: 35, currency: 'USD' },
                    bookingStatus: 'optional'
                }
            ]
        });
    }
    
    return {
        tripId: trip.id,
        days,
        totalCost: { amount: dayCount * 60, currency: 'USD' },
        status: 'draft',
        generatedAt: FieldValue.serverTimestamp(),
        lastUpdatedAt: FieldValue.serverTimestamp()
    };
}