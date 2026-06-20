// @ts-nocheck
// eslint-disable-next-line
import { reconcileCongestion } from "../src/congestion";
import * as admin from "firebase-admin";

describe("reconcileCongestion", () => {
  it("corrects driver activePickups and updates curbLoadFactor", async () => {
    // Arrange – mock Firestore
    const driverUpdate = jest.fn().mockResolvedValue(undefined);
    const zoneUpdate = jest.fn().mockResolvedValue(undefined);

    const driverDoc = {
      id: "driver-1",
      data: () => ({ activePickups: 5 }),
      ref: { update: driverUpdate },
    } as any;

    const zoneDoc = {
      id: "zone-1",
      data: () => ({ capacityCars: 2, activePickups: 5 }),
      ref: { update: zoneUpdate },
    } as any;

    // Mock query objects with fluent where()
    const rideRequestsQuery: any = {
      where: jest.fn().mockReturnThis(),
      get: jest.fn().mockResolvedValue({ size: 2 }), // actual driver pickups
    };

    const rideLegsQuery: any = {
      where: jest.fn().mockReturnThis(),
      get: jest.fn().mockResolvedValue({ size: 5 }), // legs in zone (over capacity)
    };

    const mockDb: any = {
      collection: (name: string) => {
        if (name === "drivers") {
          return {
            get: jest.fn().mockResolvedValue({ docs: [driverDoc] }),
          };
        }
        if (name === "rideRequests") {
          return rideRequestsQuery;
        }
        if (name === "pickupZones") {
          return {
            get: jest.fn().mockResolvedValue({ docs: [zoneDoc] }),
          };
        }
        return {};
      },
      collectionGroup: (name: string) => {
        if (name === "rideLegs") {
          return rideLegsQuery;
        }
        return {};
      },
    };

    jest.spyOn(admin, "firestore").mockReturnValue(mockDb as any);
    (admin.firestore as any).FieldValue = { delete: () => "DEL" };

    // Act
    await reconcileCongestion(mockDb);

    // Assert
    expect(driverUpdate).toHaveBeenCalledWith({ activePickups: 2 });
    expect(zoneUpdate).toHaveBeenCalledWith({ activePickups: 5, curbLoadFactor: 2.5, driveIsoShrinkMeters: 60 });
  });
}); 