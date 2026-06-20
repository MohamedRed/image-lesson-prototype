-- BigQuery Procedures and Views for Ride Sharing Platform

-- Procedure to refresh hourly aggregation data
CREATE OR REPLACE PROCEDURE `ride_sharing.refresh_hourly_aggregation`()
BEGIN
  -- Create temporary table with latest hourly data
  CREATE OR REPLACE TEMP TABLE temp_hourly AS
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
      AVG(COALESCE(surge_multiplier, 1.0)) as avg_surge_multiplier
    FROM `ride_sharing.ride_requests`
    WHERE pickup_zone_id IS NOT NULL
      AND created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 25 HOUR)
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
      AND updated_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 25 HOUR)
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

  -- Insert new records that don't already exist
  INSERT INTO `ride_sharing.hourly_demand_supply`
  SELECT * FROM temp_hourly
  WHERE hour_timestamp NOT IN (
    SELECT DISTINCT hour_timestamp 
    FROM `ride_sharing.hourly_demand_supply`
    WHERE hour_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 25 HOUR)
  );

  -- Log completion
  SELECT 
    'Hourly aggregation refresh completed' as status,
    COUNT(*) as records_processed,
    MIN(hour_timestamp) as earliest_hour,
    MAX(hour_timestamp) as latest_hour
  FROM temp_hourly;
END;

-- View for real-time demand/supply metrics
CREATE OR REPLACE VIEW `ride_sharing.current_demand_supply` AS
WITH recent_demand AS (
  SELECT 
    pickup_zone_id as zone_id,
    COUNT(*) as current_demand,
    COUNT(CASE WHEN state IN ('searching', 'no-driver') THEN 1 END) as unmatched_demand
  FROM `ride_sharing.ride_requests`
  WHERE created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 MINUTE)
    AND pickup_zone_id IS NOT NULL
  GROUP BY 1
),
recent_supply AS (
  SELECT 
    pickup_zone_id as zone_id,
    COUNT(DISTINCT driver_id) as current_supply
  FROM `ride_sharing.driver_locations`
  WHERE updated_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 10 MINUTE)
    AND pickup_zone_id IS NOT NULL 
    AND is_available = TRUE
  GROUP BY 1
),
zone_info AS (
  SELECT 
    zone_id,
    zone_name,
    zone_lat,
    zone_lng,
    capacity_cars
  FROM `ride_sharing.pickup_zones`
)
SELECT 
  zi.zone_id,
  zi.zone_name,
  zi.zone_lat,
  zi.zone_lng,
  zi.capacity_cars,
  COALESCE(rd.current_demand, 0) as current_demand,
  COALESCE(rs.current_supply, 0) as current_supply,
  COALESCE(rd.unmatched_demand, 0) as unmatched_demand,
  CASE 
    WHEN COALESCE(rs.current_supply, 0) = 0 THEN 5.0
    ELSE GREATEST(1.0, COALESCE(rd.current_demand, 0) / COALESCE(rs.current_supply, 1))
  END as current_surge_multiplier,
  CURRENT_TIMESTAMP() as calculated_at
FROM zone_info zi
LEFT JOIN recent_demand rd ON zi.zone_id = rd.zone_id
LEFT JOIN recent_supply rs ON zi.zone_id = rs.zone_id
ORDER BY current_surge_multiplier DESC;

-- View for ML model training data with features
CREATE OR REPLACE VIEW `ride_sharing.ml_training_features` AS
SELECT 
  hds.zone_id,
  hds.hour_timestamp,
  hds.hour_of_day,
  hds.day_of_week,
  -- Current hour metrics
  hds.demand_count,
  hds.supply_count,
  hds.completed_rides,
  hds.avg_wait_time_seconds,
  hds.surge_multiplier,
  -- Lagged features (previous hour)
  LAG(hds.demand_count, 1) OVER (
    PARTITION BY hds.zone_id 
    ORDER BY hds.hour_timestamp
  ) as prev_hour_demand,
  LAG(hds.supply_count, 1) OVER (
    PARTITION BY hds.zone_id 
    ORDER BY hds.hour_timestamp
  ) as prev_hour_supply,
  LAG(hds.surge_multiplier, 1) OVER (
    PARTITION BY hds.zone_id 
    ORDER BY hds.hour_timestamp
  ) as prev_hour_surge,
  -- Rolling averages (last 24 hours)
  AVG(hds.demand_count) OVER (
    PARTITION BY hds.zone_id 
    ORDER BY hds.hour_timestamp 
    ROWS BETWEEN 23 PRECEDING AND 1 PRECEDING
  ) as avg_demand_24h,
  AVG(hds.supply_count) OVER (
    PARTITION BY hds.zone_id 
    ORDER BY hds.hour_timestamp 
    ROWS BETWEEN 23 PRECEDING AND 1 PRECEDING
  ) as avg_supply_24h,
  AVG(hds.surge_multiplier) OVER (
    PARTITION BY hds.zone_id 
    ORDER BY hds.hour_timestamp 
    ROWS BETWEEN 23 PRECEDING AND 1 PRECEDING
  ) as avg_surge_24h,
  -- Weekly patterns (same hour last week)
  LAG(hds.demand_count, 168) OVER (
    PARTITION BY hds.zone_id 
    ORDER BY hds.hour_timestamp
  ) as same_hour_last_week_demand,
  LAG(hds.supply_count, 168) OVER (
    PARTITION BY hds.zone_id 
    ORDER BY hds.hour_timestamp
  ) as same_hour_last_week_supply,
  -- Zone characteristics
  pz.zone_type,
  pz.capacity_cars,
  -- Weather and events (placeholder for future enhancement)
  CASE 
    WHEN hds.day_of_week IN (1, 7) THEN 'weekend'
    ELSE 'weekday'
  END as day_type,
  CASE 
    WHEN hds.hour_of_day BETWEEN 7 AND 9 THEN 'morning_rush'
    WHEN hds.hour_of_day BETWEEN 17 AND 19 THEN 'evening_rush'
    WHEN hds.hour_of_day BETWEEN 22 AND 6 THEN 'late_night'
    ELSE 'regular'
  END as time_period
FROM `ride_sharing.hourly_demand_supply` hds
LEFT JOIN `ride_sharing.pickup_zones` pz ON hds.zone_id = pz.zone_id
WHERE hds.hour_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
ORDER BY hds.zone_id, hds.hour_timestamp;

-- View for model performance monitoring
CREATE OR REPLACE VIEW `ride_sharing.forecast_accuracy` AS
WITH actual_vs_predicted AS (
  SELECT 
    hm.timestamp,
    hm.zone_id,
    hm.predicted_demand,
    hm.predicted_supply,
    hm.predicted_surge,
    -- Get actual values from next hour
    LEAD(hds.demand_count, 1) OVER (
      PARTITION BY hm.zone_id 
      ORDER BY hm.timestamp
    ) as actual_demand,
    LEAD(hds.supply_count, 1) OVER (
      PARTITION BY hm.zone_id 
      ORDER BY hm.timestamp
    ) as actual_supply,
    LEAD(hds.surge_multiplier, 1) OVER (
      PARTITION BY hm.zone_id 
      ORDER BY hm.timestamp
    ) as actual_surge
  FROM `ride_sharing.heat_maps` hm
  LEFT JOIN `ride_sharing.hourly_demand_supply` hds 
    ON hm.zone_id = hds.zone_id 
    AND TIMESTAMP_TRUNC(hm.timestamp, HOUR) = hds.hour_timestamp
  WHERE hm.timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
)
SELECT 
  zone_id,
  COUNT(*) as prediction_count,
  -- Demand accuracy metrics
  AVG(ABS(predicted_demand - actual_demand)) as mean_absolute_error_demand,
  SQRT(AVG(POW(predicted_demand - actual_demand, 2))) as rmse_demand,
  CORR(predicted_demand, actual_demand) as correlation_demand,
  -- Supply accuracy metrics  
  AVG(ABS(predicted_supply - actual_supply)) as mean_absolute_error_supply,
  SQRT(AVG(POW(predicted_supply - actual_supply, 2))) as rmse_supply,
  CORR(predicted_supply, actual_supply) as correlation_supply,
  -- Surge accuracy metrics
  AVG(ABS(predicted_surge - actual_surge)) as mean_absolute_error_surge,
  SQRT(AVG(POW(predicted_surge - actual_surge, 2))) as rmse_surge,
  CORR(predicted_surge, actual_surge) as correlation_surge,
  -- Overall accuracy score (0-100)
  100 * (
    CORR(predicted_demand, actual_demand) * 0.4 +
    CORR(predicted_supply, actual_supply) * 0.4 +
    CORR(predicted_surge, actual_surge) * 0.2
  ) as overall_accuracy_score
FROM actual_vs_predicted
WHERE actual_demand IS NOT NULL 
  AND actual_supply IS NOT NULL
  AND actual_surge IS NOT NULL
GROUP BY zone_id
ORDER BY overall_accuracy_score DESC; 