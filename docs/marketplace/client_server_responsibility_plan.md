### Marketplace: Client vs Backend Responsibilities and API Plan

Purpose: define a clean split between iOS (client) and backend for Marketplace, prevent duplication of business logic, and ensure security/consistency. Mirrors structure used for Food Delivery.

### Responsibilities (target authoritative split)

- Client (iOS: `Packages/MarketplaceFeature`, `Packages/MarketplaceService`)
  - UI flows: discovery, listing detail, create listing, chat, offers, reservations, Try Lab experiences.
  - Local state and optimistic UI hints; never authoritative on pricing, status, or moderation.
  - Capture device inputs (camera, ARKit, body segmentation when on‑device), compress/enhance images locally before upload.
  - On‑device quick ranking and intent detection for latency; defer authoritative ranking to backend.
  - Authenticate via Firebase; pass tokens to backend; no secrets stored locally.

- Backend (Functions: `backend/functions/src/marketplace` + optional services)
  - Listing lifecycle: create/update/delete, status transitions (active/reserved/sold/removed) with validation and audit.
  - Search indexing and retrieval (full‑text + vector), geo filtering, city/neighborhood facets; authoritative ranking.
  - Offers and reservations: rules, expiries, conflicts, idempotency, concurrency control.
  - Payments: COD guidance; phase 2 escrow (Stripe Connect) intents, capture/refund; webhook handling. Reuse `services/payments/stripeService.ts` and follow patterns in `food-delivery/stripeConnect.ts`.
  - Messaging: conversation creation, message persistence, anti‑fraud filters, rate limits, notifications fan‑out. Reuse `services/notifications/fcmService.ts` + `services/notifications/templates.ts`.
  - AI orchestration: tool endpoints for query rewrite, watchers, negotiation suggestions, plugin invocations.
  - Moderation: image/text checks, forbidden catalog by city, review queue.
  - Cross‑app traits: brokered via Parent AI with explicit consent scopes; never directly exposed to clients.
  - Reused services (do not re‑implement):
    - Payments: `services/payments/stripeService.ts`, optional `services/payments/dlocalService.ts`; patterns from `food-delivery/stripeConnect.ts` for Connect.
    - Notifications: `services/notifications/fcmService.ts`, `services/notifications/templates.ts`.
    - Location & geo: `services/location/radarService.ts`, `shared/geoHelpers.ts`.
    - ETA/routing: `shared/eta/mapboxMatrix.ts` (if courier delivery is enabled).
    - LiveKit (optional): `services/livekit/livekitService.ts`, `shared/livekitToken.ts`.
    - Platform/shared: `shared/{idempotency.ts, audit.ts, trace.ts, metrics.ts, analytics.ts, bigQueryExport.ts, secretManager.ts}`.

### Client surface (what lives on device)

- Discovery & search UI; submits queries and filters to backend; renders reason codes from results.
- Create Listing Flow: photo capture, local cleanup, calls backend for title/category/price suggestions; uploads media to Storage; obtains signed paths from backend if needed.
- Chat UI: reads conversation stream, sends messages via backend endpoint; displays moderation warnings.
- Offers/Reservations UI: creates offers, accepts/declines, makes reservations; all via backend.
- Try Lab: invokes on‑device components (body segmentation, AR) and calls backend plugins when required.
- Notifications: register for FCM, display messages; routing to screens.

### Backend surface (APIs and triggers)

Transport: Use Firebase Callable Functions for app APIs. Reserve HTTP only for third‑party webhooks (e.g., Stripe) or streaming endpoints if ever needed.

- Listings (Callable)
  - `marketplace.createListing`
  - `marketplace.updateListing`
  - `marketplace.markReserved`
  - `marketplace.markSold`
  - TRIGGER `onListingWrite` → index to search/vector stores; run moderation checks.

- Search & Personalization (Callable)
  - `marketplace.search` (q, filters, geo, page); returns results + reason codes.
  - `marketplace.getRecommendations` (context, user inferred) for personalized feeds.

- Chat & Notifications (Callable)
  - `marketplace.openConversation`
  - `marketplace.sendMessage`
  - TRIGGER `onMessageWrite` → moderation + FCM fan‑out.

- Offers & Reservations (Callable)
  - `marketplace.makeOffer`
  - `marketplace.respondToOffer`
  - `marketplace.createReservation`
  - `marketplace.completeReservation`

- Payments (phase 2)
  - (Callable) `marketplace.createEscrowIntent`
  - (Callable) `marketplace.captureEscrow`
  - (Callable) `marketplace.refund`
  - (HTTP Webhook) `marketplaceStripeWebhook`
  - Reuse `services/payments/stripeService.ts` for intents/capture/refunds; keep keys in Secret Manager.

- AI Orchestrator (Callable)
  - `marketplace.ai.answer`
  - `marketplace.ai.createWatcher`
  - `marketplace.ai.suggestNegotiation`
  - `marketplace.ai.invokePlugin`
  - May call Parent AI client using shared auth/secret helpers in `shared/secretManager.ts` and tracing in `shared/trace.ts`.

### Security & integrity

- All write endpoints require Firebase Auth; derive `userId` from token.
- Firestore rules enforce: users can write only their listings/offers/messages; reads on active listings; admin elevated for moderation.
- Idempotency keys for createListing, makeOffer, and reservation paths.
- Rate limit chat/messages and listing creation per user; content filters server‑side.
- Consent gates for cross‑app traits; audit stored in `consentGrants`.

### Client edits (once APIs are live)

- `FirestoreMarketplaceService.swift`
  - Replace any direct Firestore writes for listings with Callable invocations above.
  - Wrap Storage uploads with backend‑issued upload tokens/paths if we enforce signed uploads.
  - Search and recommendations fetched via Callable functions; keep optional on‑device re‑rank.
  - Chat send flows via Callable `marketplace.sendMessage`; subscribe to conversation updates via Firestore listeners (or SSE only if added later).
  - Offers and reservations exclusively via backend callables; disable local direct mutations.

### Backend edits (initial backlog)

- Implement `listings.ts` with input validation, status FSM, and indexing hooks (Callable exports).
- Implement `search.ts` with hybrid search (text + vector) and geo facets; connect to Algolia/Typesense/ES + vector store (Callable exports).
- Implement `ai_orchestrator.ts` with tool handlers and Parent AI trait broker client (Callable exports).
- Implement `moderation.ts` (image/text checks, forbidden items, review queue writes).
- Implement `notifications.ts` for FCM sends (chat, offers, reservations, price drops, alerts).
  - Use `services/notifications/fcmService.ts` and `services/notifications/templates.ts`.
- Implement `payments.ts` (phase 2) for escrow flows (Callable) and Stripe webhooks (HTTP).
  - Use `services/payments/stripeService.ts`; mirror `food-delivery/stripeConnect.ts` Connect account flows if needed for seller payouts.

### Rollout & toggles

- Backend first: ship listing CRUD, search, chat, offers/reservations, notifications.
- Client feature flag `marketplaceServerAuthoritative` default ON; fall back paths only in debug.
- Gradual enablement of AI Try Lab plugins by category; allow disabling per city.

### Acceptance criteria

- No client writes listings/offers/reservations directly; all validated via backend.
- Search results and recommendations are returned with reason codes; client only renders.
- Moderation events block or demote forbidden content reliably; audit present.
- Escrow flows (phase 2) operate without client secrets; webhook updates state.


