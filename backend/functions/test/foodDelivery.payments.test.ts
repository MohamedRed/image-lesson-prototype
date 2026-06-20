import { describe, test, expect } from '@jest/globals';

describe('FoodDelivery Payments basic math', () => {
  test('convert MAD to cents (Stripe minor units)', () => {
    const toCents = (amountMad: number) => Math.round(amountMad * 100);
    expect(toCents(10)).toBe(1000);
    expect(toCents(10.25)).toBe(1025);
  });

  test('partial capture cannot exceed auth amount', () => {
    const authorized = 15000; // 150 MAD
    const capture = (requested: number) => Math.min(requested, authorized);
    expect(capture(10000)).toBe(10000);
    expect(capture(20000)).toBe(authorized);
  });
});










