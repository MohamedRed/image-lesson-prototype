import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { withAudit } from "../shared/audit";

export const submitCourierKyc = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentication required");

  const { documents } = request.data || {};
  if (!Array.isArray(documents) || documents.length === 0) {
    throw new HttpsError("invalid-argument", "documents is required");
  }

  const ref = admin.firestore().doc(`couriers/${uid}`);
  await ref.set({ kyc: { status: "pending", documents, submittedAt: admin.firestore.FieldValue.serverTimestamp() } }, { merge: true });

  await withAudit(uid, "submitCourierKyc", uid, async () => Promise.resolve(), "courier");
  return { success: true };
});

export const submitRestaurantKyc = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentication required");

  const { restaurantId, documents } = request.data || {};
  if (!restaurantId || !Array.isArray(documents) || documents.length === 0) {
    throw new HttpsError("invalid-argument", "restaurantId and documents are required");
  }

  const restDoc = await admin.firestore().doc(`restaurants/${restaurantId}`).get();
  if (!restDoc.exists) throw new HttpsError("not-found", "Restaurant not found");
  const restaurant = restDoc.data()!;
  if (restaurant.ownerId !== uid) throw new HttpsError("permission-denied", "Not owner");

  await restDoc.ref.set({ kyc: { status: "pending", documents, submittedAt: admin.firestore.FieldValue.serverTimestamp() } }, { merge: true });
  await withAudit(uid, "submitRestaurantKyc", restaurantId, async () => Promise.resolve(), "merchant");
  return { success: true };
});


