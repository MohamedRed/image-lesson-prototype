// @ts-nocheck
import * as admin from "firebase-admin";
import { logEvent } from "../src/shared/analytics";

jest.mock("firebase-admin", () => {
  const addMock = jest.fn().mockResolvedValue({ id: "abc" });
  const collectionMock = jest.fn().mockReturnValue({ add: addMock });
  const firestoreFn: any = jest.fn().mockReturnValue({ collection: collectionMock });
  firestoreFn.FieldValue = { serverTimestamp: jest.fn(() => "ts") };
  return {
    __esModule: true,
    firestore: firestoreFn,
  } as any;
});

describe("analytics.logEvent", () => {
  it("writes event with payload and server timestamp field", async () => {
    await logEvent("user1", "order_created", { orderId: "o1" });
    const db = (admin.firestore as any)();
    expect(db.collection).toHaveBeenCalledWith("analyticsEvents");
    const add = db.collection.mock.results[0].value.add;
    expect(add).toHaveBeenCalled();
    const arg = add.mock.calls[0][0];
    expect(arg.userId).toBe("user1");
    expect(arg.name).toBe("order_created");
    expect(arg.metadata.orderId).toBe("o1");
    expect(arg.createdAt).toBeDefined();
  });
});


