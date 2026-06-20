import { BigQuery } from '@google-cloud/bigquery';
import { Firestore } from '@google-cloud/firestore';
import { VertexAI } from '@google-cloud/vertexai';
import { logger } from '../utils/logger';

interface MLTrainingData {
  features: {
    activityConsistency: number;
    sleepRegularity: number;
    heartRateVariability: number;
    exerciseProgression: number;
    goalAdherenceRate: number;
    socialEngagementScore: number;
    demographics: {
      ageRange: string;
      biologicalSex: string;
      activityLevel: string;
      bmiCategory: string;
    };
  };
  labels: {
    programCompletionLikelihood: number;
    healthImprovement30d: number;
    engagementRiskScore: number;
    churnProbability: number;
  };
}

export class MLService {
  private bigquery: BigQuery;
  private firestore: Firestore;
  private vertexai: VertexAI;
  private datasetId: string;

  constructor() {
    this.bigquery = new BigQuery();
    this.firestore = new Firestore();
    this.vertexai = new VertexAI({
      project: process.env.GOOGLE_CLOUD_PROJECT || 'liive-health',
      location: 'us-central1',
    });
    this.datasetId = process.env.BIGQUERY_DATASET || 'health_analytics';
  }

  // Prepare training data for ML models
  async prepareTrainingData(startDate: string, endDate: string): Promise<MLTrainingData[]> {
    logger.info(`Preparing ML training data from ${startDate} to ${endDate}`);

    try {
      const query = `
        WITH user_metrics AS (
          SELECT 
            userId,
            AVG(daily_steps) as avg_steps,
            STDDEV(daily_steps) as steps_variability,
            AVG(exercise_minutes) as avg_exercise,
            AVG(sleep_hours) as avg_sleep,
            STDDEV(sleep_hours) as sleep_variability,
            AVG(avg_heart_rate) as avg_hr,
            STDDEV(avg_heart_rate) as hr_variability,
            AVG(wellness_score) as avg_wellness,
            COUNT(*) as data_days,
            AVG(data_completeness_score) as data_quality
          FROM \`${process.env.GOOGLE_CLOUD_PROJECT}.${this.datasetId}.daily_health_metrics\`
          WHERE date BETWEEN @start_date AND @end_date
          GROUP BY userId
          HAVING COUNT(*) >= 14  -- At least 2 weeks of data
        ),
        program_outcomes AS (
          SELECT 
            userId,
            COUNT(*) as programs_started,
            SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as programs_completed,
            AVG(progress) as avg_program_progress,
            AVG(CASE WHEN status = 'active' THEN 1 ELSE 0 END) as current_engagement
          FROM \`${process.env.GOOGLE_CLOUD_PROJECT}.${this.datasetId}.health_programs\`
          WHERE createdAt BETWEEN @start_date AND @end_date
          GROUP BY userId
        ),
        user_demographics AS (
          SELECT 
            userId,
            demographics.age_range,
            demographics.biological_sex,
            demographics.activity_level,
            demographics.bmi_category
          FROM \`${process.env.GOOGLE_CLOUD_PROJECT}.${this.datasetId}.health_profiles\`
        ),
        training_features AS (
          SELECT 
            m.userId,
            -- Features
            COALESCE(m.steps_variability / NULLIF(m.avg_steps, 0), 0) as activity_consistency,
            COALESCE(1 - (m.sleep_variability / NULLIF(m.avg_sleep, 0)), 0) as sleep_regularity,
            COALESCE(m.hr_variability / NULLIF(m.avg_hr, 0), 0) as heart_rate_variability,
            CASE 
              WHEN LAG(m.avg_exercise) OVER (PARTITION BY m.userId ORDER BY @end_date) IS NOT NULL
              THEN (m.avg_exercise - LAG(m.avg_exercise) OVER (PARTITION BY m.userId ORDER BY @end_date)) / 
                   NULLIF(LAG(m.avg_exercise) OVER (PARTITION BY m.userId ORDER BY @end_date), 0)
              ELSE 0 
            END as exercise_progression,
            COALESCE(p.avg_program_progress, 0) as goal_adherence_rate,
            m.data_quality as social_engagement_score,  -- Proxy for engagement
            -- Demographics
            d.age_range,
            d.biological_sex,
            d.activity_level,
            d.bmi_category,
            -- Labels (outcomes to predict)
            COALESCE(p.programs_completed / NULLIF(p.programs_started, 0), 0) as program_completion_likelihood,
            CASE 
              WHEN LEAD(m.avg_wellness) OVER (PARTITION BY m.userId ORDER BY @end_date) IS NOT NULL
              THEN (LEAD(m.avg_wellness) OVER (PARTITION BY m.userId ORDER BY @end_date) - m.avg_wellness) / 30.0
              ELSE 0
            END as health_improvement_30d,
            CASE 
              WHEN m.data_quality < 0.3 OR m.data_days < 7 THEN 0.8
              WHEN m.data_quality < 0.5 OR m.data_days < 14 THEN 0.5
              WHEN m.data_quality < 0.7 THEN 0.3
              ELSE 0.1
            END as engagement_risk_score,
            CASE
              WHEN p.current_engagement = 0 AND p.programs_started > 0 THEN 0.7
              WHEN m.data_days < 7 THEN 0.6
              WHEN m.data_quality < 0.3 THEN 0.5
              ELSE 0.2
            END as churn_probability
          FROM user_metrics m
          LEFT JOIN program_outcomes p ON m.userId = p.userId
          LEFT JOIN user_demographics d ON m.userId = d.userId
        )
        SELECT * FROM training_features
        WHERE activity_consistency IS NOT NULL 
          AND sleep_regularity IS NOT NULL
          AND age_range IS NOT NULL
          AND biological_sex IS NOT NULL
      `;

      const options = {
        query,
        params: { start_date: startDate, end_date: endDate },
        location: 'US'
      };

      const [job] = await this.bigquery.createQueryJob(options);
      const [rows] = await job.getQueryResults();

      const trainingData: MLTrainingData[] = rows.map((row: any) => ({
        features: {
          activityConsistency: row.activity_consistency || 0,
          sleepRegularity: row.sleep_regularity || 0,
          heartRateVariability: row.heart_rate_variability || 0,
          exerciseProgression: row.exercise_progression || 0,
          goalAdherenceRate: row.goal_adherence_rate || 0,
          socialEngagementScore: row.social_engagement_score || 0,
          demographics: {
            ageRange: row.age_range || 'unknown',
            biologicalSex: row.biological_sex || 'unknown',
            activityLevel: row.activity_level || 'moderate',
            bmiCategory: row.bmi_category || 'normal'
          }
        },
        labels: {
          programCompletionLikelihood: row.program_completion_likelihood || 0,
          healthImprovement30d: row.health_improvement_30d || 0,
          engagementRiskScore: row.engagement_risk_score || 0.5,
          churnProbability: row.churn_probability || 0.3
        }
      }));

      logger.info(`Prepared ${trainingData.length} training samples`);
      return trainingData;

    } catch (error) {
      logger.error(`Error preparing training data: ${error}`);
      throw error;
    }
  }

  // Train personalization models using Vertex AI
  async trainPersonalizationModels(): Promise<void> {
    logger.info('Starting personalization model training');

    try {
      // Prepare training data for last 6 months
      const endDate = new Date().toISOString().split('T')[0];
      const startDate = new Date(Date.now() - 180 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
      
      const trainingData = await this.prepareTrainingData(startDate, endDate);

      if (trainingData.length < 100) {
        logger.warn('Insufficient training data for model training');
        return;
      }

      // Create training dataset in BigQuery for Vertex AI
      await this.createTrainingDataset(trainingData);

      // Train program completion prediction model
      await this.trainProgramCompletionModel(trainingData);

      // Train health improvement prediction model  
      await this.trainHealthImprovementModel(trainingData);

      // Train engagement risk model
      await this.trainEngagementRiskModel(trainingData);

      logger.info('Completed personalization model training');

    } catch (error) {
      logger.error(`Error training personalization models: ${error}`);
      throw error;
    }
  }

  // Generate personalized recommendations using trained models
  async generatePersonalizedRecommendations(userId: string): Promise<any[]> {
    logger.info(`Generating personalized recommendations for user ${userId}`);

    try {
      // Get user's current features
      const userFeatures = await this.extractUserFeatures(userId);
      if (!userFeatures) {
        return [];
      }

      // Get predictions from trained models
      const programCompletionScore = await this.predictProgramCompletion(userFeatures);
      const healthImprovementScore = await this.predictHealthImprovement(userFeatures);
      const engagementRisk = await this.predictEngagementRisk(userFeatures);

      // Generate recommendations based on predictions
      const recommendations = [];

      // Low program completion likelihood
      if (programCompletionScore < 0.4) {
        recommendations.push({
          type: 'program_adjustment',
          title: 'Simplified Program Approach',
          description: 'Consider breaking your current goals into smaller, more achievable steps.',
          rationale: `Based on your activity patterns, shorter programs may be more suitable.`,
          confidence: 0.8,
          actions: [
            'Switch to 2-week mini-programs',
            'Focus on one habit at a time',
            'Set more flexible scheduling options'
          ]
        });
      }

      // High health improvement potential
      if (healthImprovementScore > 0.6) {
        recommendations.push({
          type: 'optimization',
          title: 'Accelerate Your Progress',
          description: 'Your data shows strong potential for significant health improvements.',
          rationale: 'Your consistency and current metrics indicate readiness for more advanced goals.',
          confidence: 0.85,
          actions: [
            'Consider increasing exercise intensity',
            'Add strength training to your routine',
            'Set more ambitious step targets'
          ]
        });
      }

      // High engagement risk
      if (engagementRisk > 0.6) {
        recommendations.push({
          type: 'engagement_boost',
          title: 'Stay Connected to Your Goals',
          description: 'Let\'s find ways to keep you motivated and engaged.',
          rationale: 'Your recent activity suggests you might benefit from additional support.',
          confidence: 0.75,
          actions: [
            'Join a health challenge with friends',
            'Set up daily check-in reminders',
            'Consider working with a health coach'
          ]
        });
      }

      // Demographic-specific recommendations
      const demographicRecs = await this.getDemographicRecommendations(userFeatures);
      recommendations.push(...demographicRecs);

      return recommendations;

    } catch (error) {
      logger.error(`Error generating personalized recommendations: ${error}`);
      return [];
    }
  }

  // A/B test framework for program variations
  async assignProgramVariation(userId: string, programType: string): Promise<string> {
    logger.info(`Assigning program variation for user ${userId}, program ${programType}`);

    try {
      // Get user's risk profile
      const userFeatures = await this.extractUserFeatures(userId);
      if (!userFeatures) {
        return 'default';
      }

      // Calculate user's risk score
      const riskScore = (
        (1 - userFeatures.activityConsistency) * 0.3 +
        (1 - userFeatures.goalAdherenceRate) * 0.4 +
        userFeatures.churnProbability * 0.3
      );

      // Assign variation based on risk profile and A/B test configuration
      const variations = await this.getActiveABTests(programType);
      
      for (const test of variations) {
        if (this.isUserEligible(userFeatures, test.eligibility)) {
          const assignedVariation = this.assignVariation(userId, test);
          
          // Log assignment for analysis
          await this.logABTestAssignment(userId, test.id, assignedVariation, riskScore);
          
          return assignedVariation;
        }
      }

      return 'default';

    } catch (error) {
      logger.error(`Error assigning program variation: ${error}`);
      return 'default';
    }
  }

  // Analyze A/B test results
  async analyzeABTestResults(testId: string): Promise<any> {
    logger.info(`Analyzing A/B test results for test ${testId}`);

    try {
      const query = `
        WITH test_participants AS (
          SELECT 
            userId,
            variation,
            assigned_at,
            user_risk_score
          FROM \`${process.env.GOOGLE_CLOUD_PROJECT}.${this.datasetId}.ab_test_assignments\`
          WHERE test_id = @test_id
        ),
        outcomes AS (
          SELECT 
            t.userId,
            t.variation,
            t.user_risk_score,
            -- Program completion outcomes
            COALESCE(p.completion_rate, 0) as completion_rate,
            COALESCE(p.average_progress, 0) as average_progress,
            -- Engagement outcomes
            COALESCE(e.session_count, 0) as session_count,
            COALESCE(e.retention_7d, 0) as retention_7d,
            COALESCE(e.retention_30d, 0) as retention_30d,
            -- Health outcomes
            COALESCE(h.score_improvement, 0) as health_score_improvement
          FROM test_participants t
          LEFT JOIN \`${process.env.GOOGLE_CLOUD_PROJECT}.${this.datasetId}.program_outcomes\` p 
            ON t.userId = p.userId AND p.started_at >= t.assigned_at
          LEFT JOIN \`${process.env.GOOGLE_CLOUD_PROJECT}.${this.datasetId}.engagement_metrics\` e 
            ON t.userId = e.userId AND e.period_start >= t.assigned_at
          LEFT JOIN \`${process.env.GOOGLE_CLOUD_PROJECT}.${this.datasetId}.health_improvements\` h 
            ON t.userId = h.userId AND h.measurement_date >= t.assigned_at
        ),
        variation_stats AS (
          SELECT 
            variation,
            COUNT(*) as participant_count,
            AVG(completion_rate) as avg_completion_rate,
            AVG(average_progress) as avg_progress,
            AVG(session_count) as avg_sessions,
            AVG(retention_7d) as avg_retention_7d,
            AVG(retention_30d) as avg_retention_30d,
            AVG(health_score_improvement) as avg_health_improvement,
            STDDEV(completion_rate) as std_completion_rate,
            STDDEV(health_score_improvement) as std_health_improvement
          FROM outcomes
          GROUP BY variation
        )
        SELECT 
          variation,
          participant_count,
          avg_completion_rate,
          std_completion_rate,
          avg_progress,
          avg_sessions,
          avg_retention_7d,
          avg_retention_30d,
          avg_health_improvement,
          std_health_improvement,
          -- Statistical significance (simplified)
          CASE 
            WHEN participant_count >= 100 AND std_completion_rate > 0 
            THEN ABS(avg_completion_rate - LAG(avg_completion_rate) OVER (ORDER BY variation)) / 
                 SQRT(POW(std_completion_rate, 2) / participant_count + 
                      POW(LAG(std_completion_rate) OVER (ORDER BY variation), 2) / 
                      LAG(participant_count) OVER (ORDER BY variation))
            ELSE NULL 
          END as t_statistic
        FROM variation_stats
        ORDER BY variation
      `;

      const options = {
        query,
        params: { test_id: testId },
        location: 'US'
      };

      const [job] = await this.bigquery.createQueryJob(options);
      const [rows] = await job.getQueryResults();

      return {
        testId,
        variations: rows.map((row: any) => ({
          variation: row.variation,
          participantCount: row.participant_count,
          metrics: {
            completionRate: {
              mean: row.avg_completion_rate,
              stdDev: row.std_completion_rate
            },
            averageProgress: row.avg_progress,
            sessionCount: row.avg_sessions,
            retention7d: row.avg_retention_7d,
            retention30d: row.avg_retention_30d,
            healthImprovement: {
              mean: row.avg_health_improvement,
              stdDev: row.std_health_improvement
            }
          },
          statisticalSignificance: {
            tStatistic: row.t_statistic,
            isSignificant: row.t_statistic && Math.abs(row.t_statistic) > 1.96
          }
        })),
        analyzedAt: new Date()
      };

    } catch (error) {
      logger.error(`Error analyzing A/B test results: ${error}`);
      throw error;
    }
  }

  // Private helper methods
  private async createTrainingDataset(trainingData: MLTrainingData[]): Promise<void> {
    const tableName = `ml_training_data_${Date.now()}`;
    const tableRef = this.bigquery.dataset(this.datasetId).table(tableName);

    await tableRef.create({
      schema: [
        { name: 'userId', type: 'STRING' },
        { name: 'features', type: 'JSON' },
        { name: 'labels', type: 'JSON' },
        { name: 'created_at', type: 'TIMESTAMP' }
      ]
    });

    const rows = trainingData.map(data => ({
      userId: `user_${Math.random().toString(36).substr(2, 9)}`, // Anonymized
      features: JSON.stringify(data.features),
      labels: JSON.stringify(data.labels),
      created_at: new Date()
    }));

    await tableRef.insert(rows);
    logger.info(`Created training dataset ${tableName} with ${rows.length} rows`);
  }

  private async trainProgramCompletionModel(trainingData: MLTrainingData[]): Promise<void> {
    // In production, this would use Vertex AI AutoML or custom training
    // For now, we'll store the training completion event
    logger.info('Program completion model training initiated');
  }

  private async trainHealthImprovementModel(trainingData: MLTrainingData[]): Promise<void> {
    // In production, this would use Vertex AI for regression model training
    logger.info('Health improvement model training initiated');
  }

  private async trainEngagementRiskModel(trainingData: MLTrainingData[]): Promise<void> {
    // In production, this would use Vertex AI for classification model training
    logger.info('Engagement risk model training initiated');
  }

  private async extractUserFeatures(userId: string): Promise<any | null> {
    // Get user features from recent data
    const metricsDoc = await this.firestore
      .collection('healthScores')
      .doc(userId)
      .get();

    if (!metricsDoc.exists) {
      return null;
    }

    const data = metricsDoc.data()!;
    return {
      activityConsistency: data.ml_features?.activity_consistency || 0.5,
      sleepRegularity: data.ml_features?.sleep_regularity || 0.5,
      heartRateVariability: data.ml_features?.heart_rate_variability || 0.5,
      exerciseProgression: data.ml_features?.exercise_progression || 0,
      goalAdherenceRate: data.ml_features?.goal_adherence_rate || 0.5,
      socialEngagementScore: data.ml_features?.social_engagement_score || 0.5,
      churnProbability: data.training_labels?.churn_probability || 0.3
    };
  }

  private async predictProgramCompletion(features: any): Promise<number> {
    // Simplified prediction logic - in production, use trained ML model
    return Math.max(0, Math.min(1, 
      features.activityConsistency * 0.3 + 
      features.goalAdherenceRate * 0.4 + 
      features.socialEngagementScore * 0.3
    ));
  }

  private async predictHealthImprovement(features: any): Promise<number> {
    // Simplified prediction logic
    return Math.max(0, Math.min(1,
      features.exerciseProgression * 0.4 +
      features.sleepRegularity * 0.3 +
      features.activityConsistency * 0.3
    ));
  }

  private async predictEngagementRisk(features: any): Promise<number> {
    return features.churnProbability || 0.3;
  }

  private async getDemographicRecommendations(features: any): Promise<any[]> {
    const recommendations = [];

    // Age-specific recommendations
    if (features.demographics?.ageRange === '50-60' || features.demographics?.ageRange === '60+') {
      recommendations.push({
        type: 'demographic_specific',
        title: 'Age-Appropriate Exercise',
        description: 'Focus on low-impact activities that are easier on joints.',
        confidence: 0.7,
        actions: [
          'Try swimming or water aerobics',
          'Include flexibility and balance exercises',
          'Consider tai chi or yoga'
        ]
      });
    }

    return recommendations;
  }

  private async getActiveABTests(programType: string): Promise<any[]> {
    // In production, this would query active A/B tests from database
    return [
      {
        id: 'program_intensity_test',
        name: 'Program Intensity Variation',
        variations: ['gentle', 'moderate', 'intensive'],
        weights: [0.33, 0.34, 0.33],
        eligibility: {
          activityLevel: ['low', 'moderate'],
          completionHistory: 'any'
        }
      }
    ];
  }

  private isUserEligible(features: any, eligibility: any): boolean {
    // Check if user meets A/B test eligibility criteria
    return true; // Simplified for demo
  }

  private assignVariation(userId: string, test: any): string {
    // Consistent assignment based on user ID hash
    const hash = userId.split('').reduce((a, b) => {
      a = ((a << 5) - a) + b.charCodeAt(0);
      return a & a;
    }, 0);
    
    const index = Math.abs(hash) % test.variations.length;
    return test.variations[index];
  }

  private async logABTestAssignment(userId: string, testId: string, variation: string, riskScore: number): Promise<void> {
    await this.firestore.collection('abTestAssignments').add({
      userId,
      testId,
      variation,
      userRiskScore: riskScore,
      assignedAt: new Date()
    });
  }
}

export const mlService = new MLService();