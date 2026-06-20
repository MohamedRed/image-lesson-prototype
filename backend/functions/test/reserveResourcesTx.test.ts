import { calculateAvailableSeats } from "../src/ride-sharing/reserveResourcesTx";

describe("reserve resource capacity helpers", () => {
  it("uses reserved seat ledger instead of pickup count for available seats", () => {
    const seats = calculateAvailableSeats({
      capacitySeats: 4,
      activePickups: 1,
      legs: [{ seats: 3 }],
    });

    expect(seats).toBe(1);
  });

  it("falls back to active pickup count when no seat ledger exists", () => {
    const seats = calculateAvailableSeats({
      capacitySeats: 4,
      activePickups: 1,
    });

    expect(seats).toBe(3);
  });
});
