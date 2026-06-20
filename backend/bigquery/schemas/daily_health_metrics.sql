-- BigQuery schema for aggregated daily health metrics
CREATE TABLE IF NOT EXISTS `health_analytics.daily_health_metrics` (
  userId STRING NOT NULL,
  date DATE NOT NULL,
  daily_steps INT64,
  avg_heart_rate FLOAT64,
  current_weight FLOAT64,
  weight_unit STRING,
  avg_blood_pressure_systolic FLOAT64,
  avg_blood_pressure_diastolic FLOAT64,
  exercise_minutes INT64,
  total_calories INT64,
  sleep_hours FLOAT64,
  sleep_quality_score FLOAT64,
  water_intake_liters FLOAT64,
  mood_score FLOAT64,
  stress_level FLOAT64,
  -- Derived wellness score
  wellness_score FLOAT64 GENERATED ALWAYS AS (
    SAFE_DIVIDE(
      COALESCE(LEAST(daily_steps / 10000.0 * 25, 25), 0) +
      COALESCE(LEAST(exercise_minutes / 30.0 * 25, 25), 0) +
      COALESCE(CASE 
        WHEN sleep_hours BETWEEN 7 AND 9 THEN 25 
        WHEN sleep_hours BETWEEN 6 AND 10 THEN 20
        ELSE 10 
      END, 0) +
      COALESCE(LEAST(mood_score / 5.0 * 25, 25), 0),
      100
    ) * 100
  ) STORED,
  data_completeness_score FLOAT64 GENERATED ALWAYS AS (
    (CASE WHEN daily_steps IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN avg_heart_rate IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN exercise_minutes IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN sleep_hours IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN mood_score IS NOT NULL THEN 1 ELSE 0 END) / 5.0
  ) STORED,
  aggregated_at TIMESTAMP NOT NULL,
  source STRING DEFAULT 'analytics_worker'
)
PARTITION BY date
CLUSTER BY userId
OPTIONS (
  description = "Daily aggregated health metrics for analytics and ML",
  labels = [("team", "health"), ("environment", "production")]
);