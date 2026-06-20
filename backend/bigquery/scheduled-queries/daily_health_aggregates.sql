-- Daily Health Aggregates Scheduled Query
-- Runs daily at 3 AM UTC to create summary tables for analytics dashboards
-- This query aggregates daily user metrics into summary statistics

CREATE OR REPLACE TABLE `health_analytics.daily_aggregates` AS
SELECT
  date,
  -- User activity metrics
  COUNT(DISTINCT userId) as active_users,
  AVG(healthScore) as avg_health_score,
  STDDEV(healthScore) as health_score_stddev,
  PERCENTILE_CONT(healthScore, 0.5) OVER() as median_health_score,
  PERCENTILE_CONT(healthScore, 0.25) OVER() as health_score_p25,
  PERCENTILE_CONT(healthScore, 0.75) OVER() as health_score_p75,
  
  -- Step metrics
  AVG(stepsCount) as avg_steps,
  SUM(stepsCount) as total_steps,
  COUNT(CASE WHEN stepsCount >= 10000 THEN 1 END) as users_10k_steps,
  COUNT(CASE WHEN stepsCount >= 7500 THEN 1 END) as users_7_5k_steps,
  
  -- Sleep metrics
  AVG(sleepHours) as avg_sleep_hours,
  COUNT(CASE WHEN sleepHours >= 7 AND sleepHours <= 9 THEN 1 END) as users_optimal_sleep,
  COUNT(CASE WHEN sleepHours < 6 THEN 1 END) as users_poor_sleep,
  
  -- Workout metrics
  AVG(workoutsCount) as avg_workouts,
  COUNT(CASE WHEN workoutsCount >= 1 THEN 1 END) as users_exercised,
  COUNT(CASE WHEN workoutsCount >= 2 THEN 1 END) as users_multiple_workouts,
  
  -- Health score distribution
  COUNT(CASE WHEN healthScore >= 90 THEN 1 END) as excellent_health_users,
  COUNT(CASE WHEN healthScore >= 70 AND healthScore < 90 THEN 1 END) as good_health_users,
  COUNT(CASE WHEN healthScore >= 50 AND healthScore < 70 THEN 1 END) as fair_health_users,
  COUNT(CASE WHEN healthScore < 50 THEN 1 END) as poor_health_users,
  
  -- Streak analysis
  AVG(streakDays) as avg_streak_days,
  COUNT(CASE WHEN streakDays >= 7 THEN 1 END) as users_week_streak,
  COUNT(CASE WHEN streakDays >= 30 THEN 1 END) as users_month_streak,
  
  -- Risk factors
  ARRAY_AGG(DISTINCT risk_factor IGNORE NULLS) as common_risk_factors,
  COUNT(CASE WHEN 'low_activity' IN UNNEST(riskFactors) THEN 1 END) as users_low_activity,
  COUNT(CASE WHEN 'poor_sleep' IN UNNEST(riskFactors) THEN 1 END) as users_sleep_risk,
  COUNT(CASE WHEN 'no_exercise' IN UNNEST(riskFactors) THEN 1 END) as users_no_exercise,
  
  -- Challenge points
  AVG(challengePoints) as avg_challenge_points,
  SUM(challengePoints) as total_challenge_points,
  
  -- Time-based insights
  EXTRACT(DAYOFWEEK FROM date) as day_of_week,
  EXTRACT(MONTH FROM date) as month_num,
  
  -- Meta information
  CURRENT_TIMESTAMP() as processed_at

FROM `health_analytics.daily_user_metrics`,
UNNEST(riskFactors) as risk_factor

WHERE date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)

GROUP BY date

-- Configuration for scheduled query:
-- Schedule: Daily at 03:00 UTC
-- Destination: health_analytics.daily_aggregates
-- Write disposition: WRITE_APPEND
-- Use legacy SQL: false