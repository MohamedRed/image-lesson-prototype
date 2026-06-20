import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { callOpenAI } from '../utils/openai';

const db = getFirestore();

// AI Orchestration Types
interface PlanningContext {
    trip: any;
    preferences?: any;
    constraints: any;
    destinations: string[];
    duration: {
        startDate: Date;
        endDate: Date;
        days: number;
    };
}

interface PlanningAgent {
    name: string;
    role: string;
    expertise: string[];
    priority: number;
}

interface AgentResponse {
    agent: string;
    stage: string;
    data: any;
    confidence: number;
    alternatives?: any[];
    reasoning: string;
}

/**
 * AI-powered itinerary generation orchestrator
 */
export const generateItinerary = onCall(
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

            const { tripId, regenerate = false } = request.data;
            const userId = request.auth.uid;

            // Get trip data
            const tripDoc = await db.collection('trips').doc(tripId).get();
            if (!tripDoc.exists) {
                throw new HttpsError('not-found', 'Trip not found');
            }

            const trip = { id: tripDoc.id, ...tripDoc.data()! };
            
            // Verify permissions
            const isMember = trip.members?.some((m: any) => m.userId === userId);
            if (!isMember) {
                throw new HttpsError('permission-denied', 'Not authorized to modify this trip');
            }

            // Create planning context
            const context: PlanningContext = {
                trip,
                preferences: trip.preferences,
                constraints: trip.constraints,
                destinations: trip.destinations || [],
                duration: {
                    startDate: trip.startDate?.toDate() || new Date(),
                    endDate: trip.endDate?.toDate() || new Date(),
                    days: 0
                }
            };
            
            context.duration.days = Math.ceil(
                (context.duration.endDate.getTime() - context.duration.startDate.getTime()) / (24 * 60 * 60 * 1000)
            );

            logger.info('Starting AI itinerary generation', { tripId, userId, destinations: context.destinations });

            // Initialize planning agents
            const agents = initializePlanningAgents();
            
            // Multi-agent orchestration
            const itinerary = await orchestratePlanning(context, agents);

            // Save the generated itinerary
            const itineraryData = {
                tripId,
                ...itinerary,
                generatedBy: 'ai-orchestrator',
                generatedAt: FieldValue.serverTimestamp(),
                lastUpdatedAt: FieldValue.serverTimestamp()
            };

            const itineraryRef = await db.collection('itineraries').add(itineraryData);

            // Update trip
            await db.collection('trips').doc(tripId).update({
                itineraryId: itineraryRef.id,
                status: 'planned',
                updatedAt: FieldValue.serverTimestamp()
            });

            logger.info('AI itinerary generated successfully', { 
                tripId, 
                itineraryId: itineraryRef.id,
                days: itinerary.days?.length || 0
            });

            return {
                success: true,
                itinerary: { id: itineraryRef.id, ...itineraryData }
            };

        } catch (error) {
            logger.error('Error generating AI itinerary', { error, userId: request.auth?.uid });
            if (error instanceof HttpsError) {
                throw error;
            }
            throw new HttpsError('internal', 'Failed to generate itinerary');
        }
    }
);

/**
 * Get alternative suggestions for a segment
 */
export const getSegmentAlternatives = onCall(
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

            const { tripId, segmentId, preferences } = request.data;
            const userId = request.auth.uid;

            // Verify permissions
            const tripDoc = await db.collection('trips').doc(tripId).get();
            if (!tripDoc.exists) {
                throw new HttpsError('not-found', 'Trip not found');
            }

            const trip = tripDoc.data()!;
            const isMember = trip.members?.some((m: any) => m.userId === userId);
            if (!isMember) {
                throw new HttpsError('permission-denied', 'Not authorized to view this trip');
            }

            // Get current segment
            const itineraryDoc = await db.collection('itineraries').doc(trip.itineraryId).get();
            if (!itineraryDoc.exists) {
                throw new HttpsError('not-found', 'Itinerary not found');
            }

            const itinerary = itineraryDoc.data()!;
            let currentSegment = null;
            
            for (const day of itinerary.days) {
                const segment = day.segments.find((s: any) => s.id === segmentId);
                if (segment) {
                    currentSegment = segment;
                    break;
                }
            }

            if (!currentSegment) {
                throw new HttpsError('not-found', 'Segment not found');
            }

            // Generate alternatives using AI
            const alternatives = await generateSegmentAlternatives(currentSegment, trip, preferences);

            return { success: true, alternatives };

        } catch (error) {
            logger.error('Error getting segment alternatives', { error, userId: request.auth?.uid });
            if (error instanceof HttpsError) {
                throw error;
            }
            throw new HttpsError('internal', 'Failed to get alternatives');
        }
    }
);

/**
 * Optimize itinerary based on user feedback
 */
export const optimizeItinerary = onCall(
    {
        region: 'us-central1',
        enforceAppCheck: true,
        cors: true,
        timeoutSeconds: 180
    },
    async (request) => {
        try {
            if (!request.auth) {
                throw new HttpsError('unauthenticated', 'Must be authenticated');
            }

            const { tripId, optimizationGoals, feedback } = request.data;
            const userId = request.auth.uid;

            // Verify permissions
            const tripDoc = await db.collection('trips').doc(tripId).get();
            if (!tripDoc.exists) {
                throw new HttpsError('not-found', 'Trip not found');
            }

            const trip = tripDoc.data()!;
            const isMember = trip.members?.some((m: any) => m.userId === userId);
            if (!isMember) {
                throw new HttpsError('permission-denied', 'Not authorized to modify this trip');
            }

            // Get current itinerary
            const itineraryDoc = await db.collection('itineraries').doc(trip.itineraryId).get();
            if (!itineraryDoc.exists) {
                throw new HttpsError('not-found', 'Itinerary not found');
            }

            const currentItinerary = itineraryDoc.data()!;

            // AI-powered optimization
            const optimizedItinerary = await optimizeWithAI(currentItinerary, optimizationGoals, feedback, trip);

            // Update itinerary
            await db.collection('itineraries').doc(trip.itineraryId).update({
                ...optimizedItinerary,
                lastOptimizedAt: FieldValue.serverTimestamp(),
                lastUpdatedAt: FieldValue.serverTimestamp()
            });

            logger.info('Itinerary optimized', { tripId, goals: optimizationGoals });

            return {
                success: true,
                itinerary: { id: trip.itineraryId, ...optimizedItinerary }
            };

        } catch (error) {
            logger.error('Error optimizing itinerary', { error, userId: request.auth?.uid });
            if (error instanceof HttpsError) {
                throw error;
            }
            throw new HttpsError('internal', 'Failed to optimize itinerary');
        }
    }
);

// Helper Functions

function initializePlanningAgents(): PlanningAgent[] {
    return [
        {
            name: 'destination-expert',
            role: 'Destination Research Specialist',
            expertise: ['local-knowledge', 'attractions', 'culture', 'seasonal-factors'],
            priority: 1
        },
        {
            name: 'logistics-coordinator',
            role: 'Travel Logistics Coordinator',
            expertise: ['transportation', 'scheduling', 'routing', 'timing'],
            priority: 2
        },
        {
            name: 'experience-curator',
            role: 'Experience Curator',
            expertise: ['activities', 'dining', 'entertainment', 'unique-experiences'],
            priority: 3
        },
        {
            name: 'budget-optimizer',
            role: 'Budget Optimization Specialist',
            expertise: ['cost-analysis', 'value-optimization', 'deals', 'pricing'],
            priority: 4
        },
        {
            name: 'accessibility-advisor',
            role: 'Accessibility & Inclusion Advisor',
            expertise: ['accessibility', 'dietary-restrictions', 'mobility', 'inclusive-travel'],
            priority: 5
        }
    ];
}

async function orchestratePlanning(context: PlanningContext, agents: PlanningAgent[]) {
    const agentResponses: AgentResponse[] = [];
    
    // Stage 1: Destination Analysis
    logger.info('AI Planning Stage 1: Destination Analysis');
    const destinationAgent = agents.find(a => a.name === 'destination-expert')!;
    const destinationAnalysis = await callPlanningAgent(destinationAgent, 'destination-analysis', context);
    agentResponses.push(destinationAnalysis);
    
    // Stage 2: Logistics Planning
    logger.info('AI Planning Stage 2: Logistics Planning');
    const logisticsAgent = agents.find(a => a.name === 'logistics-coordinator')!;
    const logisticsContext = { ...context, destinationInsights: destinationAnalysis.data };
    const logisticsPlan = await callPlanningAgent(logisticsAgent, 'logistics-planning', logisticsContext);
    agentResponses.push(logisticsPlan);
    
    // Stage 3: Experience Curation
    logger.info('AI Planning Stage 3: Experience Curation');
    const curatorAgent = agents.find(a => a.name === 'experience-curator')!;
    const curatorContext = { 
        ...context, 
        destinationInsights: destinationAnalysis.data,
        logisticsPlan: logisticsPlan.data
    };
    const experiencesPlan = await callPlanningAgent(curatorAgent, 'experience-curation', curatorContext);
    agentResponses.push(experiencesPlan);
    
    // Stage 4: Budget Optimization
    logger.info('AI Planning Stage 4: Budget Optimization');
    const budgetAgent = agents.find(a => a.name === 'budget-optimizer')!;
    const budgetContext = {
        ...context,
        destinationInsights: destinationAnalysis.data,
        logisticsPlan: logisticsPlan.data,
        experiencesPlan: experiencesPlan.data
    };
    const budgetOptimization = await callPlanningAgent(budgetAgent, 'budget-optimization', budgetContext);
    agentResponses.push(budgetOptimization);
    
    // Stage 5: Accessibility Review
    logger.info('AI Planning Stage 5: Accessibility Review');
    if (context.preferences?.accessibilityNeeds?.length > 0 || context.constraints?.accessibility?.length > 0) {
        const accessibilityAgent = agents.find(a => a.name === 'accessibility-advisor')!;
        const accessibilityContext = {
            ...context,
            preliminaryPlan: {
                destinations: destinationAnalysis.data,
                logistics: logisticsPlan.data,
                experiences: experiencesPlan.data,
                budget: budgetOptimization.data
            }
        };
        const accessibilityReview = await callPlanningAgent(accessibilityAgent, 'accessibility-review', accessibilityContext);
        agentResponses.push(accessibilityReview);
    }
    
    // Final Integration
    logger.info('AI Planning Stage 6: Final Integration');
    const finalItinerary = await integratePlanningResults(context, agentResponses);
    
    return finalItinerary;
}

async function callPlanningAgent(agent: PlanningAgent, stage: string, context: any): Promise<AgentResponse> {
    const systemPrompt = `You are ${agent.role}, specializing in ${agent.expertise.join(', ')}. 
    Your task is to contribute to travel itinerary planning for the ${stage} stage.
    
    Provide detailed, actionable recommendations based on your expertise.
    Consider the traveler's preferences, constraints, and the overall trip context.
    
    Respond with a JSON object containing:
    - recommendations: detailed suggestions for your area of expertise
    - confidence: 0-1 confidence score
    - alternatives: alternative options if applicable  
    - reasoning: explanation of your recommendations
    - considerations: important factors to note
    `;
    
    const userPrompt = `
    Trip Context:
    - Destinations: ${context.destinations.join(', ')}
    - Duration: ${context.duration.days} days (${context.duration.startDate.toDateString()} to ${context.duration.endDate.toDateString()})
    - Travel Style: ${context.constraints.travelStyle}
    - Budget: ${context.constraints.budget ? `${context.constraints.budget.amount} ${context.constraints.budget.currency}` : 'Not specified'}
    - Group Size: ${context.trip.members?.length || 1}
    - Preferences: ${JSON.stringify(context.preferences || {})}
    - Constraints: ${JSON.stringify(context.constraints)}
    
    Additional Context:
    ${JSON.stringify(context, null, 2)}
    
    Please provide your ${stage} recommendations.
    `;
    
    try {
        const response = await callOpenAI([
            { role: 'system', content: systemPrompt },
            { role: 'user', content: userPrompt }
        ], {
            model: 'gpt-4',
            temperature: 0.7,
            max_tokens: 2000
        });
        
        const agentData = JSON.parse(response);
        
        return {
            agent: agent.name,
            stage,
            data: agentData.recommendations,
            confidence: agentData.confidence || 0.8,
            alternatives: agentData.alternatives,
            reasoning: agentData.reasoning
        };
        
    } catch (error) {
        logger.warn(`Agent ${agent.name} failed for stage ${stage}`, { error });
        
        // Fallback response
        return {
            agent: agent.name,
            stage,
            data: { status: 'fallback', message: 'Agent processing failed' },
            confidence: 0.1,
            reasoning: 'Fallback due to processing error'
        };
    }
}

async function integratePlanningResults(context: PlanningContext, agentResponses: AgentResponse[]) {
    const integrationPrompt = `
    Integrate the following AI agent recommendations into a complete, detailed travel itinerary:
    
    Trip Context:
    ${JSON.stringify(context, null, 2)}
    
    Agent Recommendations:
    ${JSON.stringify(agentResponses, null, 2)}
    
    Create a comprehensive itinerary with the following structure:
    {
        "days": [
            {
                "dayNumber": 1,
                "date": "2024-01-01",
                "title": "Day Title",
                "segments": [
                    {
                        "id": "unique_id",
                        "type": "activity|meal|transport|accommodation|free_time",
                        "title": "Segment Title",
                        "description": "Detailed description",
                        "startTime": "09:00",
                        "endTime": "11:00",
                        "duration": 7200,
                        "location": {
                            "latitude": 40.7128,
                            "longitude": -74.0060,
                            "address": "Full Address"
                        },
                        "cost": {
                            "amount": 25,
                            "currency": "USD"
                        },
                        "bookingStatus": "required|optional|confirmed",
                        "provider": "Provider Name",
                        "notes": "Additional notes",
                        "tags": ["tag1", "tag2"]
                    }
                ],
                "dailyBudget": {
                    "amount": 150,
                    "currency": "USD"
                },
                "transportSummary": "Daily transport overview"
            }
        ],
        "totalCost": {
            "amount": 1500,
            "currency": "USD"
        },
        "status": "draft",
        "metadata": {
            "generationMethod": "ai-orchestration",
            "agentsUsed": ["agent1", "agent2"],
            "confidence": 0.85,
            "alternatives": []
        }
    }
    
    Ensure the itinerary is:
    1. Realistic and feasible
    2. Well-paced with appropriate timing
    3. Geographically logical
    4. Budget-conscious
    5. Aligned with traveler preferences
    6. Accessible if needed
    `;
    
    try {
        const response = await callOpenAI([
            { role: 'system', content: 'You are an expert travel planner integrating AI recommendations into a detailed itinerary.' },
            { role: 'user', content: integrationPrompt }
        ], {
            model: 'gpt-4',
            temperature: 0.3,
            max_tokens: 4000
        });
        
        const itinerary = JSON.parse(response);
        
        // Add timestamps to dates
        if (itinerary.days) {
            for (const day of itinerary.days) {
                day.date = Timestamp.fromDate(new Date(day.date));
                if (day.segments) {
                    for (const segment of day.segments) {
                        // Convert time strings to proper timestamps
                        if (segment.startTime && segment.endTime) {
                            const dayDate = day.date.toDate();
                            const [startHour, startMin] = segment.startTime.split(':').map(Number);
                            const [endHour, endMin] = segment.endTime.split(':').map(Number);
                            
                            segment.startTime = Timestamp.fromDate(
                                new Date(dayDate.getFullYear(), dayDate.getMonth(), dayDate.getDate(), startHour, startMin)
                            );
                            segment.endTime = Timestamp.fromDate(
                                new Date(dayDate.getFullYear(), dayDate.getMonth(), dayDate.getDate(), endHour, endMin)
                            );
                        }
                    }
                }
            }
        }
        
        return itinerary;
        
    } catch (error) {
        logger.error('Failed to integrate planning results', { error });
        throw new HttpsError('internal', 'Failed to generate integrated itinerary');
    }
}

async function generateSegmentAlternatives(segment: any, trip: any, preferences: any = {}) {
    const prompt = `
    Generate 3-5 alternative options for this travel segment:
    
    Current Segment:
    ${JSON.stringify(segment, null, 2)}
    
    Trip Context:
    - Destinations: ${trip.destinations?.join(', ') || 'Unknown'}
    - Travel Style: ${trip.constraints?.travelStyle || 'balanced'}
    - Budget Level: ${trip.constraints?.budget ? 'Set' : 'Flexible'}
    
    User Preferences:
    ${JSON.stringify(preferences, null, 2)}
    
    Provide alternatives that:
    1. Maintain the same general purpose/timing
    2. Offer different experiences/price points
    3. Suit different preferences or moods
    4. Are realistic and bookable
    
    Return JSON array of alternative segments with the same structure as the original.
    `;
    
    try {
        const response = await callOpenAI([
            { role: 'system', content: 'You are a creative travel advisor providing diverse alternatives for travel activities.' },
            { role: 'user', content: prompt }
        ]);
        
        return JSON.parse(response);
        
    } catch (error) {
        logger.error('Failed to generate segment alternatives', { error });
        return [];
    }
}

async function optimizeWithAI(itinerary: any, goals: string[], feedback: string, trip: any) {
    const prompt = `
    Optimize this travel itinerary based on the specified goals and user feedback:
    
    Current Itinerary:
    ${JSON.stringify(itinerary, null, 2)}
    
    Optimization Goals: ${goals.join(', ')}
    
    User Feedback:
    "${feedback}"
    
    Trip Context:
    ${JSON.stringify(trip, null, 2)}
    
    Apply optimizations while maintaining the overall trip structure. Focus on:
    ${goals.map(goal => {
        switch(goal) {
            case 'cost': return '- Reducing costs without sacrificing quality';
            case 'time': return '- Improving efficiency and reducing travel time';
            case 'comfort': return '- Enhancing comfort and reducing stress';
            case 'experience': return '- Maximizing unique and memorable experiences';
            case 'safety': return '- Prioritizing safer options and locations';
            case 'sustainability': return '- Choosing more environmentally friendly options';
            default: return `- Optimizing for ${goal}`;
        }
    }).join('\n')}
    
    Return the optimized itinerary with the same structure, highlighting what was changed.
    `;
    
    try {
        const response = await callOpenAI([
            { role: 'system', content: 'You are an expert travel optimizer improving itineraries based on specific goals and feedback.' },
            { role: 'user', content: prompt }
        ], {
            model: 'gpt-4',
            temperature: 0.4
        });
        
        const optimizedItinerary = JSON.parse(response);
        
        // Ensure timestamps are preserved
        if (optimizedItinerary.days && itinerary.days) {
            for (let i = 0; i < optimizedItinerary.days.length; i++) {
                const optimizedDay = optimizedItinerary.days[i];
                const originalDay = itinerary.days[i];
                
                if (originalDay && optimizedDay) {
                    optimizedDay.date = originalDay.date;
                    
                    if (optimizedDay.segments && originalDay.segments) {
                        for (let j = 0; j < optimizedDay.segments.length; j++) {
                            const optimizedSegment = optimizedDay.segments[j];
                            const originalSegment = originalDay.segments[j];
                            
                            if (originalSegment && optimizedSegment) {
                                // Preserve timing if not explicitly changed
                                if (typeof optimizedSegment.startTime === 'string') {
                                    optimizedSegment.startTime = originalSegment.startTime;
                                }
                                if (typeof optimizedSegment.endTime === 'string') {
                                    optimizedSegment.endTime = originalSegment.endTime;
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return optimizedItinerary;
        
    } catch (error) {
        logger.error('Failed to optimize itinerary with AI', { error });
        throw new HttpsError('internal', 'Failed to optimize itinerary');
    }
}