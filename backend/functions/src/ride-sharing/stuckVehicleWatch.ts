import { onDocumentWritten, FirestoreEvent } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { withMetrics } from "../shared/metrics";
import { slackNotify } from "../shared/curbImport";

try { admin.app(); } catch { admin.initializeApp(); }

interface DriverLocation {
  lat: number;
  lng: number;
  timestamp: admin.firestore.Timestamp;
  isOnCurb?: boolean;
  speed?: number; // km/h
}

const STUCK_THRESHOLD_SECONDS = 45;
const MIN_MOVEMENT_THRESHOLD_METERS = 10;
const SPEED_THRESHOLD_KMH = 5;

/**
 * Stuck Vehicle Watchdog
 * Monitors driver location updates and detects vehicles that are:
 * 1. Not moving (< 5 km/h for 45+ seconds)
 * 2. Not on a legal curb
 * 3. Potentially blocking traffic
 */
export const stuckVehicleWatch = withMetrics("stuckVehicleWatch", onDocumentWritten(
  "drivers/{driverId}",
  async (event: FirestoreEvent<any, { driverId: string }>) => {
    const driverId = event.params.driverId;
    const before = event.data?.before?.data() as any;
    const after = event.data?.after?.data() as any;

    if (!after?.currentLocation) return;

    const currentLocation: DriverLocation = {
      lat: after.currentLocation.latitude,
      lng: after.currentLocation.longitude,
      timestamp: after.lastSeenAt || admin.firestore.Timestamp.now(),
      isOnCurb: after.isOnCurb,
      speed: after.currentSpeed,
    };

    // Only check if driver has active pickups (is in service)
    if (!after.activePickups || after.activePickups === 0) return;

    // Check if this is a significant location update
    if (before?.currentLocation) {
      const prevLocation: DriverLocation = {
        lat: before.currentLocation.latitude,
        lng: before.currentLocation.longitude,
        timestamp: before.lastSeenAt || admin.firestore.Timestamp.now(),
        isOnCurb: before.isOnCurb,
        speed: before.currentSpeed,
      };

      await checkForStuckVehicle(driverId, prevLocation, currentLocation);
    }
  }
));

async function checkForStuckVehicle(
  driverId: string,
  prevLocation: DriverLocation,
  currentLocation: DriverLocation,
  db: admin.firestore.Firestore = admin.firestore()
): Promise<void> {
  // Calculate movement distance
  const distanceMeters = haversineDistance(
    prevLocation.lat,
    prevLocation.lng,
    currentLocation.lat,
    currentLocation.lng
  );

  // Calculate time difference
  const timeDiffSeconds = currentLocation.timestamp.seconds - prevLocation.timestamp.seconds;
  
  // Skip if update is too recent or too old
  if (timeDiffSeconds < 10 || timeDiffSeconds > 300) return;

  // Calculate speed if not provided
  let currentSpeed = currentLocation.speed;
  if (!currentSpeed && timeDiffSeconds > 0) {
    currentSpeed = (distanceMeters / 1000) / (timeDiffSeconds / 3600); // km/h
  }

  // Check stuck conditions
  const isMovingSlowly = (currentSpeed || 0) < SPEED_THRESHOLD_KMH;
  const hasntMovedMuch = distanceMeters < MIN_MOVEMENT_THRESHOLD_METERS;
  const isNotOnCurb = !currentLocation.isOnCurb;
  const hasBeenStuckLongEnough = timeDiffSeconds >= STUCK_THRESHOLD_SECONDS;

  if (isMovingSlowly && hasntMovedMuch && isNotOnCurb && hasBeenStuckLongEnough) {
    await handleStuckVehicle(driverId, currentLocation, {
      distanceMeters,
      timeDiffSeconds,
      currentSpeed: currentSpeed || 0,
      isOnCurb: currentLocation.isOnCurb || false,
    }, db);
  }
}

async function handleStuckVehicle(
  driverId: string,
  location: DriverLocation,
  metrics: {
    distanceMeters: number;
    timeDiffSeconds: number;
    currentSpeed: number;
    isOnCurb: boolean;
  },
  db: admin.firestore.Firestore
): Promise<void> {
  const roadBlockId = `${driverId}_${Date.now()}`;
  
  try {
    // Create road block document
    await db.collection("roadBlocks").doc(roadBlockId).set({
      driverId,
      location: new admin.firestore.GeoPoint(location.lat, location.lng),
      detectedAt: admin.firestore.FieldValue.serverTimestamp(),
      status: "active",
      metrics,
      severity: calculateSeverity(metrics),
      notifiedAt: null,
    });

    // Get driver details for notification
    const driverDoc = await db.doc(`drivers/${driverId}`).get();
    const driverData = driverDoc.data();
    const driverName = driverData?.name || `Driver ${driverId}`;
    const vehicleInfo = driverData?.vehicle || {};

    // Send Slack alert
    const alertMessage = `🚨 **STUCK VEHICLE DETECTED**
Driver: ${driverName} (${driverId})
Vehicle: ${vehicleInfo.make} ${vehicleInfo.model} (${vehicleInfo.licensePlate})
Location: ${location.lat.toFixed(6)}, ${location.lng.toFixed(6)}
Speed: ${metrics.currentSpeed.toFixed(1)} km/h
Stationary for: ${Math.round(metrics.timeDiffSeconds)} seconds
On curb: ${metrics.isOnCurb ? "✅" : "❌"}

🎯 Action needed: Contact driver or dispatch traffic management`;

    await slackNotify(alertMessage);

    // Update road block with notification timestamp
    await db.collection("roadBlocks").doc(roadBlockId).update({
      notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Flag driver as potentially stuck
    await db.doc(`drivers/${driverId}`).update({
      isStuck: true,
      stuckSince: location.timestamp,
      stuckLocation: new admin.firestore.GeoPoint(location.lat, location.lng),
    });

    logger.warn("Stuck vehicle detected and reported", {
      driverId,
      roadBlockId,
      location: { lat: location.lat, lng: location.lng },
      metrics,
    });

  } catch (error: any) {
    logger.error("Failed to handle stuck vehicle", {
      driverId,
      error: error.message,
      location,
      metrics,
    });
  }
}

function calculateSeverity(metrics: {
  timeDiffSeconds: number;
  currentSpeed: number;
  isOnCurb: boolean;
}): "low" | "medium" | "high" | "critical" {
  const { timeDiffSeconds, currentSpeed, isOnCurb } = metrics;

  // Critical: Blocking traffic lane for >2 minutes
  if (!isOnCurb && timeDiffSeconds > 120) return "critical";
  
  // High: Blocking traffic lane for >45 seconds
  if (!isOnCurb && timeDiffSeconds > 45) return "high";
  
  // Medium: On curb but stuck for >5 minutes
  if (isOnCurb && timeDiffSeconds > 300) return "medium";
  
  // Low: Minor delays
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

/**
 * Cleanup job to resolve old road blocks
 */
export async function cleanupRoadBlocks(db: admin.firestore.Firestore = admin.firestore()): Promise<void> {
  const cutoff = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - 30 * 60 * 1000) // 30 minutes ago
  );

  const oldBlocks = await db
    .collection("roadBlocks")
    .where("status", "==", "active")
    .where("detectedAt", "<", cutoff)
    .get();

  const batch = db.batch();
  oldBlocks.docs.forEach(doc => {
    batch.update(doc.ref, { 
      status: "auto-resolved",
      resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  if (!oldBlocks.empty) {
    await batch.commit();
    logger.info("Auto-resolved old road blocks", { count: oldBlocks.size });
  }
} 