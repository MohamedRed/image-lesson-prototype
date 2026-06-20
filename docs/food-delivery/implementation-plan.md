## Food Delivery Feature (Morocco) — Implementation Plan

### 1) Vision, Goals, and Success Metrics
- **Vision**: Add a modern food delivery experience (like Uber Eats/Glovo) to the super app for Morocco, leveraging the app’s existing mapping, auth, payments, and messaging foundations.
- **Primary goals**:
  - Seamless customer ordering and tracking with reliable ETAs.
  - Efficient courier dispatch with fair pricing and incentives.
  - Merchant self-onboarding, menus, and order management.
  - Fast rollout to Casablanca, Rabat, Marrakech, then scale.
- **Success metrics (MVP)**:
  - Conversion rate from menu view to checkout ≥ 15%.
  - On-time delivery rate ≥ 90% of orders.
  - Avg. delivery time (accept → delivered) ≤ 40 minutes.
  - Order failure/cancellation rate ≤ 5%.
  - App crash rate < 0.5% sessions.

### 2) Personas and Key User Stories
- **Customer**
  - Browse restaurants/menus nearby and by category; search dishes.
  - Customize items (options/add-ons), manage cart, apply promos, select payment method (card, COD), and place order.
  - Track status across states (accepted, preparing, pickup, en route, delivered).
  - Contact merchant/courier via in-app messaging; rate & tip.
- **Courier (Rider/Driver)**
  - Go online/offline; receive/accept orders; batched orders (phase 2+).
  - Navigate pickup/drop-off via Mapbox; see earnings/tips; cash handling if COD.
- **Merchant (Restaurant)**
  - Onboard (KYC), set opening hours, delivery zones, menu & prices.
  - Receive orders (new → preparing → ready), manage out-of-stock, pause store.
  - Settlement dashboard (payouts, fees, taxes), promotions.
- **Operations/Admin**
  - Manage disputes, refunds, adjustments; merchant/courier verification; fraud checks.

### 3) MVP Scope
- Cities: Casablanca (arrondissements), Rabat; later Marrakech, Fes.
- Customer app: discovery, cart, checkout (Stripe + COD), live tracking, push notifications, order history, re-order.
- Merchant panel (in-app screens initially, separate backend console later): receive orders, set prep time, mark ready, manage menu.
- Courier: basic accept/decline, pickup confirmation, route to customer, proof-of-delivery.
- Pricing: base delivery fee + per-km + surge, small order fee, tip, promotional coupons.
- Languages: fr-MA, ar-MA (RTL), with fallbacks to en.

Non-goals (Phase 2+):
- Complex batching/dispatch algorithms, scheduled orders, group orders, subscriptions, loyalty tiers, wallet top-ups, in-depth marketing suite.

### 4) Architecture Overview
- Reuse existing tech:
  - **Firebase** (Auth, Firestore, Functions, Storage, Messaging).
  - **Stripe** for payments (PaymentSheet, webhooks), with COD fallback.
  - **Mapbox** for maps/routing; **Radar** for geofencing/ETA if useful.
  - Existing patterns from `RideSharingFeature` and `HomeServicesFeature`.
- New Swift packages (mirroring existing module structure):
  - `Packages/FoodDeliveryService` — domain models, service protocol, Firestore/Functions impl, Combine publishers.
  - `Packages/FoodDeliveryFeature` — SwiftUI flows: discovery, menu, cart/checkout, tracking, merchant console (MVP UI), courier minimal UI.
  - Optional (later): `FoodDeliveryAdmin` (internal tools), `FoodDeliveryAnalytics`.
- Data flow: Service emits `AnyPublisher` updates (orders, courier positions), UI binds via `ObservableObject` view models.
- Config: extend `HomeServicesConfig`-style to `FoodDeliveryConfig` (environment, locale, currency "MAD").

Proposed repo structure snippet:
```
docs/
  food-delivery/
    implementation-plan.md
Packages/
  FoodDeliveryService/
    Package.swift
    Sources/FoodDeliveryService/
      FoodDeliveryModels.swift
      FoodDeliveryService.swift
      FirestoreFoodDeliveryService.swift
      PricingEngine.swift
  FoodDeliveryFeature/
    Sources/FoodDeliveryFeature/
      FoodDiscoveryView.swift
      RestaurantDetailView.swift
      MenuItemCustomizationView.swift
      CartView.swift
      CheckoutView.swift
      OrderTrackingView.swift
      MerchantConsoleView.swift
      CourierConsoleView.swift
      FoodDeliveryViewModel.swift
```

### 5) Data Model (Firestore First)
- `restaurants` (collection)
  - id, name, logoUrl, cuisineTags[], rating, isOpen, phone, address{city, arrondissement?, street}, coordinates{lat,lng}
  - openingHours{mon..sun: [timeRange]}, avgPrepMinutes, deliveryZones[], deliveryFeePolicy, surgeProfile?
  - kyc{status, documents[], verificationTier}, payouts{stripeAccountId?}
- `menus` (subcollection under restaurant) and `menuItems`
  - category, title, description, imageUrl, price, currency: "MAD", isAvailable, options[] (sizes, add-ons with price deltas), maxAddons, calories?
- `orders` (collection)
  - id, customerId, restaurantId, courierId?, status (see FSM), items[], subtotal, deliveryFee, serviceFee, tip, total, currency, coupon, payment{method: card|cod, intentId?, status}
  - addresses: pickup (restaurant), dropoff {lat,lng, addressLine, city, arrondissement?}
  - timings: createdAt, acceptedAt, readyAt, pickedUpAt, deliveredAt, cancelledAt, etaSeconds
  - tracking: routePolyline?, distanceKm, currentCourierLocation, handoffProofUrl?
  - cancellation{by, reasonCode, notes}
- `couriers`
  - id, userId, name, vehicleType (bike|motorbike|car), rating, isOnline, currentOrderId?, location{lat,lng, lastUpdatedAt}
  - kyc{status, docs}, payouts{stripeAccountId?}
- `customers`
  - id, userId, defaultAddresses[], paymentMethods (Stripe), preferences.
- `pricingConfigs`, `promotions`, `deliveryZones` (polygon or city configs), `surgeWindows`.

### 6) Order State Machine (FSM)
- `created` → `restaurant_accepted` → `preparing` → `ready_for_pickup` → `picked_up` → `on_route` → `delivered`
- Cancellation branches: `cancelled_by_customer`, `cancelled_by_merchant`, `cancelled_no_courier`.
- Events: accept/decline (merchant), assign courier (system), pickup (courier), arrival at customer, delivered (POD).

### 7) Pricing & Fees (MVP)
- Delivery fee: `baseMAD` + `perKmMAD * distanceKm` + surge multiplier (optional).
- Service fee: small percentage on subtotal (cap by city policy).
- Small order fee: if subtotal < threshold.
- Tips: optional fixed or percentage at checkout; adjustable after delivery (phase 2).
- Promotions: flat or percentage off (precedence and caps), validate via Cloud Function.

### 8) Dispatch & ETA
- MVP: Greedy assignment within radius (e.g., 3–5 km), nearest available courier by ETA (Mapbox Matrix) with timeout (e.g., 30s) then expand radius.
- Backoff strategy: broadcast to multiple couriers if first declines.
- Batched orders: disabled in MVP; design models to allow linking multiple orders to one courier later.
- ETA: use Mapbox Directions + prep time buffer; update every ~15–30s.

### 9) Maps, Geocoding, and Geofencing
- Mapbox Geocoding for address search and reverse geocoding; store structured address (city, arrondissement, street, extra).
- Radar geofences (optional) for pickup/drop-off arrival events; or rely on courier explicit actions (Arrived, Picked up).
- Validate restaurant and courier positions; snap-to-road for better ETA.

### 10) Payments Strategy (Morocco)
- Currency: **MAD**.
- Card: Stripe PaymentSheet; require 3DS where applicable; hold/capture model:
  - Pre-authorize at order creation, capture after pickup or delivery (configurable), handle partial captures for out-of-stock.
- Cash on Delivery (COD): enable per city/merchant; include courier cash flow handling and reconciliation entries.
- Refunds: partial and full via Functions + Stripe webhooks; auto-refund if order fails before pickup.
- Payouts: Stripe Connect (Express) for merchants and couriers (phase 2), or weekly off-platform payout process (MVP ops fallback).

### 11) Notifications & Messaging
- Push via FCM: order status changes, courier assignment, courier near arrival.
- In-app messaging (reuse existing `Message` model): customer↔courier, customer↔merchant; simple safety filters, rate limits.
- SMS fallback (phase 2) for critical handoffs.

### 12) KYC, Compliance, and Safety
- Merchant KYC: business docs, food license (as applicable), bank account or settlement info, phone verification.
- Courier KYC: ID, photo, driver’s license if motorbike/car; background checks (ops process).
- Privacy & data retention: align with current Firebase rules; PII minimization; redact sensitive info in chat when needed.
- Taxes/receipts: line items with VAT where applicable; merchant invoice generation (phase 2 export).

### 13) Localization & Accessibility
- `fr-MA`, `ar-MA` (RTL); unify strings keys; right-align numeric/time where appropriate for RTL.
- Accessible color choices; Dynamic Type; VoiceOver labels on status/timers.

### 14) Observability & Analytics
- Events: restaurant_viewed, item_added_to_cart, checkout_started, payment_authorized, order_created, courier_assigned, picked_up, delivered, cancelled_[by_x], refund_issued.
- Crashlytics and non-PII logs for dispatch/ETA anomalies.
- Fraud & abuse metrics: repeated cancellations, COD no-shows.

### 15) Security & Firestore Rules (Outline)
- Collections secured by roles: customers can read/write own orders; merchants can read restaurant’s orders; couriers can read assigned orders; admins elevated.
- Functions enforce server-side checks for prices, fees, promotions, and status transitions.

### 16) UX Flows (MVP)
- Customer: Discovery → Restaurant Detail → Menu Item Customization → Cart → Checkout (address, payment) → Order Tracking → Rating/Tip.
- Merchant: Orders Queue → Accept/Decline → Prep Timer → Ready.
- Courier: Go Online → Accept Job → Navigate to Restaurant → Pickup → Navigate to Customer → Deliver (POD).

### 17) Integration with Super App Navigation
- Add a new entry in `FeatureNavigationView` (Food Delivery) → `FoodDeliveryFeature` root view.
- Deep links: `liive://food/order/{id}`, `liive://food/restaurant/{id}`.

### 18) Rollout Plan
- Phase 0: Internal sandbox with seed data; 10–20 test orders.
- Phase 1: Casablanca pilot (2–5 districts), curated restaurants, small courier pool.
- Phase 2: Expand to Rabat; add COD and promotions; improve dispatch.
- Phase 3: Marrakech; connect payouts; batching; scheduled orders.

### 19) Testing Strategy
- Unit tests for pricing, fees, and status transitions.
- UI snapshot tests for critical screens (cart, checkout, tracking).
- Integration tests using seed scripts (Firestore + Storage + Functions emulators) and mocked Maps/Stripe.
- Load test dispatch path (assign/accept) via Functions.

### 20) Project Plan & Milestones (Indicative)
- Week 1–2: Models, service protocol, basic Firestore structure, discovery UI.
- Week 3–4: Menu/customization, cart/checkout, payment intents, order creation.
- Week 5–6: Merchant order console, status transitions, courier basic flow, tracking map.
- Week 7: Notifications, localization, analytics, polish.
- Week 8: Pilot readiness, ops playbooks, on-call runbooks.

### 21) Open Questions
- Local payment alternatives in Morocco beyond Stripe cards (Maroc Telecommerce, CIH e-Pay)? Roadmap priority vs. COD.
- Liability and refunds policy; who bears food issues vs. delivery issues.
- Packaging fees and tips revenue share policy.
- Service areas: polygon zones vs. radius per restaurant.

---

### Appendix A — Service Protocol (Sketch)
```swift
public protocol FoodDeliveryServicing {
  // Discovery
  func listRestaurants(near: Coordinates, radiusKm: Double?) async throws -> [Restaurant]
  func getRestaurant(id: String) async throws -> Restaurant?
  func getMenu(restaurantId: String) async throws -> [MenuItem]

  // Cart & Pricing
  func priceOrder(draft: OrderDraft) async throws -> PricedOrder
  func applyPromotion(code: String, to draft: OrderDraft) async throws -> PricedOrder

  // Orders
  func createOrder(_ order: PricedOrder, paymentMethod: PaymentMethod) async throws -> Order
  func getOrder(id: String) async throws -> Order?
  func listMyOrders() async throws -> [Order]
  func cancelOrder(id: String, reason: String) async throws

  // Real-time updates
  var orderUpdates: AnyPublisher<Order, Never> { get }
  var courierLocationUpdates: AnyPublisher<CourierLocation, Never> { get }
}
```

### Appendix B — Firestore Collections (Sketch)
```text
restaurants/{restaurantId}
  menus/{menuId}/items/{menuItemId}
orders/{orderId}
couriers/{courierId}
customers/{customerId}
pricingConfigs/{city}
promotions/{promoId}
deliveryZones/{zoneId}
```

### 22) AI‑Powered Personalization & Recommendations (Delight Focus)
- Objective: Deliver an innovative, taste-aware, context-aware experience that balances familiarity and novelty so users don’t get bored and still feel understood.
- Surfaces (customer):
  - Home "For You" carousel, cuisine rails ("Because you like Italian"), dish rails ("Chicken you’ll love"), "New for you", "Faster near you".
  - Restaurant detail: recommended items based on your patterns and time-of-day.
  - Cart cross-sell: sides/drinks tailored to taste profile.
- Signals (privacy-preserving, consented):
  - Taste: cuisines liked, ingredient affinities (e.g., chicken), dietary tags (halal/vegetarian/gluten‑free), spice tolerance.
  - Variety/novelty: items not ordered recently, newly added menu items, "new to you" restaurants.
  - Context: distance/proximity, current prep time and queue, delivery ETA, open status, surge, price fit vs. user’s basket history, time‑of‑day (breakfast/lunch/dinner/late night), day-of-week, weather (e.g., cold → soups), local events.
  - Quality: ratings, popularity trends, cancellation/late history.
- Ranking (multi‑objective)
  - Compute a score per candidate (restaurant or dish). Example (normalized 0..1):
    - score = wTaste*tasteMatch + wDiversity*diversityBoost + wNovelty*noveltyBoost + wProximity*proximity + wETA*etaSpeed + wPromo*promoBoost + wPrice*priceFit + wFresh*menuFreshness + wTime*timeOfDayFit + wWeather*weatherFit.
  - Constrain with diversity (MMR‑style re‑rank) to avoid monotonous feeds; ensure at least N items are "new to you" each session.
  - Exploration (ε‑greedy / Thompson Sampling) to discover new favorites without hurting CTR.
- Cold start: Use city/popularity priors + time‑of‑day templates; gradually personalize as signals arrive.
- Feedback loop: Thumbs up/down, "Show less like this", "Block ingredient"; auto‑learn from dwell time and add‑to‑cart without purchase.
- "Propose new experiences"
  - Highlight newly launched items from favorite cuisines/ingredients.
  - Surface seasonal/limited‑time items and geo‑nearby specials.
  - "Different from yesterday": diversity rule that down‑ranks same primary ingredient consumed yesterday.
- On‑device vs Cloud
  - On‑device quick re‑ranking (contextual weights: proximity, ETA, time‑of‑day).
  - Cloud candidate generation (collaborative filtering + content‑based embeddings).
- Data model additions
  - customers/{id}: tasteProfile{ likedCuisines[], likedIngredients[], blockedIngredients[], dietaryTags[], priceBand, noveltyPreference }, recentOrders[], lastIngredients[].
  - menus/items: embedding, primaryIngredients[], dietaryTags[], launchedAt.
  - restaurants: embedding, primaryCuisines[], avgPrepMinutesRealtime (rolling), noveltyScore (new items density).
  - interactions collection: (userId, type: view/add_to_cart/purchase/thumbs_up/down, entityId, entityType: dish/restaurant, ts, context).
- Service API (additions)
  - getPersonalizedFeed(context) returns ranked candidates with reason codes ("because you like chicken", "new near you").
  - logInteraction(event) for training signals; getRecommendationsForRestaurant(restaurantId, context) for item suggestions.
- MLOps
  - Export Firestore to BigQuery; daily batch training of CF + item/user embeddings (e.g., matrix factorization or Two‑Tower).
  - Serving: Vertex AI or Functions with a lightweight re‑ranker; feature store in Firestore/Redis.
  - A/B testing: measure rec CTR, add‑to‑cart, order conversion, diversity, user satisfaction.
- Privacy & Consent
  - Clear opt‑in for personalization; easy reset of taste profile; comply with data minimization.

Phased rollout:
- MVP: Heuristic re‑rank using known tastes, proximity, ETA, novelty rules, time‑of‑day.
- Phase 2: CF embeddings + diversity/novelty policy + feedback controls.
- Phase 3: Contextual bandits for exploration and continuous learning; weather/events signals.

### Appendix C — Recommendation Context (Sketch)
```swift
public struct RecContext: Codable {
  public var location: Coordinates
  public var timeOfDay: String // breakfast|lunch|dinner|late
  public var weather: String?  // clear|hot|cold|rainy
  public var maxEtaMinutes: Int?
  public var priceBand: String? // low|mid|high
}
```


