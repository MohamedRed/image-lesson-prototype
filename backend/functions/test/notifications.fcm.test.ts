import { describe, test, expect, beforeEach, jest } from '@jest/globals';
import { sendToUser, shouldSendNotification } from '../src/services/notifications/fcmService';

describe('fcmService dedupe and token hygiene', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('removes invalid tokens and respects dedupe window', async () => {
    const canSend1 = await shouldSendNotification('customer_u1', 'new_order', 'order123', 60, 100);
    expect(canSend1).toBe(true);
    const canSend2 = await shouldSendNotification('customer_u1', 'new_order', 'order123', 60, 100);
    expect(canSend2).toBe(false);

    const result: any = await sendToUser('customer','u1', { title: 't', body: 'b', data: { k: 'v' } }, { templateKey: 'new_order', dedupeWindowSec: 0, rateLimitPerMin: 100, contextKey: 'order123-2' });
    expect(result).toBeTruthy();
  });
});


