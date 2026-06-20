import * as admin from "firebase-admin";

export type AuditEvent = {
  actorUid?: string;
  actorRole?: string;
  action: string;
  target?: string;
  status: "success" | "failure";
  reason?: string;
  metadata?: Record<string, any>;
  createdAt?: FirebaseFirestore.FieldValue;
};

export async function writeAuditLog(event: AuditEvent): Promise<void> {
  try {
    const payload = {
      ...event,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    await admin.firestore().collection("auditLogs").add(payload);
  } catch (e) {
    // Best-effort logging; do not throw
    console.error("Failed to write audit log", e);
  }
}

export async function withAudit<T>(
  actorUid: string | undefined,
  action: string,
  target: string | undefined,
  fn: () => Promise<T>,
  role?: string,
  metadata?: Record<string, any>
): Promise<T> {
  try {
    const result = await fn();
    await writeAuditLog({ actorUid, actorRole: role, action, target, status: "success", metadata });
    return result;
  } catch (err: any) {
    await writeAuditLog({ actorUid, actorRole: role, action, target, status: "failure", reason: err?.message, metadata });
    throw err;
  }
}










