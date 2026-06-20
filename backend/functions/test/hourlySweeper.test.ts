// @ts-nocheck
import { performHourlySweep } from "../src/sweeper";
import * as admin from "firebase-admin";

describe("performHourlySweep", () => {
  it("marks old legs completed", async () => {
    const legUpdate = jest.fn();
    const docMock = { ref: { update: legUpdate } } as any;

    const cgQuery: any = {
      where: jest.fn().mockReturnThis(),
      get: jest.fn().mockResolvedValue({ docs: [docMock], size: 1 }),
    };

    const dbMock: any = {
      collectionGroup: (name: string) => {
        if (name === "rideLegs") return cgQuery;
        return {};
      },
    };

    jest.spyOn(admin, "firestore").mockReturnValue(dbMock);
    (admin.firestore as any).FieldValue = { serverTimestamp: () => "TS" };

    await performHourlySweep(dbMock);

    expect(legUpdate).toHaveBeenCalledWith({ status: "completed", swept: true, sweptAt: "TS" });
  });
}); 