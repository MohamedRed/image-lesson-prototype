import { onDocumentWritten, FirestoreEvent } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { withMetrics } from "../shared/metrics";
import { slackNotify } from "../shared/curbImport";

try { admin.app(); } catch { admin.initializeApp(); }

interface LocationUpdate {
  lat: number;
  lng: number;
  timestamp: admin.firestore.Timestamp;
  accuracy?: number; // meters
  altitude?: number;
  speed?: number; // km/h
  bearing?: number; // degrees
  source?: "gps" | "network" | "passive";
}

interface SpoofingIndicators {
  rapidJumps: number;
  impossibleSpeed: number;
  lowAccuracy: number;
  patternScore: number;
  totalScore: number;
}

const MAX_REALISTIC_SPEED_KMH = 150; // Urban speed limit + buffer
const MIN_ACCURACY_THRESHOLD_METERS = 100;
const RAPID_JUMP_THRESHOLD_METERS = 500;
const SPOOFING_SCORE_THRESHOLD = 75;

/**
 * Location Spoof Detector
 * Analyzes driver location updates for signs of GPS manipulation:
 * - Impossible speed changes
 * - Rapid position jumps
 * - Consistently poor accuracy
 * - Unnatural movement patterns
 */
export const locationSpoofDetector = withMetrics("locationSpoofDetector", onDocumentWritten(
  "drivers/{driverId}",
  async (event: FirestoreEvent<any, { driverId: string }>) => {
    const driverId = event.params.driverId;
    const before = event.data?.before?.data() as any;
    const after = event.data?.after?.data() as any;

    if (!after?.currentLocation || !before?.currentLocation) return;

    const currentUpdate: LocationUpdate = {
      lat: after.currentLocation.latitude,
      lng: after.currentLocation.longitude,
      timestamp: after.lastSeenAt || admin.firestore.Timestamp.now(),
      accuracy: after.locationAccuracy,
      speed: after.currentSpeed,
      bearing: after.bearing,
      source: after.locationSource,
    };

    const previousUpdate: LocationUpdate = {
      lat: before.currentLocation.latitude,
      lng: before.currentLocation.longitude,
      timestamp: before.lastSeenAt || admin.firestore.Timestamp.now(),
      accuracy: before.locationAccuracy,
      speed: before.currentSpeed,
      bearing: before.bearing,
      source: before.locationSource,
    };

    await analyzeSpoofingIndicators(driverId, previousUpdate, currentUpdate);
  }
));

async function analyzeSpoofingIndicators(
  driverId: string,
  previous: LocationUpdate,
  current: LocationUpdate,
  db: admin.firestore.Firestore = admin.firestore()
): Promise<void> {
  const timeDiffSeconds = current.timestamp.seconds - previous.timestamp.seconds;
  
  // Skip if updates are too close together or too far apart
  if (timeDiffSeconds < 5 || timeDiffSeconds > 300) return;

  const distanceMeters = haversineDistance(
    previous.lat,
    previous.lng,
    current.lat,
    current.lng
  );

  const calculatedSpeedKmh = (distanceMeters / 1000) / (timeDiffSeconds / 3600);

  // Calculate spoofing indicators
  const indicators: SpoofingIndicators = {
    rapidJumps: 0,
    impossibleSpeed: 0,
    lowAccuracy: 0,
    patternScore: 0,
    totalScore: 0,
  };

  // Check for rapid position jumps
  if (distanceMeters > RAPID_JUMP_THRESHOLD_METERS && timeDiffSeconds < 30) {
    indicators.rapidJumps = Math.min(50, distanceMeters / 100);
  }

  // Check for impossible speeds
  if (calculatedSpeedKmh > MAX_REALISTIC_SPEED_KMH) {
    indicators.impossibleSpeed = Math.min(40, (calculatedSpeedKmh - MAX_REALISTIC_SPEED_KMH) / 10);
  }

  // Check for consistently poor accuracy
  const avgAccuracy = ((current.accuracy || 0) + (previous.accuracy || 0)) / 2;
  if (avgAccuracy > MIN_ACCURACY_THRESHOLD_METERS || avgAccuracy === 0) {
    indicators.lowAccuracy = Math.min(20, avgAccuracy / 50);
  }

  // Check for unnatural movement patterns
  indicators.patternScore = await analyzeMovementPattern(driverId, current, db);

  // Calculate total spoofing score
  indicators.totalScore = 
    indicators.rapidJumps + 
    indicators.impossibleSpeed + 
    indicators.lowAccuracy + 
    indicators.patternScore;

  // Store indicators for trend analysis
  await storeLocationAnalysis(driverId, current, indicators, {
    distanceMeters,
    timeDiffSeconds,
    calculatedSpeedKmh,
  }, db);

  // Alert if spoofing score exceeds threshold
  if (indicators.totalScore >= SPOOFING_SCORE_THRESHOLD) {
    await handleSuspiciousLocation(driverId, current, indicators, {
      distanceMeters,
      calculatedSpeedKmh,
      timeDiffSeconds,
    }, db);
  }
}

async function analyzeMovementPattern(
  driverId: string,
  current: LocationUpdate,
  db: admin.firestore.Firestore
): Promise<number> {
  try {
    // Get recent location history
    const recentAnalyses = await db
      .collection("locationAnalyses")
      .where("driverId", "==", driverId)
      .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(
        new Date(Date.now() - 10 * 60 * 1000) // Last 10 minutes
      ))
      .orderBy("timestamp", "desc")
      .limit(5)
      .get();

    if (recentAnalyses.size < 3) return 0;

    let patternScore = 0;
    const analyses = recentAnalyses.docs.map(doc => doc.data());

    // Check for teleportation pattern (rapid jumps without gradual movement)
    const rapidJumps = analyses.filter(a => a.indicators?.rapidJumps > 0).length;
    if (rapidJumps >= 2) {
      patternScore += 15;
    }

    // Check for consistent high speeds without acceleration pattern
    const highSpeeds = analyses.filter(a => a.metrics?.calculatedSpeedKmh > 80).length;
    if (highSpeeds >= 3) {
      patternScore += 10;
    }

    // Check for location source inconsistency
    const sources = analyses.map(a => a.locationUpdate?.source).filter(Boolean);
    const uniqueSources = new Set(sources);
    if (uniqueSources.size > 2) {
      patternScore += 5;
    }

    return Math.min(25, patternScore);

  } catch (error: any) {
    logger.warn("Pattern analysis failed", { driverId, error: error.message });
    return 0;
  }
}

async function storeLocationAnalysis(
  driverId: string,
  locationUpdate: LocationUpdate,
  indicators: SpoofingIndicators,
  metrics: {
    distanceMeters: number;
    timeDiffSeconds: number;
    calculatedSpeedKmh: number;
  },
  db: admin.firestore.Firestore
): Promise<void> {
  const analysisId = `${driverId}_${Date.now()}`;
  
  await db.collection("locationAnalyses").doc(analysisId).set({
    driverId,
    timestamp: locationUpdate.timestamp,
    locationUpdate,
    indicators,
    metrics,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Clean up old analyses (keep last 24 hours)
  const cutoff = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - 24 * 60 * 60 * 1000)
  );

  const oldAnalyses = await db
    .collection("locationAnalyses")
    .where("driverId", "==", driverId)
    .where("timestamp", "<", cutoff)
    .limit(20)
    .get();

  if (!oldAnalyses.empty) {
    const batch = db.batch();
    oldAnalyses.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
  }
}

async function handleSuspiciousLocation(
  driverId: string,
  location: LocationUpdate,
  indicators: SpoofingIndicators,
  metrics: {
    distanceMeters: number;
    calculatedSpeedKmh: number;
    timeDiffSeconds: number;
  },
  db: admin.firestore.Firestore
): Promise<void> {
  const alertId = `spoof_${driverId}_${Date.now()}`;

  try {
    // Create spoof alert document
    await db.collection("spoofAlerts").doc(alertId).set({
      driverId,
      location: new admin.firestore.GeoPoint(location.lat, location.lng),
      detectedAt: admin.firestore.FieldValue.serverTimestamp(),
      indicators,
      metrics,
      status: "active",
      severity: getSpoofingSeverity(indicators.totalScore),
    });

    // Get driver details
    const driverDoc = await db.doc(`drivers/${driverId}`).get();
    const driverData = driverDoc.data();
    const driverName = driverData?.name || `Driver ${driverId}`;

    // Send Slack alert
    const severity = getSpoofingSeverity(indicators.totalScore);
    const severityEmoji = {
      low: "⚠️",
      medium: "🚨",
      high: "🔥",
      critical: "💀"
    }[severity];

    const alertMessage = `${severityEmoji} **LOCATION SPOOFING DETECTED**
Driver: ${driverName} (${driverId})
Location: ${location.lat.toFixed(6)}, ${location.lng.toFixed(6)}
Spoofing Score: ${indicators.totalScore.toFixed(1)}/100
Severity: ${severity.toUpperCase()}

**Indicators:**
• Rapid jumps: ${indicators.rapidJumps.toFixed(1)}
• Impossible speed: ${indicators.impossibleSpeed.toFixed(1)}
• Low accuracy: ${indicators.lowAccuracy.toFixed(1)}
• Pattern anomaly: ${indicators.patternScore.toFixed(1)}

**Metrics:**
• Distance: ${metrics.distanceMeters.toFixed(0)}m
• Speed: ${metrics.calculatedSpeedKmh.toFixed(1)} km/h
• Time diff: ${metrics.timeDiffSeconds}s

🎯 **Suggested Actions:**
• Suspend driver account temporarily
• Request location permission audit
• Manual verification of recent trips
• Consider device inspection`;

    await slackNotify(alertMessage);

    // Flag driver account
    await db.doc(`drivers/${driverId}`).update({
      isSuspiciousLocation: true,
      lastSpoofAlert: admin.firestore.FieldValue.serverTimestamp(),
      spoofingScore: indicators.totalScore,
    });

    logger.warn("Location spoofing detected", {
      driverId,
      alertId,
      indicators,
      metrics,
      severity,
    });

  } catch (error: any) {
    logger.error("Failed to handle suspicious location", {
      driverId,
      error: error.message,
      indicators,
      metrics,
    });
  }
}

function getSpoofingSeverity(score: number): "low" | "medium" | "high" | "critical" {
  if (score >= 90) return "critical";
  if (score >= 80) return "high";
  if (score >= 70) return "medium";
  return "low";
}

function haversineDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371000; // Earth radius in meters
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRad(degrees: number): number {
  return degrees * (Math.PI / 180);
} 