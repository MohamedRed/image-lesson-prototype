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
  dropoffZoneId?: string;
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
    dropoffZoneId: string;
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
    dropoffZoneId: string;
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
  db: admin.firestore.Firestore = admin.firestore(),
  dropoffZoneId?: string
): Promise<ReservationResult> {
  const startTime = Date.now();
  
  try {
    const result = await db.runTransaction(async (transaction) => {
      // Read current state
      const driverRef = db.doc(`drivers/${driverId}`);
      const zoneRef = db.doc(`pickupZones/${pickupZoneId}`);
      const dropoffZoneRef = dropoffZoneId && dropoffZoneId !== pickupZoneId
        ? db.doc(`pickupZones/${dropoffZoneId}`)
        : undefined;
      
      const [driverSnap, zoneSnap, dropoffZoneSnap] = await Promise.all([
        transaction.get(driverRef),
        transaction.get(zoneRef),
        dropoffZoneRef ? transaction.get(dropoffZoneRef) : Promise.resolve(undefined)
      ]);

      if (!driverSnap.exists) {
        throw new Error(`Driver ${driverId} not found`);
      }
      
      if (!zoneSnap.exists) {
        throw new Error(`Pickup zone ${pickupZoneId} not found`);
      }

      if (dropoffZoneRef && (!dropoffZoneSnap || !dropoffZoneSnap.exists)) {
        throw new Error(`Dropoff zone ${dropoffZoneId} not found`);
      }

      const driverData = driverSnap.data()!;
      const zoneData = zoneSnap.data()!;
      const dropoffZoneData = dropoffZoneSnap?.data();

      // Validate driver constraints
      const validation = validateDriverResources(driverData, requirements);
      if (!validation.valid) {
        throw new Error(`Driver validation failed: ${validation.error}`);
      }

      // Validate pickup/dropoff zone capacity
      const zoneValidation = validateZoneCapacity(zoneData);
      if (!zoneValidation.valid) {
        throw new Error(`Pickup zone validation failed: ${zoneValidation.error}`);
      }
      if (dropoffZoneData) {
        const dropoffZoneValidation = validateZoneCapacity(dropoffZoneData);
        if (!dropoffZoneValidation.valid) {
          throw new Error(`Dropoff zone validation failed: ${dropoffZoneValidation.error}`);
        }
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
      const nextPassengerGenders = passengerGenderUpdate(driverData.currentPassengerGenders || [], requirements.riderGender);
      if (nextPassengerGenders) {
        driverUpdates.currentPassengerGenders = nextPassengerGenders;
      }

      // Update pickup zone
      const zoneUpdates: Record<string, any> = {
        activePickups: admin.firestore.FieldValue.increment(1),
        lastReservationAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Apply updates
      transaction.update(driverRef, driverUpdates);
      transaction.update(zoneRef, zoneUpdates);
      if (dropoffZoneRef) {
        transaction.update(dropoffZoneRef, zoneUpdates);
      }

      return {
        success: true,
        driverId,
        pickupZoneId,
        dropoffZoneId,
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
      dropoffZoneId,
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
      dropoffZoneId,
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
  const hasSeatLedger = Object.prototype.hasOwnProperty.call(driverData, "legs");
  const reservedSeats = getCurrentSeatUsage(driverData.legs || []);
  const seatsUsed = hasSeatLedger ? reservedSeats : (driverData.activePickups || 0);
  return capacitySeats - seatsUsed;
}

function getCurrentSeatUsage(legs: any[]): number {
  return legs.reduce((total, leg) => total + (leg.seats || 0), 0);
}

function normalizePassengerGender(gender?: string): string | undefined {
  const normalized = gender?.trim().toLowerCase();
  return normalized || undefined;
}

function currentPassengerGenderPool(currentPassengerGenders: unknown[]): string[] {
  return currentPassengerGenders
    .filter((gender): gender is string => typeof gender === "string")
    .map((gender) => normalizePassengerGender(gender))
    .filter((gender): gender is string => Boolean(gender));
}

function genderPoolCompatible(currentPassengerGenders: unknown[], riderGender?: string): boolean {
  const normalizedRiderGender = normalizePassengerGender(riderGender);
  if (!normalizedRiderGender) {
    return true;
  }
  const existingGenders = new Set(currentPassengerGenderPool(currentPassengerGenders));
  return existingGenders.size === 0 || existingGenders.has(normalizedRiderGender);
}

function passengerGenderUpdate(currentPassengerGenders: unknown[], riderGender?: string): string[] | undefined {
  const normalizedRiderGender = normalizePassengerGender(riderGender);
  if (!normalizedRiderGender) {
    return undefined;
  }
  return [...currentPassengerGenderPool(currentPassengerGenders), normalizedRiderGender];
}

function premiumCapabilityRequired(value: any): boolean {
  return typeof value !== "boolean" || value === true;
}

function exclusiveRequested(premiumRequested?: Record<string, any>): boolean {
  return premiumRequested?.exclusive === true;
}

function driverHasExistingPassengers(driverData: any): boolean {
  return calculateAvailableSeats(driverData) < (driverData.capacitySeats || 4) ||
    currentPassengerGenderPool(driverData.currentPassengerGenders || []).length > 0;
}

function validatePremiumRequirements(driverData: any, premiumRequested?: Record<string, any>): { valid: boolean; error?: string } {
  if (!premiumRequested) {
    return { valid: true };
  }

  if (exclusiveRequested(premiumRequested) && driverHasExistingPassengers(driverData)) {
    return { valid: false, error: "exclusive ride requires empty vehicle" };
  }

  const capabilities = driverData.premiumCapabilities || {};
  for (const [key, value] of Object.entries(premiumRequested)) {
    if (!premiumCapabilityRequired(value)) {
      continue;
    }
    if (capabilities[key] !== value) {
      return { valid: false, error: `Missing premium capability: ${key}` };
    }
  }

  return { valid: true };
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
  if (!genderPoolCompatible(driverData.currentPassengerGenders || [], requirements.riderGender)) {
    return {
      valid: false,
      error: `Gender pool mismatch: driver has ${currentPassengerGenderPool(driverData.currentPassengerGenders || [])}, requested ${requirements.riderGender}`,
    };
  }

  const premiumValidation = validatePremiumRequirements(driverData, requirements.premiumRequested);
  if (!premiumValidation.valid) {
    return premiumValidation;
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

function validateZoneCapacityForPending(
  zoneData: any,
  pendingReservations: number,
  zoneId: string
): { valid: boolean; error?: string } {
  const capacity = zoneData.capacityCars || 10;
  const active = zoneData.activePickups || 0;

  if (active + pendingReservations > capacity) {
    return {
      valid: false,
      error: `Zone ${zoneId} aggregate capacity exceeded: ${active}+${pendingReservations}/${capacity}`,
    };
  }

  return { valid: true };
}

function aggregateMultiLegZoneReservationDeltas(
  legs: MultiLegResourceRequirements["legs"]
): Map<string, number> {
  const deltas = new Map<string, number>();

  for (const leg of legs) {
    addZoneReservationDelta(deltas, leg.pickupZoneId);
    if (leg.dropoffZoneId !== leg.pickupZoneId) {
      addZoneReservationDelta(deltas, leg.dropoffZoneId);
    }
  }

  return deltas;
}

function addZoneReservationDelta(deltas: Map<string, number>, zoneId: string): void {
  deltas.set(zoneId, (deltas.get(zoneId) || 0) + 1);
}

function calculateChildSeatRequirements(children: Array<{ ageYears: number; weightKg: number }>): Record<string, number> {
  const requirements: Record<string, number> = {};
  
  for (const child of children) {
    if (child.ageYears <= 1) {
      requirements.infant = (requirements.infant || 0) + 1;
    } else if (child.ageYears <= 4) {
      requirements.forward = (requirements.forward || 0) + 1;
    } else if (child.ageYears <= 8 || (child.weightKg > 0 && child.weightKg < 36)) {
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
      const zoneReservationDeltas = aggregateMultiLegZoneReservationDeltas(requirements.legs);
      
      // Phase 1: Validate all legs can be reserved
      for (const leg of requirements.legs) {
        const driverRef = db.doc(`drivers/${leg.driverId}`);
        const zoneRef = db.doc(`pickupZones/${leg.pickupZoneId}`);
        const dropoffZoneRef = leg.dropoffZoneId !== leg.pickupZoneId
          ? db.doc(`pickupZones/${leg.dropoffZoneId}`)
          : undefined;
        
        const [driverSnap, zoneSnap, dropoffZoneSnap] = await Promise.all([
          transaction.get(driverRef),
          transaction.get(zoneRef),
          dropoffZoneRef ? transaction.get(dropoffZoneRef) : Promise.resolve(undefined)
        ]);

        if (!driverSnap.exists) {
          throw new Error(`Driver ${leg.driverId} not found for leg ${leg.legNumber}`);
        }
        
        if (!zoneSnap.exists) {
          throw new Error(`Pickup zone ${leg.pickupZoneId} not found for leg ${leg.legNumber}`);
        }

        if (dropoffZoneRef && (!dropoffZoneSnap || !dropoffZoneSnap.exists)) {
          throw new Error(`Dropoff zone ${leg.dropoffZoneId} not found for leg ${leg.legNumber}`);
        }

        const driverData = driverSnap.data()!;
        const zoneData = zoneSnap.data()!;
        const dropoffZoneData = dropoffZoneSnap?.data();

        // Validate driver constraints for this leg
        const validation = validateDriverResources(driverData, leg.requirements);
        if (!validation.valid) {
          throw new Error(`Driver validation failed for leg ${leg.legNumber}: ${validation.error}`);
        }

        // Validate pickup/dropoff zone capacity against aggregate pending increments
        const zoneValidation = validateZoneCapacityForPending(
          zoneData,
          zoneReservationDeltas.get(leg.pickupZoneId) || 1,
          leg.pickupZoneId
        );
        if (!zoneValidation.valid) {
          throw new Error(`Zone validation failed for leg ${leg.legNumber}: ${zoneValidation.error}`);
        }
        if (dropoffZoneData) {
          const dropoffZoneValidation = validateZoneCapacityForPending(
            dropoffZoneData,
            zoneReservationDeltas.get(leg.dropoffZoneId) || 1,
            leg.dropoffZoneId
          );
          if (!dropoffZoneValidation.valid) {
            throw new Error(`Dropoff zone validation failed for leg ${leg.legNumber}: ${dropoffZoneValidation.error}`);
          }
        }

        // Validate gender pool consistency across legs
        if (!genderPoolCompatible(driverData.currentPassengerGenders || [], leg.requirements.riderGender)) {
          throw new Error(`Gender pool inconsistency on leg ${leg.legNumber}`);
        }
      }

      // Phase 2: Reserve resources for all legs
      for (const leg of requirements.legs) {
        const driverRef = db.doc(`drivers/${leg.driverId}`);
        const zoneRef = db.doc(`pickupZones/${leg.pickupZoneId}`);
        const dropoffZoneRef = leg.dropoffZoneId !== leg.pickupZoneId
          ? db.doc(`pickupZones/${leg.dropoffZoneId}`)
          : undefined;
        
        // Get fresh data for reservation calculations
        const [driverSnap] = await Promise.all([
          transaction.get(driverRef),
          transaction.get(zoneRef),
          dropoffZoneRef ? transaction.get(dropoffZoneRef) : Promise.resolve(undefined)
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
        const nextPassengerGenders = passengerGenderUpdate(driverData.currentPassengerGenders || [], leg.requirements.riderGender);
        if (nextPassengerGenders) {
          driverUpdates.currentPassengerGenders = nextPassengerGenders;
        }

        // Update pickup zone
        const zoneUpdates: Record<string, any> = {
          activePickups: admin.firestore.FieldValue.increment(1),
          lastReservationAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        // Apply updates
        transaction.update(driverRef, driverUpdates);
        transaction.update(zoneRef, zoneUpdates);
        if (dropoffZoneRef) {
          transaction.update(dropoffZoneRef, zoneUpdates);
        }

        // Track reserved resources for this leg
        reservedLegs!.push({
          legNumber: leg.legNumber,
          driverId: leg.driverId,
          pickupZoneId: leg.pickupZoneId,
          dropoffZoneId: leg.dropoffZoneId,
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