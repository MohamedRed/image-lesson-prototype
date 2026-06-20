// @ts-nocheck
import { initializeTestEnvironment, assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import fs from "fs";
import path from "path";

const rules = fs.readFileSync(path.resolve(__dirname, "../../../firestore.rules"), "utf8");

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-project",
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

describe("Firestore security rules (food-delivery)", () => {
  it("denies client creating orders (server-only)", async () => {
    const ctx = testEnv.authenticatedContext("cust1");
    const db = ctx.firestore();
    const doc = db.collection("orders").doc("o1");
    await assertFails(doc.set({ customerId: "cust1", status: "created" }));
  });

  it("allows customer to read own order but not others", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection("orders").doc("o2").set({ customerId: "custA", restaurantId: "r1" });
    });

    const ownCtx = testEnv.authenticatedContext("custA");
    const ownDb = ownCtx.firestore();
    await assertSucceeds(ownDb.collection("orders").doc("o2").get());

    const otherCtx = testEnv.authenticatedContext("custB");
    const otherDb = otherCtx.firestore();
    await assertFails(otherDb.collection("orders").doc("o2").get());
  });

  it("allows courier limited profile updates only on allowed fields", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection("couriers").doc("c1").set({ userId: "c1", isOnline: false });
    });

    const courierCtx = testEnv.authenticatedContext("c1");
    const cdb = courierCtx.firestore();
    const doc = cdb.collection("couriers").doc("c1");
    await assertSucceeds(doc.update({ isOnline: true, appVersion: "1.2.3" }));
    await assertFails(doc.update({ kyc: { status: "approved" } }));
  });

  it("denies client writes to analytics and audit logs", async () => {
    const ctx = testEnv.authenticatedContext("u1");
    const db = ctx.firestore();
    await assertFails(db.collection("analyticsEvents").doc("e1").set({ a: 1 }));
    await assertFails(db.collection("auditLogs").doc("a1").set({ a: 1 }));
  });

  it("allows restaurant owner to update own restaurant and denies others", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection("restaurants").doc("r1").set({ ownerId: "owner1", name: "Foo" });
    });

    const ownerCtx = testEnv.authenticatedContext("owner1");
    const ownerDb = ownerCtx.firestore();
    await assertSucceeds(ownerDb.collection("restaurants").doc("r1").update({ name: "Bar" }));

    const otherCtx = testEnv.authenticatedContext("owner2");
    const otherDb = otherCtx.firestore();
    await assertFails(otherDb.collection("restaurants").doc("r1").update({ name: "Baz" }));
  });

  it("enforces menuItems ownership for create/update/delete", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection("restaurants").doc("r2").set({ ownerId: "owner2" });
      await adminDb.collection("menuItems").doc("m1").set({ restaurantId: "r2", name: "Pizza" });
    });

    const ownerCtx = testEnv.authenticatedContext("owner2");
    const ownerDb = ownerCtx.firestore();
    await assertSucceeds(ownerDb.collection("menuItems").add({ restaurantId: "r2", name: "Burger" }));
    await assertSucceeds(ownerDb.collection("menuItems").doc("m1").update({ name: "Margherita", restaurantId: "r2" }));
    await assertSucceeds(ownerDb.collection("menuItems").doc("m1").delete());

    const otherCtx = testEnv.authenticatedContext("owner3");
    const otherDb = otherCtx.firestore();
    await assertFails(otherDb.collection("menuItems").add({ restaurantId: "r2", name: "Sushi" }));
    await assertFails(otherDb.collection("menuItems").doc("m1").update({ name: "Pepperoni" }));
    await assertFails(otherDb.collection("menuItems").doc("m1").delete());
  });

  it("enforces menuCategories ownership for create/update/delete", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection("restaurants").doc("r3").set({ ownerId: "owner3" });
      await adminDb.collection("menuCategories").doc("c1").set({ restaurantId: "r3", name: "Main" });
    });

    const ownerCtx = testEnv.authenticatedContext("owner3");
    const ownerDb = ownerCtx.firestore();
    await assertSucceeds(ownerDb.collection("menuCategories").add({ restaurantId: "r3", name: "Sides" }));
    await assertSucceeds(ownerDb.collection("menuCategories").doc("c1").update({ name: "Mains", restaurantId: "r3" }));
    await assertSucceeds(ownerDb.collection("menuCategories").doc("c1").delete());

    const otherCtx = testEnv.authenticatedContext("owner4");
    const otherDb = otherCtx.firestore();
    await assertFails(otherDb.collection("menuCategories").add({ restaurantId: "r3", name: "Desserts" }));
    await assertFails(otherDb.collection("menuCategories").doc("c1").update({ name: "Foo", restaurantId: "r3" }));
    await assertFails(otherDb.collection("menuCategories").doc("c1").delete());
  });
});