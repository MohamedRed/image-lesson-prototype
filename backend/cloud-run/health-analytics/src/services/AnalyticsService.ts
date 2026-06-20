import { BigQuery } from '@google-cloud/bigquery';
import { Firestore } from '@google-cloud/firestore';
import { logger } from '../utils/logger';

export class AnalyticsService {
  private bigquery: BigQuery;
  private firestore: Firestore;
  private datasetId: string;

  constructor() {
    this.bigquery = new BigQuery();
    this.firestore = new Firestore();
    this.datasetId = process.env.BIGQUERY_DATASET || 'health_analytics';
  }

  // Daily health metrics aggregation
  async aggregateDailyMetrics(date?: string): Promise<void> {
    const targetDate = date || new Date().toISOString().split('T')[0];
    logger.info(`Starting daily metrics aggregation for ${targetDate}`);

    try {
      // Query to aggregate daily health metrics
      const query = `
        WITH daily_observations AS (
          SELECT 
            userId,
            type,
            DATE(timestamp) as observation_date,
            AVG(CAST(JSON_EXTRACT_SCALAR(value, '$.numeric') AS FLOAT64)) as avg_value,
            MAX(CAST(JSON_EXTRACT_SCALAR(value, '$.numeric') AS FLOAT64)) as max_value,
            MIN(CAST(JSON_EXTRACT_SCALAR(value, '$.numeric') AS FLOAT64)) as min_value,
            COUNT(*) as observation_count,
            JSON_EXTRACT_SCALAR(value, '$.unit') as unit
          FROM \`${process.env.GOOGLE_CLOUD_PROJECT}.${this.datasetId}.health_observations\`
          WHERE DATE(timestamp) = @target_date
            AND JSON_EXTRACT_SCALAR(value, '$.numeric') IS NOT NULL
          GROUP BY userId, type, observation_date, unit
        ),
        user_daily_summary AS (
          SELECT 
            userId,
            observation_date,
            MAX(CASE WHEN type = 'steps' THEN avg_value END) as daily_steps,
            AVG(CASE WHEN type = 'heartRate' THEN avg_value END) as avg_heart_rate,
            MAX(CASE WHEN type = 'weight' THEN max_value END) as current_weight,
            AVG(CASE WHEN type = 'bloodPressure' THEN avg_value END) as avg_blood_pressure,
            SUM(CASE WHEN type = 'exerciseMinutes' THEN avg_value END) as total_exercise_minutes,
            SUM(CASE WHEN type = 'calories' THEN avg_value END) as total_calories,
            AVG(CASE WHEN type = 'sleep' THEN avg_value END) as sleep_hours
          FROM daily_observations
          GROUP BY userId, observation_date
        )
        SELECT 
          userId,
          observation_date,
          daily_steps,
          avg_heart_rate,
          current_weight,
          avg_blood_pressure,
          total_exercise_minutes,
          total_calories,
          sleep_hours,
          CURRENT_TIMESTAMP() as aggregated_at
        FROM user_daily_summary
      `;

      const options = {
        query,
        params: { target_date: targetDate },
        location: 'US',
        jobId: `daily_aggregation_${targetDate}_${Date.now()}`
      };

      const [job] = await this.bigquery.createQueryJob(options);
      const [rows] = await job.getQueryResults();

      logger.info(`Aggregated ${rows.length} user daily summaries for ${targetDate}`);

      // Store aggregated results back to Firestore for quick access
      const batch = this.firestore.batch();
      
      rows.forEach((row: any) => {
        const docRef = this.firestore
          .collection('healthMetrics')
          .doc(row.userId)
          .collection('daily')
          .doc(targetDate);

        batch.set(docRef, {
          date: targetDate,
          steps: row.daily_steps || 0,
          heartRateAvg: row.avg_heart_rate || null,
          currentWeight: row.current_weight || null,
          avgBloodPressure: row.avg_blood_pressure || null,
          exerciseMinutes: row.total_exercise_minutes || 0,
          calories: row.total_calories || 0,
          sleepHours: row.sleep_hours || null,
          aggregatedAt: new Date(),
          source: 'analytics_worker'
        }, { merge: true });
      });

      await batch.commit();
      logger.info(`Stored ${rows.length} daily summaries to Firestore`);

    } catch (error) {
      logger.error(`Error in daily metrics aggregation: ${error}`);
      throw error;
    }
  }

  // Calculate health scores and risk assessments
  async calculateHealthScores(userId?: string): Promise<void> {
    logger.info(`Calculating health scores${userId ? ` for user ${userId}` : ' for all users'}`);

    try {
      let whereClause = '';
      let params: any = {};

      if (userId) {
        whereClause = 'WHERE userId = @userId';
        params.userId = userId;
      }

      const query = `
        WITH recent_metrics AS (
          SELECT 
            userId,
            AVG(daily_steps) as avg_steps,
            AVG(avg_heart_rate) as avg_hr,
            AVG(exercise_minutes) as avg_exercise,
            AVG(sleep_hours) as avg_sleep,
            COUNT(*) as days_with_data
          FROM \`${process.env.GOOGLE_CLOUD_PROJECT}.${this.datasetId}.daily_health_metrics\`
          WHERE DATE(aggregated_at) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
          ${whereClause}
          GROUP BY userId
          HAVING COUNT(*) >= 7  -- At least 7 days of data
        ),
        health_scores AS (
          SELECT 
            userId,
            -- Activity score (0-100 based on WHO recommendations)
            LEAST(100, (avg_steps / 10000.0) * 40 + (avg_exercise / 150.0) * 40 + 20) as activity_score,
            -- Cardiovascular score (basic resting HR assessment)
            CASE 
              WHEN avg_hr IS NULL THEN 50
              WHEN avg_hr < 60 THEN GREATEST(0, 100 - (60 - avg_hr) * 2)
              WHEN avg_hr > 100 THEN GREATEST(0, 100 - (avg_hr - 100) * 1.5)
              ELSE 100 - ABS(avg_hr - 70) * 0.5
            END as cardio_score,
            -- Sleep score
            CASE 
              WHEN avg_sleep IS NULL THEN 50
              WHEN avg_sleep < 7 THEN (avg_sleep / 7.0) * 80
              WHEN avg_sleep > 9 THEN 80 - (avg_sleep - 9) * 10
              ELSE 80 + (8 - ABS(avg_sleep - 8)) * 2.5
            END as sleep_score,
            avg_steps,
            avg_hr,
            avg_exercise,
            avg_sleep,
            days_with_data
          FROM recent_metrics
        )
        SELECT 
          userId,
          activity_score,
          cardio_score,
          sleep_score,
          (activity_score + cardio_score + sleep_score) / 3 as overall_health_score,
          avg_steps,
          avg_hr,
          avg_exercise,
          avg_sleep,
          days_with_data,
          CURRENT_TIMESTAMP() as calculated_at
        FROM health_scores
      `;

      const options = {
        query,
        params,
        location: 'US'
      };

      const [job] = await this.bigquery.createQueryJob(options);
      const [rows] = await job.getQueryResults();

      // Store health scores in Firestore
      const batch = this.firestore.batch();

      rows.forEach((row: any) => {
        const scoreDoc = this.firestore
          .collection('healthScores')
          .doc(row.userId);

        batch.set(scoreDoc, {
          userId: row.userId,
          scores: {
            activity: Math.round(row.activity_score),
            cardiovascular: Math.round(row.cardio_score),
            sleep: Math.round(row.sleep_score),
            overall: Math.round(row.overall_health_score)
          },
          metrics: {
            avgSteps: row.avg_steps,
            avgHeartRate: row.avg_hr,
            avgExerciseMinutes: row.avg_exercise,
            avgSleepHours: row.avg_sleep,
            daysWithData: row.days_with_data
          },
          calculatedAt: new Date(),
          version: '1.0'
        }, { merge: true });
      });

      await batch.commit();
      logger.info(`Calculated and stored health scores for ${rows.length} users`);

    } catch (error) {
      logger.error(`Error calculating health scores: ${error}`);
      throw error;
    }
  }

  // Advanced pattern recognition for health insights
  async detectHealthPatterns(userId: string, days: number = 30): Promise<any[]> {
    logger.info(`Detecting health patterns for user ${userId} over ${days} days`);

    try {
      const query = `
        WITH daily_data AS (
          SELECT 
            DATE(timestamp) as date,
            type,
            AVG(CAST(JSON_EXTRACT_SCALAR(value, '$.numeric') AS FLOAT64)) as avg_value,
            COUNT(*) as reading_count
          FROM \`${process.env.GOOGLE_CLOUD_PROJECT}.${this.datasetId}.health_observations\`
          WHERE userId = @userId
            AND DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL @days DAY)
            AND JSON_EXTRACT_SCALAR(value, '$.numeric') IS NOT NULL
          GROUP BY date, type
        ),
        trend_analysis AS (
          SELECT 
            type,
            date,
            avg_value,
            LAG(avg_value, 1) OVER (PARTITION BY type ORDER BY date) as prev_value,
            LAG(avg_value, 7) OVER (PARTITION BY type ORDER BY date) as week_ago_value,
            AVG(avg_value) OVER (PARTITION BY type ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) as rolling_avg
          FROM daily_data
        ),
        pattern_detection AS (
          SELECT 
            type,
            date,
            avg_value,
            prev_value,
            week_ago_value,
            rolling_avg,
            CASE 
              WHEN avg_value - prev_value > rolling_avg * 0.2 THEN 'sudden_increase'
              WHEN prev_value - avg_value > rolling_avg * 0.2 THEN 'sudden_decrease'
              WHEN week_ago_value IS NOT NULL AND avg_value > week_ago_value * 1.1 THEN 'weekly_trend_up'
              WHEN week_ago_value IS NOT NULL AND avg_value < week_ago_value * 0.9 THEN 'weekly_trend_down'
              ELSE 'normal'
            END as pattern
          FROM trend_analysis
          WHERE prev_value IS NOT NULL
        )
        SELECT 
          type,
          pattern,
          COUNT(*) as pattern_count,
          AVG(avg_value) as avg_metric_value,
          MIN(date) as first_occurrence,
          MAX(date) as last_occurrence
        FROM pattern_detection
        WHERE pattern != 'normal'
        GROUP BY type, pattern
        HAVING COUNT(*) >= 2  -- At least 2 occurrences to be significant
        ORDER BY type, pattern_count DESC
      `;

      const options = {
        query,
        params: { userId, days },
        location: 'US'
      };

      const [job] = await this.bigquery.createQueryJob(options);
      const [rows] = await job.getQueryResults();

      return rows.map((row: any) => ({
        dataType: row.type,
        pattern: row.pattern,
        occurrences: row.pattern_count,
        avgValue: row.avg_metric_value,
        firstSeen: row.first_occurrence?.value,
        lastSeen: row.last_occurrence?.value,
        significance: row.pattern_count >= 5 ? 'high' : row.pattern_count >= 3 ? 'medium' : 'low'
      }));

    } catch (error) {
      logger.error(`Error detecting health patterns: ${error}`);
      throw error;
    }
  }

  // Generate predictive health insights
  async generatePredictiveInsights(userId: string): Promise<any[]> {
    logger.info(`Generating predictive insights for user ${userId}`);

    try {
      // Get user's historical patterns
      const patterns = await this.detectHealthPatterns(userId, 90);
      
      // Get current health scores
      const scoresDoc = await this.firestore
        .collection('healthScores')
        .doc(userId)
        .get();

      if (!scoresDoc.exists) {
        return [];
      }

      const currentScores = scoresDoc.data()!;
      const insights: any[] = [];

      // Analyze patterns and generate predictions
      for (const pattern of patterns) {
        let prediction: any = null;

        switch (pattern.pattern) {
          case 'weekly_trend_down':
            if (pattern.dataType === 'steps' && pattern.significance === 'high') {
              prediction = {
                type: 'risk_alert',
                category: 'activity',
                title: 'Declining Activity Pattern Detected',
                description: `Your step count has been consistently decreasing over the past ${pattern.occurrences} weeks.`,
                prediction: 'If this trend continues, you may fall below recommended daily activity levels within 2-3 weeks.',
                confidence: 0.8,
                recommendedActions: [
                  'Set small, achievable daily step goals',
                  'Schedule regular walking breaks',
                  'Consider joining group activities for motivation'
                ]
              };
            }
            break;

          case 'sudden_increase':
            if (pattern.dataType === 'heartRate' && pattern.avgValue > 100) {
              prediction = {
                type: 'health_alert',
                category: 'cardiovascular',
                title: 'Elevated Heart Rate Pattern',
                description: `Your resting heart rate has shown sudden increases ${pattern.occurrences} times recently.`,
                prediction: 'This may indicate increased stress, overtraining, or other health factors requiring attention.',
                confidence: 0.7,
                recommendedActions: [
                  'Monitor for additional symptoms',
                  'Consider stress management techniques',
                  'Consult with a healthcare provider if pattern persists'
                ]
              };
            }
            break;

          case 'weekly_trend_up':
            if (pattern.dataType === 'exerciseMinutes') {
              prediction = {
                type: 'positive_trend',
                category: 'fitness',
                title: 'Improving Exercise Consistency',
                description: `Your exercise duration has been steadily increasing for ${pattern.occurrences} weeks.`,
                prediction: 'Maintaining this trend could lead to significant fitness improvements within 2-3 months.',
                confidence: 0.85,
                recommendedActions: [
                  'Continue current routine',
                  'Gradually increase intensity',
                  'Track strength and endurance improvements'
                ]
              };
            }
            break;
        }

        if (prediction) {
          insights.push({
            ...prediction,
            userId,
            basedOnPattern: pattern,
            generatedAt: new Date(),
            source: 'analytics_ml'
          });
        }
      }

      return insights;

    } catch (error) {
      logger.error(`Error generating predictive insights: ${error}`);
      throw error;
    }
  }

  // Comparative analysis against population benchmarks
  async compareAgainstBenchmarks(userId: string): Promise<any> {
    logger.info(`Comparing user ${userId} against population benchmarks`);

    try {
      // Get user profile for demographic matching
      const profileDoc = await this.firestore
        .collection('healthProfiles')
        .doc(userId)
        .get();

      if (!profileDoc.exists) {
        throw new Error('User profile not found');
      }

      const profile = profileDoc.data()!;
      const age = profile.demographics?.age;
      const sex = profile.demographics?.biologicalSex;

      // Get user's current scores
      const scoresDoc = await this.firestore
        .collection('healthScores')
        .doc(userId)
        .get();

      if (!scoresDoc.exists) {
        throw new Error('User health scores not found');
      }

      const userScores = scoresDoc.data()!;

      // Query population benchmarks
      const query = `
        SELECT 
          AVG(scores.activity) as avg_activity_score,
          AVG(scores.cardiovascular) as avg_cardio_score,
          AVG(scores.sleep) as avg_sleep_score,
          AVG(scores.overall) as avg_overall_score,
          APPROX_QUANTILES(scores.activity, 100)[OFFSET(50)] as median_activity,
          APPROX_QUANTILES(scores.cardiovascular, 100)[OFFSET(50)] as median_cardio,
          APPROX_QUANTILES(scores.sleep, 100)[OFFSET(50)] as median_sleep,
          APPROX_QUANTILES(scores.overall, 100)[OFFSET(50)] as median_overall,
          COUNT(*) as sample_size
        FROM \`${process.env.GOOGLE_CLOUD_PROJECT}.${this.datasetId}.health_scores\`
        WHERE demographics.age BETWEEN @min_age AND @max_age
          AND demographics.biologicalSex = @sex
      `;

      const ageRange = age ? { min: age - 5, max: age + 5 } : { min: 18, max: 80 };
      
      const options = {
        query,
        params: {
          min_age: ageRange.min,
          max_age: ageRange.max,
          sex: sex || 'unknown'
        },
        location: 'US'
      };

      const [job] = await this.bigquery.createQueryJob(options);
      const [rows] = await job.getQueryResults();

      if (rows.length === 0) {
        return null;
      }

      const benchmark = rows[0];
      
      return {
        userId,
        demographics: { age, sex },
        userScores: userScores.scores,
        benchmarks: {
          activity: {
            average: Math.round(benchmark.avg_activity_score),
            median: Math.round(benchmark.median_activity),
            userPercentile: this.calculatePercentile(userScores.scores.activity, benchmark.median_activity)
          },
          cardiovascular: {
            average: Math.round(benchmark.avg_cardio_score),
            median: Math.round(benchmark.median_cardio),
            userPercentile: this.calculatePercentile(userScores.scores.cardiovascular, benchmark.median_cardio)
          },
          sleep: {
            average: Math.round(benchmark.avg_sleep_score),
            median: Math.round(benchmark.median_sleep),
            userPercentile: this.calculatePercentile(userScores.scores.sleep, benchmark.median_sleep)
          },
          overall: {
            average: Math.round(benchmark.avg_overall_score),
            median: Math.round(benchmark.median_overall),
            userPercentile: this.calculatePercentile(userScores.scores.overall, benchmark.median_overall)
          }
        },
        sampleSize: benchmark.sample_size,
        comparedAt: new Date()
      };

    } catch (error) {
      logger.error(`Error comparing against benchmarks: ${error}`);
      throw error;
    }
  }

  private calculatePercentile(userScore: number, medianScore: number): number {
    // Simplified percentile calculation
    // In production, this would use actual distribution data
    const ratio = userScore / medianScore;
    if (ratio >= 1.2) return 90;
    if (ratio >= 1.1) return 80;
    if (ratio >= 1.0) return 70;
    if (ratio >= 0.9) return 50;
    if (ratio >= 0.8) return 30;
    if (ratio >= 0.7) return 20;
    return 10;
  }
}

export const analyticsService = new AnalyticsService();