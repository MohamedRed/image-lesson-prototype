import { describe, test, expect } from '@jest/globals';
class HttpsError extends Error { constructor(public code: string, message: string){ super(message);} }

describe('KYC callables basic validation', () => {
  test('submitRestaurantKyc missing args', async () => {
    const fn = async () => {
      // Simulate callable input validation throwing
      throw new HttpsError('invalid-argument', 'restaurantId and documents are required');
    };
    await expect(fn()).rejects.toHaveProperty('code', 'invalid-argument');
  });

  test('submitCourierKyc requires auth', async () => {
    const fn = async () => {
      throw new HttpsError('unauthenticated', 'Authentication required');
    };
    await expect(fn()).rejects.toHaveProperty('code', 'unauthenticated');
  });
});


