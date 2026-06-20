import { ResourceRequirements, ReservationResult, MultiLegResourceRequirements } from "./reserveResourcesTx";

export interface PlannerRideRequest {
  origin: any;
  destination: any;
  passengerCount?: number;
  riderGender?: string | null;
  luggageManifest?: Record<string, number>;
  pet?: Record<string, number>;
  childPassengers?: Array<{ ageYears: number; weightKg: number }>;
  premiumRequested?: Record<string, any>;
  walkRadiusM?: number;
  oriWalkIso?: any;
  destWalkIso?: any;
  oriDriveIso?: any;
  originWalkIso?: any;
  destinationWalkIso?: any;
  originDriveGeo?: any;
  excludedDriverIds?: string[];
}

export interface PlannerJourney {
  legs: Array<{
    driverId: string;
    pickupZoneId?: string;
    etaSeconds?: number;
    [key: string]: any;
  }>;
  totalEtaSeconds?: number;
  [key: string]: any;
}

export type FetchLike = (url: string, init: { method: string; headers: Record<string, string>; body: string }) => Promise<{
  ok: boolean;
  status: number;
  json: () => Promise<any>;
}>;

export type ReserveSingleLeg = (
  driverId: string,
  pickupZoneId: string,
  requirements: ResourceRequirements
) => Promise<ReservationResult>;

export interface PlannerReservationRetryParams {
  plannerUrl: string;
  rideRequest: any;
  geoUpdates?: Record<string, any>;
  resourceRequirements: ResourceRequirements;
  reserveResources: ReserveSingleLeg;
  fetchImpl?: FetchLike;
  maxAttempts?: number;
}

export interface PlannerReservationRetryResult {
  journey: PlannerJourney;
  reservation?: ReservationResult;
  pickupZoneId?: string;
  attemptedDriverIds: string[];
  excludedDriverIds: string[];
}

export function buildPlannerRequest(
  rideRequest: any,
  geoUpdates: Record<string, any> = {},
  excludedDriverIds: string[] = []
): PlannerRideRequest {
  const oriWalkIso = rideRequest.oriWalkIso ?? geoUpdates.oriWalkIso;
  const destWalkIso = rideRequest.destWalkIso ?? geoUpdates.destWalkIso;
  const oriDriveIso = rideRequest.oriDriveIso ?? geoUpdates.oriDriveIso;

  return {
    origin: rideRequest.origin,
    destination: rideRequest.destination,
    passengerCount: rideRequest.passengerCount ?? 1,
    riderGender: rideRequest.riderGender ?? null,
    luggageManifest: rideRequest.luggageManifest,
    pet: rideRequest.pet,
    childPassengers: rideRequest.childPassengers,
    premiumRequested: rideRequest.premiumRequested,
    walkRadiusM: rideRequest.walkRadiusM,
    oriWalkIso,
    destWalkIso,
    oriDriveIso,
    originWalkIso: rideRequest.originWalkIso ?? oriWalkIso,
    destinationWalkIso: rideRequest.destinationWalkIso ?? destWalkIso,
    originDriveGeo: rideRequest.originDriveGeo ?? oriDriveIso,
    excludedDriverIds,
  };
}

export async function requestPlannerJourney(
  plannerUrl: string,
  rideRequest: any,
  geoUpdates: Record<string, any> = {},
  excludedDriverIds: string[] = [],
  fetchImpl: FetchLike = fetch as unknown as FetchLike
): Promise<PlannerJourney> {
  const plannerResp = await fetchImpl(`${plannerUrl}/plan`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(buildPlannerRequest(rideRequest, geoUpdates, excludedDriverIds)),
  });

  if (!plannerResp.ok) {
    throw new Error(`Planner HTTP ${plannerResp.status}`);
  }

  const journey = (await plannerResp.json()) as PlannerJourney;
  if (!journey.legs || journey.legs.length === 0) {
    throw new Error("Planner returned no journey legs");
  }

  return journey;
}

export function buildResourceRequirements(rideRequest: any): ResourceRequirements {
  return {
    passengerCount: rideRequest.passengerCount ?? 1,
    riderGender: rideRequest.riderGender,
    luggageManifest: rideRequest.luggageManifest,
    pet: rideRequest.pet,
    childPassengers: rideRequest.childPassengers,
    premiumRequested: rideRequest.premiumRequested,
  };
}

export function buildMultiLegReservationRequirements(
  journey: PlannerJourney,
  rideRequest: any,
  rideRequestId: string
): MultiLegResourceRequirements {
  if (!journey.legs || journey.legs.length === 0) {
    throw new Error("Planner returned no journey legs");
  }

  const requirements = buildResourceRequirements(rideRequest);
  return {
    legs: journey.legs.map((leg, index) => {
      if (!leg.driverId) {
        throw new Error(`Planner leg ${index + 1} missing driverId`);
      }
      if (!leg.pickupZoneId) {
        throw new Error(`Planner leg ${index + 1} missing pickupZoneId for driver ${leg.driverId}`);
      }
      return {
        driverId: leg.driverId,
        pickupZoneId: leg.pickupZoneId,
        legNumber: index + 1,
        requirements,
      };
    }),
    totalPassengerCount: rideRequest.passengerCount ?? 1,
    rideRequestId,
  };
}

export async function planJourneyWithSingleLegReservationRetry({
  plannerUrl,
  rideRequest,
  geoUpdates = {},
  resourceRequirements,
  reserveResources,
  fetchImpl = fetch as unknown as FetchLike,
  maxAttempts = 3,
}: PlannerReservationRetryParams): Promise<PlannerReservationRetryResult> {
  const excludedDriverIds: string[] = [];
  const attemptedDriverIds: string[] = [];
  const reservationErrors: string[] = [];

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const journey = await requestPlannerJourney(plannerUrl, rideRequest, geoUpdates, excludedDriverIds, fetchImpl);

    if (journey.legs.length !== 1) {
      return { journey, attemptedDriverIds, excludedDriverIds };
    }

    const firstLeg = journey.legs[0];
    const driverId = firstLeg.driverId;
    if (!firstLeg.pickupZoneId) {
      throw new Error(`Planner leg missing pickupZoneId for driver ${driverId}`);
    }
    const pickupZoneId = firstLeg.pickupZoneId;
    attemptedDriverIds.push(driverId);

    const reservation = await reserveResources(driverId, pickupZoneId, resourceRequirements);
    if (reservation.success) {
      return { journey, reservation, pickupZoneId, attemptedDriverIds, excludedDriverIds };
    }

    reservationErrors.push(`${driverId}: ${reservation.error || "reservation failed"}`);
    excludedDriverIds.push(driverId);
  }

  throw new Error(
    `Resource reservation failed after ${attemptedDriverIds.length} candidate(s): ${reservationErrors.join("; ")}`
  );
}
