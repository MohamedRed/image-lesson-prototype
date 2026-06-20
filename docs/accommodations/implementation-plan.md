## Accommodations Feature — Implementation Plan (iOS 16+ and Backend)

### Vision
Help users discover, evaluate, and book accommodations anywhere (nearby or remote), with AI-powered recommendations and a voice-first experience. The feature should also serve the Trips planner to suggest and book stays within itineraries while remaining useful as a standalone app feature.

### Objectives
- Provide fast, high-quality search with robust filtering and sorting.
- Offer AI recommendations balancing price, quality, ratings, and travel constraints.
- Support broad inventory types: hotels, hostels, apartments, rooms, homestays, B&B, vacation rentals.
- Integrate with third-party providers via official APIs/affiliates; avoid scraping and respect ToS.
- Enable users to import existing accommodations via URL or confirmation details, with AI-assisted extraction.
- Integrate across the super app: Trips (planning), RideSharing (to/from property), Friends (group sharing), FoodDelivery/Marketplace (contextual upsell).
- Enterprise-grade security, reliability, observability, and compliance.

### Non-Goals (initial)
- Building a provider-like inventory from scratch. We aggregate via partners/APIs.
- Replacing OTA loyalty accounts. We may link accounts or deep-link to provider flows when required.

### High-Level Architecture
```mermaid
graph TD
    subgraph iOS[AccommodationsFeature (iOS 16+)]
        UI[SwiftUI Views] --> VM[ViewModels (Combine/async)]
        VM --> CS[Client Service]
        VA[Voice Assistant UI]
        UI --> VA
        MAP[Map + Geocoding]
        UI --> MAP
    end

    CS -->|HTTPS/JSON| API[Accommodations API (Functions v2 / Cloud Run)]
    API --> AUTH[Firebase Auth]
    API --> SVC[Domain Services]
    SVC --> FS[Firestore]
    SVC --> CACHE[Redis/Memory Cache]
    SVC --> TASKS[Cloud Tasks]
    SVC --> MQ[Pub/Sub]
    SVC --> PAY[Stripe]
    SVC --> REC[Recommender]
    REC --> BQ[BigQuery]
    REC --> VTX[Vertex AI]

    subgraph Providers
        BK[Booking/Expedia/Amadeus APIs]
        AB[Airbnb Partner APIs/Deep Links]
        LOC[Local PMS/Channel Managers]
    end

    SVC --> BK
    SVC --> AB
    SVC --> LOC

    SVC --> RS[RideSharing Service]
    SVC --> TRIPS[Trips Service]
    SVC --> FRIENDS[Friends Service]
```

### Clear Separation: Backend vs iOS
- Backend (must do):
  - Aggregation from providers; availability/rate fetching; price normalization; taxes/fees computation.
  - Ranking/recommendations; deduplication and inventory unification; amenity normalization.
  - Booking orchestration; payments (Stripe); idempotency and PCI-compliant tokenization.
  - URL/import processing (where permitted); email/ICS parsing; provider deep-link generation.
  - Compliance, rate limits, retries, circuit breakers; caching and TTL management.
  - Security controls, data validation, audit logs, analytics, and experimentation frameworks.
- iOS (must not do):
  - No direct provider API calls or scraping; no price logic; no secret storage.
  - No ranking computation; avoid business rules duplication.
- iOS (should do):
  - Present data; local caching of responses; graceful offline; accessibility; voice UI.
  - Map/list UIs, filters UI, booking forms; native payments UI where available (PaymentSheet).

### Domain Model (Unified)
- AccommodationProperty: id, providerRefs, name, brand, type, rating, reviewsCount, address, geo, photos, amenities, safety, checkIn/Out, policies.
- RoomType: id, name, capacity, beds, amenities, images.
- RatePlan: id, mealPlan, cancellationPolicy, refundableUntil, inclusions, taxes/fees, paymentType.
- Availability: dateRange, inventoryCount, priceBreakdown (base, taxes, fees, currency), lastUpdated.
- Review: rating, count, sourceDistribution.
- ProviderReference: provider, providerPropertyId, deepLink, terms.
- Booking: id, userId, propertyRef, roomTypeRef, guests, priceSnapshot, payment, status, providerConfirmation.
- ImportRecord: id, userId, sourceUrl or code, parsedAttributes, status, provenance.
- RecoContext: userPrefs, tripContext, budget, location, timeline.

### Firestore Schema (proposed)
- collections:
  - accommodations_properties/{propertyId}
  - accommodations_cache_availability/{hashKey}  // TTL via background sweeper (e.g., 2–15 min)
  - accommodations_searches/{searchId}  // user search state, paging tokens
  - accommodations_recommendations/{userId}/items/{recoId}
  - accommodations_bookings/{bookingId}
  - accommodations_imports/{importId}
  - accommodations_provider_accounts/{userId}/providers/{provider}
- indexes:
  - properties: geo (geohash), rating desc, price buckets, amenities array contains
  - availability cache: searchKey composite (lat/lng bucket, dateStart, dateEnd, occupancy hash)

### Provider Integrations Strategy
- Prefer official affiliate/partner APIs where possible: Booking.com Affiliate, Expedia Rapid, Amadeus Hotel Search/Booking, Sabre Content Services for Lodging.
- Airbnb: partner APIs are limited; primary approach is deep-link with prefilled search and explicit user consent for handoff. Support “Import existing booking” via user-provided confirmation details; avoid scraping.
- Channel managers/PMS (e.g., SiteMinder, Cloudbeds) for boutique inventory (phase 2+).
- Abide rate limits and ToS; implement caching, exponential backoff, and circuit breaker per provider.
- Currency normalization via daily FX rates; handle local taxes/fees (tourist taxes, resort fees) per market.

### Search & Recommendation
- Search inputs: location (current GPS or target), date range, guests, rooms, budget range, accommodation types, amenities, rating, cancellable, accessibility needs.
- Heuristic ranking v1: price normalized, distance score, rating score, amenity coverage, cancellation flexibility; diversity constraint to avoid near-duplicates.
- Learning-to-Rank v2+:
  - Features: user prefs, session intent (NLU), past clicks/bookings, price vs budget gap, distance to planned POIs (from Trips), social proof.
  - Training: offline in BigQuery/Vertex AI; online inference via Functions/Cloud Run.
  - Exploration: epsilon-greedy or Thompson sampling for safe exploration in top-K.
- Re-ranking for fairness/diversity; explainability string returned for UI (“Great value + 5 min to airport”).

### Voice Assistant
- iOS: AVAudioSession + Speech (SFSpeechRecognizer) for STT, AVSpeechSynthesizer for TTS; on-device where possible. UI: compact mic button, waveforms, partial results.
- Backend: NLU orchestration (Vertex AI / server LLM) to extract structured search intent and constraints; maintain dialog state; execute search; summarize tradeoffs.
- Safety: PII redaction in prompts; profanity filtering in TTS; explicit consent for provider handoffs.

### Backend Implementation (Firebase-first, enterprise-grade)
- Platform: Firebase Functions v2 (TypeScript/Node 18+), HTTP endpoints + scheduled jobs; heavy workloads to Cloud Run.
- Data: Firestore (strongly typed via schemas), Cloud Storage for images/documents, BigQuery for analytics.
- Queueing: Cloud Tasks for provider fetch fan-out; Pub/Sub for async pipelines (imports, reco refresh).
- Payments: Stripe (Payment Intents + PaymentSheet); Apple Pay pass-through where available.
- Geospatial: Mapbox or Google Maps Geocoding; store geohashes and lat/lng.
- Security: Firebase Auth (v1) with custom claims; App Check; Firestore rules per document ownership and booking write gates.
- Observability: Structured logs (traceId, userId-hash, searchId); metrics (latency, error rate, cache hit); alerting; provider-specific dashboards.
- Resilience: rate limiter per provider, bulkhead isolation, retry with jitter, idempotency keys for booking.

### Proposed API Surface (HTTP JSON)
- GET /accommodations/search
  - q: lat,lng or placeId; dateStart, dateEnd; guests; rooms; filters (budget, rating, amenities, cancellable, types); pageToken
  - returns: properties[], availability summaries, paging
- GET /accommodations/recommendations
  - context: userId or anonymous session; optional tripId
  - returns: ranked properties with explanations
- GET /accommodations/properties/{id}
  - returns: details, roomTypes, ratePlans, live availability (cached)
- POST /accommodations/book
  - payload: propertyId, roomTypeId, ratePlanId, guestDetails, paymentMethodId
  - returns: bookingId, status, providerConfirmation
- POST /accommodations/import
  - payload: url OR provider + confirmationCode + lastName
  - returns: importId; processed booking if available; deep-link fallback
- POST /accommodations/voice/interpret
  - payload: transcript + optional audioRef; context
  - returns: intent, normalized search params, nextPrompt

All endpoints authenticated (except basic search), with App Check and per-IP/device throttling. Responses include cache-control hints for client-side caching.

### iOS App (SwiftUI, iOS 16+)
- Packages: `AccommodationsFeature` (UI) depends on `AccommodationsService` (client).
- Screens:
  - Landing: Ask “Using current location?” or enter destination; voice assistant entry.
  - Search Results: list + map toggle; chips for filters/sorts; infinite scroll.
  - Property Detail: photo gallery, amenities, reviews summary, room selection, cancellation policy.
  - Booking: guest details, payment (Stripe PaymentSheet), confirmation with deep-link if needed.
  - Import Booking: paste URL or code; show parsed summary; attach to Trips if relevant.
  - Saved/Shortlists: compare properties.
- State: MVVM with Combine/async; offline cache (URLCache + small SQLite if needed); graceful retries.
- Accessibility: Dynamic Type, VoiceOver labels, color contrast, focus order; haptics.
- Performance: prefetch images with low-res placeholders; throttled map annotations; diffable lists.

### Data Privacy, Security, Compliance
- PII minimization; PCI handled by Stripe; do not store raw card data.
- GDPR/CCPA: consent, data export/delete; clear privacy notices for provider handoffs.
- Provider ToS: no scraping; respect display requirements (attribution, logo, deep-link rules).
- Audit logs for booking-related writes; signed webhooks (Stripe, providers).

### Caching & Freshness
- Availability and prices are volatile:
  - Hot cache: 2–15 minutes TTL by search key; background refresh on scroll/pagination.
  - Stale-while-revalidate strategy; mark items with freshness metadata in UI.

### Testing Strategy
- Unit tests: domain mapping, price normalization, cancellation logic, NLU parsers.
- Contract tests: provider connectors (sandbox environments).
- Integration tests: end-to-end search → details → booking (test provider).
- iOS UI tests: filters, map interactions, booking flow, voice assistant happy/edge paths.
- Load tests: search fan-out (Cloud Tasks), rate-limited safely.
- Chaos: inject provider timeouts/errors; verify circuit breakers.

### Observability & KPIs
- Dashboards: search latency (P50/P95), conversion, click-through, booking success, cache hit rate, provider error rate, ranking quality metrics.
- Alerts: provider outage, elevated booking failures, payment declines spike.

### Rollout Plan
- Phase 0: Provider sandbox integration + internal dogfood (feature flag off)
- Phase 1: Nearby search read-only (no booking) + recommendations v1
- Phase 2: Limited booking with one provider + import flow
- Phase 3: Multi-provider, voice assistant GA, Trips integration
- Feature flags per capability; canary 1–5% cohorts; A/B for ranking tweaks.

### Risks & Mitigations
- Provider API constraints or denial: design with pluggable connectors; prioritize partners with accessible programs.
- Price/tax mismatches: display price provenance; re-validate on booking submit; show delta confirmation.
- Availability staleness: aggressive SWR, user warning on stale, quick refresh endpoints.
- Ranking bias: include fairness constraints; monitor distribution; allow user control.

### Milestones (indicative)
- Week 1–2: Schema, API skeleton, one provider connector (search only), iOS list/map.
- Week 3–4: Availability cache, details screen, filters, recommendations v1.
- Week 5–6: Booking with Stripe test mode; import flow MVP; observability.
- Week 7–8: Voice assistant beta; Trips integration; performance hardening; canary rollout.

### Integration Points in Super App
- Trips: `TripsService` requests recommended stays for itinerary segments; attach booking to trip; expose re-price endpoint.
- RideSharing: deep-link from booking confirmation to route; commute-time scoring in ranking.
- Friends: share shortlist; split costs; group availability poll.
- FoodDelivery/Marketplace: breakfast add-ons, local deals near property during stay dates.

### Implementation Notes (Tech Choices)
- Backend: Firebase Functions v2 (TypeScript), Cloud Run for long-running tasks, Firestore, Cloud Tasks, Pub/Sub, BigQuery, Vertex AI, Stripe, Mapbox/Google Geocoding.
- iOS: SwiftUI, Combine, async/await, AVFoundation Speech/TTS, Mapbox SDK, Stripe PaymentSheet; iOS 16 deployment target.

### Next Steps
- Confirm initial provider partner (e.g., Amadeus Hotel Search) and obtain credentials.
- Finalize Firestore indexes; implement search/read endpoints; wire iOS list/map.
- Stand up ranking v1 and logging for future LTR.


