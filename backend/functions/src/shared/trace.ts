import { logger } from "firebase-functions";

export function withTrace<T extends (...args: any[]) => any>(handler: T): T {
  // eslint-disable-next-line @typescript-eslint/ban-ts-comment
  // @ts-ignore
  const wrapped = async (...args: any[]) => {
    // Basic trace id (timestamp-random). In production you'd use @google-cloud/trace-agent.
    const traceId = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;

    // Patch logger to include traceId
    const origLog = logger.info.bind(logger);
    const origErr = logger.error.bind(logger);
    const origWarn = logger.warn.bind(logger);
    logger.info = (msg: any, data?: any) => origLog(msg, { ...data, traceId });
    logger.error = (msg: any, data?: any) => origErr(msg, { ...data, traceId });
    logger.warn = (msg: any, data?: any) => origWarn(msg, { ...data, traceId });

    try {
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-ignore
      return await handler(...args);
    } finally {
      // restore
      logger.info = origLog;
      logger.error = origErr;
      logger.warn = origWarn;
    }
  };

  // Cast to preserve original signature
  return (wrapped as unknown) as T;
} 