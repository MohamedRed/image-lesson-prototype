import { calculateAvailableSeats, reserveResourcesTransaction } from "../src/ride-sharing/reserveResourcesTx";

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
});

describe("reserveResourcesTransaction", () => {
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
