-- BigQuery Schema for Ride Sharing Platform
-- Run this script to set up the complete data warehouse

-- Create dataset if not exists
CREATE SCHEMA IF NOT EXISTS `ride_sharing`
OPTIONS (
  description = "Ride sharing platform analytics and ML models",
  location = "US"
);

-- Ride requests fact table
CREATE OR REPLACE TABLE `ride_sharing.ride_requests` (
  ride_request_id STRING NOT NULL,
  created_at TIMESTAMP NOT NULL,
  state STRING NOT NULL,
  passenger_count INT64 NOT NULL DEFAULT 1,
  fare_total FLOAT64,
  pickup_zone_id STRING,
  dropoff_zone_id STRING,
  rider_gender STRING,
  driver_id STRING,
  pickup_lat FLOAT64,
  pickup_lng FLOAT64,
  dropoff_lat FLOAT64,
  dropoff_lng FLOAT64,
  estimated_duration_seconds INT64,
  actual_duration_seconds INT64,
  distance_km FLOAT64,
  surge_multiplier FLOAT64 DEFAULT 1.0,
  payment_method STRING,
  cancelled_reason STRING,
  completed_at TIMESTAMP
)
PARTITION BY DATE(created_at)
CLUSTER BY state, pickup_zone_id
OPTIONS (
  description = "All ride requests with outcomes and metrics"
);

-- Driver locations for supply tracking
CREATE OR REPLACE TABLE `ride_sharing.driver_locations` (
  driver_id STRING NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  lat FLOAT64 NOT NULL,
  lng FLOAT64 NOT NULL,
  pickup_zone_id STRING,
  is_available BOOL NOT NULL DEFAULT TRUE,
  active_pickups INT64 DEFAULT 0,
  capacity_seats INT64 DEFAULT 4
)
PARTITION BY DATE(updated_at)
CLUSTER BY pickup_zone_id, is_available
OPTIONS (
  description = "Driver location snapshots for supply analysis"
);

-- Pickup zones dimension table
CREATE OR REPLACE TABLE `ride_sharing.pickup_zones` (
  zone_id STRING NOT NULL,
  zone_name STRING,
  zone_lat FLOAT64 NOT NULL,
  zone_lng FLOAT64 NOT NULL,
  capacity_cars INT64 DEFAULT 10,
  city STRING DEFAULT 'demo-city',
  zone_type STRING, -- downtown, residential, airport, etc.
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
OPTIONS (
  description = "Geographic zones for pickup/dropoff aggregation"
);

-- Demand/supply aggregated by hour for ML training
CREATE OR REPLACE TABLE `ride_sharing.hourly_demand_supply` (
  zone_id STRING NOT NULL,
  hour_timestamp TIMESTAMP NOT NULL,
  hour_of_day INT64 NOT NULL,
  day_of_week INT64 NOT NULL,
  demand_count INT64 NOT NULL DEFAULT 0,
  supply_count INT64 NOT NULL DEFAULT 0,
  completed_rides INT64 NOT NULL DEFAULT 0,
  avg_wait_time_seconds FLOAT64,
  surge_multiplier FLOAT64 DEFAULT 1.0
)
PARTITION BY DATE(hour_timestamp)
CLUSTER BY zone_id, hour_of_day
OPTIONS (
  description = "Hourly aggregated demand/supply for ML model training"
);

-- Create or replace the demand/supply aggregation view
CREATE OR REPLACE VIEW `ride_sharing.hourly_aggregation` AS
WITH hourly_demand AS (
  SELECT 
    pickup_zone_id as zone_id,
    TIMESTAMP_TRUNC(created_at, HOUR) as hour_timestamp,
    EXTRACT(HOUR FROM created_at) as hour_of_day,
    EXTRACT(DAYOFWEEK FROM created_at) as day_of_week,
    COUNT(*) as demand_count,
    COUNT(CASE WHEN state = 'completed' THEN 1 END) as completed_rides,
    AVG(CASE 
      WHEN state = 'completed' AND actual_duration_seconds > 0 
      THEN actual_duration_seconds 
    END) as avg_wait_time_seconds,
    AVG(surge_multiplier) as avg_surge_multiplier
  FROM `ride_sharing.ride_requests`
  WHERE pickup_zone_id IS NOT NULL
  GROUP BY 1, 2, 3, 4
),
hourly_supply AS (
  SELECT 
    pickup_zone_id as zone_id,
    TIMESTAMP_TRUNC(updated_at, HOUR) as hour_timestamp,
    COUNT(DISTINCT driver_id) as supply_count
  FROM `ride_sharing.driver_locations`
  WHERE pickup_zone_id IS NOT NULL 
    AND is_available = TRUE
  GROUP BY 1, 2
)
SELECT 
  COALESCE(d.zone_id, s.zone_id) as zone_id,
  COALESCE(d.hour_timestamp, s.hour_timestamp) as hour_timestamp,
  COALESCE(d.hour_of_day, EXTRACT(HOUR FROM s.hour_timestamp)) as hour_of_day,
  COALESCE(d.day_of_week, EXTRACT(DAYOFWEEK FROM s.hour_timestamp)) as day_of_week,
  COALESCE(d.demand_count, 0) as demand_count,
  COALESCE(s.supply_count, 0) as supply_count,
  COALESCE(d.completed_rides, 0) as completed_rides,
  d.avg_wait_time_seconds,
  COALESCE(d.avg_surge_multiplier, 1.0) as surge_multiplier
FROM hourly_demand d
FULL OUTER JOIN hourly_supply s
  ON d.zone_id = s.zone_id 
  AND d.hour_timestamp = s.hour_timestamp;

-- Materialized table refresh job (run this periodically)
CREATE OR REPLACE PROCEDURE `ride_sharing.refresh_hourly_aggregation`()
BEGIN
  -- Insert new hourly data
  INSERT INTO `ride_sharing.hourly_demand_supply`
  SELECT * FROM `ride_sharing.hourly_aggregation`
  WHERE hour_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 25 HOUR)
    AND hour_timestamp NOT IN (
      SELECT DISTINCT hour_timestamp 
      FROM `ride_sharing.hourly_demand_supply`
      WHERE hour_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 25 HOUR)
    );
END;

-- Create BigQuery ML model for demand/supply forecasting
CREATE OR REPLACE MODEL `ride_sharing.demand_supply_forecast_model`
OPTIONS (
  model_type = 'BOOSTED_TREE_REGRESSOR',
  input_label_cols = ['demand_count', 'supply_count'],
  max_iterations = 50,
  learn_rate = 0.1,
  subsample = 0.8
) AS
SELECT 
  zone_id,
  hour_of_day,
  day_of_week,
  -- Lagged features
  LAG(demand_count, 1) OVER (PARTITION BY zone_id ORDER BY hour_timestamp) as prev_demand,
  LAG(supply_count, 1) OVER (PARTITION BY zone_id ORDER BY hour_timestamp) as prev_supply,
  LAG(surge_multiplier, 1) OVER (PARTITION BY zone_id ORDER BY hour_timestamp) as prev_surge,
  -- Rolling averages
  AVG(demand_count) OVER (
    PARTITION BY zone_id 
    ORDER BY hour_timestamp 
    ROWS BETWEEN 23 PRECEDING AND 1 PRECEDING
  ) as avg_demand_24h,
  AVG(supply_count) OVER (
    PARTITION BY zone_id 
    ORDER BY hour_timestamp 
    ROWS BETWEEN 23 PRECEDING AND 1 PRECEDING
  ) as avg_supply_24h,
  -- Target variables
  demand_count,
  supply_count
FROM `ride_sharing.hourly_demand_supply`
WHERE hour_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
  AND hour_timestamp < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR);

-- Model evaluation query
CREATE OR REPLACE VIEW `ride_sharing.model_evaluation` AS
SELECT
  *
FROM ML.EVALUATE(
  MODEL `ride_sharing.demand_supply_forecast_model`,
  (
    SELECT 
      zone_id,
      hour_of_day,
      day_of_week,
      LAG(demand_count, 1) OVER (PARTITION BY zone_id ORDER BY hour_timestamp) as prev_demand,
      LAG(supply_count, 1) OVER (PARTITION BY zone_id ORDER BY hour_timestamp) as prev_supply,
      LAG(surge_multiplier, 1) OVER (PARTITION BY zone_id ORDER BY hour_timestamp) as prev_surge,
      AVG(demand_count) OVER (
        PARTITION BY zone_id 
        ORDER BY hour_timestamp 
        ROWS BETWEEN 23 PRECEDING AND 1 PRECEDING
      ) as avg_demand_24h,
      AVG(supply_count) OVER (
        PARTITION BY zone_id 
        ORDER BY hour_timestamp 
        ROWS BETWEEN 23 PRECEDING AND 1 PRECEDING
      ) as avg_supply_24h,
      demand_count,
      supply_count
    FROM `ride_sharing.hourly_demand_supply`
    WHERE hour_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  )
); 