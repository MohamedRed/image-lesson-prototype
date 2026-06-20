// @ts-nocheck
import { performPayoutRun } from "../src/payoutScheduler";
import * as admin from "firebase-admin";
import Stripe from "stripe";

global.process.env.DRIVER_SHARE_PERCENT = "80";

describe("performPayoutRun", () => {
  it("aggregates rides and creates stripe transfers", async () => {
    // --- Mock Firestore ---
    const ride1 = {
      data: () => ({
        assignedDriverId: "driverA",
        state: "completed",
        completedAt: { toDate: () => new Date("2024-02-01T00:00:00Z") },
        fareBreakdown: { total: 100 },
      }),
    };
    const ride2 = {
      data: () => ({
        assignedDriverId: "driverA",
        state: "completed",
        completedAt: { toDate: () => new Date("2024-02-01T00:10:00Z") },
        fareBreakdown: { total: 50 },
      }),
    };
    const ride3 = {
      data: () => ({
        assignedDriverId: "driverB",
        state: "completed",
        completedAt: { toDate: () => new Date("2024-02-01T00:05:00Z") },
        fareBreakdown: { total: 50 },
      }),
    };

    const rideQuery = {
      where: jest.fn().mockReturnThis(),
      get: jest.fn().mockResolvedValue({ empty: false, forEach: (cb: any) => { [ride1, ride2, ride3].forEach(cb); } }),
    };

    const driverDocA = { exists: true, data: () => ({ stripeAccountId: "acct_A" }) };
    const driverDocB = { exists: true, data: () => ({ stripeAccountId: "acct_B" }) };

    const payoutsAdd = jest.fn();
    const cfgSet = jest.fn();

    const dbMock: any = {
      collection: (name: string) => {
        if (name === "rideRequests") return rideQuery;
        if (name === "_internal") return { doc: () => ({ get: jest.fn().mockResolvedValue({ exists: false }), set: cfgSet }) };
        if (name === "payouts") return { add: payoutsAdd };
        if (name === "drivers") {
          return {
            doc: (id: string) => ({ get: jest.fn().mockResolvedValue(id === "driverA" ? driverDocA : driverDocB) }),
          };
        }
        return {};
      },
      doc: () => ({}),
    };

    jest.spyOn(admin, "firestore").mockReturnValue(dbMock);

    // --- Mock Stripe ---
    const acctRetrieve = jest.fn().mockResolvedValue({ requirements: { currently_due: [] } });
    const transferCreate = jest.fn().mockResolvedValue({ id: "tr_123" });
    const stripeMock: any = {
      accounts: { retrieve: acctRetrieve },
      transfers: { create: transferCreate },
    } as unknown as Stripe;

    const results = await performPayoutRun(dbMock, stripeMock);

    expect(results.length).toBe(2);
    // driverA total 150 * 0.8 = 120 => 12000 cents
    expect(transferCreate).toHaveBeenCalledWith(expect.objectContaining({ amount: 12000, destination: "acct_A" }));
    // driverB total 50 *0.8 = 40 => 4000 cents
    expect(transferCreate).toHaveBeenCalledWith(expect.objectContaining({ amount: 4000, destination: "acct_B" }));
    expect(payoutsAdd).toHaveBeenCalledTimes(2);
    expect(cfgSet).toHaveBeenCalled();
  });
}); 