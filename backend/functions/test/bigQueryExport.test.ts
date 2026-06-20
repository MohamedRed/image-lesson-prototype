// @ts-nocheck
import { exportRideRequestsOnce } from "../src/bigQueryExport";
import * as admin from "firebase-admin";

describe("exportRideRequestsOnce", () => {
  it("exports rows and updates checkpoint", async () => {
    // Mock Firestore docs
    const rrDoc = {
      id: "req1",
      data: () => ({
        createdAt: { toDate: () => new Date("2024-01-01T00:00:00Z") },
        state: "searching",
        passengerCount: 2,
        fareBreakdown: { total: 10 },
      }),
    };

    const collectionMock = {
      where: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      get: jest.fn().mockResolvedValue({ empty: false, forEach: (cb: any) => cb(rrDoc) }),
    };

    const setMock = jest.fn();

    const dbMock: any = {
      collection: (name: string) => {
        if (name === "rideRequests") return collectionMock;
        if (name === "_internal") return { doc: () => ({ get: jest.fn().mockResolvedValue({ exists: false }), set: setMock }) };
        return {};
      },
    };

    // Mock BigQuery
    const insertMock = jest.fn();
    const table = { insert: insertMock };
    const bqMock: any = { dataset: () => ({ table: () => table }) };

    jest.spyOn(admin, "firestore").mockReturnValue(dbMock);

    const count = await exportRideRequestsOnce(dbMock, bqMock);
    expect(count).toBe(1);
    expect(insertMock).toHaveBeenCalledWith(expect.arrayContaining([expect.objectContaining({ ride_request_id: "req1" })]), expect.any(Object));
    expect(setMock).toHaveBeenCalled();
  });
}); 