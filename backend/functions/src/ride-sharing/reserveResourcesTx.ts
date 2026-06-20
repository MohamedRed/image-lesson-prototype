import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import { incrementCounter, recordLatencyMs } from "../shared/metrics";

try { admin.app(); } catch { admin.initializeApp(); }

export interface ResourceRequirements {
  passengerCount: number;
  riderGender?: "female" | "male" | "nb";
  luggageManifest?: Record<string, number>; // e.g., {"suitcase": 2, "backpack": 1}
  pet?: Record<string, number>; // e.g., {"small": 1}
  childPassengers?: Array<{
    ageYears: number;
    weightKg: number;
  }>;
  premiumRequested?: Record<string, any>;
}

export interface ReservationResult {
  success: boolean;
  driverId?: string;
  pickupZoneId?: string;
  error?: string;
  reservedResources?: {
    seats: number;
    cargo: Record<string, number>;
    pets: Record<string, number>;
    childSeats: Record<string, number>;
  };
}

export interface MultiLegResourceRequirements {
  legs: Array<{
    driverId: string;
    pickupZoneId: string;
    requirements: ResourceRequirements;
    legNumber: number;
  }>;
  totalPassengerCount: number;
  rideRequestId: string;
}

export interface MultiLegReservationResult {
  success: boolean;
  rideRequestId: string;
  error?: string;
  reservedLegs?: Array<{
    legNumber: number;
    driverId: string;
    pickupZoneId: string;
    reservedResources: {
      seats: number;
      cargo: Record<string, number>;
      pets: Record<string, number>;
      childSeats: Record<string, number>;
    };
  }>;
}

/**
 * Atomically reserves driver and pickup zone resources for a ride request.
 * This prevents race conditions and ensures inventory consistency.
 */
export async function reserveResourcesTransaction(
  driverId: string,
  pickupZoneId: string,
  requirements: ResourceRequirements,
  db: admin.firestore.Firestore = admin.firestore()
): Promise<ReservationResult> {
  const startTime = Date.now();
  
  try {
    const result = await db.runTransaction(async (transaction) => {
      // Read current state
      const driverRef = db.doc(`drivers/${driverId}`);
      const zoneRef = db.doc(`pickupZones/${pickupZoneId}`);
      
      const [driverSnap, zoneSnap] = await Promise.all([
        transaction.get(driverRef),
        transaction.get(zoneRef)
      ]);

      if (!driverSnap.exists) {
        throw new Error(`Driver ${driverId} not found`);
      }
      
      if (!zoneSnap.exists) {
        throw new Error(`Pickup zone ${pickupZoneId} not found`);
      }

      const driverData = driverSnap.data()!;
      const zoneData = zoneSnap.data()!;

      // Validate driver constraints
      const validation = validateDriverResources(driverData, requirements);
      if (!validation.valid) {
        throw new Error(`Driver validation failed: ${validation.error}`);
      }

      // Validate pickup zone capacity
      const zoneValidation = validateZoneCapacity(zoneData);
      if (!zoneValidation.valid) {
        throw new Error(`Zone validation failed: ${zoneValidation.error}`);
      }

      // Calculate resource deltas
      const seatDelta = requirements.passengerCount;
      const cargoDeltas = requirements.luggageManifest || {};
      const petDeltas = requirements.pet || {};
      const childSeatDeltas = calculateChildSeatRequirements(requirements.childPassengers || []);

      // Update driver ledgers
      const driverUpdates: Record<string, any> = {
        activePickups: admin.firestore.FieldValue.increment(1),
        lastReservationAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Update seat ledger
      if (driverData.legs) {
        driverUpdates.legs = admin.firestore.FieldValue.arrayUnion({
          reservedAt: admin.firestore.FieldValue.serverTimestamp(),
          seats: seatDelta,
          riderGender: requirements.riderGender,
        });
      } else {
        driverUpdates.legs = [{
          reservedAt: admin.firestore.FieldValue.serverTimestamp(),
          seats: seatDelta,
          riderGender: requirements.riderGender,
        }];
      }

      // Update cargo ledger
      if (Object.keys(cargoDeltas).length > 0) {
        const cargoLedger = driverData.cargoLedger || [];
        cargoLedger.push({
          reservedAt: admin.firestore.FieldValue.serverTimestamp(),
          items: cargoDeltas,
        });
        driverUpdates.cargoLedger = cargoLedger;
      }

      // Update pet ledger
      if (Object.keys(petDeltas).length > 0) {
        const petLedger = driverData.petLedger || [];
        petLedger.push({
          reservedAt: admin.firestore.FieldValue.serverTimestamp(),
          pets: petDeltas,
        });
        driverUpdates.petLedger = petLedger;
      }

      // Update child seat ledger
      if (Object.keys(childSeatDeltas).length > 0) {
        const childSeatLedger = driverData.childSeatLedger || [];
        childSeatLedger.push({
          reservedAt: admin.firestore.FieldValue.serverTimestamp(),
          seats: childSeatDeltas,
        });
        driverUpdates.childSeatLedger = childSeatLedger;
      }

      // Update current passenger genders for safety
      if (requirements.riderGender) {
        const currentGenders = driverData.currentPassengerGenders || [];
        currentGenders.push(requirements.riderGender);
        driverUpdates.currentPassengerGenders = currentGenders;
      }

      // Update pickup zone
      const zoneUpdates: Record<string, any> = {
        activePickups: admin.firestore.FieldValue.increment(1),
        lastReservationAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Apply updates
      transaction.update(driverRef, driverUpdates);
      transaction.update(zoneRef, zoneUpdates);

      return {
        success: true,
        driverId,
        pickupZoneId,
        reservedResources: {
          seats: seatDelta,
          cargo: cargoDeltas,
          pets: petDeltas,
          childSeats: childSeatDeltas,
        },
      };
    });

    await recordLatencyMs("reserveResourcesTx/success", Date.now() - startTime);
    await incrementCounter("reserveResourcesTx/success");
    
    logger.info("Resources reserved successfully", {
      driverId,
      pickupZoneId,
      requirements,
      reservedResources: result.reservedResources,
    });

    return result;

  } catch (error: any) {
    await recordLatencyMs("reserveResourcesTx/error", Date.now() - startTime);
    await incrementCounter("reserveResourcesTx/error");
    
    logger.error("Resource reservation failed", {
      driverId,
      pickupZoneId,
      requirements,
      error: error.message,
    });

    return {
      success: false,
      error: error.message,
    };
  }
}

export function calculateAvailableSeats(driverData: any): number {
  const capacitySeats = driverData.capacitySeats || 4;
  const reservedSeats = getCurrentSeatUsage(driverData.legs || []);
  const seatsUsed = reservedSeats > 0 ? reservedSeats : (driverData.activePickups || 0);
  return capacitySeats - seatsUsed;
}

function getCurrentSeatUsage(legs: any[]): number {
  return legs.reduce((total, leg) => total + (leg.seats || 0), 0);
}

function validateDriverResources(
  driverData: any,
  requirements: ResourceRequirements
): { valid: boolean; error?: string } {
  // Check seat capacity using reserved seat ledger. activePickups counts cars at
  // pickup, not passenger seats, so it is only a backwards-compatible fallback.
  const availableSeats = calculateAvailableSeats(driverData);
  if (availableSeats < requirements.passengerCount) {
    return {
      valid: false,
      error: `Insufficient seats: need ${requirements.passengerCount}, have ${availableSeats}`,
    };
  }

  // Check gender pool consistency
  if (requirements.riderGender && driverData.currentPassengerGenders?.length > 0) {
    const existingGenders = new Set(driverData.currentPassengerGenders);
    if (!existingGenders.has(requirements.riderGender) && existingGenders.size > 0) {
      return {
        valid: false,
        error: `Gender pool mismatch: driver has ${Array.from(existingGenders)}, requested ${requirements.riderGender}`,
      };
    }
  }

  // Check luggage capacity
  if (requirements.luggageManifest) {
    const driverCapacity = driverData.luggageCapacity || {};
    for (const [type, needed] of Object.entries(requirements.luggageManifest)) {
      const available = driverCapacity[type] || 0;
      const currentUsed = getCurrentLuggageUsage(driverData.cargoLedger || [], type);
      if (available - currentUsed < needed) {
        return {
          valid: false,
          error: `Insufficient ${type} capacity: need ${needed}, have ${available - currentUsed}`,
        };
      }
    }
  }

  // Check pet limits
  if (requirements.pet) {
    const driverLimits = driverData.petLimits || {};
    for (const [petType, needed] of Object.entries(requirements.pet)) {
      const limit = driverLimits[petType] || 0;
      const currentUsed = getCurrentPetUsage(driverData.petLedger || [], petType);
      if (limit - currentUsed < needed) {
        return {
          valid: false,
          error: `Pet limit exceeded for ${petType}: need ${needed}, have ${limit - currentUsed}`,
        };
      }
    }
  }

  // Check child seat inventory
  if (requirements.childPassengers && requirements.childPassengers.length > 0) {
    const childSeatNeeds = calculateChildSeatRequirements(requirements.childPassengers);
    const driverInventory = driverData.childSeatInventory || {};
    
    for (const [seatType, needed] of Object.entries(childSeatNeeds)) {
      const available = driverInventory[seatType] || 0;
      const currentUsed = getCurrentChildSeatUsage(driverData.childSeatLedger || [], seatType);
      if (available - currentUsed < needed) {
        return {
          valid: false,
          error: `Insufficient ${seatType} child seats: need ${needed}, have ${available - currentUsed}`,
        };
      }
    }
  }

  return { valid: true };
}

function validateZoneCapacity(zoneData: any): { valid: boolean; error?: string } {
  const capacity = zoneData.capacityCars || 10;
  const active = zoneData.activePickups || 0;
  
  if (active >= capacity) {
    return {
      valid: false,
      error: `Pickup zone at capacity: ${active}/${capacity}`,
    };
  }

  return { valid: true };
}

function calculateChildSeatRequirements(children: Array<{ ageYears: number; weightKg: number }>): Record<string, number> {
  const requirements: Record<string, number> = {};
  
  for (const child of children) {
    if (child.ageYears <= 1) {
      requirements.infant = (requirements.infant || 0) + 1;
    } else if (child.ageYears <= 4) {
      requirements.forward = (requirements.forward || 0) + 1;
    } else if (child.ageYears <= 8 || child.weightKg < 36) {
      requirements.booster = (requirements.booster || 0) + 1;
    }
  }
  
  return requirements;
}

function getCurrentLuggageUsage(cargoLedger: any[], luggageType: string): number {
  return cargoLedger.reduce((total, entry) => {
    return total + (entry.items?.[luggageType] || 0);
  }, 0);
}

function getCurrentPetUsage(petLedger: any[], petType: string): number {
  return petLedger.reduce((total, entry) => {
    return total + (entry.pets?.[petType] || 0);
  }, 0);
}

function getCurrentChildSeatUsage(childSeatLedger: any[], seatType: string): number {
  return childSeatLedger.reduce((total, entry) => {
    return total + (entry.seats?.[seatType] || 0);
  }, 0);
}

/**
 * Atomically reserves resources across multiple legs for multi-hop journeys.
 * Ensures all legs can be reserved before committing any changes.
 */
export async function reserveMultiLegResources(
  requirements: MultiLegResourceRequirements,
  db: admin.firestore.Firestore = admin.firestore()
): Promise<MultiLegReservationResult> {
  const startTime = Date.now();
  
  try {
    const result = await db.runTransaction(async (transaction) => {
      const reservedLegs: MultiLegReservationResult["reservedLegs"] = [];
      
      // Phase 1: Validate all legs can be reserved
      for (const leg of requirements.legs) {
        const driverRef = db.doc(`drivers/${leg.driverId}`);
        const zoneRef = db.doc(`pickupZones/${leg.pickupZoneId}`);
        
        const [driverSnap, zoneSnap] = await Promise.all([
          transaction.get(driverRef),
          transaction.get(zoneRef)
        ]);

        if (!driverSnap.exists) {
          throw new Error(`Driver ${leg.driverId} not found for leg ${leg.legNumber}`);
        }
        
        if (!zoneSnap.exists) {
          throw new Error(`Pickup zone ${leg.pickupZoneId} not found for leg ${leg.legNumber}`);
        }

        const driverData = driverSnap.data()!;
        const zoneData = zoneSnap.data()!;

        // Validate driver constraints for this leg
        const validation = validateDriverResources(driverData, leg.requirements);
        if (!validation.valid) {
          throw new Error(`Driver validation failed for leg ${leg.legNumber}: ${validation.error}`);
        }

        // Validate pickup zone capacity
        const zoneValidation = validateZoneCapacity(zoneData);
        if (!zoneValidation.valid) {
          throw new Error(`Zone validation failed for leg ${leg.legNumber}: ${zoneValidation.error}`);
        }

        // Validate gender pool consistency across legs
        if (leg.requirements.riderGender && driverData.currentPassengerGenders?.length > 0) {
          const existingGenders = new Set(driverData.currentPassengerGenders);
          if (!existingGenders.has(leg.requirements.riderGender) && existingGenders.size > 0) {
            throw new Error(`Gender pool inconsistency on leg ${leg.legNumber}`);
          }
        }
      }

      // Phase 2: Reserve resources for all legs
      for (const leg of requirements.legs) {
        const driverRef = db.doc(`drivers/${leg.driverId}`);
        const zoneRef = db.doc(`pickupZones/${leg.pickupZoneId}`);
        
        // Get fresh data for reservation calculations
        const [driverSnap, zoneSnap] = await Promise.all([
          transaction.get(driverRef),
          transaction.get(zoneRef)
        ]);
        
        const driverData = driverSnap.data()!;
        const seatDelta = leg.requirements.passengerCount;
        const cargoDeltas = leg.requirements.luggageManifest || {};
        const petDeltas = leg.requirements.pet || {};
        const childSeatDeltas = calculateChildSeatRequirements(leg.requirements.childPassengers || []);

        // Update driver ledgers for this leg
        const driverUpdates: Record<string, any> = {
          activePickups: admin.firestore.FieldValue.increment(1),
          lastReservationAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        // Create leg entry
        const legEntry = {
          legNumber: leg.legNumber,
          rideRequestId: requirements.rideRequestId,
          reservedAt: admin.firestore.FieldValue.serverTimestamp(),
          seats: seatDelta,
          riderGender: leg.requirements.riderGender,
        };

        if (driverData.legs) {
          driverUpdates.legs = admin.firestore.FieldValue.arrayUnion(legEntry);
        } else {
          driverUpdates.legs = [legEntry];
        }

        // Update cargo, pet, and child seat ledgers
        if (Object.keys(cargoDeltas).length > 0) {
          const cargoLedger = driverData.cargoLedger || [];
          cargoLedger.push({
            legNumber: leg.legNumber,
            rideRequestId: requirements.rideRequestId,
            reservedAt: admin.firestore.FieldValue.serverTimestamp(),
            items: cargoDeltas,
          });
          driverUpdates.cargoLedger = cargoLedger;
        }

        if (Object.keys(petDeltas).length > 0) {
          const petLedger = driverData.petLedger || [];
          petLedger.push({
            legNumber: leg.legNumber,
            rideRequestId: requirements.rideRequestId,
            reservedAt: admin.firestore.FieldValue.serverTimestamp(),
            pets: petDeltas,
          });
          driverUpdates.petLedger = petLedger;
        }

        if (Object.keys(childSeatDeltas).length > 0) {
          const childSeatLedger = driverData.childSeatLedger || [];
          childSeatLedger.push({
            legNumber: leg.legNumber,
            rideRequestId: requirements.rideRequestId,
            reservedAt: admin.firestore.FieldValue.serverTimestamp(),
            seats: childSeatDeltas,
          });
          driverUpdates.childSeatLedger = childSeatLedger;
        }

        // Update passenger genders for safety validation
        if (leg.requirements.riderGender) {
          const currentGenders = driverData.currentPassengerGenders || [];
          currentGenders.push(leg.requirements.riderGender);
          driverUpdates.currentPassengerGenders = currentGenders;
        }

        // Update pickup zone
        const zoneUpdates: Record<string, any> = {
          activePickups: admin.firestore.FieldValue.increment(1),
          lastReservationAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        // Apply updates
        transaction.update(driverRef, driverUpdates);
        transaction.update(zoneRef, zoneUpdates);

        // Track reserved resources for this leg
        reservedLegs!.push({
          legNumber: leg.legNumber,
          driverId: leg.driverId,
          pickupZoneId: leg.pickupZoneId,
          reservedResources: {
            seats: seatDelta,
            cargo: cargoDeltas,
            pets: petDeltas,
            childSeats: childSeatDeltas,
          },
        });
      }

      return {
        success: true,
        rideRequestId: requirements.rideRequestId,
        reservedLegs,
      };
    });

    // Record metrics
    const latency = Date.now() - startTime;
    await recordLatencyMs("reserveMultiLegResources/success", latency);
    await incrementCounter("reserveMultiLegResources/legs_reserved", { legs_count: requirements.legs.length.toString() });

    logger.info("Multi-leg resources reserved successfully", {
      rideRequestId: requirements.rideRequestId,
      legsCount: requirements.legs.length,
      latencyMs: latency,
    });

    return result;

  } catch (error: any) {
    const latency = Date.now() - startTime;
    await recordLatencyMs("reserveMultiLegResources/error", latency);
    await incrementCounter("reserveMultiLegResources/failures");

    logger.error("Multi-leg resource reservation failed", {
      rideRequestId: requirements.rideRequestId,
      error: error.message,
      latencyMs: latency,
    });

    return {
      success: false,
      rideRequestId: requirements.rideRequestId,
      error: error.message,
    };
  }
} 