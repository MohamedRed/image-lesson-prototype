-- BigQuery schema for health scores and ML training data
CREATE TABLE IF NOT EXISTS `health_analytics.health_scores` (
  userId STRING NOT NULL,
  calculation_date DATE NOT NULL,
  scores STRUCT<
    activity INT64,
    cardiovascular INT64,
    sleep INT64,
    nutrition INT64,
    mental_health INT64,
    overall INT64
  >,
  metrics STRUCT<
    avg_steps FLOAT64,
    avg_heart_rate FLOAT64,
    avg_exercise_minutes FLOAT64,
    avg_sleep_hours FLOAT64,
    avg_nutrition_score FLOAT64,
    avg_mood_score FLOAT64,
    days_with_data INT64
  >,
  demographics STRUCT<
    age_range STRING,
    biological_sex STRING,
    activity_level STRING,
    bmi_category STRING
  >,
  risk_factors ARRAY<STRUCT<
    factor STRING,
    severity STRING,
    confidence FLOAT64
  >>,
  improvement_areas ARRAY<STRING>,
  benchmark_percentiles STRUCT<
    activity_percentile INT64,
    cardio_percentile INT64,
    sleep_percentile INT64,
    overall_percentile INT64
  >,
  calculated_at TIMESTAMP NOT NULL,
  model_version STRING DEFAULT '1.0',
  -- ML features for training
  ml_features STRUCT<
    activity_consistency FLOAT64,
    sleep_regularity FLOAT64,
    heart_rate_variability FLOAT64,
    exercise_progression FLOAT64,
    goal_adherence_rate FLOAT64,
    social_engagement_score FLOAT64
  >,
  -- Training labels for supervised learning
  training_labels STRUCT<
    program_completion_likelihood FLOAT64,
    health_improvement_30d FLOAT64,
    engagement_risk_score FLOAT64,
    churn_probability FLOAT64
  >
)
PARTITION BY calculation_date
CLUSTER BY userId, demographics.age_range, demographics.biological_sex
OPTIONS (
  description = "Health scores and ML training features for personalization models",
  labels = [("team", "health"), ("environment", "production"), ("purpose", "ml_training")]
);