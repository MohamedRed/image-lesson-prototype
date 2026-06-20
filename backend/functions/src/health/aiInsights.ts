import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { VertexAI } from '@google-cloud/vertexai';

const db = getFirestore();

// Initialize Vertex AI
const vertex_ai = new VertexAI({
  project: process.env.GOOGLE_CLOUD_PROJECT || 'liive-health',
  location: 'us-central1',
});

const model = vertex_ai.preview.getGenerativeModel({
  model: 'gemini-1.5-pro-002',
  generationConfig: {
    maxOutputTokens: 2048,
    temperature: 0.3,
    topP: 0.8,
  },
});

interface HealthDataPoint {
  type: string;
  value: number | string;
  unit?: string;
  timestamp: string;
  source: string;
}

interface UserHealthProfile {
  demographics?: {
    age?: number;
    biologicalSex?: string;
    height?: number;
  };
  goals: Array<{
    type: string;
    targetValue: number;
    currentValue: number;
    targetDate: string;
  }>;
  conditions: string[];
  preferences: {
    activityLevel: 'low' | 'moderate' | 'high';
    dietaryRestrictions: string[];
  };
}

interface AIInsightRequest {
  analysisType: 'health_trends' | 'goal_progress' | 'anomaly_detection' | 'personalized_recommendations';
  timeframe?: 'week' | 'month' | 'quarter';
  dataTypes?: string[];
}

interface AIInsight {
  id: string;
  type: 'trend' | 'anomaly' | 'recommendation' | 'alert' | 'prediction';
  category: 'activity' | 'nutrition' | 'sleep' | 'mental' | 'medical' | 'goals';
  title: string;
  description: string;
  confidence: number; // 0-1
  severity: 'low' | 'medium' | 'high' | 'critical';
  recommendations: string[];
  evidencePoints: Array<{
    dataType: string;
    value: string;
    significance: string;
  }>;
  predictedOutcomes?: Array<{
    outcome: string;
    probability: number;
    timeframe: string;
  }>;
  aiModel: string;
  aiVersion: string;
  generatedAt: string;
}

// Generate AI-driven health insights
export const generateAIInsights = onCall<AIInsightRequest, AIInsight[]>(
  {
    enforceAppCheck: true,
    cors: true,
    timeoutSeconds: 60,
  },
  async (request: CallableRequest<AIInsightRequest>): Promise<AIInsight[]> => {
    try {
      if (!request.auth?.uid) {
        throw new HttpsError('unauthenticated', 'User must be authenticated');
      }

      const userId = request.auth.uid;
      const { analysisType, timeframe = 'month', dataTypes } = request.data;

      logger.info(`Generating AI insights for user: ${userId}, type: ${analysisType}`);

      // Get user's health profile and recent data
      const userProfile = await getUserHealthProfile(userId);
      const healthData = await getRecentHealthData(userId, timeframe, dataTypes);

      if (healthData.length === 0) {
        return [];
      }

      let insights: AIInsight[] = [];

      switch (analysisType) {
        case 'health_trends':
          insights = await analyzeHealthTrends(userId, userProfile, healthData);
          break;
        
        case 'goal_progress':
          insights = await analyzeGoalProgress(userId, userProfile, healthData);
          break;
        
        case 'anomaly_detection':
          insights = await detectHealthAnomalies(userId, userProfile, healthData);
          break;
        
        case 'personalized_recommendations':
          insights = await generatePersonalizedRecommendations(userId, userProfile, healthData);
          break;
        
        default:
          throw new HttpsError('invalid-argument', 'Invalid analysis type');
      }

      // Save insights to database
      if (insights.length > 0) {
        const batch = db.batch();
        
        insights.forEach(insight => {
          const insightRef = db.collection('aiGeneratedInsights').doc();
          batch.set(insightRef, {
            ...insight,
            id: insightRef.id,
            userId,
            createdAt: FieldValue.serverTimestamp()
          });
        });

        await batch.commit();
      }

      logger.info(`Generated ${insights.length} AI insights for user: ${userId}`);
      return insights;

    } catch (error) {
      logger.error('Error generating AI insights:', error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError('internal', 'Failed to generate AI insights');
    }
  }
);

// Analyze health trends using AI
async function analyzeHealthTrends(
  userId: string, 
  profile: UserHealthProfile, 
  healthData: HealthDataPoint[]
): Promise<AIInsight[]> {
  const insights: AIInsight[] = [];

  // Group data by type
  const dataByType = groupDataByType(healthData);

  for (const [dataType, dataPoints] of Object.entries(dataByType)) {
    if (dataPoints.length < 5) continue; // Need minimum data for trend analysis

    try {
      const trendAnalysis = await analyzeTrendWithAI(dataType, dataPoints, profile);
      if (trendAnalysis) {
        insights.push({
          id: '',
          type: 'trend',
          category: mapDataTypeToCategory(dataType),
          title: trendAnalysis.title,
          description: trendAnalysis.description,
          confidence: trendAnalysis.confidence,
          severity: trendAnalysis.severity,
          recommendations: trendAnalysis.recommendations,
          evidencePoints: trendAnalysis.evidence,
          aiModel: 'gemini-1.5-pro',
          aiVersion: '002',
          generatedAt: new Date().toISOString()
        });
      }
    } catch (error) {
      logger.warn(`Failed to analyze trend for ${dataType}:`, error);
    }
  }

  return insights;
}

// Analyze goal progress using AI
async function analyzeGoalProgress(
  userId: string,
  profile: UserHealthProfile,
  healthData: HealthDataPoint[]
): Promise<AIInsight[]> {
  const insights: AIInsight[] = [];

  for (const goal of profile.goals) {
    try {
      const relevantData = healthData.filter(d => isDataRelevantToGoal(d, goal));
      
      if (relevantData.length === 0) continue;

      const progressAnalysis = await analyzeGoalProgressWithAI(goal, relevantData, profile);
      if (progressAnalysis) {
        insights.push({
          id: '',
          type: 'recommendation',
          category: 'goals',
          title: progressAnalysis.title,
          description: progressAnalysis.description,
          confidence: progressAnalysis.confidence,
          severity: progressAnalysis.severity,
          recommendations: progressAnalysis.recommendations,
          evidencePoints: progressAnalysis.evidence,
          predictedOutcomes: progressAnalysis.predictions,
          aiModel: 'gemini-1.5-pro',
          aiVersion: '002',
          generatedAt: new Date().toISOString()
        });
      }
    } catch (error) {
      logger.warn(`Failed to analyze goal progress for ${goal.type}:`, error);
    }
  }

  return insights;
}

// Detect health anomalies using AI
async function detectHealthAnomalies(
  userId: string,
  profile: UserHealthProfile,
  healthData: HealthDataPoint[]
): Promise<AIInsight[]> {
  const insights: AIInsight[] = [];

  // Group data by type for anomaly detection
  const dataByType = groupDataByType(healthData);

  for (const [dataType, dataPoints] of Object.entries(dataByType)) {
    if (dataPoints.length < 10) continue; // Need sufficient data for anomaly detection

    try {
      const anomalies = await detectAnomaliesWithAI(dataType, dataPoints, profile);
      insights.push(...anomalies);
    } catch (error) {
      logger.warn(`Failed to detect anomalies for ${dataType}:`, error);
    }
  }

  return insights;
}

// Generate personalized recommendations using AI
async function generatePersonalizedRecommendations(
  userId: string,
  profile: UserHealthProfile,
  healthData: HealthDataPoint[]
): Promise<AIInsight[]> {
  try {
    const recommendations = await generateRecommendationsWithAI(profile, healthData);
    
    return recommendations.map(rec => ({
      id: '',
      type: 'recommendation',
      category: rec.category,
      title: rec.title,
      description: rec.description,
      confidence: rec.confidence,
      severity: rec.severity,
      recommendations: rec.actionItems,
      evidencePoints: rec.evidence,
      aiModel: 'gemini-1.5-pro',
      aiVersion: '002',
      generatedAt: new Date().toISOString()
    }));
  } catch (error) {
    logger.error('Failed to generate personalized recommendations:', error);
    return [];
  }
}

// Use AI to analyze trends
async function analyzeTrendWithAI(
  dataType: string,
  dataPoints: HealthDataPoint[],
  profile: UserHealthProfile
): Promise<any> {
  const prompt = createTrendAnalysisPrompt(dataType, dataPoints, profile);
  
  const result = await model.generateContent([{
    parts: [{ text: prompt }]
  }]);

  const response = result.response;
  if (response.candidates && response.candidates[0]?.content?.parts?.[0]?.text) {
    try {
      return JSON.parse(response.candidates[0].content.parts[0].text);
    } catch (error) {
      logger.warn('Failed to parse AI trend analysis response:', error);
      return null;
    }
  }

  return null;
}

// Use AI to analyze goal progress
async function analyzeGoalProgressWithAI(
  goal: any,
  relevantData: HealthDataPoint[],
  profile: UserHealthProfile
): Promise<any> {
  const prompt = createGoalProgressPrompt(goal, relevantData, profile);
  
  const result = await model.generateContent([{
    parts: [{ text: prompt }]
  }]);

  const response = result.response;
  if (response.candidates && response.candidates[0]?.content?.parts?.[0]?.text) {
    try {
      return JSON.parse(response.candidates[0].content.parts[0].text);
    } catch (error) {
      logger.warn('Failed to parse AI goal progress response:', error);
      return null;
    }
  }

  return null;
}

// Use AI to detect anomalies
async function detectAnomaliesWithAI(
  dataType: string,
  dataPoints: HealthDataPoint[],
  profile: UserHealthProfile
): Promise<AIInsight[]> {
  const prompt = createAnomalyDetectionPrompt(dataType, dataPoints, profile);
  
  const result = await model.generateContent([{
    parts: [{ text: prompt }]
  }]);

  const response = result.response;
  if (response.candidates && response.candidates[0]?.content?.parts?.[0]?.text) {
    try {
      const anomalies = JSON.parse(response.candidates[0].content.parts[0].text);
      return Array.isArray(anomalies) ? anomalies.map(a => ({
        ...a,
        id: '',
        type: 'anomaly',
        category: mapDataTypeToCategory(dataType),
        aiModel: 'gemini-1.5-pro',
        aiVersion: '002',
        generatedAt: new Date().toISOString()
      })) : [];
    } catch (error) {
      logger.warn('Failed to parse AI anomaly detection response:', error);
      return [];
    }
  }

  return [];
}

// Use AI to generate personalized recommendations
async function generateRecommendationsWithAI(
  profile: UserHealthProfile,
  healthData: HealthDataPoint[]
): Promise<any[]> {
  const prompt = createPersonalizedRecommendationsPrompt(profile, healthData);
  
  const result = await model.generateContent([{
    parts: [{ text: prompt }]
  }]);

  const response = result.response;
  if (response.candidates && response.candidates[0]?.content?.parts?.[0]?.text) {
    try {
      const recommendations = JSON.parse(response.candidates[0].content.parts[0].text);
      return Array.isArray(recommendations) ? recommendations : [];
    } catch (error) {
      logger.warn('Failed to parse AI recommendations response:', error);
      return [];
    }
  }

  return [];
}

// Create prompt for trend analysis
function createTrendAnalysisPrompt(
  dataType: string,
  dataPoints: HealthDataPoint[],
  profile: UserHealthProfile
): string {
  const dataValues = dataPoints.map(dp => `${dp.timestamp}: ${dp.value} ${dp.unit || ''}`).join('\n');
  
  return `
Analyze the following ${dataType} health data trend for a user:

User Profile:
- Age: ${profile.demographics?.age || 'Unknown'}
- Sex: ${profile.demographics?.biologicalSex || 'Unknown'}
- Activity Level: ${profile.preferences?.activityLevel || 'Unknown'}

Health Data (${dataType}):
${dataValues}

Please analyze this data and provide insights in the following JSON format:
{
  "title": "Brief title describing the trend",
  "description": "Detailed description of the trend and its significance",
  "confidence": 0.8,
  "severity": "low|medium|high|critical",
  "recommendations": ["actionable recommendation 1", "actionable recommendation 2"],
  "evidence": [
    {
      "dataType": "${dataType}",
      "value": "specific data point",
      "significance": "why this point is significant"
    }
  ]
}

Focus on:
1. Direction and magnitude of changes
2. Clinical significance relative to normal ranges
3. Consistency of patterns
4. Potential health implications
5. Actionable recommendations

Respond only with valid JSON.`;
}

// Create prompt for goal progress analysis
function createGoalProgressPrompt(
  goal: any,
  relevantData: HealthDataPoint[],
  profile: UserHealthProfile
): string {
  const dataValues = relevantData.map(dp => `${dp.timestamp}: ${dp.value} ${dp.unit || ''}`).join('\n');
  
  return `
Analyze goal progress for a user:

Goal Information:
- Type: ${goal.type}
- Target: ${goal.targetValue} ${goal.unit || ''}
- Current: ${goal.currentValue} ${goal.unit || ''}
- Deadline: ${goal.targetDate}

User Profile:
- Age: ${profile.demographics?.age || 'Unknown'}
- Activity Level: ${profile.preferences?.activityLevel || 'Unknown'}

Recent Data:
${dataValues}

Provide analysis in JSON format:
{
  "title": "Goal progress assessment title",
  "description": "Detailed progress analysis",
  "confidence": 0.9,
  "severity": "low|medium|high",
  "recommendations": ["specific action 1", "specific action 2"],
  "evidence": [
    {
      "dataType": "progress_rate",
      "value": "calculated rate",
      "significance": "what this means for goal achievement"
    }
  ],
  "predictions": [
    {
      "outcome": "likely outcome",
      "probability": 0.75,
      "timeframe": "when this might happen"
    }
  ]
}

Consider:
1. Current progress rate vs required rate
2. Trend consistency
3. Realistic timeline adjustments
4. Specific actions to improve progress

Respond only with valid JSON.`;
}

// Create prompt for anomaly detection
function createAnomalyDetectionPrompt(
  dataType: string,
  dataPoints: HealthDataPoint[],
  profile: UserHealthProfile
): string {
  const dataValues = dataPoints.map(dp => `${dp.timestamp}: ${dp.value} ${dp.unit || ''}`).join('\n');
  
  return `
Detect anomalies in the following health data:

Data Type: ${dataType}
User Age: ${profile.demographics?.age || 'Unknown'}
User Sex: ${profile.demographics?.biologicalSex || 'Unknown'}

Data Points:
${dataValues}

Identify any anomalies and return as JSON array:
[
  {
    "title": "Anomaly description",
    "description": "Detailed explanation of the anomaly",
    "confidence": 0.85,
    "severity": "low|medium|high|critical",
    "recommendations": ["immediate action 1", "monitoring step 2"],
    "evidencePoints": [
      {
        "dataType": "${dataType}",
        "value": "specific anomalous value",
        "significance": "why this is concerning"
      }
    ]
  }
]

Look for:
1. Values outside normal ranges for age/sex
2. Sudden significant changes
3. Concerning patterns
4. Missing expected patterns

Return empty array [] if no anomalies found.
Respond only with valid JSON.`;
}

// Create prompt for personalized recommendations
function createPersonalizedRecommendationsPrompt(
  profile: UserHealthProfile,
  healthData: HealthDataPoint[]
): string {
  const dataByType = groupDataByType(healthData);
  const dataSummary = Object.entries(dataByType).map(([type, points]) => 
    `${type}: ${points.length} data points, latest: ${points[0]?.value} ${points[0]?.unit || ''}`
  ).join('\n');
  
  return `
Generate personalized health recommendations based on:

User Profile:
- Age: ${profile.demographics?.age || 'Unknown'}
- Sex: ${profile.demographics?.biologicalSex || 'Unknown'}
- Activity Level: ${profile.preferences?.activityLevel || 'Unknown'}
- Conditions: ${profile.conditions.join(', ') || 'None reported'}
- Goals: ${profile.goals.map(g => `${g.type} (${g.currentValue}/${g.targetValue})`).join(', ')}

Recent Health Data Summary:
${dataSummary}

Generate actionable recommendations in JSON format:
[
  {
    "category": "activity|nutrition|sleep|mental|medical",
    "title": "Recommendation title",
    "description": "Detailed recommendation explanation",
    "confidence": 0.8,
    "severity": "low|medium|high",
    "actionItems": ["specific action 1", "specific action 2"],
    "evidence": [
      {
        "dataType": "relevant data type",
        "value": "supporting data point",
        "significance": "why this supports the recommendation"
      }
    ]
  }
]

Focus on:
1. Evidence-based recommendations
2. Personalization based on user profile
3. Actionable and realistic steps
4. Priority based on health impact
5. Integration with user goals

Limit to 3-5 most important recommendations.
Respond only with valid JSON.`;
}

// Helper functions
function groupDataByType(healthData: HealthDataPoint[]): Record<string, HealthDataPoint[]> {
  return healthData.reduce((acc, data) => {
    if (!acc[data.type]) {
      acc[data.type] = [];
    }
    acc[data.type].push(data);
    return acc;
  }, {} as Record<string, HealthDataPoint[]>);
}

function mapDataTypeToCategory(dataType: string): AIInsight['category'] {
  const categoryMap: Record<string, AIInsight['category']> = {
    'steps': 'activity',
    'heartRate': 'medical',
    'bloodPressure': 'medical',
    'weight': 'nutrition',
    'sleep': 'sleep',
    'mood': 'mental',
    'bloodSugar': 'medical'
  };

  return categoryMap[dataType] || 'medical';
}

function isDataRelevantToGoal(data: HealthDataPoint, goal: any): boolean {
  const relevanceMap: Record<string, string[]> = {
    'weightLoss': ['weight', 'steps', 'calories'],
    'stepsDaily': ['steps'],
    'exerciseMinutes': ['steps', 'heartRate', 'calories'],
    'sleepHours': ['sleep'],
    'bloodSugar': ['bloodSugar', 'weight']
  };

  const relevantTypes = relevanceMap[goal.type] || [];
  return relevantTypes.includes(data.type);
}

async function getUserHealthProfile(userId: string): Promise<UserHealthProfile> {
  try {
    const profileDoc = await db.collection('healthProfiles').doc(userId).get();
    
    if (!profileDoc.exists) {
      return {
        goals: [],
        conditions: [],
        preferences: {
          activityLevel: 'moderate',
          dietaryRestrictions: []
        }
      };
    }

    const data = profileDoc.data()!;
    return {
      demographics: data.demographics,
      goals: data.goals || [],
      conditions: data.conditions?.map((c: any) => c.name) || [],
      preferences: {
        activityLevel: data.preferences?.activityLevel || 'moderate',
        dietaryRestrictions: data.preferences?.dietaryRestrictions || []
      }
    };
  } catch (error) {
    logger.warn('Failed to get user health profile:', error);
    return {
      goals: [],
      conditions: [],
      preferences: {
        activityLevel: 'moderate',
        dietaryRestrictions: []
      }
    };
  }
}

async function getRecentHealthData(
  userId: string, 
  timeframe: string, 
  dataTypes?: string[]
): Promise<HealthDataPoint[]> {
  try {
    let startDate = new Date();
    
    switch (timeframe) {
      case 'week':
        startDate.setDate(startDate.getDate() - 7);
        break;
      case 'month':
        startDate.setMonth(startDate.getMonth() - 1);
        break;
      case 'quarter':
        startDate.setMonth(startDate.getMonth() - 3);
        break;
    }

    let query = db.collection('healthObservations')
      .where('userId', '==', userId)
      .where('timestamp', '>=', startDate.toISOString())
      .orderBy('timestamp', 'desc')
      .limit(1000);

    if (dataTypes && dataTypes.length > 0) {
      query = query.where('type', 'in', dataTypes);
    }

    const querySnapshot = await query.get();
    
    return querySnapshot.docs.map(doc => {
      const data = doc.data();
      return {
        type: data.type,
        value: data.value?.numeric || data.value?.text || data.value,
        unit: data.value?.unit,
        timestamp: data.timestamp,
        source: data.source
      };
    });
  } catch (error) {
    logger.error('Failed to get recent health data:', error);
    return [];
  }
}