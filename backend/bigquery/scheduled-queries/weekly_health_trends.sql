-- Weekly Health Trends Scheduled Query
-- Runs weekly on Sundays at 4 AM UTC to analyze week-over-week trends
-- This query creates trending insights for the health analytics dashboard

CREATE OR REPLACE TABLE `health_analytics.weekly_trends` AS
WITH weekly_metrics AS (
  SELECT
    DATE_TRUNC(date, WEEK(MONDAY)) as week_start,
    userId,
    AVG(healthScore) as avg_health_score,
    SUM(stepsCount) as total_steps,
    AVG(sleepHours) as avg_sleep,
    SUM(workoutsCount) as total_workouts,
    SUM(challengePoints) as total_points,
    COUNT(*) as active_days,
    MAX(streakDays) as max_streak
  FROM `health_analytics.daily_user_metrics`
  WHERE date >= DATE_SUB(DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY)), INTERVAL 8 WEEK)
  GROUP BY week_start, userId
),

week_over_week AS (
  SELECT
    curr.week_start,
    curr.userId,
    curr.avg_health_score as current_health_score,
    LAG(curr.avg_health_score) OVER (PARTITION BY curr.userId ORDER BY curr.week_start) as prev_health_score,
    curr.total_steps as current_steps,
    LAG(curr.total_steps) OVER (PARTITION BY curr.userId ORDER BY curr.week_start) as prev_steps,
    curr.avg_sleep as current_sleep,
    LAG(curr.avg_sleep) OVER (PARTITION BY curr.userId ORDER BY curr.week_start) as prev_sleep,
    curr.total_workouts as current_workouts,
    LAG(curr.total_workouts) OVER (PARTITION BY curr.userId ORDER BY curr.week_start) as prev_workouts,
    curr.active_days,
    curr.max_streak,
    curr.total_points
  FROM weekly_metrics curr
)

SELECT
  week_start,
  
  -- User engagement trends
  COUNT(DISTINCT userId) as active_users,
  COUNT(DISTINCT CASE WHEN active_days >= 5 THEN userId END) as highly_engaged_users,
  AVG(active_days) as avg_active_days_per_user,
  
  -- Health score trends
  AVG(current_health_score) as avg_health_score,
  AVG(CASE WHEN prev_health_score IS NOT NULL 
       THEN current_health_score - prev_health_score END) as avg_health_score_change,
  COUNT(CASE WHEN current_health_score > prev_health_score THEN 1 END) as users_improved,
  COUNT(CASE WHEN current_health_score < prev_health_score THEN 1 END) as users_declined,
  SAFE_DIVIDE(
    COUNT(CASE WHEN current_health_score > prev_health_score THEN 1 END),
    COUNT(CASE WHEN prev_health_score IS NOT NULL THEN 1 END)
  ) * 100 as improvement_rate_pct,
  
  -- Step trends
  AVG(current_steps) as avg_weekly_steps,
  AVG(CASE WHEN prev_steps IS NOT NULL 
       THEN current_steps - prev_steps END) as avg_steps_change,
  COUNT(CASE WHEN current_steps >= 70000 THEN 1 END) as users_70k_weekly_steps,
  
  -- Sleep trends
  AVG(current_sleep) as avg_daily_sleep,
  AVG(CASE WHEN prev_sleep IS NOT NULL 
       THEN current_sleep - prev_sleep END) as avg_sleep_change,
  COUNT(CASE WHEN current_sleep >= 7.5 THEN 1 END) as users_good_sleep,
  
  -- Workout trends
  AVG(current_workouts) as avg_weekly_workouts,
  AVG(CASE WHEN prev_workouts IS NOT NULL 
       THEN current_workouts - prev_workouts END) as avg_workouts_change,
  COUNT(CASE WHEN current_workouts >= 3 THEN 1 END) as users_3plus_workouts,
  
  -- Streak analysis
  AVG(max_streak) as avg_max_streak,
  COUNT(CASE WHEN max_streak >= 7 THEN 1 END) as users_week_plus_streak,
  COUNT(CASE WHEN max_streak >= 21 THEN 1 END) as users_3week_plus_streak,
  
  -- Challenge engagement
  AVG(total_points) as avg_weekly_points,
  SUM(total_points) as total_community_points,
  
  -- User retention metrics
  COUNT(CASE WHEN prev_health_score IS NOT NULL THEN 1 END) as returning_users,
  SAFE_DIVIDE(
    COUNT(CASE WHEN prev_health_score IS NOT NULL THEN 1 END),
    COUNT(DISTINCT userId)
  ) * 100 as retention_rate_pct,
  
  -- Behavior patterns
  ARRAY_AGG(
    CASE WHEN current_health_score >= 80 THEN userId END 
    IGNORE NULLS LIMIT 10
  ) as top_performers,
  
  ARRAY_AGG(
    CASE WHEN current_health_score > prev_health_score + 10 THEN userId END 
    IGNORE NULLS LIMIT 10
  ) as most_improved,
  
  -- Seasonal and trend indicators
  AVG(current_health_score) - LAG(AVG(current_health_score)) OVER (ORDER BY week_start) as week_over_week_trend,
  
  -- Meta information
  CURRENT_TIMESTAMP() as processed_at

FROM week_over_week

WHERE week_start = DATE_SUB(DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY)), INTERVAL 1 WEEK)

GROUP BY week_start

-- Configuration for scheduled query:
-- Schedule: Weekly on Sunday at 04:00 UTC  
-- Destination: health_analytics.weekly_trends
-- Write disposition: WRITE_APPEND
-- Use legacy SQL: false