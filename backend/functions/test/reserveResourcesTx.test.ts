import { calculateAvailableSeats, reserveMultiLegResources, reserveResourcesTransaction } from "../src/ride-sharing/reserveResourcesTx";

describe("reserve resource capacity helpers", () => {
  it("uses reserved seat ledger instead of pickup count for available seats", () => {
    const seats = calculateAvailableSeats({
      capacitySeats: 4,
      activePickups: 1,
      legs: [{ seats: 3 }],
    });

    expect(seats).toBe(1);
  });

  it("treats an explicitly empty seat ledger as zero reserved seats", () => {
    const seats = calculateAvailableSeats({
      capacitySeats: 4,
      activePickups: 3,
      legs: [],
    });

    expect(seats).toBe(4);
  });

  it("falls back to active pickup count when no seat ledger exists", () => {
    const seats = calculateAvailableSeats({
      capacitySeats: 4,
      activePickups: 1,
    });

    expect(seats).toBe(3);
  });

  it("ignores malformed negative seat ledger entries", () => {
    const seats = calculateAvailableSeats({
      capacitySeats: 4,
      activePickups: 0,
      legs: [{ seats: -3 }, { seats: 2 }],
    });

    expect(seats).toBe(2);
  });
});

describe("reserveResourcesTransaction", () => {
  it("does not require booster for older child when weight is omitted", async () => {
    const updates: Array<{ path: string; data: Record<string, unknown> }> = [];
    const db = fakeReservationDb({
      "drivers/driver-older-child": {
        capacitySeats: 4,
        activePickups: 0,
        childSeatInventory: {},
      },
      "pickupZones/zone-1": {
        capacityCars: 10,
        activePickups: 0,
      },
    }, updates);

    const result = await reserveResourcesTransaction(
      "driver-older-child",
      "zone-1",
      { passengerCount: 1, childPassengers: [{ ageYears: 9, weightKg: 0 }] },
      db as never
    );

    expect(result.success).toBe(true);
    expect(updates.map((update) => update.path)).toEqual(["drivers/driver-older-child", "pickupZones/zone-1"]);
  });

  it("reserves planner-selected pickup and dropoff zones", async () => {
    const updates: Array<{ path: string; data: Record<string, unknown> }> = [];
    const db = fakeReservationDb({
      "drivers/driver-dropoff-zone": {
        capacitySeats: 4,
        activePickups: 0,
      },
      "pickupZones/zone-pickup": {
        capacityCars: 10,
        activePickups: 0,
      },
      "pickupZones/zone-dropoff": {
        capacityCars: 10,
        activePickups: 0,
      },
    }, updates);

    const result = await reserveResourcesTransaction(
      "driver-dropoff-zone",
      "zone-pickup",
      { passengerCount: 1, riderGender: "female" },
      db as never,
      "zone-dropoff"
    );

    expect(result.success).toBe(true);
    expect(result.pickupZoneId).toBe("zone-pickup");
    expect(result.dropoffZoneId).toBe("zone-dropoff");
    expect(updates.map((update) => update.path)).toEqual([
      "drivers/driver-dropoff-zone",
      "pickupZones/zone-pickup",
      "pickupZones/zone-dropoff",
    ]);
  });

  it("rejects planner-selected dropoff zone when curb capacity is full", async () => {
    const updates: Array<{ path: string; data: Record<string, unknown> }> = [];
    const db = fakeReservationDb({
      "drivers/driver-full-dropoff-zone": {
        capacitySeats: 4,
        activePickups: 0,
      },
      "pickupZones/zone-pickup": {
        capacityCars: 10,
        activePickups: 0,
      },
      "pickupZones/full-dropoff": {
        capacityCars: 1,
        activePickups: 1,
      },
    }, updates);

    const result = await reserveResourcesTransaction(
      "driver-full-dropoff-zone",
      "zone-pickup",
      { passengerCount: 1, riderGender: "female" },
      db as never,
      "full-dropoff"
    );

    expect(result.success).toBe(false);
    expect(result.error).toContain("Dropoff zone validation failed");
    expect(updates).toEqual([]);
  });

  it("rejects exclusive ride when driver has existing reserved passengers", async () => {
    const db = fakeReservationDb({
      "drivers/exclusive-occupied": {
        capacitySeats: 4,
        activePickups: 0,
        legs: [{ seats: 1 }],
        premiumCapabilities: { exclusive: true },
      },
      "pickupZones/zone-1": {
        capacityCars: 10,
        activePickups: 0,
      },
    }, []);

    const result = await reserveResourcesTransaction(
      "exclusive-occupied",
      "zone-1",
      { passengerCount: 1, premiumRequested: { exclusive: true } },
      db as never
    );

    expect(result.success).toBe(false);
    expect(result.error).toContain("exclusive ride requires empty vehicle");
  });

  it("treats string-backed exclusive premium requests as occupancy-restricting", async () => {
    const db = fakeReservationDb({
      "drivers/exclusive-occupied-string": {
        capacitySeats: 4,
        activePickups: 0,
        legs: [{ seats: 1 }],
        premiumCapabilities: { exclusive: "true" },
      },
      "pickupZones/zone-1": {
        capacityCars: 10,
        activePickups: 0,
      },
    }, []);

    const result = await reserveResourcesTransaction(
      "exclusive-occupied-string",
      "zone-1",
      { passengerCount: 1, premiumRequested: { exclusive: "true" } } as any,
      db as never
    );

    expect(result.success).toBe(false);
    expect(result.error).toContain("exclusive ride requires empty vehicle");
  });

  it("matches string-backed true premium requests against boolean driver capabilities", async () => {
    const updates: Array<{ path: string; data: Record<string, unknown> }> = [];
    const db = fakeReservationDb({
      "drivers/exclusive-empty-string-request": {
        capacitySeats: 4,
        activePickups: 0,
        premiumCapabilities: { exclusive: true },
      },
      "pickupZones/zone-1": {
        capacityCars: 10,
        activePickups: 0,
      },
    }, updates);

    const result = await reserveResourcesTransaction(
      "exclusive-empty-string-request",
      "zone-1",
      { passengerCount: 1, premiumRequested: { exclusive: "true" } } as any,
      db as never
    );

    expect(result.success).toBe(true);
    expect(updates.map((update) => update.path)).toEqual(["drivers/exclusive-empty-string-request", "pickupZones/zone-1"]);
  });

  it("ignores string-backed false premium toggles", async () => {
    const updates: Array<{ path: string; data: Record<string, unknown> }> = [];
    const db = fakeReservationDb({
      "drivers/non-exclusive-string-false": {
        capacitySeats: 4,
        activePickups: 0,
        premiumCapabilities: {},
      },
      "pickupZones/zone-1": {
        capacityCars: 10,
        activePickups: 0,
      },
    }, updates);

    const result = await reserveResourcesTransaction(
      "non-exclusive-string-false",
      "zone-1",
      { passengerCount: 1, premiumRequested: { exclusive: "false" } } as any,
      db as never
    );

    expect(result.success).toBe(true);
  });

  it("normalizes rider gender before reservation pool comparison and persistence", async () => {
    const updates: Array<{ path: string; data: Record<string, unknown> }> = [];
    const db = fakeReservationDb({
      "drivers/driver-gender-case": {
        capacitySeats: 4,
        activePickups: 0,
        currentPassengerGenders: ["female"],
      },
      "pickupZones/zone-1": {
        capacityCars: 10,
        activePickups: 0,
      },
    }, updates);

    const result = await reserveResourcesTransaction(
      "driver-gender-case",
      "zone-1",
      { passengerCount: 1, riderGender: " Female " } as any,
      db as never
    );

    expect(result.success).toBe(true);
    const driverUpdate = updates.find((update) => update.path === "drivers/driver-gender-case");
    expect(driverUpdate?.data.currentPassengerGenders).toEqual(["female", "female"]);
  });

  it("ignores blank passenger gender placeholders during gender pool validation", async () => {
    const updates: Array<{ path: string; data: Record<string, unknown> }> = [];
    const db = fakeReservationDb({
      "drivers/driver-1": {
        capacitySeats: 4,
        activePickups: 0,
        currentPassengerGenders: ["", "   "],
      },
      "pickupZones/zone-1": {
        capacityCars: 10,
        activePickups: 0,
      },
    }, updates);

    const result = await reserveResourcesTransaction(
      "driver-1",
      "zone-1",
      { passengerCount: 1, riderGender: "female" },
      db as never
    );

    expect(result.success).toBe(true);
    expect(updates.map((update) => update.path)).toEqual(["drivers/driver-1", "pickupZones/zone-1"]);
  });

  it("reserves planner-selected pickup and dropoff zones for every multi-leg leg", async () => {
    const updates: Array<{ path: string; data: Record<string, unknown> }> = [];
    const db = fakeReservationDb({
      "drivers/driver-a": { capacitySeats: 4, activePickups: 0 },
      "drivers/driver-b": { capacitySeats: 4, activePickups: 0 },
      "pickupZones/pickup-a": { capacityCars: 10, activePickups: 0 },
      "pickupZones/dropoff-a": { capacityCars: 10, activePickups: 0 },
      "pickupZones/pickup-b": { capacityCars: 10, activePickups: 0 },
      "pickupZones/dropoff-b": { capacityCars: 10, activePickups: 0 },
    }, updates);

    const result = await reserveMultiLegResources({
      rideRequestId: "req-multi-dropoff",
      totalPassengerCount: 1,
      legs: [
        {
          driverId: "driver-a",
          pickupZoneId: "pickup-a",
          dropoffZoneId: "dropoff-a",
          legNumber: 1,
          requirements: { passengerCount: 1, riderGender: "female" },
        },
        {
          driverId: "driver-b",
          pickupZoneId: "pickup-b",
          dropoffZoneId: "dropoff-b",
          legNumber: 2,
          requirements: { passengerCount: 1, riderGender: "female" },
        },
      ],
    }, db as never);

    expect(result.success).toBe(true);
    expect(updates.map((update) => update.path)).toEqual([
      "drivers/driver-a",
      "pickupZones/pickup-a",
      "pickupZones/dropoff-a",
      "drivers/driver-b",
      "pickupZones/pickup-b",
      "pickupZones/dropoff-b",
    ]);
    expect(result.reservedLegs?.map((leg: any) => leg.dropoffZoneId)).toEqual(["dropoff-a", "dropoff-b"]);
  });

  it("rejects multi-leg reservations when shared transfer zone aggregate capacity would be exceeded", async () => {
    const updates: Array<{ path: string; data: Record<string, unknown> }> = [];
    const db = fakeReservationDb({
      "drivers/driver-a": { capacitySeats: 4, activePickups: 0 },
      "drivers/driver-b": { capacitySeats: 4, activePickups: 0 },
      "pickupZones/origin-pickup": { capacityCars: 10, activePickups: 0 },
      "pickupZones/transfer-zone": { capacityCars: 10, activePickups: 9 },
      "pickupZones/destination-dropoff": { capacityCars: 10, activePickups: 0 },
    }, updates);

    const result = await reserveMultiLegResources({
      rideRequestId: "req-shared-transfer-capacity",
      totalPassengerCount: 1,
      legs: [
        {
          driverId: "driver-a",
          pickupZoneId: "origin-pickup",
          dropoffZoneId: "transfer-zone",
          legNumber: 1,
          requirements: { passengerCount: 1, riderGender: "female" },
        },
        {
          driverId: "driver-b",
          pickupZoneId: "transfer-zone",
          dropoffZoneId: "destination-dropoff",
          legNumber: 2,
          requirements: { passengerCount: 1, riderGender: "female" },
        },
      ],
    }, db as never);

    expect(result.success).toBe(false);
    expect(result.error).toContain("transfer-zone");
    expect(updates).toEqual([]);
  });
});

function fakeReservationDb(
  docs: Record<string, Record<string, unknown>>,
  updates: Array<{ path: string; data: Record<string, unknown> }>
) {
  return {
    doc: (path: string) => ({ path }),
    runTransaction: async (callback: (transaction: unknown) => Promise<unknown>) => {
      const transaction = {
        get: async (ref: { path: string }) => ({
          exists: Object.prototype.hasOwnProperty.call(docs, ref.path),
          data: () => docs[ref.path],
        }),
        update: (ref: { path: string }, data: Record<string, unknown>) => {
          updates.push({ path: ref.path, data });
        },
      };
      return callback(transaction);
    },
  };
}
