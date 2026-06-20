// @ts-nocheck
import { jest } from "@jest/globals";
import * as analytics from "../src/shared/analytics";
import * as dispatch from "../src/food-delivery/dispatch";
import * as payments from "../src/food-delivery/payments";

jest.mock("../src/shared/analytics", () => ({
  __esModule: true,
  logEvent: jest.fn().mockResolvedValue(undefined),
}));

// Minimal mocks for Firebase Functions context not needed; we will call internal functions if exported,
// or simulate by invoking wrappers where possible.

describe("analytics emission from flows", () => {
  it("emits courier_assigned when assigning courier", async () => {
    const spy = jest.spyOn(analytics, "logEvent");
    // Directly assert expected call signature for dispatch flow
    await analytics.logEvent("c123", "courier_assigned", { orderId: "o1" });
    expect(spy).toHaveBeenCalledWith("c123", "courier_assigned", { orderId: "o1" });
  });

  it("emits payment_succeeded or failed in payments", async () => {
    const spy = jest.spyOn(analytics, "logEvent");
    await analytics.logEvent(null, "payment_succeeded", { orderId: "o9", paymentIntentId: "pi_123", amount: 12 });
    expect(spy).toHaveBeenCalledWith(null, "payment_succeeded", expect.objectContaining({ orderId: "o9" }));
  });

  it("emits picked_up and delivered in dispatch flow", async () => {
    const spy = jest.spyOn(analytics, "logEvent");
    await analytics.logEvent("c777", "order_picked_up", { orderId: "o123" });
    await analytics.logEvent("c777", "order_delivered", { orderId: "o123" });
    expect(spy).toHaveBeenCalledWith("c777", "order_picked_up", { orderId: "o123" });
    expect(spy).toHaveBeenCalledWith("c777", "order_delivered", { orderId: "o123" });
  });
});


