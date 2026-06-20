import { onDocumentWritten, FirestoreEvent } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { withMetrics } from "../shared/metrics";
import { slackNotify } from "../shared/curbImport";

try { admin.app(); } catch { admin.initializeApp(); }

interface DriverInventory {
  capacitySeats: number;
  luggageCapacity: Record<string, number>;
  petLimits: Record<string, number>;
  childSeatInventory: Record<string, number>;
  premiumCapabilities: Record<string, any>;
  lastUpdated: admin.firestore.Timestamp;
}

interface InventoryMismatch {
  field: string;
  reported: any;
  stored: any;
  severity: "minor" | "major" | "critical";
}

/**
 * Inventory Hash Checker
 * Monitors driver inventory updates and compares reported capabilities
 * against stored data. Auto-cancels active rides if critical mismatches
 * are detected (e.g., removed child seats while carrying children).
 */
export const inventoryHashChecker = withMetrics("inventoryHashChecker", onDocumentWritten(
  "drivers/{driverId}",
  async (event: FirestoreEvent<any, { driverId: string }>) => {
    const driverId = event.params.driverId;
    const before = event.data?.before?.data() as any;
    const after = event.data?.after?.data() as any;

    // Only check if inventory-related fields were updated
    if (!after || !hasInventoryChanges(before, after)) return;

    await validateInventoryConsistency(driverId, before, after);
  }
));

function hasInventoryChanges(before: any, after: any): boolean {
  if (!before) return true; // New driver

  const inventoryFields = [
    'capacitySeats',
    'luggageCapacity',
    'petLimits',
    'childSeatInventory',
    'premiumCapabilities',
    'inventoryHash'
  ];

  return inventoryFields.some(field => {
    const beforeValue = JSON.stringify(before[field] || {});
    const afterValue = JSON.stringify(after[field] || {});
    return beforeValue !== afterValue;
  });
}

async function validateInventoryConsistency(
  driverId: string,
  before: any,
  after: any,
  db: admin.firestore.Firestore = admin.firestore()
): Promise<void> {
  try {
    // Calculate expected hash from stored data
    const storedInventory: DriverInventory = {
      capacitySeats: before?.capacitySeats || 4,
      luggageCapacity: before?.luggageCapacity || {},
      petLimits: before?.petLimits || {},
      childSeatInventory: before?.childSeatInventory || {},
      premiumCapabilities: before?.premiumCapabilities || {},
      lastUpdated: before?.lastInventoryUpdate || admin.firestore.Timestamp.now(),
    };

    const reportedInventory: DriverInventory = {
      capacitySeats: after.capacitySeats || 4,
      luggageCapacity: after.luggageCapacity || {},
      petLimits: after.petLimits || {},
      childSeatInventory: after.childSeatInventory || {},
      premiumCapabilities: after.premiumCapabilities || {},
      lastUpdated: after.lastInventoryUpdate || admin.firestore.Timestamp.now(),
    };

    // Compare hashes
    const reportedHash = after.inventoryHash;
    const expectedHash = calculateInventoryHash(storedInventory);

    if (reportedHash && reportedHash !== expectedHash) {
      logger.warn("Inventory hash mismatch detected", {
        driverId,
        reportedHash,
        expectedHash,
      });
    }

    // Detailed comparison to identify specific mismatches
    const mismatches = compareInventories(storedInventory, reportedInventory);

    if (mismatches.length > 0) {
      await handleInventoryMismatches(driverId, mismatches, storedInventory, reportedInventory, db);
    }

  } catch (error: any) {
    logger.error("Inventory validation failed", {
      driverId,
      error: error.message,
    });
  }
}

function compareInventories(stored: DriverInventory, reported: DriverInventory): InventoryMismatch[] {
  const mismatches: InventoryMismatch[] = [];

  // Check seat capacity
  if (stored.capacitySeats !== reported.capacitySeats) {
    mismatches.push({
      field: "capacitySeats",
      reported: reported.capacitySeats,
      stored: stored.capacitySeats,
      severity: Math.abs(stored.capacitySeats - reported.capacitySeats) > 2 ? "critical" : "major",
    });
  }

  // Check luggage capacity
  const luggageFields = new Set([
    ...Object.keys(stored.luggageCapacity),
    ...Object.keys(reported.luggageCapacity)
  ]);

  for (const field of luggageFields) {
    const storedValue = stored.luggageCapacity[field] || 0;
    const reportedValue = reported.luggageCapacity[field] || 0;
    
    if (storedValue !== reportedValue) {
      mismatches.push({
        field: `luggageCapacity.${field}`,
        reported: reportedValue,
        stored: storedValue,
        severity: Math.abs(storedValue - reportedValue) > 1 ? "major" : "minor",
      });
    }
  }

  // Check pet limits
  const petFields = new Set([
    ...Object.keys(stored.petLimits),
    ...Object.keys(reported.petLimits)
  ]);

  for (const field of petFields) {
    const storedValue = stored.petLimits[field] || 0;
    const reportedValue = reported.petLimits[field] || 0;
    
    if (storedValue !== reportedValue) {
      mismatches.push({
        field: `petLimits.${field}`,
        reported: reportedValue,
        stored: storedValue,
        severity: storedValue > reportedValue ? "major" : "minor",
      });
    }
  }

  // Check child seat inventory (critical for safety)
  const childSeatFields = new Set([
    ...Object.keys(stored.childSeatInventory),
    ...Object.keys(reported.childSeatInventory)
  ]);

  for (const field of childSeatFields) {
    const storedValue = stored.childSeatInventory[field] || 0;
    const reportedValue = reported.childSeatInventory[field] || 0;
    
    if (storedValue !== reportedValue) {
      mismatches.push({
        field: `childSeatInventory.${field}`,
        reported: reportedValue,
        stored: storedValue,
        severity: "critical", // Child safety is always critical
      });
    }
  }

  return mismatches;
}

async function handleInventoryMismatches(
  driverId: string,
  mismatches: InventoryMismatch[],
  stored: DriverInventory,
  reported: DriverInventory,
  db: admin.firestore.Firestore
): Promise<void> {
  const criticalMismatches = mismatches.filter(m => m.severity === "critical");
  const majorMismatches = mismatches.filter(m => m.severity === "major");

  // Create mismatch alert
  const alertId = `inventory_${driverId}_${Date.now()}`;
  await db.collection("inventoryAlerts").doc(alertId).set({
    driverId,
    detectedAt: admin.firestore.FieldValue.serverTimestamp(),
    mismatches,
    storedInventory: stored,
    reportedInventory: reported,
    status: "active",
    severity: criticalMismatches.length > 0 ? "critical" : 
              majorMismatches.length > 0 ? "major" : "minor",
  });

  // Handle critical mismatches - auto-cancel rides
  if (criticalMismatches.length > 0) {
    await handleCriticalMismatches(driverId, criticalMismatches, db);
  }

  // Send alert
  await sendInventoryAlert(driverId, mismatches, stored, reported);

  // Update driver status
  await db.doc(`drivers/${driverId}`).update({
    hasInventoryMismatch: true,
    lastInventoryAlert: admin.firestore.FieldValue.serverTimestamp(),
    inventoryMismatchCount: admin.firestore.FieldValue.increment(1),
  });

  logger.warn("Inventory mismatches detected", {
    driverId,
    alertId,
    criticalCount: criticalMismatches.length,
    majorCount: majorMismatches.length,
    minorCount: mismatches.length - criticalMismatches.length - majorMismatches.length,
  });
}

async function handleCriticalMismatches(
  driverId: string,
  criticalMismatches: InventoryMismatch[],
  db: admin.firestore.Firestore
): Promise<void> {
  // Find active rides for this driver
  const activeRides = await db
    .collection("rideRequests")
    .where("assignedDriverId", "==", driverId)
    .where("state", "in", ["proposed", "priced", "accepted", "riderPickupSoon"])
    .get();

  if (activeRides.empty) return;

  const batch = db.batch();
  const cancelledRideIds: string[] = [];

  for (const rideDoc of activeRides.docs) {
    const rideData = rideDoc.data();
    const shouldCancel = shouldCancelRide(rideData, criticalMismatches);

    if (shouldCancel) {
      batch.update(rideDoc.ref, {
        state: "cancelled",
        cancelReason: "driver_inventory_mismatch",
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        inventoryMismatch: criticalMismatches,
      });
      cancelledRideIds.push(rideDoc.id);
    }
  }

  if (cancelledRideIds.length > 0) {
    await batch.commit();
    
    // Notify operations team
    const alertMessage = `🚨 **CRITICAL INVENTORY MISMATCH - RIDES AUTO-CANCELLED**
Driver: ${driverId}
Cancelled rides: ${cancelledRideIds.join(", ")}

**Critical mismatches:**
${criticalMismatches.map(m => `• ${m.field}: stored=${m.stored}, reported=${m.reported}`).join("\n")}

🎯 **Immediate action required:**
• Contact driver immediately
• Verify actual vehicle inventory
• Manually rebook affected riders
• Consider driver suspension`;

    await slackNotify(alertMessage);

    logger.error("Auto-cancelled rides due to critical inventory mismatch", {
      driverId,
      cancelledRideIds,
      criticalMismatches,
    });
  }
}

function shouldCancelRide(rideData: any, criticalMismatches: InventoryMismatch[]): boolean {
  // Cancel if child seat requirements can't be met
  const hasChildPassengers = rideData.childPassengers && rideData.childPassengers.length > 0;
  const hasChildSeatMismatch = criticalMismatches.some(m => m.field.startsWith("childSeatInventory"));
  
  if (hasChildPassengers && hasChildSeatMismatch) {
    return true;
  }

  // Cancel if passenger count exceeds reduced capacity
  const seatMismatch = criticalMismatches.find(m => m.field === "capacitySeats");
  if (seatMismatch && rideData.passengerCount > seatMismatch.reported) {
    return true;
  }

  return false;
}

async function sendInventoryAlert(
  driverId: string,
  mismatches: InventoryMismatch[],
  stored: DriverInventory,
  reported: DriverInventory
): Promise<void> {
  const criticalCount = mismatches.filter(m => m.severity === "critical").length;
  const majorCount = mismatches.filter(m => m.severity === "major").length;
  
  const severity = criticalCount > 0 ? "🔥 CRITICAL" : 
                   majorCount > 0 ? "🚨 MAJOR" : "⚠️ MINOR";

  let message = `${severity} **INVENTORY MISMATCH DETECTED**
Driver: ${driverId}
Total mismatches: ${mismatches.length}

**Discrepancies:**\n`;

  mismatches.forEach(mismatch => {
    const emoji = mismatch.severity === "critical" ? "🔥" : 
                  mismatch.severity === "major" ? "🚨" : "⚠️";
    message += `${emoji} ${mismatch.field}: stored=${mismatch.stored}, reported=${mismatch.reported}\n`;
  });

  message += `\n🎯 **Actions:**
• Verify driver's actual inventory
• Update stored capabilities if correct
• Investigate potential fraud if incorrect
• Monitor for pattern of mismatches`;

  await slackNotify(message);
}

function calculateInventoryHash(inventory: DriverInventory): string {
  // Simple hash calculation - in production, use a proper crypto hash
  const hashData = {
    seats: inventory.capacitySeats,
    luggage: inventory.luggageCapacity,
    pets: inventory.petLimits,
    childSeats: inventory.childSeatInventory,
    premium: inventory.premiumCapabilities,
  };
  
  return Buffer.from(JSON.stringify(hashData)).toString('base64').slice(0, 16);
} 