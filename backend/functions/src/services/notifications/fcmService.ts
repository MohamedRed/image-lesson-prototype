import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import { TemplateKey } from "./templates";

type UserKind = "customer" | "courier" | "restaurant";

export interface NotificationPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

export async function sendToTokens(tokens: string[], payload: NotificationPayload) {
  if (!tokens || tokens.length === 0) return { success: false, sent: 0 };
  const message: admin.messaging.MulticastMessage = {
    notification: { title: payload.title, body: payload.body },
    data: payload.data,
    tokens,
    android: { priority: "high" },
    apns: { headers: { "apns-priority": "10" } }
  };
  try {
    const resp = await admin.messaging().sendEachForMulticast(message);
    const invalidTokens: string[] = [];
    resp.responses.forEach((r, idx) => {
      const code = (r.error as any)?.code || (r.error as any)?.errorInfo?.code;
      if (code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token') {
        invalidTokens.push(tokens[idx]);
      }
    });
    return { success: true, sent: resp.successCount, failed: resp.failureCount, invalidTokens } as any;
  } catch (e: any) {
    logger.error("FCM sendToTokens failed", { error: e?.message });
    return { success: false, sent: 0 };
  }
}

export async function sendToTopic(topic: string, payload: NotificationPayload) {
  const message: admin.messaging.Message = {
    notification: { title: payload.title, body: payload.body },
    data: payload.data,
    topic
  };
  try {
    await admin.messaging().send(message);
    return { success: true };
  } catch (e: any) {
    logger.error("FCM sendToTopic failed", { error: e?.message, topic });
    return { success: false };
  }
}

export async function sendToUser(
  kind: UserKind,
  id: string,
  payload: NotificationPayload,
  opts?: { templateKey?: TemplateKey; dedupeWindowSec?: number; rateLimitPerMin?: number; contextKey?: string }
) {
  const col = kind === "customer" ? "customers" : kind === "courier" ? "couriers" : "restaurants";
  try {
    // Dedupe & throttle
    const templateKey = opts?.templateKey || 'new_order';
    const contextKey = opts?.contextKey || payload.body;
    const shouldSend = await shouldSendNotification(`${kind}_${id}`, templateKey, contextKey, opts?.dedupeWindowSec ?? 30, opts?.rateLimitPerMin ?? 12);
    if (!shouldSend) {
      logger.info("Notification suppressed by dedupe/throttle", { kind, id, templateKey });
      return { success: false, suppressed: true } as any;
    }

    const docRef = admin.firestore().doc(`${col}/${id}`);
    const doc = await docRef.get();
    const data = doc.exists ? (doc.data() as any) : undefined;
    const tokensRaw: any[] = data?.fcmTokens || [];
    const tokens = Array.from(new Set(tokensRaw.filter(Boolean)));
    if (tokens.length > 0) {
      const resp: any = await sendToTokens(tokens, payload);
      if (resp?.invalidTokens?.length) {
        try {
          const remaining = tokens.filter(t => !resp.invalidTokens.includes(t));
          await docRef.update({ fcmTokens: remaining });
        } catch {}
      }
      return resp;
    }
    const topic = `fd_${kind}_${id}`; // fallback topic pattern
    return await sendToTopic(topic, payload);
  } catch (e: any) {
    logger.error("sendToUser failed", { error: e?.message, kind, id });
    return { success: false };
  }
}

// Simple dedupe + rate limit using Firestore
export async function shouldSendNotification(
  userKey: string,
  templateKey: TemplateKey,
  contextKey: string,
  dedupeWindowSec: number,
  perMinuteLimit: number
): Promise<boolean> {
  try {
    const db = admin.firestore();
    const now = Date.now();
    const bucket = Math.floor(now / 60000); // minute bucket
    const dedupeId = `${userKey}_${templateKey}_${stringHash(contextKey)}`;
    const dedupeRef = db.doc(`notificationLedger/${dedupeId}`);
    const rateRef = db.doc(`notificationRate/${userKey}_${bucket}`);

    const [dedupeSnap, rateSnap] = await Promise.all([dedupeRef.get(), rateRef.get()]);

    if (dedupeSnap.exists) {
      const last = (dedupeSnap.data() as any)?.ts?.toDate?.()?.getTime?.() || now;
      if ((now - last) / 1000 < dedupeWindowSec) {
        return false;
      }
    }

    const count = rateSnap.exists ? ((rateSnap.data() as any)?.count || 0) : 0;
    if (count >= perMinuteLimit) {
      return false;
    }

    await Promise.all([
      dedupeRef.set({ ts: admin.firestore.FieldValue.serverTimestamp(), templateKey, contextKey }, { merge: true }),
      rateRef.set({ count: admin.firestore.FieldValue.increment(1), bucket, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true })
    ]);
    return true;
  } catch (e: any) {
    logger.warn("Notification dedupe/throttle check failed, sending anyway", { error: e?.message });
    return true;
  }
}

function stringHash(input: string): string {
  let hash = 0;
  for (let i = 0; i < input.length; i++) {
    hash = (hash << 5) - hash + input.charCodeAt(i);
    hash |= 0;
  }
  return Math.abs(hash).toString(36);
}


