import { Firestore } from '@google-cloud/firestore';
import { BigQuery } from '@google-cloud/bigquery';
import { PubSub } from '@google-cloud/pubsub';
import * as winston from 'winston';
import * as moment from 'moment';

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console()
  ]
});

export interface UserHealthMetrics {
  userId: string;
  date: string;
  stepsCount: number;
  caloriesBurned: number;
  sleepHours: number;
  heartRateAvg: number;
  workoutsCount: number;
  mindfulnessMinutes: number;
  hydrationLiters: number;
  weightKg?: number;
  healthScore: number;
  streakDays: number;
  challengePoints: number;
  riskFactors: string[];
  achievements: string[];
}

export interface LeaderboardEntry {
  userId: string;
  username: string;
  points: number;
  healthScore: number;
  rank: number;
  category: 'daily' | 'weekly' | 'monthly' | 'annual';
  date: string;
  achievements: string[];
}

export interface HealthInsight {
  userId: string;
  type: 'trend' | 'recommendation' | 'alert' | 'achievement';
  title: string;
  description: string;
  severity: 'low' | 'medium' | 'high';
  actionItems: string[];
  dataPoints: any[];
  generatedAt: Date;
  expiresAt?: Date;
}

export class ETLService {
  private firestore: Firestore;
  private bigQuery: BigQuery;
  private pubSub: PubSub;

  constructor() {
    this.firestore = new Firestore();
    this.bigQuery = new BigQuery();
    this.pubSub = new PubSub();
  }

  /**
   * Main daily ETL job that processes all user health data
   */
  async runDailyETL(date?: string): Promise<void> {
    const targetDate = date || moment().subtract(1, 'day').format('YYYY-MM-DD');
    logger.info(`Starting daily ETL for ${targetDate}`);

    try {
      // 1. Extract and transform user health data
      const userMetrics = await this.extractDailyMetrics(targetDate);
      logger.info(`Extracted metrics for ${userMetrics.length} users`);

      // 2. Calculate health scores and streaks
      const enrichedMetrics = await this.calculateHealthScores(userMetrics);

      // 3. Load to BigQuery for analytics
      await this.loadToBigQuery(enrichedMetrics, targetDate);

      // 4. Update user profiles with latest metrics
      await this.updateUserProfiles(enrichedMetrics);

      // 5. Generate leaderboards
      await this.generateLeaderboards(targetDate);

      // 6. Generate personalized insights
      await this.generateInsights(enrichedMetrics);

      // 7. Trigger notifications for achievements/alerts
      await this.triggerNotifications(enrichedMetrics);

      logger.info(`Daily ETL completed successfully for ${targetDate}`);
    } catch (error) {
      logger.error('Daily ETL failed:', error);
      throw error;
    }
  }

  /**
   * Extract daily health metrics from Firestore
   */
  private async extractDailyMetrics(date: string): Promise<UserHealthMetrics[]> {
    const startOfDay = moment(date).startOf('day').toDate();
    const endOfDay = moment(date).endOf('day').toDate();

    // Get all users who have health data for this date
    const usersSnapshot = await this.firestore
      .collectionGroup('healthObservations')
      .where('effectiveDateTime', '>=', startOfDay)
      .where('effectiveDateTime', '<=', endOfDay)
      .get();

    const userIds = [...new Set(usersSnapshot.docs.map(doc => doc.data().userId))];
    const userMetrics: UserHealthMetrics[] = [];

    for (const userId of userIds) {
      try {
        const metrics = await this.extractUserDailyMetrics(userId, date);
        userMetrics.push(metrics);
      } catch (error) {
        logger.warn(`Failed to extract metrics for user ${userId}:`, error);
      }
    }

    return userMetrics;
  }

  /**
   * Extract daily metrics for a specific user
   */
  private async extractUserDailyMetrics(userId: string, date: string): Promise<UserHealthMetrics> {
    const startOfDay = moment(date).startOf('day').toDate();
    const endOfDay = moment(date).endOf('day').toDate();

    // Get health observations for the day
    const observationsSnapshot = await this.firestore
      .collection('users')
      .doc(userId)
      .collection('healthObservations')
      .where('effectiveDateTime', '>=', startOfDay)
      .where('effectiveDateTime', '<=', endOfDay)
      .get();

    // Get previous streak data
    const userDoc = await this.firestore.collection('users').doc(userId).get();
    const userData = userDoc.data() || {};

    // Initialize metrics
    const metrics: UserHealthMetrics = {
      userId,
      date,
      stepsCount: 0,
      caloriesBurned: 0,
      sleepHours: 0,
      heartRateAvg: 0,
      workoutsCount: 0,
      mindfulnessMinutes: 0,
      hydrationLiters: 0,
      healthScore: 0,
      streakDays: userData.currentStreak || 0,
      challengePoints: 0,
      riskFactors: [],
      achievements: []
    };

    // Process observations
    const heartRates: number[] = [];
    
    for (const doc of observationsSnapshot.docs) {
      const obs = doc.data();
      
      switch (obs.type) {
        case 'steps':
          metrics.stepsCount += obs.value?.numeric || 0;
          break;
        case 'calories':
          metrics.caloriesBurned += obs.value?.numeric || 0;
          break;
        case 'sleep':
          metrics.sleepHours += (obs.value?.numeric || 0) / 3600; // Convert seconds to hours
          break;
        case 'heart_rate':
          heartRates.push(obs.value?.numeric || 0);
          break;
        case 'workout':
          metrics.workoutsCount += 1;
          break;
        case 'mindfulness':
          metrics.mindfulnessMinutes += (obs.value?.numeric || 0) / 60; // Convert seconds to minutes
          break;
        case 'hydration':
          metrics.hydrationLiters += obs.value?.numeric || 0;
          break;
        case 'weight':
          metrics.weightKg = obs.value?.numeric;
          break;
      }
    }

    // Calculate average heart rate
    if (heartRates.length > 0) {
      metrics.heartRateAvg = heartRates.reduce((sum, hr) => sum + hr, 0) / heartRates.length;
    }

    return metrics;
  }

  /**
   * Calculate health scores and update streaks
   */
  private async calculateHealthScores(userMetrics: UserHealthMetrics[]): Promise<UserHealthMetrics[]> {
    return userMetrics.map(metrics => {
      // Health score calculation (0-100)
      let score = 0;
      let factors = 0;

      // Steps (25 points max)
      if (metrics.stepsCount >= 10000) score += 25;
      else if (metrics.stepsCount >= 7500) score += 20;
      else if (metrics.stepsCount >= 5000) score += 15;
      else if (metrics.stepsCount >= 2500) score += 10;
      factors += 25;

      // Sleep (20 points max)
      if (metrics.sleepHours >= 7 && metrics.sleepHours <= 9) score += 20;
      else if (metrics.sleepHours >= 6 && metrics.sleepHours <= 10) score += 15;
      else if (metrics.sleepHours >= 5) score += 10;
      factors += 20;

      // Workouts (20 points max)
      if (metrics.workoutsCount >= 1) score += 20;
      factors += 20;

      // Heart rate (15 points max)
      if (metrics.heartRateAvg > 0 && metrics.heartRateAvg >= 60 && metrics.heartRateAvg <= 100) {
        score += 15;
      } else if (metrics.heartRateAvg > 0) {
        score += 10;
      }
      factors += 15;

      // Mindfulness (10 points max)
      if (metrics.mindfulnessMinutes >= 10) score += 10;
      else if (metrics.mindfulnessMinutes >= 5) score += 8;
      else if (metrics.mindfulnessMinutes > 0) score += 5;
      factors += 10;

      // Hydration (10 points max)
      if (metrics.hydrationLiters >= 2.5) score += 10;
      else if (metrics.hydrationLiters >= 2.0) score += 8;
      else if (metrics.hydrationLiters >= 1.5) score += 5;
      factors += 10;

      metrics.healthScore = Math.round((score / factors) * 100);

      // Update streak
      if (metrics.healthScore >= 70) {
        metrics.streakDays += 1;
      } else {
        metrics.streakDays = 0;
      }

      // Calculate challenge points
      metrics.challengePoints = Math.round(metrics.healthScore + (metrics.streakDays * 5));

      // Identify risk factors
      if (metrics.stepsCount < 5000) metrics.riskFactors.push('low_activity');
      if (metrics.sleepHours < 6 || metrics.sleepHours > 10) metrics.riskFactors.push('poor_sleep');
      if (metrics.workoutsCount === 0) metrics.riskFactors.push('no_exercise');
      if (metrics.heartRateAvg > 100 || (metrics.heartRateAvg > 0 && metrics.heartRateAvg < 60)) {
        metrics.riskFactors.push('heart_rate_concern');
      }

      // Generate achievements
      if (metrics.stepsCount >= 15000) metrics.achievements.push('super_stepper');
      if (metrics.sleepHours >= 8 && metrics.sleepHours <= 9) metrics.achievements.push('sleep_champion');
      if (metrics.workoutsCount >= 2) metrics.achievements.push('fitness_enthusiast');
      if (metrics.streakDays >= 7) metrics.achievements.push('week_warrior');
      if (metrics.streakDays >= 30) metrics.achievements.push('month_master');
      if (metrics.healthScore >= 90) metrics.achievements.push('health_hero');

      return metrics;
    });
  }

  /**
   * Load processed data to BigQuery for analytics
   */
  private async loadToBigQuery(userMetrics: UserHealthMetrics[], date: string): Promise<void> {
    const dataset = this.bigQuery.dataset('health_analytics');
    const table = dataset.table('daily_user_metrics');

    const rows = userMetrics.map(metrics => ({
      ...metrics,
      date: new Date(date),
      processed_at: new Date()
    }));

    await table.insert(rows);
    logger.info(`Loaded ${rows.length} rows to BigQuery`);
  }

  /**
   * Update user profiles with latest metrics
   */
  private async updateUserProfiles(userMetrics: UserHealthMetrics[]): Promise<void> {
    const batch = this.firestore.batch();

    for (const metrics of userMetrics) {
      const userRef = this.firestore.collection('users').doc(metrics.userId);
      
      batch.update(userRef, {
        'health.lastHealthScore': metrics.healthScore,
        'health.currentStreak': metrics.streakDays,
        'health.totalPoints': this.firestore.FieldValue.increment(metrics.challengePoints),
        'health.lastUpdated': new Date(),
        'health.riskFactors': metrics.riskFactors,
        'health.recentAchievements': metrics.achievements
      });
    }

    await batch.commit();
    logger.info(`Updated ${userMetrics.length} user profiles`);
  }

  /**
   * Generate leaderboards for different time periods
   */
  private async generateLeaderboards(date: string): Promise<void> {
    await Promise.all([
      this.generateDailyLeaderboard(date),
      this.generateWeeklyLeaderboard(date),
      this.generateMonthlyLeaderboard(date)
    ]);
  }

  private async generateDailyLeaderboard(date: string): Promise<void> {
    const query = `
      SELECT 
        userId,
        healthScore,
        challengePoints as points,
        achievements,
        ROW_NUMBER() OVER (ORDER BY challengePoints DESC, healthScore DESC) as rank
      FROM \`health_analytics.daily_user_metrics\`
      WHERE date = @date
      ORDER BY challengePoints DESC, healthScore DESC
      LIMIT 100
    `;

    const [rows] = await this.bigQuery.query({
      query,
      params: { date: new Date(date) }
    });

    const leaderboard: LeaderboardEntry[] = [];
    for (const row of rows) {
      // Get username
      const userDoc = await this.firestore.collection('users').doc(row.userId).get();
      const userData = userDoc.data();
      
      leaderboard.push({
        userId: row.userId,
        username: userData?.profile?.username || 'Anonymous',
        points: row.points,
        healthScore: row.healthScore,
        rank: row.rank,
        category: 'daily',
        date,
        achievements: row.achievements || []
      });
    }

    // Store leaderboard
    await this.firestore
      .collection('leaderboards')
      .doc(`daily_${date}`)
      .set({
        category: 'daily',
        date,
        entries: leaderboard,
        generatedAt: new Date()
      });

    logger.info(`Generated daily leaderboard with ${leaderboard.length} entries`);
  }

  private async generateWeeklyLeaderboard(date: string): Promise<void> {
    const weekStart = moment(date).startOf('week').format('YYYY-MM-DD');
    const weekEnd = moment(date).endOf('week').format('YYYY-MM-DD');

    const query = `
      SELECT 
        userId,
        AVG(healthScore) as avg_health_score,
        SUM(challengePoints) as total_points,
        ARRAY_AGG(DISTINCT achievement IGNORE NULLS) as all_achievements
      FROM \`health_analytics.daily_user_metrics\`,
      UNNEST(achievements) as achievement
      WHERE date BETWEEN @weekStart AND @weekEnd
      GROUP BY userId
      ORDER BY total_points DESC, avg_health_score DESC
      LIMIT 100
    `;

    const [rows] = await this.bigQuery.query({
      query,
      params: { 
        weekStart: new Date(weekStart),
        weekEnd: new Date(weekEnd)
      }
    });

    const leaderboard: LeaderboardEntry[] = [];
    let rank = 1;

    for (const row of rows) {
      const userDoc = await this.firestore.collection('users').doc(row.userId).get();
      const userData = userDoc.data();
      
      leaderboard.push({
        userId: row.userId,
        username: userData?.profile?.username || 'Anonymous',
        points: row.total_points,
        healthScore: Math.round(row.avg_health_score),
        rank: rank++,
        category: 'weekly',
        date: weekStart,
        achievements: row.all_achievements || []
      });
    }

    await this.firestore
      .collection('leaderboards')
      .doc(`weekly_${weekStart}`)
      .set({
        category: 'weekly',
        weekStart,
        weekEnd,
        entries: leaderboard,
        generatedAt: new Date()
      });

    logger.info(`Generated weekly leaderboard with ${leaderboard.length} entries`);
  }

  private async generateMonthlyLeaderboard(date: string): Promise<void> {
    const monthStart = moment(date).startOf('month').format('YYYY-MM-DD');
    const monthEnd = moment(date).endOf('month').format('YYYY-MM-DD');

    const query = `
      SELECT 
        userId,
        AVG(healthScore) as avg_health_score,
        SUM(challengePoints) as total_points,
        MAX(streakDays) as max_streak,
        COUNT(*) as active_days
      FROM \`health_analytics.daily_user_metrics\`
      WHERE date BETWEEN @monthStart AND @monthEnd
      GROUP BY userId
      HAVING active_days >= 15  -- Must have at least half the month active
      ORDER BY total_points DESC, avg_health_score DESC, max_streak DESC
      LIMIT 100
    `;

    const [rows] = await this.bigQuery.query({
      query,
      params: { 
        monthStart: new Date(monthStart),
        monthEnd: new Date(monthEnd)
      }
    });

    const leaderboard: LeaderboardEntry[] = [];
    let rank = 1;

    for (const row of rows) {
      const userDoc = await this.firestore.collection('users').doc(row.userId).get();
      const userData = userDoc.data();
      
      leaderboard.push({
        userId: row.userId,
        username: userData?.profile?.username || 'Anonymous',
        points: row.total_points,
        healthScore: Math.round(row.avg_health_score),
        rank: rank++,
        category: 'monthly',
        date: monthStart,
        achievements: [`${row.active_days}_days_active`, `${row.max_streak}_day_streak`]
      });
    }

    await this.firestore
      .collection('leaderboards')
      .doc(`monthly_${monthStart}`)
      .set({
        category: 'monthly',
        monthStart,
        monthEnd,
        entries: leaderboard,
        generatedAt: new Date()
      });

    logger.info(`Generated monthly leaderboard with ${leaderboard.length} entries`);
  }

  /**
   * Generate personalized insights for users
   */
  private async generateInsights(userMetrics: UserHealthMetrics[]): Promise<void> {
    for (const metrics of userMetrics) {
      try {
        const insights = await this.generateUserInsights(metrics);
        
        if (insights.length > 0) {
          const batch = this.firestore.batch();
          
          for (const insight of insights) {
            const insightRef = this.firestore
              .collection('users')
              .doc(metrics.userId)
              .collection('healthInsights')
              .doc();
            
            batch.set(insightRef, insight);
          }
          
          await batch.commit();
        }
      } catch (error) {
        logger.warn(`Failed to generate insights for user ${metrics.userId}:`, error);
      }
    }
  }

  private async generateUserInsights(metrics: UserHealthMetrics): Promise<HealthInsight[]> {
    const insights: HealthInsight[] = [];

    // Get historical data for trends
    const query = `
      SELECT *
      FROM \`health_analytics.daily_user_metrics\`
      WHERE userId = @userId
      AND date >= DATE_SUB(@currentDate, INTERVAL 30 DAY)
      ORDER BY date DESC
    `;

    const [historicalRows] = await this.bigQuery.query({
      query,
      params: { 
        userId: metrics.userId,
        currentDate: new Date(metrics.date)
      }
    });

    // Trend analysis
    if (historicalRows.length >= 7) {
      const recentScores = historicalRows.slice(0, 7).map((row: any) => row.healthScore);
      const previousScores = historicalRows.slice(7, 14).map((row: any) => row.healthScore);
      
      const recentAvg = recentScores.reduce((sum: number, score: number) => sum + score, 0) / recentScores.length;
      const previousAvg = previousScores.length > 0 
        ? previousScores.reduce((sum: number, score: number) => sum + score, 0) / previousScores.length
        : recentAvg;

      if (recentAvg > previousAvg + 5) {
        insights.push({
          userId: metrics.userId,
          type: 'trend',
          title: 'Health Score Improving! 📈',
          description: `Your health score has improved by ${Math.round(recentAvg - previousAvg)} points over the past week!`,
          severity: 'low',
          actionItems: ['Keep up the great work!', 'Consider setting a new health goal'],
          dataPoints: recentScores,
          generatedAt: new Date()
        });
      } else if (recentAvg < previousAvg - 5) {
        insights.push({
          userId: metrics.userId,
          type: 'trend',
          title: 'Health Score Declining',
          description: `Your health score has decreased by ${Math.round(previousAvg - recentAvg)} points. Let's get back on track!`,
          severity: 'medium',
          actionItems: [
            'Review your recent activity levels',
            'Consider consulting with a health professional',
            'Focus on sleep and exercise consistency'
          ],
          dataPoints: recentScores,
          generatedAt: new Date()
        });
      }
    }

    // Risk factor alerts
    if (metrics.riskFactors.includes('low_activity')) {
      insights.push({
        userId: metrics.userId,
        type: 'alert',
        title: 'Low Activity Alert',
        description: `You only had ${metrics.stepsCount} steps yesterday. Aim for at least 7,500 steps daily.`,
        severity: 'medium',
        actionItems: [
          'Take a 10-minute walk every hour',
          'Use stairs instead of elevators',
          'Park farther from destinations'
        ],
        dataPoints: [{ steps: metrics.stepsCount, target: 7500 }],
        generatedAt: new Date()
      });
    }

    if (metrics.riskFactors.includes('poor_sleep')) {
      insights.push({
        userId: metrics.userId,
        type: 'alert',
        title: 'Sleep Pattern Alert',
        description: `You got ${metrics.sleepHours.toFixed(1)} hours of sleep. Aim for 7-9 hours nightly.`,
        severity: 'high',
        actionItems: [
          'Establish a consistent bedtime routine',
          'Avoid screens 1 hour before bed',
          'Keep your bedroom cool and dark'
        ],
        dataPoints: [{ sleep: metrics.sleepHours, target: 8 }],
        generatedAt: new Date()
      });
    }

    // Achievement celebrations
    if (metrics.achievements.length > 0) {
      insights.push({
        userId: metrics.userId,
        type: 'achievement',
        title: 'New Achievements Unlocked! 🏆',
        description: `Congratulations! You earned: ${metrics.achievements.join(', ')}`,
        severity: 'low',
        actionItems: ['Share your success with friends!', 'Set your next health goal'],
        dataPoints: metrics.achievements,
        generatedAt: new Date()
      });
    }

    // Personalized recommendations based on patterns
    if (historicalRows.length >= 14) {
      const workoutDays = historicalRows.filter((row: any) => row.workoutsCount > 0).length;
      const workoutRate = workoutDays / historicalRows.length;

      if (workoutRate < 0.3) {
        insights.push({
          userId: metrics.userId,
          type: 'recommendation',
          title: 'Boost Your Workout Routine',
          description: `You've worked out ${workoutDays} days in the past ${historicalRows.length} days. Try to increase your frequency!`,
          severity: 'medium',
          actionItems: [
            'Schedule 3-4 workout sessions per week',
            'Try different activities to stay motivated',
            'Start with 15-minute workouts if time is limited'
          ],
          dataPoints: [{ workoutDays, totalDays: historicalRows.length }],
          generatedAt: new Date()
        });
      }
    }

    return insights;
  }

  /**
   * Trigger notifications for achievements and alerts
   */
  private async triggerNotifications(userMetrics: UserHealthMetrics[]): Promise<void> {
    const notifications = [];

    for (const metrics of userMetrics) {
      // Achievement notifications
      for (const achievement of metrics.achievements) {
        notifications.push({
          userId: metrics.userId,
          type: 'achievement',
          title: 'New Achievement! 🏆',
          body: this.getAchievementMessage(achievement),
          data: { achievement, healthScore: metrics.healthScore }
        });
      }

      // Alert notifications
      if (metrics.riskFactors.includes('poor_sleep') && metrics.sleepHours < 5) {
        notifications.push({
          userId: metrics.userId,
          type: 'alert',
          title: 'Sleep Alert',
          body: `You only got ${metrics.sleepHours.toFixed(1)} hours of sleep. Your health depends on good rest!`,
          data: { riskFactor: 'poor_sleep', sleepHours: metrics.sleepHours }
        });
      }

      if (metrics.streakDays > 0 && metrics.streakDays % 7 === 0) {
        notifications.push({
          userId: metrics.userId,
          type: 'streak',
          title: 'Streak Milestone! 🔥',
          body: `Amazing! You're on a ${metrics.streakDays}-day health streak!`,
          data: { streakDays: metrics.streakDays }
        });
      }
    }

    // Publish notifications to Pub/Sub for processing
    if (notifications.length > 0) {
      const topic = this.pubSub.topic('health-notifications');
      
      for (const notification of notifications) {
        await topic.publishMessage({ 
          json: notification,
          attributes: { type: notification.type }
        });
      }

      logger.info(`Published ${notifications.length} notifications`);
    }
  }

  private getAchievementMessage(achievement: string): string {
    const messages: { [key: string]: string } = {
      'super_stepper': 'You walked over 15,000 steps today! You\'re a walking champion!',
      'sleep_champion': 'Perfect sleep! You got optimal rest last night.',
      'fitness_enthusiast': 'Multiple workouts today! Your dedication is impressive!',
      'week_warrior': '7-day streak! You\'re building amazing healthy habits!',
      'month_master': '30-day streak! You\'re a health transformation success story!',
      'health_hero': 'Health score over 90! You\'re in the top tier of healthy living!'
    };

    return messages[achievement] || 'Great job on your health achievement!';
  }
}