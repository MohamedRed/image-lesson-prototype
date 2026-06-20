import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';

const db = getFirestore();

interface MealNutritionData {
  mealId: string;
  userId: string;
  mealType: 'breakfast' | 'lunch' | 'dinner' | 'snack';
  consumedAt: string;
  nutrition: {
    calories: number;
    protein: number;
    carbs: number;
    fat: number;
    fiber: number;
    sodium: number;
    sugar: number;
  };
  ingredients: Array<{
    name: string;
    amount: number;
    unit: string;
  }>;
}

interface ActivityData {
  activityId: string;
  userId: string;
  activityType: 'workout' | 'sports' | 'outdoor' | 'class';
  name: string;
  duration: number; // minutes
  intensity: 'low' | 'moderate' | 'high';
  caloriesBurned?: number;
  heartRateAvg?: number;
  startTime: string;
  endTime: string;
}

interface HealthIntegrationEvent {
  eventType: 'meal_logged' | 'activity_completed' | 'goal_updated' | 'program_completed';
  sourceService: 'meal_planning' | 'activities' | 'ride_sharing' | 'health';
  targetService: string[];
  data: any;
  userId: string;
  timestamp: string;
}

// Sync meal nutrition data from Meal Planning service
export const syncMealNutritionData = onCall<{mealId: string}, {synced: boolean}>(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request: CallableRequest<{mealId: string}>): Promise<{synced: boolean}> => {
    try {
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const userId = request.auth.uid;
      const { mealId } = request.data;

      logger.info(`Syncing meal nutrition data for user: ${userId}, meal: ${mealId}`);

      // Get meal data from Meal Planning service
      const mealDoc = await db.collection('meals').doc(mealId).get();
      
      if (!mealDoc.exists || mealDoc.data()?.userId !== userId) {
        throw new HttpsError('not-found', 'Meal not found or access denied');
      }

      const mealData = mealDoc.data()!;
      
      // Create nutrition observations for health tracking
      const nutritionObservations = createNutritionObservations(mealData, userId);
      
      // Save nutrition data to health observations
      const batch = db.batch();
      
      nutritionObservations.forEach(obs => {
        const obsRef = db.collection('healthObservations').doc();
        batch.set(obsRef, {
          ...obs,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp()
        });
      });

      await batch.commit();

      // Update daily nutrition summary
      await updateDailyNutritionSummary(userId, mealData);

      // Check nutrition goals and generate insights
      await checkNutritionGoals(userId, mealData);

      logger.info(`Successfully synced meal nutrition data for user: ${userId}`);
      return { synced: true };

    } catch (error) {
      logger.error('Error syncing meal nutrition data:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to sync meal nutrition data');
    }
  }
);

// Sync activity data from Activities service
export const syncActivityData = onCall<{activityId: string}, {synced: boolean}>(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request: CallableRequest<{activityId: string}>): Promise<{synced: boolean}> => {
    try {
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const userId = request.auth.uid;
      const { activityId } = request.data;

      logger.info(`Syncing activity data for user: ${userId}, activity: ${activityId}`);

      // Get activity data from Activities service
      const activityDoc = await db.collection('activities').doc(activityId).get();
      
      if (!activityDoc.exists || activityDoc.data()?.userId !== userId) {
        throw new HttpsError('not-found', 'Activity not found or access denied');
      }

      const activityData = activityDoc.data()!;
      
      // Create health observations from activity data
      const activityObservations = createActivityObservations(activityData, userId);
      
      // Save activity data to health observations
      const batch = db.batch();
      
      activityObservations.forEach(obs => {
        const obsRef = db.collection('healthObservations').doc();
        batch.set(obsRef, {
          ...obs,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp()
        });
      });

      await batch.commit();

      // Update daily activity summary
      await updateDailyActivitySummary(userId, activityData);

      // Check activity goals and generate insights
      await checkActivityGoals(userId, activityData);

      // Update health programs based on activity
      await updateHealthProgramsFromActivity(userId, activityData);

      logger.info(`Successfully synced activity data for user: ${userId}`);
      return { synced: true };

    } catch (error) {
      logger.error('Error syncing activity data:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to sync activity data');
    }
  }
);

// Auto-sync trigger for meal planning events
export const onMealPlanningEvent = onDocumentWritten('meals/{mealId}', async (event) => {
  try {
    const snapshot = event.data;
    if (!snapshot) return;

    const mealData = snapshot.after.exists ? snapshot.after.data() : null;
    if (!mealData || !mealData.userId) return;

    const userId = mealData.userId;
    const mealId = event.params.mealId;

    logger.info(`Auto-syncing meal data for user: ${userId}, meal: ${mealId}`);

    // Check if meal was consumed (status changed to 'consumed')
    if (mealData.status === 'consumed' && 
        (!snapshot.before.exists || snapshot.before.data()?.status !== 'consumed')) {
      
      // Create nutrition observations
      const nutritionObservations = createNutritionObservations(mealData, userId);
      
      const batch = db.batch();
      
      nutritionObservations.forEach(obs => {
        const obsRef = db.collection('healthObservations').doc();
        batch.set(obsRef, {
          ...obs,
          source: 'meal_planning_auto',
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp()
        });
      });

      await batch.commit();
      await updateDailyNutritionSummary(userId, mealData);
    }

  } catch (error) {
    logger.error('Error in meal planning auto-sync:', error);
  }
});

// Auto-sync trigger for activities events
export const onActivitiesEvent = onDocumentWritten('activities/{activityId}', async (event) => {
  try {
    const snapshot = event.data;
    if (!snapshot) return;

    const activityData = snapshot.after.exists ? snapshot.after.data() : null;
    if (!activityData || !activityData.userId) return;

    const userId = activityData.userId;
    const activityId = event.params.activityId;

    logger.info(`Auto-syncing activity data for user: ${userId}, activity: ${activityId}`);

    // Check if activity was completed
    if (activityData.status === 'completed' && 
        (!snapshot.before.exists || snapshot.before.data()?.status !== 'completed')) {
      
      // Create activity observations
      const activityObservations = createActivityObservations(activityData, userId);
      
      const batch = db.batch();
      
      activityObservations.forEach(obs => {
        const obsRef = db.collection('healthObservations').doc();
        batch.set(obsRef, {
          ...obs,
          source: 'activities_auto',
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp()
        });
      });

      await batch.commit();
      await updateDailyActivitySummary(userId, activityData);
      await updateHealthProgramsFromActivity(userId, activityData);
    }

  } catch (error) {
    logger.error('Error in activities auto-sync:', error);
  }
});

// Integration with ride sharing for active transportation tracking
export const onRideSharingEvent = onDocumentWritten('rides/{rideId}', async (event) => {
  try {
    const snapshot = event.data;
    if (!snapshot) return;

    const rideData = snapshot.after.exists ? snapshot.after.data() : null;
    if (!rideData) return;

    // Track active transportation (walking, biking) as health activity
    if (rideData.transportMode === 'bike' || rideData.transportMode === 'walk') {
      const userId = rideData.passengerId; // or driverId based on context
      
      if (rideData.status === 'completed') {
        // Create activity observation for active transportation
        const transportObservation = {
          userId,
          type: rideData.transportMode === 'bike' ? 'cycling' : 'walking',
          value: {
            numeric: rideData.distance || 0,
            unit: 'km'
          },
          duration: rideData.duration || 0, // minutes
          source: 'ride_sharing',
          timestamp: rideData.completedAt || new Date().toISOString(),
          metadata: {
            rideId: event.params.rideId,
            startLocation: rideData.startLocation,
            endLocation: rideData.endLocation
          }
        };

        await db.collection('healthObservations').add({
          ...transportObservation,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp()
        });

        logger.info(`Tracked active transportation for user: ${userId}, mode: ${rideData.transportMode}`);
      }
    }

  } catch (error) {
    logger.error('Error in ride sharing auto-sync:', error);
  }
});

// Cross-service goal alignment
export const alignGoalsAcrossServices = onCall<{}, {aligned: number}>(
  {
    enforceAppCheck: true,
    cors: true,
  },
  async (request: CallableRequest<{}>): Promise<{aligned: number}> => {
    try {
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const userId = request.auth.uid;
      let alignedCount = 0;

      logger.info(`Aligning goals across services for user: ${userId}`);

      // Get health goals
      const healthGoalsQuery = await db
        .collection('healthGoals')
        .where('userId', '==', userId)
        .where('status', '==', 'active')
        .get();

      const healthGoals = healthGoalsQuery.docs.map(doc => ({ id: doc.id, ...doc.data() }));

      // Align with meal planning goals
      const mealGoalsQuery = await db
        .collection('mealPlanningGoals')
        .where('userId', '==', userId)
        .where('status', '==', 'active')
        .get();

      const mealGoals = mealGoalsQuery.docs.map(doc => ({ id: doc.id, ...doc.data() }));

      // Find related goals and create alignments
      const batch = db.batch();

      for (const healthGoal of healthGoals) {
        // Weight loss health goal ↔ Calorie tracking meal goal
        if (healthGoal.type === 'weightLoss') {
          const relatedMealGoal = mealGoals.find(g => g.type === 'calorie_deficit');
          if (relatedMealGoal) {
            const alignmentRef = db.collection('goalAlignments').doc();
            batch.set(alignmentRef, {
              userId,
              healthGoalId: healthGoal.id,
              mealGoalId: relatedMealGoal.id,
              alignmentType: 'weight_loss_calorie_deficit',
              createdAt: FieldValue.serverTimestamp()
            });
            alignedCount++;
          }
        }

        // Exercise health goal ↔ Activity goals
        if (healthGoal.type === 'exerciseMinutes') {
          const activitiesGoalsQuery = await db
            .collection('activityGoals')
            .where('userId', '==', userId)
            .where('type', '==', 'weekly_minutes')
            .where('status', '==', 'active')
            .get();

          activitiesGoalsQuery.docs.forEach(doc => {
            const activityGoal = { id: doc.id, ...doc.data() };
            const alignmentRef = db.collection('goalAlignments').doc();
            batch.set(alignmentRef, {
              userId,
              healthGoalId: healthGoal.id,
              activityGoalId: activityGoal.id,
              alignmentType: 'exercise_minutes_alignment',
              createdAt: FieldValue.serverTimestamp()
            });
            alignedCount++;
          });
        }
      }

      await batch.commit();

      logger.info(`Aligned ${alignedCount} goals across services for user: ${userId}`);
      return { aligned: alignedCount };

    } catch (error) {
      logger.error('Error aligning goals across services:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to align goals across services');
    }
  }
);

// Helper functions
function createNutritionObservations(mealData: any, userId: string): any[] {
  const observations = [];
  const nutrition = mealData.nutrition || {};
  const timestamp = mealData.consumedAt || mealData.createdAt || new Date().toISOString();

  // Create individual nutrition observations
  if (nutrition.calories) {
    observations.push({
      userId,
      type: 'calories',
      value: { numeric: nutrition.calories, unit: 'kcal' },
      source: 'meal_planning',
      timestamp,
      metadata: {
        mealId: mealData.id || mealData.mealId,
        mealType: mealData.mealType,
        mealName: mealData.name
      }
    });
  }

  if (nutrition.protein) {
    observations.push({
      userId,
      type: 'protein',
      value: { numeric: nutrition.protein, unit: 'g' },
      source: 'meal_planning',
      timestamp,
      metadata: { mealId: mealData.id || mealData.mealId, mealType: mealData.mealType }
    });
  }

  if (nutrition.carbs) {
    observations.push({
      userId,
      type: 'carbohydrates',
      value: { numeric: nutrition.carbs, unit: 'g' },
      source: 'meal_planning',
      timestamp,
      metadata: { mealId: mealData.id || mealData.mealId, mealType: mealData.mealType }
    });
  }

  if (nutrition.fat) {
    observations.push({
      userId,
      type: 'fat',
      value: { numeric: nutrition.fat, unit: 'g' },
      source: 'meal_planning',
      timestamp,
      metadata: { mealId: mealData.id || mealData.mealId, mealType: mealData.mealType }
    });
  }

  return observations;
}

function createActivityObservations(activityData: any, userId: string): any[] {
  const observations = [];
  const timestamp = activityData.endTime || activityData.completedAt || new Date().toISOString();

  // Exercise minutes
  if (activityData.duration) {
    observations.push({
      userId,
      type: 'exerciseMinutes',
      value: { numeric: activityData.duration, unit: 'minutes' },
      source: 'activities',
      timestamp,
      metadata: {
        activityId: activityData.id || activityData.activityId,
        activityType: activityData.activityType,
        activityName: activityData.name,
        intensity: activityData.intensity
      }
    });
  }

  // Calories burned
  if (activityData.caloriesBurned) {
    observations.push({
      userId,
      type: 'caloriesBurned',
      value: { numeric: activityData.caloriesBurned, unit: 'kcal' },
      source: 'activities',
      timestamp,
      metadata: { activityId: activityData.id || activityData.activityId, activityType: activityData.activityType }
    });
  }

  // Average heart rate
  if (activityData.heartRateAvg) {
    observations.push({
      userId,
      type: 'heartRate',
      value: { numeric: activityData.heartRateAvg, unit: 'bpm' },
      source: 'activities',
      timestamp,
      metadata: { activityId: activityData.id || activityData.activityId, context: 'exercise_average' }
    });
  }

  return observations;
}

async function updateDailyNutritionSummary(userId: string, mealData: any) {
  const date = new Date(mealData.consumedAt || mealData.createdAt).toISOString().split('T')[0];
  const nutritionRef = db.collection('dailyNutritionSummaries').doc(`${userId}_${date}`);

  const nutrition = mealData.nutrition || {};
  const updates: any = {};

  if (nutrition.calories) updates[`calories`] = FieldValue.increment(nutrition.calories);
  if (nutrition.protein) updates[`protein`] = FieldValue.increment(nutrition.protein);
  if (nutrition.carbs) updates[`carbohydrates`] = FieldValue.increment(nutrition.carbs);
  if (nutrition.fat) updates[`fat`] = FieldValue.increment(nutrition.fat);

  if (Object.keys(updates).length > 0) {
    await nutritionRef.set({
      userId,
      date,
      ...updates,
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });
  }
}

async function updateDailyActivitySummary(userId: string, activityData: any) {
  const date = new Date(activityData.endTime || activityData.completedAt).toISOString().split('T')[0];
  const activityRef = db.collection('dailyActivitySummaries').doc(`${userId}_${date}`);

  const updates: any = {};

  if (activityData.duration) {
    updates[`exerciseMinutes`] = FieldValue.increment(activityData.duration);
  }

  if (activityData.caloriesBurned) {
    updates[`caloriesBurned`] = FieldValue.increment(activityData.caloriesBurned);
  }

  if (Object.keys(updates).length > 0) {
    await activityRef.set({
      userId,
      date,
      ...updates,
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });
  }
}

async function checkNutritionGoals(userId: string, mealData: any) {
  // This would check if nutrition intake aligns with health goals
  // and generate insights or alerts if needed
  logger.info(`Checking nutrition goals for user: ${userId}`);
}

async function checkActivityGoals(userId: string, activityData: any) {
  // This would check if activity aligns with health goals
  // and update progress or generate insights
  logger.info(`Checking activity goals for user: ${userId}`);
}

async function updateHealthProgramsFromActivity(userId: string, activityData: any) {
  // This would update health program progress based on completed activities
  const activePrograms = await db
    .collection('healthPrograms')
    .where('userId', '==', userId)
    .where('status', '==', 'active')
    .get();

  for (const programDoc of activePrograms.docs) {
    const program = programDoc.data();
    
    // Check if activity matches any program steps
    const relevantSteps = await db
      .collection('programSteps')
      .where('programId', '==', programDoc.id)
      .where('category', '==', 'exercise')
      .where('isCompleted', '==', false)
      .get();

    // Mark relevant steps as completed based on activity
    const batch = db.batch();
    let stepsCompleted = 0;

    relevantSteps.docs.forEach(stepDoc => {
      const step = stepDoc.data();
      
      // Simple matching logic - could be more sophisticated
      if (activityData.duration >= (step.estimatedDuration || 0)) {
        batch.update(stepDoc.ref, {
          isCompleted: true,
          completedAt: FieldValue.serverTimestamp(),
          completedBy: 'activity_sync',
          linkedActivityId: activityData.id || activityData.activityId
        });
        stepsCompleted++;
      }
    });

    if (stepsCompleted > 0) {
      await batch.commit();
      logger.info(`Completed ${stepsCompleted} program steps for user: ${userId}`);
    }
  }
}