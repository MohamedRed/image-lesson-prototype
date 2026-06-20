import { describe, test, expect } from '@jest/globals';

// Lightweight unit tests mirroring PricingEngine behavior in backend calculatePricing callable
// Here we validate the fee calculations math with sample inputs

function calculateServiceFee(subtotal: number): number {
  const fee = subtotal * 0.03;
  return Math.min(fee, 15.0);
}

function calculateDeliveryFee(baseMAD: number, perKmMAD: number, distanceKm: number, surgeMultiplier = 1): number {
  return (baseMAD + perKmMAD * distanceKm) * surgeMultiplier;
}

describe('FoodDelivery Pricing', () => {
  test('service fee capped at 15 MAD', () => {
    expect(calculateServiceFee(100)).toBeCloseTo(3.0);
    expect(calculateServiceFee(1000)).toBeCloseTo(15.0);
    expect(calculateServiceFee(10000)).toBeCloseTo(15.0);
  });

  test('delivery fee with surge multiplier', () => {
    const base = 10; const perKm = 2; const distance = 5;
    expect(calculateDeliveryFee(base, perKm, distance, 1)).toBeCloseTo(20);
    expect(calculateDeliveryFee(base, perKm, distance, 1.5)).toBeCloseTo(30);
  });
});










