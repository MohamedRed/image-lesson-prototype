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
  destDriveIso?: any;
  originWalkIso?: any;
  destinationWalkIso?: any;
  originDriveGeo?: any;
  destinationDriveGeo?: any;
  excludedDriverIds?: string[];
}

export interface PlannerJourney {
  legs: Array<{
    driverId: string;
    pickupZoneId?: string;
    dropoffZoneId?: string;
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

export type AuthTokenProvider = (audience: string) => Promise<string | undefined>;

export type ReserveSingleLeg = (
  driverId: string,
  pickupZoneId: string,
  dropoffZoneId: string,
  requirements: ResourceRequirements
) => Promise<ReservationResult>;

export interface PlannerReservationRetryParams {
  plannerUrl: string;
  rideRequest: any;
  geoUpdates?: Record<string, any>;
  resourceRequirements: ResourceRequirements;
  reserveResources: ReserveSingleLeg;
  fetchImpl?: FetchLike;
  authTokenProvider?: AuthTokenProvider;
  maxAttempts?: number;
}

export interface PlannerReservationRetryResult {
  journey: PlannerJourney;
  reservation?: ReservationResult;
  pickupZoneId?: string;
  dropoffZoneId?: string;
  attemptedDriverIds: string[];
  excludedDriverIds: string[];
}

export function normalizeDriverIds(driverIds: string[] = []): string[] {
  const normalized: string[] = [];
  const seen = new Set<string>();
  for (const driverId of driverIds) {
    const value = String(driverId ?? "").trim();
    if (!value || seen.has(value)) continue;
    seen.add(value);
    normalized.push(value);
  }
  return normalized;
}

function appendUniqueDriverId(driverIds: string[], driverId: string): void {
  const normalized = normalizeDriverIds([...driverIds, driverId]);
  driverIds.splice(0, driverIds.length, ...normalized);
}

export function buildPlannerRequest(
  rideRequest: any,
  geoUpdates: Record<string, any> = {},
  excludedDriverIds: string[] = rideRequest.excludedDriverIds || []
): PlannerRideRequest {
  const originWalkIso = geoUpdates.originWalkIso ?? geoUpdates.oriWalkIso ?? rideRequest.originWalkIso ?? rideRequest.oriWalkIso;
  const oriWalkIso = originWalkIso;
  const destinationWalkIso = geoUpdates.destinationWalkIso ?? geoUpdates.destWalkIso ?? rideRequest.destinationWalkIso ?? rideRequest.destWalkIso;
  const destWalkIso = destinationWalkIso;
  const originDriveGeo = geoUpdates.originDriveGeo ?? geoUpdates.oriDriveIso ?? rideRequest.originDriveGeo ?? rideRequest.oriDriveIso;
  const oriDriveIso = originDriveGeo;
  const destinationDriveGeo = geoUpdates.destinationDriveGeo ?? geoUpdates.destDriveIso ?? rideRequest.destinationDriveGeo ?? rideRequest.destDriveIso;
  const destDriveIso = destinationDriveGeo;

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
    originWalkIso,
    destinationWalkIso,
    originDriveGeo,
    destinationDriveGeo,
    destDriveIso,
    excludedDriverIds: normalizeDriverIds(excludedDriverIds),
  };
}

export async function requestPlannerJourney(
  plannerUrl: string,
  rideRequest: any,
  geoUpdates: Record<string, any> = {},
  excludedDriverIds: string[] = [],
  fetchImpl: FetchLike = fetch as unknown as FetchLike,
  authTokenProvider?: AuthTokenProvider
): Promise<PlannerJourney> {
  const plannerBaseUrl = normalizePlannerBaseUrl(plannerUrl);
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  const tokenProvider = authTokenProvider ?? (shouldUseMetadataPlannerAuth(plannerBaseUrl) ? metadataIdentityTokenProvider : undefined);
  if (tokenProvider) {
    const token = await tokenProvider(plannerAudience(plannerBaseUrl));
    if (token) {
      headers.Authorization = `Bearer ${token}`;
    }
  }

  const plannerResp = await fetchImpl(`${plannerBaseUrl}/plan`, {
    method: "POST",
    headers,
    body: JSON.stringify(buildPlannerRequest(rideRequest, geoUpdates, excludedDriverIds)),
  });

  if (!plannerResp.ok) {
    throw new Error(`Planner HTTP ${plannerResp.status}`);
  }

  const journey = (await plannerResp.json()) as PlannerJourney;
  if (!journey.legs || journey.legs.length === 0) {
    throw new Error("Planner returned no journey legs");
  }

  assertJourneyDisplayGeometry(journey);

  return journey;
}

function normalizePlannerBaseUrl(plannerUrl: string): string {
  return plannerUrl.replace(/\/+$/, "");
}

function plannerAudience(plannerBaseUrl: string): string {
  return process.env.PLANNER_ID_TOKEN_AUDIENCE || plannerBaseUrl;
}

function shouldUseMetadataPlannerAuth(plannerBaseUrl: string): boolean {
  if (process.env.PLANNER_AUTH_DISABLED === "true") return false;
  if (process.env.PLANNER_ID_TOKEN_AUDIENCE) return true;
  if (!plannerBaseUrl.startsWith("https://")) return false;
  return Boolean(process.env.K_SERVICE || process.env.FUNCTION_TARGET || process.env.FUNCTION_NAME);
}

async function metadataIdentityTokenProvider(audience: string): Promise<string | undefined> {
  const url = `http://metadata/computeMetadata/v1/instance/service-accounts/default/identity?audience=${encodeURIComponent(audience)}&format=full`;
  const response = await fetch(url, { headers: { "Metadata-Flavor": "Google" } });
  if (!response.ok) {
    throw new Error(`Metadata identity token HTTP ${response.status}`);
  }
  const token = (await response.text()).trim();
  return token || undefined;
}

export function assertJourneyDisplayGeometry(journey: PlannerJourney): void {
  journey.legs.forEach((leg, index) => {
    if (!hasGeoPoint(leg.pickup ?? leg.Pickup) || !hasGeoPoint(leg.dropoff ?? leg.Dropoff)) {
      throw new Error(`Planner leg ${index + 1} missing pickup/dropoff geometry for driver ${leg.driverId}`);
    }
  });
}

function hasGeoPoint(value: any): boolean {
  if (!value || typeof value !== "object") return false;
  const latitude = value.latitude ?? value.Latitude;
  const longitude = value.longitude ?? value.Longitude;
  return typeof latitude === "number" && Number.isFinite(latitude) &&
    typeof longitude === "number" && Number.isFinite(longitude);
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
      if (!leg.dropoffZoneId) {
        throw new Error(`Planner leg ${index + 1} missing dropoffZoneId for driver ${leg.driverId}`);
      }
      return {
        driverId: leg.driverId,
        pickupZoneId: leg.pickupZoneId,
        dropoffZoneId: leg.dropoffZoneId,
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
  authTokenProvider,
  maxAttempts = 3,
}: PlannerReservationRetryParams): Promise<PlannerReservationRetryResult> {
  const excludedDriverIds: string[] = normalizeDriverIds(rideRequest.excludedDriverIds || []);
  const attemptedDriverIds: string[] = [];
  const reservationErrors: string[] = [];

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const journey = await requestPlannerJourney(plannerUrl, rideRequest, geoUpdates, excludedDriverIds, fetchImpl, authTokenProvider);

    if (journey.legs.length !== 1) {
      return { journey, attemptedDriverIds, excludedDriverIds };
    }

    const firstLeg = journey.legs[0];
    const driverId = firstLeg.driverId;
    if (!firstLeg.pickupZoneId) {
      throw new Error(`Planner leg missing pickupZoneId for driver ${driverId}`);
    }
    if (!firstLeg.dropoffZoneId) {
      throw new Error(`Planner leg missing dropoffZoneId for driver ${driverId}`);
    }
    const pickupZoneId = firstLeg.pickupZoneId;
    const dropoffZoneId = firstLeg.dropoffZoneId;
    attemptedDriverIds.push(driverId);

    let reservation: ReservationResult;
    try {
      reservation = await reserveResources(driverId, pickupZoneId, dropoffZoneId, resourceRequirements);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      reservationErrors.push(`${driverId}: ${message || "reservation threw"}`);
      appendUniqueDriverId(excludedDriverIds, driverId);
      continue;
    }
    if (reservation.success) {
      return { journey, reservation, pickupZoneId, dropoffZoneId, attemptedDriverIds, excludedDriverIds };
    }

    reservationErrors.push(`${driverId}: ${reservation.error || "reservation failed"}`);
    appendUniqueDriverId(excludedDriverIds, driverId);
  }

  throw new Error(
    `Resource reservation failed after ${attemptedDriverIds.length} candidate(s): ${reservationErrors.join("; ")}`
  );
}
