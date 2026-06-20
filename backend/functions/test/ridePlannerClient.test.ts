import {
  buildPlannerRequest,
  planJourneyWithSingleLegReservationRetry,
} from "../src/ride-sharing/plannerClient";

describe("planner client", () => {
  const origin = { latitude: 37.1, longitude: -122.1 };
  const destination = { latitude: 37.2, longitude: -122.2 };
  const oriWalkIso = { type: "Polygon", coordinates: [[[0, 0], [1, 0], [1, 1], [0, 0]]] };
  const destWalkIso = { type: "Polygon", coordinates: [[[2, 2], [3, 2], [3, 3], [2, 2]]] };
  const oriDriveIso = { type: "Polygon", coordinates: [[[4, 4], [5, 4], [5, 5], [4, 4]]] };

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
      { oriWalkIso, destWalkIso, oriDriveIso },
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
      excludedDriverIds: ["driverA"],
    });
  });

  it("requires planner pickupZoneId before attempting reservation", async () => {
    const fetchImpl = jest.fn(async () => ({
      ok: true,
      status: 200,
      json: async () => ({
        legs: [{ driverId: "driverA", etaSeconds: 120 }],
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
          legs: [{ driverId, pickupZoneId: "zone-1", etaSeconds: 120 }],
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
});
