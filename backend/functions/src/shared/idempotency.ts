import * as admin from "firebase-admin";

export async function withIdempotency<T>(
  key: string | undefined,
  handlerName: string,
  fn: () => Promise<T>
): Promise<T> {
  if (!key) {
    return fn();
  }

  const docRef = admin.firestore().doc(`idempotency/${handlerName}_${key}`);
  return await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(docRef);
    if (snap.exists) {
      const data = snap.data() as any;
      if (data.status === "completed" && data.result !== undefined) {
        return data.result as T;
      }
      if (data.status === "in_progress") {
        // Another request in-flight; treat as retry and return previous result if any
        if (data.result !== undefined) return data.result as T;
      }
    } else {
      tx.set(docRef, {
        status: "in_progress",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    const result = await fn();
    tx.set(docRef, {
      status: "completed",
      result,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return result;
  });
}










