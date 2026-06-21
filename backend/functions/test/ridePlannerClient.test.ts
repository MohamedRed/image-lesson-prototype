import {
  buildMultiLegReservationRequirements,
  buildPlannerRequest,
  planJourneyWithSingleLegReservationRetry,
} from "../src/ride-sharing/plannerClient";

describe("planner client", () => {
  const origin = { latitude: 37.1, longitude: -122.1 };
  const destination = { latitude: 37.2, longitude: -122.2 };
  const oriWalkIso = { type: "Polygon", coordinates: [[[0, 0], [1, 0], [1, 1], [0, 0]]] };
  const destWalkIso = { type: "Polygon", coordinates: [[[2, 2], [3, 2], [3, 3], [2, 2]]] };
  const oriDriveIso = { type: "Polygon", coordinates: [[[4, 4], [5, 4], [5, 5], [4, 4]]] };
  const destinationDriveGeo = { type: "Polygon", coordinates: [[[6, 6], [7, 6], [7, 7], [6, 6]]] };

  it("passes rider isochrones and excluded drivers to planner", () => {
    const request = buildPlannerRequest(
      {
        origin,
        destination,
        passengerCount: 2,
        riderGender: "female",
        luggageManifest: { suitcase: 1 },
        walkRadiusM: 80,
      },
      { oriWalkIso, destWalkIso, oriDriveIso, destinationDriveGeo },
      ["driverA"]
    );

    expect(request).toMatchObject({
      origin,
      destination,
      passengerCount: 2,
      riderGender: "female",
      luggageManifest: { suitcase: 1 },
      walkRadiusM: 80,
      oriWalkIso,
      destWalkIso,
      oriDriveIso,
      originWalkIso: oriWalkIso,
      destinationWalkIso: destWalkIso,
      originDriveGeo: oriDriveIso,
      destinationDriveGeo,
      excludedDriverIds: ["driverA"],
    });
  });

  it("requires planner pickup/dropoff points before attempting reservation", async () => {
    const fetchImpl = jest.fn(async () => ({
      ok: true,
      status: 200,
      json: async () => ({
        legs: [{ driverId: "driverA", pickupZoneId: "zone-1", etaSeconds: 120 }],
        totalEtaSeconds: 120,
      }),
    }));

    const reserve = jest.fn(async () => ({
      success: true,
      driverId: "driverA",
      pickupZoneId: "zone-1",
      reservedResources: { seats: 1, cargo: {}, pets: {}, childSeats: {} },
    }));

    await expect(planJourneyWithSingleLegReservationRetry({
      plannerUrl: "https://planner.example",
      rideRequest: { origin, destination, passengerCount: 1, riderGender: "female" },
      resourceRequirements: { passengerCount: 1, riderGender: "female" },
      reserveResources: reserve,
      fetchImpl,
    })).rejects.toThrow("Planner leg 1 missing pickup/dropoff geometry for driver driverA");

    expect(reserve).not.toHaveBeenCalled();
  });

  it("requires planner pickupZoneId before attempting reservation", async () => {
    const fetchImpl = jest.fn(async () => ({
      ok: true,
      status: 200,
      json: async () => ({
        legs: [{
          driverId: "driverA",
          etaSeconds: 120,
          pickup: origin,
          dropoff: destination,
        }],
        totalEtaSeconds: 120,
      }),
    }));

    const reserve = jest.fn(async () => ({
      success: true,
      driverId: "driverA",
      pickupZoneId: "default-zone",
      reservedResources: { seats: 1, cargo: {}, pets: {}, childSeats: {} },
    }));

    await expect(planJourneyWithSingleLegReservationRetry({
      plannerUrl: "https://planner.example",
      rideRequest: { origin, destination, passengerCount: 1, riderGender: "female" },
      resourceRequirements: { passengerCount: 1, riderGender: "female" },
      reserveResources: reserve,
      fetchImpl,
    })).rejects.toThrow("Planner leg missing pickupZoneId for driver driverA");

    expect(reserve).not.toHaveBeenCalled();
  });

  it("retries the planner with excluded driver when single-leg reservation fails", async () => {
    const fetchBodies: any[] = [];
    const fetchImpl = jest.fn(async (_url: string, init: any) => {
      const body = JSON.parse(init.body);
      fetchBodies.push(body);
      const excluded = body.excludedDriverIds || [];
      const driverId = excluded.includes("driverA") ? "driverB" : "driverA";
      return {
        ok: true,
        status: 200,
        json: async () => ({
          legs: [{ driverId, pickupZoneId: "zone-1", pickup: origin, dropoff: destination, etaSeconds: 120 }],
          totalEtaSeconds: 120,
        }),
      };
    });

    const reserve = jest.fn(async (driverId: string) => ({
      success: driverId === "driverB",
      error: driverId === "driverB" ? undefined : "driver full",
      driverId,
      pickupZoneId: "zone-1",
      reservedResources: { seats: 1, cargo: {}, pets: {}, childSeats: {} },
    }));

    const result = await planJourneyWithSingleLegReservationRetry({
      plannerUrl: "https://planner.example",
      rideRequest: { origin, destination, passengerCount: 1, riderGender: "female" },
      geoUpdates: { oriWalkIso, destWalkIso, oriDriveIso },
      resourceRequirements: { passengerCount: 1, riderGender: "female" },
      reserveResources: reserve,
      fetchImpl,
      maxAttempts: 3,
    });

    expect(result.journey.legs[0].driverId).toBe("driverB");
    expect(result.reservation?.success).toBe(true);
    expect(result.attemptedDriverIds).toEqual(["driverA", "driverB"]);
    expect(fetchBodies.map((body) => body.excludedDriverIds)).toEqual([[], ["driverA"]]);
    expect(fetchBodies[0].oriWalkIso).toEqual(oriWalkIso);
    expect(fetchBodies[0].destWalkIso).toEqual(destWalkIso);
    expect(fetchBodies[0].oriDriveIso).toEqual(oriDriveIso);
  });

  it("preserves existing excluded drivers while retrying reservation failures", async () => {
    const fetchBodies: any[] = [];
    const fetchImpl = jest.fn(async (_url: string, init: any) => {
      const body = JSON.parse(init.body);
      fetchBodies.push(body);
      const excluded = body.excludedDriverIds || [];
      const driverId = excluded.includes("driverA") ? "driverB" : "driverA";
      return {
        ok: true,
        status: 200,
        json: async () => ({
          legs: [{ driverId, pickupZoneId: "zone-1", pickup: origin, dropoff: destination, etaSeconds: 120 }],
          totalEtaSeconds: 120,
        }),
      };
    });

    const reserve = jest.fn(async (driverId: string) => ({
      success: driverId === "driverB",
      error: driverId === "driverB" ? undefined : "driver full",
      driverId,
      pickupZoneId: "zone-1",
      reservedResources: { seats: 1, cargo: {}, pets: {}, childSeats: {} },
    }));

    const result = await planJourneyWithSingleLegReservationRetry({
      plannerUrl: "https://planner.example",
      rideRequest: { origin, destination, passengerCount: 1, riderGender: "female", excludedDriverIds: ["previously-failed"] },
      resourceRequirements: { passengerCount: 1, riderGender: "female" },
      reserveResources: reserve,
      fetchImpl,
      maxAttempts: 3,
    });

    expect(result.journey.legs[0].driverId).toBe("driverB");
    expect(result.attemptedDriverIds).toEqual(["driverA", "driverB"]);
    expect(result.excludedDriverIds).toEqual(["previously-failed", "driverA"]);
    expect(fetchBodies.map((body) => body.excludedDriverIds)).toEqual([
      ["previously-failed"],
      ["previously-failed", "driverA"],
    ]);
  });

  it("retries the next planner candidate when reservation transaction throws", async () => {
    const fetchBodies: any[] = [];
    const fetchImpl = jest.fn(async (_url: string, init: any) => {
      const body = JSON.parse(init.body);
      fetchBodies.push(body);
      const excluded = body.excludedDriverIds || [];
      const driverId = excluded.includes("driverA") ? "driverB" : "driverA";
      return {
        ok: true,
        status: 200,
        json: async () => ({
          legs: [{ driverId, pickupZoneId: "zone-1", pickup: origin, dropoff: destination, etaSeconds: 120 }],
          totalEtaSeconds: 120,
        }),
      };
    });

    const reserve = jest.fn(async (driverId: string) => {
      if (driverId === "driverA") {
        throw new Error("transaction aborted");
      }
      return {
        success: true,
        driverId,
        pickupZoneId: "zone-1",
        reservedResources: { seats: 1, cargo: {}, pets: {}, childSeats: {} },
      };
    });

    const result = await planJourneyWithSingleLegReservationRetry({
      plannerUrl: "https://planner.example",
      rideRequest: { origin, destination, passengerCount: 1, riderGender: "female" },
      resourceRequirements: { passengerCount: 1, riderGender: "female" },
      reserveResources: reserve,
      fetchImpl,
      maxAttempts: 3,
    });

    expect(result.journey.legs[0].driverId).toBe("driverB");
    expect(result.attemptedDriverIds).toEqual(["driverA", "driverB"]);
    expect(fetchBodies.map((body) => body.excludedDriverIds)).toEqual([[], ["driverA"]]);
  });

  it("builds multi-leg reservation requirements only from planner-provided pickup zones", () => {
    const requirements = buildMultiLegReservationRequirements(
      {
        legs: [
          { driverId: "driverA", pickupZoneId: "zone-a", etaSeconds: 120 },
          { driverId: "driverB", pickupZoneId: "zone-b", etaSeconds: 240 },
        ],
      },
      {
        passengerCount: 2,
        riderGender: "female",
        luggageManifest: { suitcase: 1 },
        pet: { small: 1 },
      },
      "req-123"
    );

    expect(requirements).toEqual({
      legs: [
        {
          driverId: "driverA",
          pickupZoneId: "zone-a",
          legNumber: 1,
          requirements: {
            passengerCount: 2,
            riderGender: "female",
            luggageManifest: { suitcase: 1 },
            pet: { small: 1 },
            childPassengers: undefined,
            premiumRequested: undefined,
          },
        },
        {
          driverId: "driverB",
          pickupZoneId: "zone-b",
          legNumber: 2,
          requirements: {
            passengerCount: 2,
            riderGender: "female",
            luggageManifest: { suitcase: 1 },
            pet: { small: 1 },
            childPassengers: undefined,
            premiumRequested: undefined,
          },
        },
      ],
      totalPassengerCount: 2,
      rideRequestId: "req-123",
    });
  });

  it("rejects multi-leg planner responses missing pickupZoneId instead of using default-zone", () => {
    expect(() => buildMultiLegReservationRequirements(
      {
        legs: [
          { driverId: "driverA", pickupZoneId: "zone-a" },
          { driverId: "driverB" },
        ],
      },
      { passengerCount: 1, riderGender: "female" },
      "req-456"
    )).toThrow("Planner leg 2 missing pickupZoneId for driver driverB");
  });
});
