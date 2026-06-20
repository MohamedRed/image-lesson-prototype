-- BigQuery schema for health observations table
CREATE TABLE IF NOT EXISTS `health_analytics.health_observations` (
  id STRING NOT NULL,
  userId STRING NOT NULL,
  type STRING NOT NULL,
  value JSON,
  source STRING NOT NULL,
  timestamp TIMESTAMP NOT NULL,
  notes STRING,
  metadata JSON,
  createdAt TIMESTAMP NOT NULL,
  updatedAt TIMESTAMP NOT NULL,
  -- Derived fields for analytics
  value_numeric FLOAT64 GENERATED ALWAYS AS (
    SAFE_CAST(JSON_EXTRACT_SCALAR(value, '$.numeric') AS FLOAT64)
  ) STORED,
  value_unit STRING GENERATED ALWAYS AS (
    JSON_EXTRACT_SCALAR(value, '$.unit')
  ) STORED,
  observation_date DATE GENERATED ALWAYS AS (
    DATE(timestamp)
  ) STORED
)
PARTITION BY observation_date
CLUSTER BY userId, type
OPTIONS (
  description = "Health observations from all sources including HealthKit, manual entry, and integrations",
  labels = [("team", "health"), ("environment", "production")]
);