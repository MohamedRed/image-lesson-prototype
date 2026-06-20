import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { withMetrics } from "../shared/metrics";
import { getSecret, secretPath, SECRET_IDS } from "../shared/secretManager";

try { admin.app(); } catch { admin.initializeApp(); }

interface MapboxCurbSegment {
  id: string;
  geometry: any;
  properties: {
    allowed_uses: string[];
    max_stop_seconds: number;
  };
}

async function fetchCurbPage(citySlug: string, pageToken: string | null, accessToken: string): Promise<{ segments: MapboxCurbSegment[]; next: string | null }> {
  const url = new URL(`https://api.mapbox.com/curb/v1/${citySlug}`);
  url.searchParams.set("access_token", accessToken);
  if (pageToken) url.searchParams.set("start", pageToken);

  const resp = await fetch(url.toString());
  if (!resp.ok) throw new Error(`Mapbox HTTP ${resp.status}`);
  const data = (await resp.json()) as any;
  return {
    segments: data.segments as MapboxCurbSegment[],
    next: data.pagination?.next ?? null,
  };
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export async function slackNotify(message: string) {
  try {
    const hook = await getSecret(secretPath(SECRET_IDS.SLACK_WEBHOOK_URL));
    if (!hook) {
      logger.warn("Slack webhook not configured, message dropped", { message });
      return;
    }

    const maxAttempts = 3;
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        const resp = await fetch(hook, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ text: message }),
        });
        if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
        return;
      } catch (err: any) {
        logger.error(`Slack notify attempt ${attempt} failed`, err);
        if (attempt < maxAttempts) {
          await sleep(1000 * attempt); // linear back-off
          continue;
        }
      }
    }
  } catch (secretError: any) {
    logger.warn("Could not retrieve Slack webhook secret", { error: secretError.message, message });
    return;
  }
}

export const nightlyCurbImport = withMetrics("nightlyCurbImport", onSchedule("0 3 * * *", async () => {
  const token = await getSecret(secretPath(SECRET_IDS.MAPBOX_ACCESS_TOKEN));
  const city = process.env.CURB_CITY_SLUG || "demo-city";
  if (!token) throw new Error("Mapbox access token not found in Secret Manager");

  const db = admin.firestore();
  let pageToken: string | null = null;
  let imported = 0;
  try {
    do {
      const { segments, next } = await fetchCurbPage(city, pageToken, token);
      pageToken = next;
      const batch = db.batch();
      for (const seg of segments) {
        const ref = db.collection("curbSegments").doc(seg.id);
        batch.set(ref, {
          geometry: seg.geometry,
          allowedUses: seg.properties.allowed_uses,
          maxStopSeconds: seg.properties.max_stop_seconds,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }
      await batch.commit();
      imported += segments.length;
    } while (pageToken);

    logger.info("Nightly curb import completed", { imported });
    await slackNotify(`✅ Curb import completed. ${imported} segments updated.`);
  } catch (err: any) {
    logger.error("Nightly curb import failed", err);
    await slackNotify(`❌ Curb import failed: ${err.message}`);
    throw err;
  }
})); 