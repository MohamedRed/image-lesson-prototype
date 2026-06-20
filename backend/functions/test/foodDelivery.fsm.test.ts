import { describe, test, expect } from '@jest/globals';

type Status = 'created' | 'restaurant_accepted' | 'preparing' | 'ready_for_pickup' | 'picked_up' | 'on_route' | 'delivered';

const allowedTransitions: Record<Status, Status[]> = {
  created: ['restaurant_accepted'],
  restaurant_accepted: ['preparing'],
  preparing: ['ready_for_pickup'],
  ready_for_pickup: ['picked_up'],
  picked_up: ['on_route'],
  on_route: ['delivered'],
  delivered: [],
};

function canTransition(from: Status, to: Status): boolean {
  return allowedTransitions[from].includes(to);
}

describe('FoodDelivery FSM', () => {
  test('valid forward transitions', () => {
    expect(canTransition('created', 'restaurant_accepted')).toBe(true);
    expect(canTransition('preparing', 'ready_for_pickup')).toBe(true);
    expect(canTransition('on_route', 'delivered')).toBe(true);
  });

  test('invalid backward transitions', () => {
    expect(canTransition('delivered', 'on_route')).toBe(false);
    expect(canTransition('ready_for_pickup', 'preparing')).toBe(false);
  });
});










