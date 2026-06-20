import { MetricServiceClient } from "@google-cloud/monitoring";
import { logger } from "firebase-functions";

const monitoring = new MetricServiceClient();
const projectId = process.env.GCP_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || "";

const projectPath = monitoring.projectPath(projectId);

export async function writeTimeSeries(metricType: string, value: number, labels: Record<string, string> = {}) {
  try {
    const dataPoint = {
      interval: { endTime: { seconds: Date.now() / 1000 } },
      value: { doubleValue: value },
    };

    await monitoring.createTimeSeries({
      name: projectPath,
      timeSeries: [
        {
          metric: { type: `custom.googleapis.com/${metricType}`, labels },
          resource: { type: "global", labels: { project_id: projectId } },
          points: [dataPoint],
        },
      ],
    });
  } catch (err) {
    logger.error("Metric write failed", err);
  }
}

export async function recordLatencyMs(metric: string, startMs: number) {
  const elapsed = Date.now() - startMs;
  await writeTimeSeries(`${metric}/latency_ms`, elapsed);
}

export async function incrementCounter(metric: string, labels: Record<string, string> = {}) {
  await writeTimeSeries(`${metric}/count`, 1, labels);
}

export function withMetrics<T extends (...args: any[]) => any>(metric: string, handler: T): T {
  // eslint-disable-next-line @typescript-eslint/ban-ts-comment
  // @ts-ignore
  return (async (...args: any[]) => {
    const start = Date.now();
    try {
      await incrementCounter(`${metric}/invocations`);
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-ignore
      return await handler(...args);
    } catch (err) {
      await incrementCounter(`${metric}/errors`);
      throw err;
    } finally {
      await recordLatencyMs(metric, start);
    }
  }) as T;
} 