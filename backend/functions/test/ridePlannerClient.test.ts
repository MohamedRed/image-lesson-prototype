import {
  buildMultiLegReservationRequirements,
  buildPlannerRequest,
  planJourneyWithSingleLegReservationRetry,
  requestPlannerJourney,
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

  it("passes canonical geo update aliases to planner in the same invocation", () => {
    const originWalkIso = { type: "Polygon", coordinates: [[[10, 10], [11, 10], [11, 11], [10, 10]]] };
    const destinationWalkIso = { type: "Polygon", coordinates: [[[12, 12], [13, 12], [13, 13], [12, 12]]] };
    const originDriveGeo = { type: "Polygon", coordinates: [[[14, 14], [15, 14], [15, 15], [14, 14]]] };
    const request = buildPlannerRequest(
      { origin, destination, passengerCount: 1 },
      { originWalkIso, destinationWalkIso, originDriveGeo, destinationDriveGeo },
      []
    );

    expect(request).toMatchObject({
      oriWalkIso: originWalkIso,
      destWalkIso: destinationWalkIso,
      oriDriveIso: originDriveGeo,
      originWalkIso,
      destinationWalkIso,
      originDriveGeo,
      destinationDriveGeo,
      destDriveIso: destinationDriveGeo,
    });
  });

  it("passes legacy destDriveIso to planner destination-drive aliases", () => {
    const legacyDestDriveIso = { type: "Polygon", coordinates: [[[16, 16], [17, 16], [17, 17], [16, 16]]] };
    const request = buildPlannerRequest(
      { origin, destination, passengerCount: 1, destDriveIso: legacyDestDriveIso },
      {},
      []
    );

    expect(request.destinationDriveGeo).toEqual(legacyDestDriveIso);
    expect(request.destDriveIso).toEqual(legacyDestDriveIso);
  });

  it("adds a metadata ID-token Authorization header for private Cloud Run planner calls", async () => {
    const previousFunctionTarget = process.env.FUNCTION_TARGET;
    const previousPlannerAuthDisabled = process.env.PLANNER_AUTH_DISABLED;
    const previousPlannerAudience = process.env.PLANNER_ID_TOKEN_AUDIENCE;
    const previousFetch = global.fetch;
    process.env.FUNCTION_TARGET = "processRideRequest";
    delete process.env.PLANNER_AUTH_DISABLED;
    delete process.env.PLANNER_ID_TOKEN_AUDIENCE;
    const metadataFetch = jest.fn(async () => ({
      ok: true,
      status: 200,
      text: async () => "metadata-token",
    }));
    (global as any).fetch = metadataFetch;
    const fetchImpl = jest.fn(async () => ({
      ok: true,
      status: 200,
      json: async () => ({
        legs: [{ driverId: "driverA", pickupZoneId: "zone-1", dropoffZoneId: "zone-dropoff", pickup: origin, dropoff: destination, etaSeconds: 120 }],
        totalEtaSeconds: 120,
      }),
    }));

    try {
      await requestPlannerJourney(
        "https://planner.example",
        { origin, destination, passengerCount: 1, riderGender: "female" },
        {},
        [],
        fetchImpl
      );
    } finally {
      if (previousFunctionTarget === undefined) delete process.env.FUNCTION_TARGET;
      else process.env.FUNCTION_TARGET = previousFunctionTarget;
      if (previousPlannerAuthDisabled === undefined) delete process.env.PLANNER_AUTH_DISABLED;
      else process.env.PLANNER_AUTH_DISABLED = previousPlannerAuthDisabled;
      if (previousPlannerAudience === undefined) delete process.env.PLANNER_ID_TOKEN_AUDIENCE;
      else process.env.PLANNER_ID_TOKEN_AUDIENCE = previousPlannerAudience;
      global.fetch = previousFetch;
    }

    expect(metadataFetch).toHaveBeenCalledWith(
      "http://metadata/computeMetadata/v1/instance/service-accounts/default/identity?audience=https%3A%2F%2Fplanner.example&format=full",
      { headers: { "Metadata-Flavor": "Google" } }
    );
    expect(fetchImpl).toHaveBeenCalledWith("https://planner.example/plan", expect.objectContaining({
      headers: expect.objectContaining({ Authorization: "Bearer metadata-token" }),
    }));
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

  it("requires planner dropoffZoneId before attempting reservation", async () => {
    const fetchImpl = jest.fn(async () => ({
      ok: true,
      status: 200,
      json: async () => ({
        legs: [{
          driverId: "driverA",
          pickupZoneId: "zone-pickup",
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
      pickupZoneId: "zone-pickup",
      reservedResources: { seats: 1, cargo: {}, pets: {}, childSeats: {} },
    }));

    await expect(planJourneyWithSingleLegReservationRetry({
      plannerUrl: "https://planner.example",
      rideRequest: { origin, destination, passengerCount: 1, riderGender: "female" },
      resourceRequirements: { passengerCount: 1, riderGender: "female" },
      reserveResources: reserve,
      fetchImpl,
    })).rejects.toThrow("Planner leg missing dropoffZoneId for driver driverA");

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
          legs: [{ driverId, pickupZoneId: "zone-1", dropoffZoneId: "zone-dropoff", pickup: origin, dropoff: destination, etaSeconds: 120 }],
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
    expect(result.pickupZoneId).toBe("zone-1");
    expect(result.dropoffZoneId).toBe("zone-dropoff");
    expect(reserve).toHaveBeenLastCalledWith("driverB", "zone-1", "zone-dropoff", { passengerCount: 1, riderGender: "female" });
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
          legs: [{ driverId, pickupZoneId: "zone-1", dropoffZoneId: "zone-dropoff", pickup: origin, dropoff: destination, etaSeconds: 120 }],
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

  it("normalizes existing excluded drivers while retrying reservation failures", async () => {
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
          legs: [{ driverId, pickupZoneId: "zone-1", dropoffZoneId: "zone-dropoff", pickup: origin, dropoff: destination, etaSeconds: 120 }],
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
      rideRequest: { origin, destination, passengerCount: 1, riderGender: "female", excludedDriverIds: [" previously-failed ", "", "driverA\n", "previously-failed"] },
      resourceRequirements: { passengerCount: 1, riderGender: "female" },
      reserveResources: reserve,
      fetchImpl,
      maxAttempts: 3,
    });

    expect(result.journey.legs[0].driverId).toBe("driverB");
    expect(result.attemptedDriverIds).toEqual(["driverB"]);
    expect(result.excludedDriverIds).toEqual(["previously-failed", "driverA"]);
    expect(fetchBodies.map((body) => body.excludedDriverIds)).toEqual([
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
          legs: [{ driverId, pickupZoneId: "zone-1", dropoffZoneId: "zone-dropoff", pickup: origin, dropoff: destination, etaSeconds: 120 }],
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

  it("builds multi-leg reservation requirements only from planner-provided pickup/dropoff zones", () => {
    const requirements = buildMultiLegReservationRequirements(
      {
        legs: [
          { driverId: "driverA", pickupZoneId: "zone-a", dropoffZoneId: "dropoff-a", etaSeconds: 120 },
          { driverId: "driverB", pickupZoneId: "zone-b", dropoffZoneId: "dropoff-b", etaSeconds: 240 },
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
          dropoffZoneId: "dropoff-a",
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
          dropoffZoneId: "dropoff-b",
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
          { driverId: "driverA", pickupZoneId: "zone-a", dropoffZoneId: "dropoff-a" },
          { driverId: "driverB", dropoffZoneId: "dropoff-b" },
        ],
      },
      { passengerCount: 1, riderGender: "female" },
      "req-456"
    )).toThrow("Planner leg 2 missing pickupZoneId for driver driverB");
  });

  it("rejects multi-leg planner responses missing dropoffZoneId instead of skipping destination curb reservation", () => {
    expect(() => buildMultiLegReservationRequirements(
      {
        legs: [
          { driverId: "driverA", pickupZoneId: "zone-a", dropoffZoneId: "dropoff-a" },
          { driverId: "driverB", pickupZoneId: "zone-b" },
        ],
      },
      { passengerCount: 1, riderGender: "female" },
      "req-789"
    )).toThrow("Planner leg 2 missing dropoffZoneId for driver driverB");
  });
});
