### Events: Client vs Backend Responsibilities and API Plan

Purpose: define a clean client/backend split for Events to keep booking/order logic server‑authoritative, reuse shared services, and ensure security and consistency. Mirrors Activities and Marketplace.

### Responsibilities (target authoritative split)

- Client (iOS: `Packages/EventsFeature`, `Packages/EventsService`)
  - UI: discovery, event detail, attendance groups, ticket linking/purchase UI, split UI, group chat.
  - Local state and optimistic hints; never authoritative on orders, capacity, pricing, or splits.
  - On‑device intent detection; backend ranking and social signals authority.
  - Auth via Firebase; no secrets in client.

- Backend (Functions: `backend/functions/src/events` + optional services)
  - Catalog ingest, promoter onboarding, moderation.
  - Search and ranking (hybrid + vector) with geo/time facets and social boosts.
  - Groups & RSVPs; invites; rate limits; audit logs.
  - Ticket orders: order FSM (pending → awaiting_split → confirmed → cancelled/refunded), capacity checks per tier.
  - Split payments: share calc, intents, expiries; webhooks reconcile order state.
  - Notifications: invites, RSVPs, reminders, splits, confirmations/changes.
  - AI orchestrator tools for search, schedule, order, split; Parent AI trait access via consent gates.
  - Reused services: payments, notifications, geo, platform shared libs.

### Client surface (device)

- Discovery & search; renders reason codes.
- Attendance groups: create, invite friends, RSVP.
- Tickets: link external; purchase UI when enabled; order/split status rendering.
- Chat for groups; moderation hints.
- Notifications routing (FCM).

### Backend surface (APIs and triggers)

Transport: Firebase Callable Functions; HTTP for Stripe webhooks and ingestion/admin endpoints.

- Catalog & Promoters (Callable/HTTP)
  - `events.promoters.create|update|get`
  - `events.catalog.create|update|get`
  - `events.catalog.ingestFromUrl` (HTTP, admin only)

- Search (Callable)
  - `events.search`

- Groups & RSVPs (Callable)
  - `events.groups.create`
  - `events.groups.invite`

- Orders & Splits (Callable + Webhooks)
  - `events.orders.create`
  - `events.splits.createIntent`
  - `events.orders.confirm`
  - (HTTP Webhook) `eventsStripeWebhook`

- Notifications (Triggers/Callable)
  - Fan‑out for invites, reminders, splits, confirmations.

- AI Orchestrator (Callable)
  - `events.ai.answer`
  - `events.ai.proposeGroupSession`
  - `events.ai.createWatcher`

### Security & integrity

- Firebase Auth required for writes; Firestore rules restrict groups and orders to participants; promoters edit their own events only.
- Idempotency keys for orders and splits; concurrency guards for capacities.
- Rate limits on invites and orders; content moderation server‑side.
- Consent gates for social traits; audits in `consentGrants`.

### Client edits (once APIs are live)

- `FirestoreEventsService.swift`: invoke Callable APIs for search, groups, orders, splits; subscribe to Firestore listeners for updates.

### Backend edits (initial backlog)

- Implement `catalog.ts` and `promotersOnboarding.ts` with moderation and sessions/tiers handling.
- Implement `search.ts` (hybrid + vector) with time and geo facets.
- Implement `groups.ts` for attendance groups/RSVPs and chat initiation.
- Implement `tickets.ts` for external links and (phase 2) in‑app orders; integrate Stripe; handle webhooks.
- Implement `splitPayments.ts` for splits and expiries.
- Implement `notifications.ts` for invites/reminders/confirmations.
- Implement `ai_orchestrator.ts` tools and Parent AI client.

### Rollout & toggles

- Backend first; client flag `eventsServerAuthoritative` ON.
- Gradually enable in‑app orders by promoter; keep external links fallback.

### Acceptance criteria

- No client‑side order finalization; webhooks reconcile without client secrets.
- Search results with reason codes; social boosts respect consent.
- Reminders and splits reliable; audit logs present.




