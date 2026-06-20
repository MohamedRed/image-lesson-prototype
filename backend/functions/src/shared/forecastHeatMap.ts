import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { BigQuery } from "@google-cloud/bigquery";
import { withMetrics } from "../shared/metrics";

try { admin.app(); } catch { admin.initializeApp(); }

const bq = new BigQuery();

interface HeatMapCell {
  lat: number;
  lng: number;
  demandScore: number;
  supplyScore: number;
  surgeMultiplier: number;
  timestamp: string;
  zoneId: string;
}

interface ForecastRow {
  zone_id: string;
  lat: number;
  lng: number;
  predicted_demand: number;
  predicted_supply: number;
  surge_multiplier: number;
  forecast_timestamp: string;
}

const DATASET = process.env.BQ_DATASET || "ride_sharing";
const FORECAST_MODEL = "demand_supply_forecast_model";

/**
 * S8 – Forecast Job
 * Runs every 10 minutes to generate demand/supply heat-map using BigQuery ML.
 * Writes results to heatMaps/{timestamp} collection for real-time surge pricing.
 */
export async function generateForecastHeatMap(
  db = admin.firestore(), 
  bigQuery: BigQuery = bq
): Promise<number> {
  const now = new Date();
  const timestamp = now.toISOString();
  
  // Query BigQuery ML model for next 10-minute prediction
  const query = `
    SELECT 
      zone_id,
      zone_lat as lat,
      zone_lng as lng,
      predicted_demand,
      predicted_supply,
      CASE 
        WHEN predicted_supply > 0 THEN GREATEST(1.0, predicted_demand / predicted_supply)
        ELSE 2.5
      END as surge_multiplier,
      CURRENT_TIMESTAMP() as forecast_timestamp
    FROM ML.PREDICT(
      MODEL \`${process.env.GOOGLE_CLOUD_PROJECT}.${DATASET}.${FORECAST_MODEL}\`,
      (
        SELECT 
          zone_id,
          zone_lat,
          zone_lng,
          EXTRACT(HOUR FROM CURRENT_TIMESTAMP()) as hour_of_day,
          EXTRACT(DAYOFWEEK FROM CURRENT_TIMESTAMP()) as day_of_week,
          -- Recent demand/supply features from last hour
          COALESCE(recent_rides.ride_count, 0) as recent_demand,
          COALESCE(active_drivers.driver_count, 0) as recent_supply
        FROM \`${process.env.GOOGLE_CLOUD_PROJECT}.${DATASET}.pickup_zones\` zones
        LEFT JOIN (
          SELECT 
            pickup_zone_id,
            COUNT(*) as ride_count
          FROM \`${process.env.GOOGLE_CLOUD_PROJECT}.${DATASET}.ride_requests\`
          WHERE created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
          GROUP BY pickup_zone_id
        ) recent_rides ON zones.zone_id = recent_rides.pickup_zone_id
        LEFT JOIN (
          SELECT 
            pickup_zone_id,
            COUNT(DISTINCT driver_id) as driver_count
          FROM \`${process.env.GOOGLE_CLOUD_PROJECT}.${DATASET}.driver_locations\`
          WHERE updated_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 10 MINUTE)
          GROUP BY pickup_zone_id
        ) active_drivers ON zones.zone_id = active_drivers.pickup_zone_id
      )
    )
    ORDER BY surge_multiplier DESC
  `;

  try {
    const [rows] = await bigQuery.query({ query });
    const forecastRows = rows as ForecastRow[];
    
    if (forecastRows.length === 0) {
      logger.warn("No forecast data returned from BigQuery ML model");
      return 0;
    }

    // Convert to heat map cells
    const heatMapCells: HeatMapCell[] = forecastRows.map(row => ({
      lat: row.lat,
      lng: row.lng,
      demandScore: Math.max(0, row.predicted_demand),
      supplyScore: Math.max(0, row.predicted_supply),
      surgeMultiplier: Math.min(5.0, Math.max(1.0, row.surge_multiplier)), // Cap surge at 5x
      timestamp,
      zoneId: row.zone_id,
    }));

    // Write to Firestore in batches
    const batch = db.batch();
    const heatMapRef = db.collection("heatMaps").doc(timestamp);
    
    batch.set(heatMapRef, {
      timestamp: admin.firestore.Timestamp.fromDate(now),
      cellCount: heatMapCells.length,
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Write individual cells as subcollection
    heatMapCells.forEach((cell, index) => {
      const cellRef = heatMapRef.collection("cells").doc(`cell_${index}`);
      batch.set(cellRef, {
        ...cell,
        timestamp: admin.firestore.Timestamp.fromDate(now),
      });
    });

    await batch.commit();

    // Clean up old heat maps (keep last 24 hours)
    const cutoff = admin.firestore.Timestamp.fromDate(
      new Date(now.getTime() - 24 * 60 * 60 * 1000)
    );
    
    const oldMaps = await db
      .collection("heatMaps")
      .where("timestamp", "<", cutoff)
      .limit(50)
      .get();

    if (!oldMaps.empty) {
      const deleteBatch = db.batch();
      oldMaps.docs.forEach(doc => deleteBatch.delete(doc.ref));
      await deleteBatch.commit();
      logger.info("Cleaned up old heat maps", { deleted: oldMaps.size });
    }

    logger.info("Forecast heat map generated", { 
      cellCount: heatMapCells.length,
      avgSurge: heatMapCells.reduce((sum, cell) => sum + cell.surgeMultiplier, 0) / heatMapCells.length,
      maxSurge: Math.max(...heatMapCells.map(cell => cell.surgeMultiplier))
    });

    return heatMapCells.length;

  } catch (error: any) {
    logger.error("Forecast heat map generation failed", { error: error.message });
    throw error;
  }
}

export const forecastHeatMap = withMetrics("forecastHeatMap", onSchedule("*/10 * * * *", async () => {
  await generateForecastHeatMap();
})); 