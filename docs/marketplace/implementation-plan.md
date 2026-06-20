## Marketplace (City‑First Secondhand) — Implementation Plan

### 1) Vision, Goals, and Success Metrics
- **Vision**: Build a hyper‑local, city‑first marketplace for secondhand items that feels native to each city and neighborhood, powered by an integrated AI assistant that proactively finds, evaluates, and helps transact on items. Each app has its own specialized AI while a parent AI orchestrates consented, cross‑app intelligence.
- **Differentiators**:
  - **City‑first discovery**: neighborhood feeds, arrondissement filters, meet‑up friendly flows, delivery via our own ride‑sharing feature.
  - **AI concierge**: natural language search, “look for me”, alerting, negotiation help, category‑specific try/learn experiences (e.g., virtual try‑on for apparel, compatibility checks + tutorials for car parts, AR placement for furniture).
  - **Trust & safety**: seller verification, escrow/COD, reputation signals, content moderation.
- **Primary goals (MVP)**:
  - Fast listing creation with AI (auto title, category, price suggestion, photo enhancement).
  - Buyer discovery with local ranking and AI assistance.
  - Safe transaction flows: in‑app chat, reservation, meet‑up scheduling, COD and optional escrow via Stripe Connect.
  - Category plugins for “Try Lab” (at least apparel try‑on and car‑part compatibility/tutorials).
- **Success metrics (MVP)**:
  - Listing→contact rate ≥ 25% within 7 days.
  - Buyer search→message/offer conversion ≥ 20%.
  - Time to first sale median ≤ 10 days.
  - ≥ 40% of buyer sessions use AI assistant; satisfaction ≥ 4.4/5.
  - Dispute rate ≤ 1.5%; scam detection recall ≥ 80% on labeled set.

### 2) Personas and Key User Stories
- **Buyer**
  - Natural language search: “Vintage wooden desk under 1500 MAD near Maarif.”
  - Ask AI to keep looking and notify when matches appear; prefers certain neighborhoods.
  - Category‑specific actions: try clothes virtually; check car‑part fits my car profile; preview furniture in my room with AR.
  - Message seller, make offer, schedule meet‑up or request courier delivery, pay COD/escrow.
- **Seller**
  - Quick listing: upload photos → AI suggests title, category, tags, condition, price; auto background cleanup.
  - Choose delivery options (meet‑up, courier), enable Stripe Connect (phase 2) or COD.
  - Respond in chat; mark reserved/sold; see simple analytics.
- **Courier (optional MVP+)**
  - Accept pickup and drop‑off tasks; proof‑of‑delivery photos.
- **Operations/Admin**
  - Moderate flagged content, handle disputes/refunds, verify sellers (KYC), manage city settings.
- **Parent AI and App AIs**
  - Parent AI orchestrates consented data flows between app AIs (e.g., clothing sizes from Food Delivery profile? car model from Ride Sharing). Marketplace AI uses these traits to personalize and assist.

### 3) MVP Scope
- **Cities**: Start Casablanca (arrondissements), then Rabat.
- **Buyer app**: localized discovery feed, map + list, search + filters, chat, offers, reservations, AI assistant (concierge + suggest + watchers), Try Lab (apparel try‑on basic, car‑part compatibility check + tutorial links).
- **Seller app**: listing creation, photo upload, AI metadata, pricing suggestion, manage status, basic analytics.
- **Payments**: COD MVP; escrow via Stripe Connect (destination charges, transfer) in phase 2.
- **Delivery**: meet‑up flows MVP; integrate with Ride Sharing for courier delivery (quote + booking) in phase 2.
- **Languages**: fr‑MA, ar‑MA (RTL), fallback en.
- **Non‑goals (MVP)**: auctions, storefronts/shops, automated bidding, cross‑country shipping, complex returns.

### 4) Architecture Overview
- **Reuse existing foundations**:
  - Firebase (Auth, Firestore, Functions, Storage, Messaging), BigQuery for analytics/ML, Mapbox for maps/geocoding.
  - iOS Swift Packages pattern (Feature + Service) and Combine data bindings per existing apps.
  - Shared backend services and utilities (reuse, do not re‑implement):
    - Payments: `backend/functions/src/services/payments/stripeService.ts` (Stripe; Connect/escrow in phase 2, following patterns from `food-delivery/stripeConnect.ts`).
    - Local payments (future): `backend/functions/src/services/payments/dlocalService.ts` (evaluate for marketplace use in Morocco if needed).
    - Notifications: `backend/functions/src/services/notifications/fcmService.ts` + `templates.ts` (FCM fan‑out and templating).
    - Location/geo: `backend/functions/src/services/location/radarService.ts` (Radar geofencing/validation); `backend/functions/src/shared/geoHelpers.ts`.
    - ETA (phase 2 courier): `backend/functions/src/shared/eta/mapboxMatrix.ts` for distance/ETA calculations.
    - Live video (optional later): `backend/functions/src/services/livekit/livekitService.ts` and `backend/functions/src/shared/livekitToken.ts`.
    - Observability & platform: `backend/functions/src/shared/{idempotency.ts, audit.ts, trace.ts, metrics.ts, analytics.ts, bigQueryExport.ts, secretManager.ts}`.
- **New Swift packages**:
  - `Packages/MarketplaceService` — domain models, service protocol, Firestore/Functions implementation, Combine publishers, vector search client.
  - `Packages/MarketplaceFeature` — SwiftUI flows: discovery, listing detail, create listing, chat, offers, reservation/checkout, Try Lab, AI assistant surface.
- **Backend**:
  - `backend/functions/src/marketplace` — listing CRUD, search indexing, pricing suggestions, AI orchestration endpoints, moderation, escrow/payment webhooks, notifications. App APIs exposed as Firebase Callable Functions; HTTP reserved for third‑party webhooks (e.g., Stripe).
  - Optional Cloud Run microservices for heavy jobs: image processing (BG removal, quality), vector indexing, try‑on/compatibility services proxy.
- **AI**:
  - `Marketplace AI` (app‑scoped): tools for search, alerts, negotiation helper, category plugins, city policies.
  - `Parent AI` (cross‑app): capability registry, consented profile graph, brokered requests with explicit scopes.
- **Data flow**: Service exposes `AnyPublisher` updates for listings, chats, and alerts; UI binds via `ObservableObject` view models.

Proposed repo structure snippet:
```
docs/
  marketplace/
    implementation-plan.md
Packages/
  MarketplaceService/
    Package.swift
    Sources/MarketplaceService/
      MarketplaceModels.swift
      MarketplaceService.swift
      FirestoreMarketplaceService.swift
      SearchIndexClient.swift
      PricingSuggestionEngine.swift
  MarketplaceFeature/
    Sources/MarketplaceFeature/
      MarketplaceRootView.swift
      DiscoveryView.swift
      ListingDetailView.swift
      CreateListingFlow/
        CreateListingView.swift
        PhotoEnhancementView.swift
        PricingSuggestionView.swift
      Chat/
        ConversationView.swift
      Offers/
        OfferSheet.swift
      TryLab/
        ApparelTryOnView.swift
        CarPartCompatibilityView.swift
        FurnitureARPlacementView.swift
      MarketplaceViewModel.swift
backend/
  functions/
    src/marketplace/
      listings.ts
      search.ts
      pricing.ts
      ai_orchestrator.ts
      moderation.ts
      payments.ts
      notifications.ts
```

### 5) Data Model (Firestore‑first)
- `cities` (collection)
  - id, name, neighborhoods[], defaultCurrency: "MAD", settings{maxDeliveryRadiusKm, meetupSafetyTipsUrl}
- `listings`
  - id, cityId, neighborhoodId?, title, description, category, condition (new|like_new|good|fair), price, currency, images[], thumbnails[], sellerId, status (active|reserved|sold|removed), createdAt, updatedAt, location{lat,lng,addressLine, arrondissement?}, deliveryOptions {meetup: bool, courier: bool}, attributes (map per category), embedding[], moderation{status, reasons[]}
- `users`
  - id, displayName, photoUrl, phoneVerified, seller{kycStatus, rating, stats{soldCount,cancelRate}}, buyer{rating}, preferences{ neighborhoods[], categories[], priceBand }
- `messages` (collection or subcollection per conversation)
  - conversationId, participants[], lastMessageAt; messages{subcollection}: senderId, type(text|image|system), content, createdAt
- `offers`
  - listingId, buyerId, amount, status (pending|accepted|declined|withdrawn|expired), createdAt
- `reservations`
  - listingId, buyerId, status (pending|confirmed|completed|cancelled), meetup{when, where}, delivery{courierJobId?}
- `payments`
  - escrowIntentId?, method (cod|card_escrow), status, amount, currency, timeline{authorizedAt,capturedAt,refundedAt}
- `alerts`
  - userId, queryDSL, cityId, neighborhoods[], priceRange, categories[], createdAt, isActive
- `interactions`
  - userId, type(view/save/contact/offer/purchase/flag/like/dislike), entityId, entityType(listing/user), ts, context
- `userTraits` (cross‑app signals)
  - userId, traits{ carModel, clothingSizes{tops,bottoms,shoes}, stylePreferences[], diySkillLevel }, updatedAt, provenance{app, scope, consentId}
- `consentGrants`
  - userId, scope (e.g., marketplace:car_profile_read), status (granted|revoked), createdAt, expiresAt?

Indexes: composite by cityId+status+createdAt desc; cityId+category+price; full‑text via external index; vector index external.

### 6) Category Plugin System ("Try Lab")
- **Goal**: Provide category‑specific “try/learn” experiences through a pluggable architecture.
- **Plugin contract**:
  - declare: `category`, `capabilities[]` (try_on, fit_check, tutorial), `inputs` schema (images, body metrics, car model), `outputs` schema (rendered preview, compatibility verdict, tutorial playlist).
  - UI component reference for iOS; backend tools endpoints for compute.
- **Initial plugins**:
  - ApparelTryOn: body segmentation on‑device, size estimation from photos or self‑reported + previous purchases; on‑device preview; optional cloud cloth‑drape rendering for higher fidelity.
  - CarPartCompatibility: use `userTraits.carModel`; match against compatibility catalog; fetch and summarize install tutorials (YouTube) with steps and required tools.
  - FurnitureARPlacement: RealityKit AR placement; checks room size; computes fit and walkway clearance.
- **Safety/Disclaimers**: “Preview only; may differ from real fit.” Provide clear opt‑ins for body images; process on‑device where possible; delete sensitive inputs by default.

### 7) AI Assistant (Concierge)
- **Capabilities**:
  - NL search + query rewriting (“looking for sturdy baby crib under 1000 MAD in Gauthier”).
  - Persistent watchers: agent subscribes to `alerts` and relevant neighborhoods; summarizes new matches.
  - Proactive suggestions using `userTraits`, past interactions, time‑of‑day, proximity.
  - Negotiation helper: fair price suggestions based on comps; draft courteous messages; detect risky wording.
  - Category plugin orchestration: trigger try‑on, compatibility, AR placement.
  - Meet‑up planning: propose safe public locations + times; optionally call Ride Sharing for courier quotes.
- **Implementation**:
  - On‑device: fast re‑rank, intent detection for offline UX.
  - Cloud: LLM orchestrator with tools: `searchListings`, `createAlert`, `negotiateOffer`, `scheduleMeetup`, `invokeCategoryPlugin`, `getUserTraits(scoped)`.
  - Reason codes returned to UI (“because it fits your car model”, “new in Maarif”).
- **Privacy & Consent**:
  - No cross‑app data without explicit `consentGrants` for scopes; show in UI with granular toggles and audit trail.

### 8) Search, Ranking, and Personalization
- **Indexing**: sync Firestore→external index for full‑text (e.g., Algolia/Typesense/ES) + vector store for embeddings. Keep geo fields for radius and neighborhood faceting.
- **Ranking (candidate→re‑rank)**:
  - Base score: text relevance + geo proximity + recency + price fit.
  - Personalization: category affinity, novelty/diversity, seller reputation, image quality.
  - Diversity: MMR‑style re‑rank to avoid redundancy; ensure “new to you” items each session.
- **Embeddings**: generate item and query embeddings (multilingual); store in vector index; use hybrid search (BM25 + vector).

### 9) Payments & Settlement
- **MVP**: COD with in‑app guidance for safe meet‑ups; optional courier cash collection.
- **Phase 2**: Stripe Connect (Express): destination charges + transfers, optional escrow: authorize at reservation, capture on proof‑of‑delivery.
- **Disputes**: evidence collection (photos, chat logs), timed windows, partial refunds per policy.

### 10) Logistics (Meet‑up and Delivery)
- **Meet‑up**: AI suggests safe public spots; calendar integration; check‑ins and reminders.
- **Courier (phase 2)**: quote via Ride Sharing service, book courier job, live tracking, POD photos.
  - Reuse Radar via `services/location/radarService.ts` for meet‑up geofencing/check‑ins if enabled.

### 11) Messaging & Notifications
- **Chat**: text + photos; anti‑fraud filters (no external payment links), rate limits, block/report.
- **Push**: new messages, offers, reservations, watcher matches, price drops.

### 12) KYC, Trust & Safety, Moderation
- **Seller verification**: phone, optional ID (phase 2); risk‑based prompts.
- **Content moderation**: image NSFW/danger detection, forbidden items list per city; ML + human review queue.
- **Reputation**: post‑transaction ratings with reason codes; strike system for policy violations.

### 13) Localization & Accessibility
- fr‑MA, ar‑MA (RTL) with shared strings and right‑aligned numerals for RTL.
- City localization: show neighborhoods, local price bands, COD norms, safety guidance.
- Dynamic Type, VoiceOver labels for images/buttons; color‑contrast.

### 14) Observability & Analytics
- Events: listing_created, listing_viewed, message_sent, offer_made, offer_accepted, reservation_created, meetup_scheduled, delivery_requested, purchased, dispute_opened, tryon_started, tryon_completed, compatibility_checked, alert_created, ai_query_run, ai_suggestion_clicked.
- BigQuery export; dashboards by city; anomaly detection for scams. Reuse `shared/analytics.ts` and `shared/bigQueryExport.ts` for pipelines.

### 15) Security & Firestore Rules (Outline)
- Roles: users read active listings; only owners edit their listings; offers limited to active listings; reservations locked by ownership checks.
- Functions enforce pricing/offer constraints, escrow state transitions, and moderation.
- `userTraits` readable by Marketplace AI only via scoped token from Parent AI; direct user reads excluded.

### 16) UX Flows (MVP)
- **Buyer**: Discovery → Search or Ask AI → Listing Detail → Try/Check → Message/Offer → Reserve → Meet‑up/Delivery → Confirm → Rate.
- **Seller**: Create Listing (AI assist) → Publish → Chat/Offers → Reserve → Handoff → Mark Sold → Payout (phase 2).

### 17) Integration with Super App Navigation
- Add Marketplace tile in `FeatureNavigationView` → `MarketplaceFeature` root.
- Deep links: `liive://marketplace/listing/{id}`, `liive://marketplace/create`, `liive://marketplace/chat/{conversationId}`.

### 18) Rollout Plan
- Phase 0: Internal sandbox with seed data; moderation workflows; test Try Lab plugins.
- Phase 1: Casablanca pilot (2–3 neighborhoods); COD only; meet‑up flows; basic AI concierge with watchers.
- Phase 2: Rabat; courier delivery integration; Stripe Connect escrow; expand plugin fidelity for try‑on; add furniture AR.
- Phase 3: Scale neighborhoods; add seller KYC tiers; optimize ranking with feedback loops.

### 19) Testing Strategy
- Unit tests: pricing suggestions, offer/escrow state machine, search ranking, plugin contracts.
- UI snapshot tests: discovery, listing detail, create listing, chat, try‑on flows.
- Integration: Firestore + Functions emulator; vector/full‑text index mocks; media pipelines.
- Load: listing search and chat scenarios; AI watcher fan‑out.

### 20) Project Plan & Milestones (Indicative)
- Week 1–2: Models, service protocol, Firestore structure, discovery UI, create listing flow with AI metadata.
- Week 3–4: Chat/offers/reservations; search index + ranking; AI concierge MVP; apparel try‑on basic; moderation hooks.
- Week 5–6: City localization polish; notifications; analytics; pilot readiness; ops runbook.
- Week 7–8 (Phase 2 start): Courier integration, escrow payments, plugin fidelity upgrades, Rabat launch prep.

### 21) Open Questions
- Escrow policy and release conditions for disputes across categories?
- Category coverage for forbidden items per city; who curates the list?
- Third‑party try‑on vendors vs. in‑house pipeline tradeoffs; budget and latency targets.
- Vector index choice (managed vs. self‑hosted) and multilingual embedding model selection.
- Seller fees and monetization (listing boosts? featured spots?) and local compliance.

### Appendix A — Service Protocol (Sketch)
```swift
public protocol MarketplaceServicing {
  // Discovery & Search
  func listNearby(in cityId: String, center: Coordinates, radiusKm: Double?) async throws -> [Listing]
  func search(query: String, filters: SearchFilters) async throws -> [Listing]
  func getListing(id: String) async throws -> Listing?

  // Listing
  func createListing(draft: ListingDraft) async throws -> Listing
  func updateListing(id: String, updates: ListingUpdate) async throws -> Listing
  func markReserved(id: String, buyerId: String?) async throws
  func markSold(id: String) async throws

  // Chat & Offers
  func openConversation(with userId: String, listingId: String) async throws -> Conversation
  func sendMessage(conversationId: String, message: MessageDraft) async throws
  func makeOffer(listingId: String, amount: Money) async throws -> Offer
  func respondToOffer(offerId: String, action: OfferAction) async throws

  // Reservations & Delivery
  func createReservation(listingId: String, details: ReservationDetails) async throws -> Reservation
  func completeReservation(reservationId: String) async throws

  // Alerts
  func createAlert(criteria: AlertCriteria) async throws -> Alert
  func listMyAlerts() async throws -> [Alert]

  // Real‑time updates
  var listingUpdates: AnyPublisher<Listing, Never> { get }
  var conversationUpdates: AnyPublisher<Message, Never> { get }
}
```

### Appendix B — AI Orchestrator Contracts (Sketch)
```swift
public protocol MarketplaceAI {
  func answer(_ query: String, context: RecContext) async throws -> AIResponse
  func createWatcher(criteria: AlertCriteria) async throws -> Alert
  func suggestNegotiation(listingId: String, targetPrice: Money?) async throws -> NegotiationSuggestion
  func invokePlugin(category: String, action: String, input: PluginInput) async throws -> PluginOutput
}

public protocol ParentAIClient {
  func requestUserTraits(scopes: [TraitScope]) async throws -> (traits: UserTraits, consentId: String)
}
```

### Appendix C — Firestore Collections (Sketch)
```text
cities/{cityId}
listings/{listingId}
messages/{conversationId}/messages/{messageId}
offers/{offerId}
reservations/{reservationId}
payments/{paymentId}
alerts/{alertId}
userTraits/{userId}
consentGrants/{grantId}
interactions/{interactionId}
```


