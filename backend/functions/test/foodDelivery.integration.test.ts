// @ts-nocheck
import admin, { ___seedDoc } from 'firebase-admin';
import * as analytics from '../src/shared/analytics';
import { createOrder, cancelOrder } from '../src/food-delivery/orders';
import { createPaymentIntent } from '../src/food-delivery/payments';
import { goOnline, acceptCourierOrder } from '../src/food-delivery/dispatch';
import { trackUserInteraction } from '../src/food-delivery/recommendations';
import * as fcm from '../src/services/notifications/fcmService';

jest.mock('../src/shared/analytics', () => ({
  __esModule: true,
  logEvent: jest.fn().mockResolvedValue(undefined),
}));

jest.spyOn(fcm, 'sendToUser').mockResolvedValue(undefined as any);

describe('Food Delivery Integration (callable-invocation)', () => {
  beforeEach(async () => {
    // seed restaurant and courier docs
    ___seedDoc('restaurants/rX', { ownerId: 'ownX', cuisineTags: ['pizza'] });
    ___seedDoc('couriers/c1', { userId: 'c1', isOnline: false });
  });

  test('orders.createOrder emits order_created; cancelOrder emits cancelled_by_*', async () => {
    const res = await createOrder({ data: { order: { restaurantId: 'rX', items: [], addresses: { dropoff: { latitude: 0, longitude: 0 } } }, paymentMethod: 'card', idempotencyKey: 'k1' }, auth: { uid: 'custX' } } as any);
    expect(res.success).toBe(true);
    expect((analytics.logEvent as jest.Mock)).toHaveBeenCalledWith('custX', 'order_created', expect.objectContaining({ orderId: expect.any(String) }));

    const orderId = (res as any).order.id;
    await cancelOrder({ data: { orderId, reason: 'customer_request', cancelledBy: 'customer' }, auth: { uid: 'custX' } } as any);
    expect((analytics.logEvent as jest.Mock)).toHaveBeenCalledWith('custX', 'cancelled_by_customer', expect.objectContaining({ orderId }));
  });

  test('payments.createPaymentIntent emits payment_authorized', async () => {
    // Create order first
    const result = await createOrder({ data: { order: { restaurantId: 'rX', items: [], addresses: { dropoff: { latitude: 0, longitude: 0 } }, payment: {} }, paymentMethod: 'card', idempotencyKey: 'k2' }, auth: { uid: 'custY' } } as any);
    const orderId = (result as any).order.id;
    await createPaymentIntent({ data: { orderId, amount: 100, currency: 'MAD', idempotencyKey: 'kp' }, auth: { uid: 'custY' } } as any);
    expect((analytics.logEvent as jest.Mock)).toHaveBeenCalledWith('custY', 'payment_authorized', expect.objectContaining({ orderId }));
  });

  test('dispatch.goOnline toggles online and acceptCourierOrder moves order', async () => {
    const goRes = await goOnline({ data: {}, auth: { uid: 'c1' } } as any);
    expect(goRes.success).toBe(true);
    expect((analytics.logEvent as jest.Mock)).toHaveBeenCalledWith('c1', 'courier_online');

    // Seed order assigned to courier
    await (admin.firestore as any)().doc('orders/oa').set({ id: 'oa', restaurantId: 'rX', customerId: 'custZ', assignedCourierId: 'c1', status: 'courier_assigned' });
    const acc = await acceptCourierOrder({ data: { orderId: 'oa' }, auth: { uid: 'c1' } } as any);
    expect(acc.success).toBe(true);
    const updated = await (admin.firestore as any)().doc('orders/oa').get();
    expect(updated.data().status).toBeDefined();
  });

  test('trackUserInteraction emits funnel analytics', async () => {
    await trackUserInteraction({ data: { type: 'restaurant_viewed', entityId: 'rX', entityType: 'restaurant' }, auth: { uid: 'custX' } } as any);
    expect((analytics.logEvent as jest.Mock)).toHaveBeenCalledWith('custX', 'restaurant_viewed', expect.any(Object));
  });
});


