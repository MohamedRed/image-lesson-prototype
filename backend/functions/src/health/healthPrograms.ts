import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';

const db = getFirestore();

interface HealthGoal {
  id: string;
  userId: string;
  title: string;
  description: string;
  type: 'weightLoss' | 'weightGain' | 'stepsDaily' | 'exerciseMinutes' | 'sleepHours' | 'waterIntake' | 'caloriesBurned';
  targetValue: number;
  currentValue: number;
  unit: string;
  targetDate: string;
  priority: 'low' | 'medium' | 'high';
  status: 'active' | 'paused' | 'completed' | 'archived';
  createdAt: string;
  updatedAt: string;
}

interface HealthProgram {
  id: string;
  userId: string;
  title: string;
  description: string;
  type: 'fitness' | 'nutrition' | 'mental-health' | 'sleep' | 'medical' | 'lifestyle';
  goal: HealthGoal;
  duration: number; // days
  difficulty: 'beginner' | 'intermediate' | 'advanced';
  status: 'active' | 'paused' | 'completed' | 'archived';
  progress: number; // 0.0 to 1.0
  completedSteps: number;
  totalSteps: number;
  steps: ProgramStep[];
  expectedOutcomes: ExpectedOutcome[];
  schedule: ProgramSchedule;
  createdAt: string;
  updatedAt: string;
  completedAt?: string;
}

interface ProgramStep {
  id: string;
  programId: string;
  title: string;
  description: string;
  instructions: string[];
  category: 'exercise' | 'nutrition' | 'mindfulness' | 'sleep' | 'medical' | 'tracking';
  estimatedDuration?: number; // minutes
  isCompleted: boolean;
  completedAt?: string;
  scheduledDate: string;
  resources: ProgramResource[];
  metadata?: Record<string, any>;
}

interface ProgramResource {
  type: 'video' | 'article' | 'audio' | 'image' | 'pdf';
  title: string;
  url: string;
  description?: string;
}

interface ExpectedOutcome {
  id: string;
  description: string;
  timeframe: string;
  confidenceScore: number; // 0.0 to 1.0
  metrics: string[];
}

interface ProgramSchedule {
  frequency: 'daily' | 'weekly' | 'custom';
  daysOfWeek?: string[];
  timeOfDay?: 'morning' | 'afternoon' | 'evening' | 'flexible';
  duration: number; // total program duration in days
  intensity: 'low' | 'moderate' | 'high';
}

interface CreateProgramRequest {
  goal: HealthGoal;
}

interface CreateProgramResponse {
  program: HealthProgram;
  recommendation: {
    reason: string;
    estimatedCompletionDate: string;
    successProbability: number;
  };
}

interface ProgressUpdateRequest {
  stepId: string;
  completed: boolean;
  feedback?: string;
  metrics?: Record<string, number>;
}

// Create a new health program
export const createProgram = onCall<CreateProgramRequest, CreateProgramResponse>(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request: CallableRequest<CreateProgramRequest>): Promise<CreateProgramResponse> => {
    try {
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const userId = request.auth.uid;
      const { goal } = request.data;

      logger.info(`Creating health program for user: ${userId}, goal: ${goal.type}`);

      // Generate program based on goal
      const program = await generateProgramForGoal(userId, goal);

      // Save program to Firestore
      const programRef = await db.collection('healthPrograms').add({
        ...program,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp()
      });

      // Generate and save program steps
      const steps = await generateProgramSteps(programRef.id, goal);
      
      const batch = db.batch();
      steps.forEach(step => {
        const stepRef = db.collection('programSteps').doc();
        batch.set(stepRef, {
          ...step,
          id: stepRef.id,
          programId: programRef.id,
          createdAt: FieldValue.serverTimestamp()
        });
      });
      await batch.commit();

      // Calculate recommendation
      const userProfile = await getUserHealthProfile(userId);
      const recommendation = await calculateProgramRecommendation(program, userProfile);

      const finalProgram: HealthProgram = {
        ...program,
        id: programRef.id,
        steps,
        totalSteps: steps.length
      };

      const response: CreateProgramResponse = {
        program: finalProgram,
        recommendation
      };

      logger.info(`Successfully created health program: ${programRef.id}`);
      return response;

    } catch (error) {
      logger.error('Error creating program:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to create program');
    }
  }
);

// Get user's health programs
export const getPrograms = onCall<{}, HealthProgram[]>(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request: CallableRequest<{}>): Promise<HealthProgram[]> => {
    try {
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const userId = request.auth.uid;

      // Get programs
      const programsQuery = await db
        .collection('healthPrograms')
        .where('userId', '==', userId)
        .orderBy('updatedAt', 'desc')
        .get();

      const programs: HealthProgram[] = [];

      for (const programDoc of programsQuery.docs) {
        const programData = programDoc.data();
        
        // Get program steps
        const stepsQuery = await db
          .collection('programSteps')
          .where('programId', '==', programDoc.id)
          .orderBy('scheduledDate', 'asc')
          .get();

        const steps: ProgramStep[] = stepsQuery.docs.map(stepDoc => {
          const stepData = stepDoc.data();
          return {
            id: stepDoc.id,
            programId: programDoc.id,
            title: stepData.title,
            description: stepData.description,
            instructions: stepData.instructions || [],
            category: stepData.category,
            estimatedDuration: stepData.estimatedDuration,
            isCompleted: stepData.isCompleted || false,
            completedAt: stepData.completedAt?.toDate?.().toISOString(),
            scheduledDate: stepData.scheduledDate,
            resources: stepData.resources || [],
            metadata: stepData.metadata
          };
        });

        const completedSteps = steps.filter(s => s.isCompleted).length;
        const progress = steps.length > 0 ? completedSteps / steps.length : 0;

        programs.push({
          id: programDoc.id,
          userId: programData.userId,
          title: programData.title,
          description: programData.description,
          type: programData.type,
          goal: programData.goal,
          duration: programData.duration,
          difficulty: programData.difficulty,
          status: programData.status,
          progress,
          completedSteps,
          totalSteps: steps.length,
          steps,
          expectedOutcomes: programData.expectedOutcomes || [],
          schedule: programData.schedule,
          createdAt: programData.createdAt?.toDate?.().toISOString() || new Date().toISOString(),
          updatedAt: programData.updatedAt?.toDate?.().toISOString() || new Date().toISOString(),
          completedAt: programData.completedAt?.toDate?.().toISOString()
        });
      }

      return programs;

    } catch (error) {
      logger.error('Error getting programs:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to get programs');
    }
  }
);

// Update program progress
export const updateProgramProgress = onCall<ProgressUpdateRequest, HealthProgram>(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request: CallableRequest<ProgressUpdateRequest>): Promise<HealthProgram> => {
    try {
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const userId = request.auth.uid;
      const { stepId, completed, feedback, metrics } = request.data;

      // Get the step
      const stepDoc = await db.collection('programSteps').doc(stepId).get();
      if (!stepDoc.exists) {
        throw new HttpsError('not-found', 'Program step not found');
      }

      const stepData = stepDoc.data()!;
      const programId = stepData.programId;

      // Verify program belongs to user
      const programDoc = await db.collection('healthPrograms').doc(programId).get();
      if (!programDoc.exists || programDoc.data()!.userId !== userId) {
        throw new HttpsError('permission-denied', 'Access denied');
      }

      // Update step completion
      const updates: any = {
        isCompleted: completed,
        updatedAt: FieldValue.serverTimestamp()
      };

      if (completed) {
        updates.completedAt = FieldValue.serverTimestamp();
        
        // Save feedback if provided
        if (feedback) {
          updates.feedback = feedback;
        }
        
        // Save metrics if provided
        if (metrics) {
          updates.completionMetrics = metrics;
        }
      } else {
        updates.completedAt = null;
        updates.feedback = null;
        updates.completionMetrics = null;
      }

      await stepDoc.ref.update(updates);

      // Record progress event
      await db.collection('programProgressEvents').add({
        userId,
        programId,
        stepId,
        action: completed ? 'completed' : 'uncompleted',
        feedback,
        metrics,
        timestamp: FieldValue.serverTimestamp()
      });

      // Update program progress
      await updateProgramStats(programId);

      // Get updated program
      const updatedPrograms = await getPrograms.handler({
        auth: request.auth,
        data: {}
      } as CallableRequest<{}>);

      const updatedProgram = updatedPrograms.find(p => p.id === programId);
      if (!updatedProgram) {
        throw new HttpsError('internal', 'Failed to retrieve updated program');
      }

      logger.info(`Updated program progress: ${programId}, step: ${stepId}, completed: ${completed}`);
      return updatedProgram;

    } catch (error) {
      logger.error('Error updating program progress:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to update program progress');
    }
  }
);

// Pause program
export const pauseProgram = onCall<{programId: string}, HealthProgram>(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request: CallableRequest<{programId: string}>): Promise<HealthProgram> => {
    return updateProgramStatus(request, 'paused');
  }
);

// Resume program
export const resumeProgram = onCall<{programId: string}, HealthProgram>(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request: CallableRequest<{programId: string}>): Promise<HealthProgram> => {
    return updateProgramStatus(request, 'active');
  }
);

// Helper function to update program status
async function updateProgramStatus(
  request: CallableRequest<{programId: string}>, 
  status: HealthProgram['status']
): Promise<HealthProgram> {
  try {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'User must be authenticated');
    }

    const userId = request.auth.uid;
    const { programId } = request.data;

    // Verify program belongs to user
    const programDoc = await db.collection('healthPrograms').doc(programId).get();
    if (!programDoc.exists || programDoc.data()!.userId !== userId) {
      throw new HttpsError('permission-denied', 'Access denied');
    }

    // Update program status
    await programDoc.ref.update({
      status,
      updatedAt: FieldValue.serverTimestamp()
    });

    // Get updated program
    const updatedPrograms = await getPrograms.handler({
      auth: request.auth,
      data: {}
    } as CallableRequest<{}>);

    const updatedProgram = updatedPrograms.find(p => p.id === programId);
    if (!updatedProgram) {
      throw new HttpsError('internal', 'Failed to retrieve updated program');
    }

    logger.info(`Updated program status: ${programId} to ${status}`);
    return updatedProgram;

  } catch (error) {
    logger.error(`Error updating program status to ${status}:`, error);
    
    if (error instanceof HttpsError) {
      throw error;
    }
    
    throw new HttpsError('internal', `Failed to ${status} program`);
  }
}

// Generate program based on user goal
async function generateProgramForGoal(userId: string, goal: HealthGoal): Promise<Omit<HealthProgram, 'id' | 'steps' | 'createdAt' | 'updatedAt'>> {
  const programTemplates: Record<HealthGoal['type'], Partial<HealthProgram>> = {
    weightLoss: {
      title: 'Weight Loss Journey',
      description: 'A comprehensive program combining nutrition, exercise, and habit formation to achieve your weight loss goals.',
      type: 'fitness',
      duration: 90,
      difficulty: 'beginner'
    },
    weightGain: {
      title: 'Healthy Weight Gain',
      description: 'Build lean muscle and gain weight healthily through structured nutrition and strength training.',
      type: 'fitness',
      duration: 120,
      difficulty: 'intermediate'
    },
    stepsDaily: {
      title: 'Daily Steps Challenge',
      description: 'Gradually increase your daily activity level and build a sustainable walking habit.',
      type: 'fitness',
      duration: 30,
      difficulty: 'beginner'
    },
    exerciseMinutes: {
      title: 'Active Lifestyle Program',
      description: 'Develop a consistent exercise routine that fits into your daily schedule.',
      type: 'fitness',
      duration: 60,
      difficulty: 'intermediate'
    },
    sleepHours: {
      title: 'Sleep Optimization',
      description: 'Improve sleep quality and duration through evidence-based sleep hygiene practices.',
      type: 'sleep',
      duration: 45,
      difficulty: 'beginner'
    },
    waterIntake: {
      title: 'Hydration Mastery',
      description: 'Build healthy hydration habits and optimize your daily water intake.',
      type: 'nutrition',
      duration: 21,
      difficulty: 'beginner'
    },
    caloriesBurned: {
      title: 'Active Energy Program',
      description: 'Increase daily calorie expenditure through targeted activities and exercise.',
      type: 'fitness',
      duration: 75,
      difficulty: 'intermediate'
    }
  };

  const template = programTemplates[goal.type];
  const userProfile = await getUserHealthProfile(userId);

  // Customize difficulty based on user's fitness level
  let difficulty: HealthProgram['difficulty'] = template.difficulty || 'beginner';
  if (userProfile?.fitnessLevel === 'advanced') {
    difficulty = 'advanced';
  } else if (userProfile?.fitnessLevel === 'intermediate') {
    difficulty = 'intermediate';
  }

  // Generate expected outcomes
  const expectedOutcomes = generateExpectedOutcomes(goal);

  // Generate program schedule
  const schedule = generateProgramSchedule(goal, difficulty);

  return {
    userId,
    title: template.title!,
    description: template.description!,
    type: template.type!,
    goal,
    duration: template.duration!,
    difficulty,
    status: 'active',
    progress: 0,
    completedSteps: 0,
    totalSteps: 0,
    expectedOutcomes,
    schedule
  };
}

// Generate program steps
async function generateProgramSteps(programId: string, goal: HealthGoal): Promise<Omit<ProgramStep, 'id' | 'programId'>[]> {
  const stepTemplates: Record<HealthGoal['type'], Array<Omit<ProgramStep, 'id' | 'programId'>>> = {
    weightLoss: [
      {
        title: 'Set Your Baseline',
        description: 'Record your current weight, measurements, and take progress photos.',
        instructions: ['Step on the scale and record weight', 'Measure waist, hips, arms', 'Take front, side, and back photos'],
        category: 'tracking',
        estimatedDuration: 15,
        isCompleted: false,
        scheduledDate: new Date().toISOString().split('T')[0],
        resources: [
          {
            type: 'article',
            title: 'How to Track Weight Loss Progress',
            url: 'https://example.com/tracking-guide'
          }
        ]
      },
      {
        title: 'Plan Your Meals',
        description: 'Create a balanced meal plan for the week with appropriate calorie deficit.',
        instructions: ['Calculate daily calorie needs', 'Plan 3 meals and 2 snacks', 'Prepare grocery list'],
        category: 'nutrition',
        estimatedDuration: 30,
        isCompleted: false,
        scheduledDate: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString().split('T')[0],
        resources: []
      },
      {
        title: 'Start Moving',
        description: 'Begin with 20 minutes of light cardio activity.',
        instructions: ['Choose your preferred activity', 'Start with 20 minutes', 'Focus on consistency over intensity'],
        category: 'exercise',
        estimatedDuration: 20,
        isCompleted: false,
        scheduledDate: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
        resources: []
      }
    ],
    stepsDaily: [
      {
        title: 'Set Your Step Goal',
        description: 'Determine your current daily step average and set a realistic increase target.',
        instructions: ['Review last week\'s step data', 'Calculate daily average', 'Set goal 10% higher than current average'],
        category: 'tracking',
        estimatedDuration: 10,
        isCompleted: false,
        scheduledDate: new Date().toISOString().split('T')[0],
        resources: []
      }
    ],
    sleepHours: [
      {
        title: 'Sleep Assessment',
        description: 'Track your current sleep patterns for 3 days to establish baseline.',
        instructions: ['Record bedtime and wake time', 'Note sleep quality 1-10', 'Track any sleep disruptions'],
        category: 'tracking',
        estimatedDuration: 5,
        isCompleted: false,
        scheduledDate: new Date().toISOString().split('T')[0],
        resources: []
      }
    ],
    // Add more step templates for other goal types...
    weightGain: [],
    exerciseMinutes: [],
    waterIntake: [],
    caloriesBurned: []
  };

  return stepTemplates[goal.type] || [];
}

// Generate expected outcomes
function generateExpectedOutcomes(goal: HealthGoal): ExpectedOutcome[] {
  const outcomeTemplates: Record<HealthGoal['type'], ExpectedOutcome[]> = {
    weightLoss: [
      {
        id: 'weight-loss-1',
        description: 'Lose 1-2 lbs per week safely and sustainably',
        timeframe: '1-2 weeks',
        confidenceScore: 0.85,
        metrics: ['weight', 'body_fat_percentage']
      },
      {
        id: 'weight-loss-2',
        description: 'Develop healthier eating habits and portion control',
        timeframe: '2-4 weeks',
        confidenceScore: 0.9,
        metrics: ['calorie_intake', 'nutrition_score']
      }
    ],
    stepsDaily: [
      {
        id: 'steps-1',
        description: 'Increase daily step count by 20%',
        timeframe: '1-2 weeks',
        confidenceScore: 0.9,
        metrics: ['daily_steps', 'active_minutes']
      }
    ],
    // Add more outcome templates...
    sleepHours: [],
    weightGain: [],
    exerciseMinutes: [],
    waterIntake: [],
    caloriesBurned: []
  };

  return outcomeTemplates[goal.type] || [];
}

// Generate program schedule
function generateProgramSchedule(goal: HealthGoal, difficulty: HealthProgram['difficulty']): ProgramSchedule {
  const scheduleTemplates: Record<HealthGoal['type'], ProgramSchedule> = {
    weightLoss: {
      frequency: 'daily',
      daysOfWeek: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'],
      timeOfDay: 'flexible',
      duration: 90,
      intensity: difficulty === 'advanced' ? 'high' : difficulty === 'intermediate' ? 'moderate' : 'low'
    },
    stepsDaily: {
      frequency: 'daily',
      daysOfWeek: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'],
      timeOfDay: 'flexible',
      duration: 30,
      intensity: 'low'
    },
    sleepHours: {
      frequency: 'daily',
      daysOfWeek: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'],
      timeOfDay: 'evening',
      duration: 45,
      intensity: 'low'
    },
    // Add more schedule templates...
    weightGain: {
      frequency: 'daily',
      daysOfWeek: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'],
      timeOfDay: 'flexible',
      duration: 120,
      intensity: 'moderate'
    },
    exerciseMinutes: {
      frequency: 'weekly',
      daysOfWeek: ['monday', 'wednesday', 'friday'],
      timeOfDay: 'flexible',
      duration: 60,
      intensity: 'moderate'
    },
    waterIntake: {
      frequency: 'daily',
      daysOfWeek: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'],
      timeOfDay: 'flexible',
      duration: 21,
      intensity: 'low'
    },
    caloriesBurned: {
      frequency: 'daily',
      daysOfWeek: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
      timeOfDay: 'flexible',
      duration: 75,
      intensity: 'moderate'
    }
  };

  return scheduleTemplates[goal.type];
}

// Get user health profile for personalization
async function getUserHealthProfile(userId: string): Promise<any> {
  try {
    const profileDoc = await db.collection('healthProfiles').doc(userId).get();
    return profileDoc.exists ? profileDoc.data() : null;
  } catch (error) {
    logger.warn('Could not get user health profile:', error);
    return null;
  }
}

// Calculate program recommendation
async function calculateProgramRecommendation(program: any, userProfile: any): Promise<CreateProgramResponse['recommendation']> {
  // Simple recommendation logic - would be more sophisticated in production
  const estimatedCompletionDate = new Date();
  estimatedCompletionDate.setDate(estimatedCompletionDate.getDate() + program.duration);

  let successProbability = 0.7; // Base probability
  
  // Adjust based on user factors
  if (userProfile?.completedPrograms > 0) {
    successProbability += 0.2;
  }
  
  if (program.difficulty === 'beginner') {
    successProbability += 0.1;
  } else if (program.difficulty === 'advanced') {
    successProbability -= 0.1;
  }

  // Cap at 95%
  successProbability = Math.min(successProbability, 0.95);

  return {
    reason: `This program is tailored to your ${program.goal.type} goal with a ${program.difficulty} difficulty level that matches your experience.`,
    estimatedCompletionDate: estimatedCompletionDate.toISOString(),
    successProbability
  };
}

// Update program statistics
async function updateProgramStats(programId: string) {
  const stepsQuery = await db
    .collection('programSteps')
    .where('programId', '==', programId)
    .get();

  const totalSteps = stepsQuery.size;
  const completedSteps = stepsQuery.docs.filter(doc => doc.data().isCompleted).length;
  const progress = totalSteps > 0 ? completedSteps / totalSteps : 0;

  let status = 'active';
  if (progress === 1.0) {
    status = 'completed';
  }

  const updates: any = {
    totalSteps,
    completedSteps,
    progress,
    status,
    updatedAt: FieldValue.serverTimestamp()
  };

  if (status === 'completed') {
    updates.completedAt = FieldValue.serverTimestamp();
  }

  await db.collection('healthPrograms').doc(programId).update(updates);
}