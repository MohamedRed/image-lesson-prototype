export const logger = {
  info: (...args: any[]) => console.log('[functions.logger.info]', ...args),
  warn: (...args: any[]) => console.warn('[functions.logger.warn]', ...args),
  error: (...args: any[]) => console.error('[functions.logger.error]', ...args),
};

export const onDocumentWritten = (_path: string, handler: any) => ({ __trigger: 'firestore.onDocumentWritten', handler } as any);
export const onDocumentCreated = (_path: string, handler: any) => ({ __trigger: 'firestore.onDocumentCreated', handler } as any);
export const onSchedule = (_sched: string, handler: any) => handler;
export const onCall = (handler: any) => handler;
export const onRequest = (_opts: any, handler: any) => handler;
export class HttpsError extends Error {
  constructor(public code: string, message: string){ super(message); this.name = 'HttpsError'; }
}

export default { logger, onDocumentWritten, onDocumentCreated, onSchedule } as any;


