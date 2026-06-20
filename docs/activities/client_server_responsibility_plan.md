### Activities: Client vs Backend Responsibilities and API Plan

Purpose: define a clean split between iOS (client) and backend for Activities, ensure server‑authoritative booking/split logic, consistency, and security. Mirrors structure used for Marketplace and Home Services.

### Responsibilities (target authoritative split)

- Client (iOS: `Packages/ActivitiesFeature`, `Packages/ActivitiesService`)
  - UI flows: discovery, activity detail, group planning, partner finder, booking/checkout, split payment UI, group chat.
  - Local state and optimistic hints; never authoritative on booking confirmation, capacity, pricing, or splits.
  - Capture device inputs (camera for venue photos, location), compress/enhance before upload.
  - On‑device quick ranking and intent detection; backend performs authoritative ranking and matching.
  - Authenticate via Firebase; pass tokens to backend; no secrets locally.

- Backend (Functions: `backend/functions/src/activities` + optional services)
  - Catalog ingest and provider onboarding; schedule/session normalization; moderation.
  - Search and partner matching: retrieval, ranking, dedupe; geo and availability constraints.
  - Groups, invites, RSVPs; rate limiting; audit trails.
  - Booking state machine: pending → awaiting_split → confirmed → completed/cancelled; capacity checks and holds.
  - Split payments: compute shares, create intents, track statuses; confirm booking on success; refunds/expiries.
  - Notifications: invites, reminders, split/payment nudges, changes.
  - AI orchestrator: tool endpoints for search, match, schedule, reserve, split; integrates with Parent AI for scoped traits.
  - Reused services (do not re‑implement):
    - Payments: `services/payments/stripeService.ts` (phase 2: Connect payouts for providers).
    - Notifications: `services/notifications/fcmService.ts`, `services/notifications/templates.ts`.
    - Location & geo: `services/location/radarService.ts`, `shared/geoHelpers.ts`.
    - Platform/shared: `shared/{idempotency.ts, audit.ts, trace.ts, metrics.ts, analytics.ts, bigQueryExport.ts, secretManager.ts}`.

### Client surface (what lives on device)

- Discovery & search UI; submits queries/filters to backend; renders reason codes.
- Group planner: create, invite friends (from Friends feature), respond to availability polls.
- Partner finder: create/view requests, signal interest; backend handles matching and safety rules.
- Booking & split UI: show shares and payment statuses; backend computes and finalizes.
- Chat UI for groups; messaging sent via backend endpoints; moderation warnings displayed.
- Notifications: FCM registration and routing to screens.

### Backend surface (APIs and triggers)

Transport: Firebase Callable Functions for app APIs; HTTP reserved for webhooks (Stripe) and ingestion endpoints.

- Catalog & Providers (Callable + HTTP for ingestion)
  - `activities.providers.create|update|get`
  - `activities.catalog.create|update|get`
  - `activities.catalog.ingestFromUrl` (HTTP, admin)

- Search & Matching (Callable)
  - `activities.search` (q, filters, geo, time window); returns results + reason codes.
  - `activities.matchPartners` (requestId) → candidates list; throttled and deduped.

- Groups & Partners (Callable)
  - `activities.groups.create`
  - `activities.groups.invite`
  - `activities.partner.createRequest`
  - `activities.partner.listRequests`

- Booking & Split (Callable + Webhooks)
  - `activities.booking.listAvailability`
  - `activities.booking.create`
  - `activities.split.createIntent`
  - `activities.booking.confirm`
  - (HTTP Webhook) `activitiesStripeWebhook`

- Notifications (Callable/Triggers)
  - Fan‑out on invites, RSVPs, split expired, booking confirmed/changed.

- AI Orchestrator (Callable)
  - `activities.ai.answer`
  - `activities.ai.createWatcher`
  - `activities.ai.proposeSchedule`
  - `activities.ai.matchPartners`

### Security & integrity

- All write endpoints require Firebase Auth; derive `userId` from token.
- Firestore rules enforce: users write only their groups/partnerRequests; bookings only for group participants; providers only edit their own offerings.
- Idempotency keys for booking and split creation; concurrency guards for capacity.
- Rate limits on invites, partner posts, and booking attempts; content filters server‑side.
- Consent gates for cross‑app traits (e.g., health or friends preferences); audited in `consentGrants`.

### Client edits (once APIs are live)

- `FirestoreActivitiesService.swift`
  - Replace any direct Firestore writes for bookings/splits with Callable invocations.
  - Search and partner matching via Callable; optional on‑device re‑rank remains.
  - Group chat send flows via Callable; subscribe to updates via Firestore listeners.

### Backend edits (initial backlog)

- Implement `catalog.ts` (offerings CRUD, sessions), `providersOnboarding.ts` (basic self‑serve), and ingestion (admin only) with moderation.
- Implement `search.ts` with hybrid search (text + vector) + availability/geo facets; connect to index/vector store.
- Implement `partner.ts` for partner requests and matching rules; dedupe and rate‑limit.
- Implement `groups.ts` for group lifecycle, invites, RSVPs, chat thread creation.
- Implement `booking.ts` for capacity holds, booking FSM, confirmations, cancellations.
- Implement `splitPayments.ts` for share calc, intents, expiries, and webhooks.
- Implement `notifications.ts` for invites/reminders/payment nudges.
- Implement `ai_orchestrator.ts` tools and Parent AI trait broker.

### Rollout & toggles

- Backend first: ship search, groups, partner requests, booking/splits, notifications.
- Client feature flag `activitiesServerAuthoritative` default ON; debug fallbacks only.
- Gradual enablement of provider self‑serve and ingestion; health signals/coach nudges behind consent gates.

### Acceptance criteria

- No client finalizes bookings/splits; all validated via backend with capacity checks.
- Search/match results return reason codes; client only renders and filters.
- Notifications/reminders fire reliably; audit trails present for sensitive actions.
- Stripe webhooks reconcile payments and update booking state without client secrets.




