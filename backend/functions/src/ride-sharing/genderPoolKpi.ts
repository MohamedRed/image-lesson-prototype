import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { BigQuery } from "@google-cloud/bigquery";
import { withMetrics } from "../shared/metrics";
import { slackNotify } from "../shared/curbImport";

try { admin.app(); } catch { admin.initializeApp(); }

const bq = new BigQuery();
const DATASET = process.env.BQ_DATASET || "ride_sharing";

interface GenderPoolMetrics {
  gender: "female" | "male" | "nb";
  zone_id: string;
  zone_name: string;
  available_drivers: number;
  pending_requests: number;
  avg_wait_time_minutes: number;
  starvation_score: number; // Higher = worse shortage
}

interface StarvationAlert {
  gender: "female" | "male" | "nb";
  zones: Array<{
    zone_id: string;
    zone_name: string;
    shortage_severity: "moderate" | "severe" | "critical";
    available_drivers: number;
    waiting_riders: number;
    estimated_wait_minutes: number;
  }>;
}

/**
 * Gender Pool Starvation KPI
 * Runs hourly to detect when specific gender pools have insufficient driver supply.
 * Alerts operations team to proactively address shortages before they impact riders.
 */
export const genderPoolKpi = withMetrics("genderPoolKpi", onSchedule("0 * * * *", async () => {
  await analyzeGenderPoolStarvation();
}));

export async function analyzeGenderPoolStarvation(
  db: admin.firestore.Firestore = admin.firestore(),
  bigQuery: BigQuery = bq
): Promise<void> {
  try {
    // Query current gender pool metrics from BigQuery
    const metricsQuery = `
      WITH current_drivers AS (
        SELECT 
          pickup_zone_id as zone_id,
          gender,
          COUNT(*) as available_drivers
        FROM \`${process.env.GOOGLE_CLOUD_PROJECT}.${DATASET}.driver_locations\` dl
        JOIN \`${process.env.GOOGLE_CLOUD_PROJECT}.${DATASET}.drivers\` d
          ON dl.driver_id = d.driver_id
        WHERE dl.updated_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 10 MINUTE)
          AND dl.is_available = TRUE
          AND d.is_active = TRUE
        GROUP BY 1, 2
      ),
      pending_requests AS (
        SELECT 
          pickup_zone_id as zone_id,
          rider_gender as gender,
          COUNT(*) as pending_count,
          AVG(TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), created_at, MINUTE)) as avg_wait_minutes
        FROM \`${process.env.GOOGLE_CLOUD_PROJECT}.${DATASET}.ride_requests\`
        WHERE state IN ('searching', 'no-driver')
          AND created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 MINUTE)
          AND rider_gender IS NOT NULL
        GROUP BY 1, 2
      ),
      zone_info AS (
        SELECT 
          zone_id,
          zone_name,
          zone_lat,
          zone_lng
        FROM \`${process.env.GOOGLE_CLOUD_PROJECT}.${DATASET}.pickup_zones\`
      )
      SELECT 
        COALESCE(cd.gender, pr.gender) as gender,
        COALESCE(cd.zone_id, pr.zone_id) as zone_id,
        zi.zone_name,
        COALESCE(cd.available_drivers, 0) as available_drivers,
        COALESCE(pr.pending_count, 0) as pending_requests,
        COALESCE(pr.avg_wait_minutes, 0) as avg_wait_time_minutes,
        -- Starvation score: higher = worse
        CASE 
          WHEN COALESCE(cd.available_drivers, 0) = 0 AND COALESCE(pr.pending_count, 0) > 0 
            THEN 100 + COALESCE(pr.pending_count, 0) * 10
          WHEN COALESCE(cd.available_drivers, 0) > 0 AND COALESCE(pr.pending_count, 0) > 0
            THEN (COALESCE(pr.pending_count, 0) / COALESCE(cd.available_drivers, 1)) * 50
          ELSE 0
        END as starvation_score
      FROM current_drivers cd
      FULL OUTER JOIN pending_requests pr
        ON cd.zone_id = pr.zone_id AND cd.gender = pr.gender
      LEFT JOIN zone_info zi
        ON COALESCE(cd.zone_id, pr.zone_id) = zi.zone_id
      WHERE COALESCE(cd.available_drivers, 0) < 3 -- Focus on low-supply areas
        OR COALESCE(pr.pending_count, 0) > 0
      ORDER BY starvation_score DESC
    `;

    const [rows] = await bigQuery.query({ query: metricsQuery }); const genderPoolRows = rows as GenderPoolMetrics[];

    if (genderPoolRows.length === 0) {
      logger.info("No gender pool starvation detected");
      return;
    }

    // Group by gender and identify critical shortages
    const starvationByGender = groupStarvationByGender(genderPoolRows);
    const alerts: StarvationAlert[] = [];

    for (const [gender, metrics] of Object.entries(starvationByGender)) {
      const criticalZones = metrics
        .filter(m => m.starvation_score >= 25) // Threshold for alerting
        .map(m => ({
          zone_id: m.zone_id,
          zone_name: m.zone_name || `Zone ${m.zone_id}`,
          shortage_severity: getSeverity(m.starvation_score),
          available_drivers: m.available_drivers,
          waiting_riders: m.pending_requests,
          estimated_wait_minutes: Math.round(m.avg_wait_time_minutes),
        }));

      if (criticalZones.length > 0) {
        alerts.push({
          gender: gender as "female" | "male" | "nb",
          zones: criticalZones,
        });
      }
    }

    // Send alerts and store metrics
    if (alerts.length > 0) {
      await sendStarvationAlerts(alerts);
    }

    await storeGenderPoolMetrics(rows, db);

    logger.info("Gender pool KPI analysis completed", {
      total_zones_analyzed: rows.length,
      alerts_sent: alerts.length,
      critical_shortages: alerts.reduce((sum, alert) => sum + alert.zones.length, 0),
    });

  } catch (error: any) {
    logger.error("Gender pool KPI analysis failed", { error: error.message });
    await slackNotify(`❌ Gender Pool KPI analysis failed: ${error.message}`);
  }
}

function groupStarvationByGender(metrics: GenderPoolMetrics[]): Record<string, GenderPoolMetrics[]> {
  return metrics.reduce((groups, metric) => {
    const gender = metric.gender || "unknown";
    if (!groups[gender]) groups[gender] = [];
    groups[gender].push(metric);
    return groups;
  }, {} as Record<string, GenderPoolMetrics[]>);
}

function getSeverity(starvationScore: number): "moderate" | "severe" | "critical" {
  if (starvationScore >= 75) return "critical";
  if (starvationScore >= 50) return "severe";
  return "moderate";
}

async function sendStarvationAlerts(alerts: StarvationAlert[]): Promise<void> {
  for (const alert of alerts) {
    const genderEmoji = {
      female: "👩",
      male: "👨", 
      nb: "🧑"
    }[alert.gender] || "👤";

    const severityEmoji = {
      moderate: "⚠️",
      severe: "🚨",
      critical: "🔥"
    };

    let message = `${genderEmoji} **GENDER POOL SHORTAGE - ${alert.gender.toUpperCase()}**\n\n`;
    
    alert.zones.forEach(zone => {
      message += `${severityEmoji[zone.shortage_severity]} **${zone.zone_name}**\n`;
      message += `• Available drivers: ${zone.available_drivers}\n`;
      message += `• Waiting riders: ${zone.waiting_riders}\n`;
      message += `• Est. wait time: ${zone.estimated_wait_minutes} min\n`;
      message += `• Severity: ${zone.shortage_severity}\n\n`;
    });

    message += `🎯 **Suggested Actions:**\n`;
    message += `• Send driver incentives to affected zones\n`;
    message += `• Expand pickup radius for waiting riders\n`;
    message += `• Consider cross-gender matching (if policy allows)\n`;
    message += `• Alert driver recruitment team\n`;

    await slackNotify(message);
  }
}

async function storeGenderPoolMetrics(
  metrics: GenderPoolMetrics[],
  db: admin.firestore.Firestore
): Promise<void> {
  const timestamp = admin.firestore.Timestamp.now();
  const batch = db.batch();

  // Store current snapshot
  const snapshotRef = db.collection("genderPoolMetrics").doc(timestamp.toDate().toISOString());
  batch.set(snapshotRef, {
    timestamp,
    metrics,
    totalZones: metrics.length,
    criticalShortages: metrics.filter(m => m.starvation_score >= 75).length,
    generatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Update latest metrics for real-time dashboard
  const latestRef = db.collection("_internal").doc("latestGenderPoolMetrics");
  batch.set(latestRef, {
    timestamp,
    metrics,
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
  });

  await batch.commit();

  // Clean up old snapshots (keep last 7 days)
  const cutoff = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
  );

  const oldSnapshots = await db
    .collection("genderPoolMetrics")
    .where("timestamp", "<", cutoff)
    .limit(50)
    .get();

  if (!oldSnapshots.empty) {
    const deleteBatch = db.batch();
    oldSnapshots.docs.forEach(doc => deleteBatch.delete(doc.ref));
    await deleteBatch.commit();
    logger.info("Cleaned up old gender pool metrics", { deleted: oldSnapshots.size });
  }
} 