### Food Delivery: Client vs Backend Responsibilities and Migration Plan

Purpose: document what currently lives on the iOS client vs the backend for the Food Delivery feature, identify duplications and risks, and define a concrete plan to move authoritative business logic to the backend while keeping the client thin.

### Current responsibilities (by code location)

- Client libraries (Swift, `Packages/FoodDeliveryService` and `Packages/FoodDeliveryFeature`)
  - Pricing and fees
    - `PricingEngine.swift`: computes subtotal, delivery fee, service fee, small order fee, ETA, surge adjustments.
    - `FirestoreFoodDeliveryService.priceOrder(...)`: calls `PricingEngine` locally; fetches restaurant and surge windows from Firestore.
    - `PromotionService.swift`: resolves/validates promotions and coupons directly from Firestore; applies discount client-side.
  - Order lifecycle and mutations
    - `FirestoreFoodDeliveryService.createOrder(...)`: assembles order locally then calls Cloud Function name `createOrder` (not present server-side); starts local listeners.
    - `cancelOrder`, `acceptCourierOrder`, `declineCourierOrder`, `confirmPickup`, `confirmDelivery`, `updateLocation`, `getAvailableOrders`: some call callable/HTTP functions; several write directly to Firestore (non-authoritative).
  - Dispatch and zones
    - `DispatchAlgorithm.swift` (`AdvancedDispatchAlgorithm`): client-side scoring, zone performance, and rebalancing stubs.
  - Recommendations (AI)
    - `AIRecommendationEngine.swift`: local personalization and trending logic; also logs interactions to Firestore.
  - Location/routing
    - `RadarLocationService.swift`: wraps Radar SDK for location, trips, geofences on device; exposes Combine publishers.
  - Courier app view models
    - `CourierViewModel.swift`, `CourierTrackingViewModel.swift`: start/stop tracking, accept/confirm actions, directly update Firestore in some flows.
  - Payments (client-side helpers)
    - `CODPaymentProcessor.swift`: client helpers around COD flows (non-authoritative); Stripe handled server-side.
  - Notifications
    - `NotificationService.swift`: handles local and app-side notification presentation; FCM send is currently TODO on server.

- Backend (TypeScript, `backend/functions/src/food-delivery`)
  - Orders and state machine: `orders.ts`
    - `orderStateManager` (Firestore trigger): validates transitions; handles picked_up/on_route/delivered; starts/stops Radar trips; captures card payments; refunds on cancellation; sends notifications (TODOs noted).
    - `orderCreationHandler` (on create): validates, calculates pricing, authorizes payment, moves to `pending_restaurant`.
    - HTTP endpoints: `cancelOrder`, `calculatePricing`.
  - Dispatch and courier ops: `dispatch.ts`
    - Triggers: `courierDispatcher` on order status changes; `courierLocationTracker` on courier doc changes.
    - HTTP endpoints: `acceptCourierOrder`, `declineCourierOrder`, `updateCourierLocation`, `confirmPickup`, `confirmDelivery`, `getAvailableOrders`.
  - Payments: `payments.ts`
    - Webhook: `foodDeliveryStripeWebhook`.
    - HTTP endpoints: `createPaymentIntent`, `capturePayment`, `processRefund`, `processCODPayment`, `settleCODBalance`, analytics endpoints.
  - Recommendations and promotions: `recommendations.ts`
    - HTTP endpoints: `trackUserInteraction`, `getPersonalizedRecommendations`, `getTrendingItems`, `getSmartSuggestions`, `validatePromotion`, `getActivePromotions`.

### Duplications, gaps, and risks

- Duplication of critical logic on client and server:
  - Pricing and promotion application (`PricingEngine.swift`, `PromotionService.swift` vs `orders.ts/calculatePricing`, `recommendations.ts/validatePromotion`).
  - Dispatch logic (`DispatchAlgorithm.swift`) vs server `dispatch.ts` (authoritative).
  - Recommendations (`AIRecommendationEngine.swift`) vs server `recommendations.ts`.
  - Courier flows (pickup/delivery/location) sometimes write directly to Firestore client-side while server exposes endpoints and triggers.
- Missing/mismatched endpoints referenced by client:
  - Client calls `functions.httpsCallable("assignCourier")` and `"updateMenuItemAvailability"`; server exposes `acceptCourierOrder`, `declineCourierOrder`, and lacks `updateMenuItemAvailability` callable.
  - Client calls `"createOrder"` callable; server has an on-create handler but no callable to create orders with validation/authorization.
- Security/trust risks:
  - Client-side pricing, promotions, and direct Firestore writes allow tampering (e.g., totals, status transitions).
  - Courier location and status updates should be authenticated, rate-limited, and validated server-side.

### Target model (authoritative split)

- Server authoritative for:
  - Pricing/fees/surge and promotion validation/application.
  - Order creation, status transitions, idempotency, and audit.
  - Courier dispatch, assignment, redispatch, and zone performance.
  - Payments (Stripe intents, capture, refunds) and COD settlement.
  - Courier online/offline, location ingestion, and delivery tracking state.
  - Notifications fan-out (FCM) and rate limiting.
  - Recommendation APIs and interaction logging.
- Client responsible for:
  - UI, local state, optimistic UX hints (non-authoritative estimates).
  - Device location capture via Radar and upload to backend; no business decisions.
  - Rendering maps/routes and polling/subscribing to server tracking.

### Migration plan (concrete edits and endpoints)

1) Orders: creation and state transitions
- Backend
  - Add `createOrder` HTTP function in `orders.ts` that:
    - Validates payload, calculates pricing via existing helpers, authorizes card payment when method = card, creates Firestore doc atomically, returns created order and client secret.
  - Ensure `sendCustomerNotification`/`sendCourierNotification`/`sendRestaurantNotification` are implemented via FCM.
  - Enforce state machine checks in `orderStateManager` for every transition.
- Client (`FirestoreFoodDeliveryService.swift`)
  - Replace callable `"createOrder"` with HTTP call to new endpoint; remove local assembly of authoritative totals (use server response).
  - Route `cancelOrder`, `confirmPickup`, `confirmDelivery` through existing server HTTP endpoints instead of Firestore `.update`.

2) Pricing, promotions, and estimates
- Backend: keep `calculatePricing`, `validatePromotion`, `getActivePromotions` and promotion application inside order creation.
- Client:
  - Keep `PricingEngine` for non-binding estimates only (UI preview). On checkout, call server `calculatePricing` and block on its totals.
  - Deprecate direct Firestore reads in `PromotionService.swift`; convert into a thin network client calling server promotion endpoints.

3) Dispatch and courier operations
- Backend: `dispatch.ts` remains authoritative for assignment, accept/decline, zone monitoring, and tracking updates.
  - Add callable/HTTP `updateMenuItemAvailability` if required by merchant UI.
  - Optionally add `couriers.goOnline`/`couriers.goOffline` HTTP endpoints to wrap the Firestore updates and validate eligibility.
- Client:
  - Remove usage of `AdvancedDispatchAlgorithm` in runtime flows. Keep only for local simulations/dev tools if needed.
  - Replace direct queries (`getAvailableOrders` Firestore) with the backend `getAvailableOrders` endpoint.
  - Replace manual courier Firestore location writes with `updateCourierLocation` endpoint.

4) Payments
- Backend: already owns Stripe webhooks, create/capture/refund, COD processing and settlement.
- Client: obtain publishable keys from config; call backend `createPaymentIntent` and confirm card payment with Stripe SDK; never compute payable totals or capture on device.

5) Recommendations & interactions
- Backend: use `trackUserInteraction`, `getPersonalizedRecommendations`, `getTrendingItems`, `getSmartSuggestions`.
- Client: deprecate `AIRecommendationEngine` for production; keep for offline/demo only. All feeds fetch from backend.

6) Notifications
- Backend: implement FCM send in `orders.ts` helpers; centralize templates.
- Client: keep `NotificationService.swift` for registration and local presentation only.

7) Radar location/trips
- Backend: continue to start/complete trips in `orders.ts` (`startLocationTracking`, `stopLocationTracking`).
- Client: keep `FoodDeliveryRadarLocationService` to capture and publish device location; send to backend via `updateCourierLocation`.

### API contracts to use (functions/HTTP)

- Orders
  - POST `createOrder` (new): body = draft + payment method; returns created order + clientSecret (if card).
  - POST `cancelOrder`: body { orderId, reason, cancelledBy }.
  - POST `confirmPickup`: headers `Authorization`, body { orderId }.
  - POST `confirmDelivery`: headers `Authorization`, body { orderId, proofImageUrl? }.
- Pricing/Promotions
  - POST `calculatePricing`: body { restaurantId, items, deliveryAddress, promoCode? }.
  - POST `validatePromotion`: body { code, customerId, restaurantId?, orderValue? }.
  - GET `getActivePromotions`.
- Dispatch/Courier
  - GET `getAvailableOrders` (header auth, infers courier).
  - POST `acceptCourierOrder` / `declineCourierOrder`.
  - POST `updateCourierLocation`.
  - (Optional) POST `couriers.goOnline` / `couriers.goOffline`.
- Payments
  - POST `createPaymentIntent`, `capturePayment`, `processRefund`, `processCODPayment`, `settleCODBalance`.
- Recommendations
  - POST `trackUserInteraction`; GET `getPersonalizedRecommendations`, `getTrendingItems`, `getSmartSuggestions`.

### Client edits (high level)

- `FirestoreFoodDeliveryService.swift`
  - priceOrder: call server `calculatePricing` for authoritative totals; keep local estimate path behind a flag.
  - applyPromotion/validateCoupon: call backend endpoints; remove direct Firestore logic.
  - createOrder: call new `createOrder` endpoint; stop writing totals or status directly.
  - accept/decline/confirmPickup/confirmDelivery/updateLocation/getAvailableOrders: route via backend HTTP; remove direct Firestore writes and collection queries.
  - goOnline/goOffline: either keep Firestore updates or call new endpoints once added.
- `DispatchAlgorithm.swift`: mark as dev-only; remove from production flows.
- `AIRecommendationEngine.swift`: compile behind `#if DEBUG` or use only for offline; production fetches from backend.
- `PromotionService.swift`: refactor to network client wrappers.
- `CourierViewModel.swift` and `CourierTrackingViewModel.swift`: ensure all mutations call service methods that hit backend endpoints; keep Radar capture only.

### Backend edits (high level)

- Add missing endpoints used by client or adjust client to existing ones:
  - Implement `createOrder` HTTP function (orders.ts).
  - Add `updateMenuItemAvailability` callable if needed by merchant console.
  - Replace client call to `assignCourier` with server `acceptCourierOrder` and align naming on client.
  - Replace ad-hoc headers (`courier-id`) with Firebase Auth (`context.auth.uid`) and enforce authorization in each handler.
  - Implement FCM send logic in notification helpers; centralize templates in `NotificationService` server module.

### Security and integrity

- Require Firebase Auth on all write endpoints; derive `customerId`/`courierId` from token, not headers.
- Use idempotency keys for order-creation and delivery confirmations.
- Validate all state transitions on server; reject invalid transitions.
- Rate-limit location updates; validate coordinates (speed/teleport checks).

### Rollout plan

1. Backend first
  - Implement `createOrder`, notifications, missing endpoints; switch handlers to use `context.auth`.
  - Add integration tests for pricing, promotions, state transitions, payments.
2. Client toggles
  - Add a feature flag `useServerAuthoritative` default ON in non-debug.
  - Gradually route: pricing -> promotions -> createOrder -> courier ops -> recommendations.
3. Cleanup
  - Remove production references to `AdvancedDispatchAlgorithm`, local `AIRecommendationEngine`, and Firestore direct writes.

### Acceptance criteria

- No client writes directly mutate `orders`, `couriers`, or `deliveryTracking` collections; all go through verified endpoints.
- Totals/fees/promotions on orders always match server-calculated values.
- All courier accept/decline/pickup/delivery flows succeed with server-side validation and are audit-logged.
- Stripe and COD flows complete without client-side secrets; webhooks update order states consistently.
- Recommendation and promotion UI backed by server APIs.

### Cross-references

- Client
  - `Packages/FoodDeliveryService/Sources/FoodDeliveryService/FirestoreFoodDeliveryService.swift`
  - `Packages/FoodDeliveryService/Sources/FoodDeliveryService/PricingEngine.swift`
  - `Packages/FoodDeliveryService/Sources/FoodDeliveryService/PromotionService.swift`
  - `Packages/FoodDeliveryService/Sources/FoodDeliveryService/DispatchAlgorithm.swift`
  - `Packages/FoodDeliveryService/Sources/FoodDeliveryService/RadarLocationService.swift`
  - `Packages/FoodDeliveryFeature/Sources/FoodDeliveryFeature/Courier/*.swift`
- Backend
  - `backend/functions/src/food-delivery/orders.ts`
  - `backend/functions/src/food-delivery/dispatch.ts`
  - `backend/functions/src/food-delivery/payments.ts`
  - `backend/functions/src/food-delivery/recommendations.ts`










