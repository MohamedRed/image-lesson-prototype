## Events — Implementation Plan

### 1) Vision, Goals, and Success Metrics
- **Vision**: Help people discover, organize, and attend events (concerts, festivals, meetups, conferences, cultural nights) with AI assistance, friend‑centric planning, and seamless ticketing/logistics.
- **Differentiators**:
  - **City‑first discovery** with time windows and venue context; map/list views.
  - **AI concierge** for event inspiration, filtering by preferences, budget, schedule, and weather.
  - **Friend layer**: see what friends plan to attend; create attendance groups with shared chat and ride coordination.
  - **Ticketing & access**: import tickets or purchase through providers; handle group seats and transfers.
- **Primary goals (MVP)**:
  - Event discovery/search with categories, time window, price bands, and neighborhoods.
  - Attendance groups: invite friends, RSVP, cost split (for group purchases), ride coordination.
  - Ticket handling: link external tickets; MVP purchase via provider links (phase 2: in‑app ticketing).
  - AI assistant: “Live jazz under 200 MAD this Friday near Gauthier, indoors.”
- **Success metrics (MVP)**:
  - Search→Intent (save/RSVP) ≥ 30%; Intent→Attend ≥ 20%.
  - ≥ 40% AI queries in sessions; satisfaction ≥ 4.4/5.
  - Group purchase completion ≥ 90% before event start.

### 2) Personas and Key User Stories
- **Seeker**: browses upcoming events, saves favorites, asks AI for ideas.
- **Organizer**: creates attendance group, invites friends, coordinates tickets and rides.
- **Joiner**: RSVPs, pays share, shares ride plan, receives reminders.
- **Promoter/Venue**: publishes events with schedules, tickets, tiers, seating; receives sales/RSVPs.
- **AI Concierge**: personalizes by interests, budget, weather, and friend signals.

Examples:
- “Find family‑friendly events this weekend indoors; budget 100–150 MAD per person.”
- “Buy 4 seats together for Friday 8pm; split evenly; invite Yasmine and Ali.”
- “What do my friends plan next week?”

### 3) MVP Scope
- City: Casablanca first, then Rabat.
- Catalog: curated seed events + simple promoter self‑serve; support online/hybrid events.
- Attendance groups: invite friends (Friends feature), RSVP states, group chat.
- Ticketing: link external ticket URLs; optional QR import; phase 2 in‑app ticket purchase and wallet.
- Logistics: venue map, meet‑up suggestions, ride deep‑link to Ride Sharing.
- AI assistant: NL search; watchers/alerts; weather/budget reasoning; social signals.
- Localization: fr‑MA, ar‑MA (RTL), en fallback.
- Non‑goals (MVP): seat maps beyond simple tiers; resale market; complex refunds.

### 4) Architecture Overview
- **Reuse**: Firebase (Auth, Firestore, Functions, Storage, Messaging), Mapbox/Radar, BigQuery; shared payments/notifications modules.
- **Swift packages**:
  - `Packages/EventsService` — models, service protocol, Firestore/Functions implementation, search, AI client surface.
  - `Packages/EventsFeature` — SwiftUI: discovery, event detail, group planning, ticket linking/purchase UI, split payments, AI assistant UI.
- **Backend**:
  - `backend/functions/src/events` — catalog ingest, search, groups/RSVPs, ticket links/purchases (phase 2), split payments for group orders, notifications, AI tools.
- **AI**:
  - `Events AI` with tools for search, social signals, schedule proposals, ticket linking/purchase, split payment logic, ride plan suggestions.

Repo structure snippet:
```
docs/
  events/
    implementation-plan.md
    client_server_responsibility_plan.md
Packages/
  EventsService/
    Package.swift
    Sources/EventsService/
      EventsModels.swift
      EventsService.swift
      FirestoreEventsService.swift
      SearchClient.swift
      SplitPaymentsEngine.swift
      EventsAIClient.swift
  EventsFeature/
    Sources/EventsFeature/
      EventsRootView.swift
      DiscoveryView.swift
      EventDetailView.swift
      GroupPlanner/
        CreateAttendanceGroupView.swift
        InviteFriendsView.swift
      Tickets/
        LinkTicketView.swift
        GroupPurchaseView.swift
        CheckoutSummaryView.swift
      Chat/
        GroupChatView.swift
      EventsViewModel.swift
backend/
  functions/
    src/events/
      catalog.ts
      search.ts
      groups.ts
      tickets.ts
      splitPayments.ts
      notifications.ts
      ai_orchestrator.ts
      promotersOnboarding.ts
```

### 5) Data Model (Firestore‑first)
- `eventPromoters`
  - id, name, contact, verificationTier, payoutAccount?, isActive
- `events`
  - id, promoterId, title, category[music|culture|sports|theater|conference|family|other], description, images[], rules[], priceTiers[{name, priceMAD, currency}], location{lat,lng,address,neighborhood?}, venueName, startAt, endAt, recurrence?, ageRestrictions?, indoor[bool], tags[], seating{hasSeatMap:bool, generalAdmission:bool}
- `eventSessions` (for repeated/recurring)
  - eventId, startAt, endAt, capacityByTier{tierName:capacity}, status[scheduled|limited|sold_out|cancelled]
- `attendanceGroups`
  - id, organizerId, eventId, sessionId?, name, status[planning|ordering|confirmed|attended|cancelled], invitedUserIds[], participantUserIds[], chatThreadId, createdAt
- `ticketOrders`
  - groupId, eventId, sessionId, promoterId, organizerId, lineItems[{tierName, qty, unitPrice}], totalAmount, currency, status[pending|awaiting_split|confirmed|cancelled|refunded], paymentIntentId?, tickets[{code,qrUrl,seat?}], settlement{splits[], fees[], collectedAt}
- `splitIntents`
  - orderId, shareType[even|custom], shares[{userId,amount}], status[pending|paid|expired], expiresAt
- `partnerRequests` (optional: “looking for event buddies”)
  - id, organizerId, category, cityId, window{from,to}, message, status[open|matched|closed]
- `reviews`
  - eventId or promoterId, fromUserId, rating, text, createdAt
- `interactions`
  - userId, type(view/save/rsvp/order/pay), entityId, entityType(event|group|order), ts, context
- `consentGrants`, `userTraits` as in Activities (interests, budget band, schedule preferences).

Indexes: events by city+category+startAt; sessions by eventId+startAt; groups by organizerId+status; partnerRequests by city+category+status.

### 6) AI Assistant (Concierge)
- **Capabilities**:
  - NL search with time windows, price tiers, indoor/outdoor, friend signals.
  - Social: show friends attending or likely interested (with consent via Friends feature).
  - Scheduling: propose sessions that fit group availability; explain tradeoffs.
  - Budget/weather reasoning; watchers for newly announced events.
  - Ticketing: link provider purchase pages; phase 2: orchestrate in‑app ticket checkout.
- **Implementation**:
  - On‑device: intent detection, quick re‑rank.
  - Cloud: LLM orchestrator tools: `searchEvents`, `createAttendanceGroup`, `proposeGroupSession`, `createTicketOrder`, `createSplitIntent`, `linkExternalTickets`, `requestRidePlan`, `getUserTraits(scoped)`.
  - Reason codes included in responses.

### 7) Search, Ranking, Personalization
- Hybrid search (text + vector) + geo/time filters.
- Ranking: relevance + proximity + time‑fit + price fit + social boost (friends attending/saved).
- Diversity/novelty and weather signals.

### 8) Ticketing, Split Payments, Settlement
- MVP: external purchase links; import QR codes; group purchase via provider link; split tracking still in app if organizer fronts payment.
- Phase 2: server‑side ticket orders with Stripe (or provider APIs), seat allocation per tier, split payment intents, webhook reconciliation; transfers/cancellations.

### 9) Logistics and Ride Sharing Integration
- Venue maps and meet‑up suggestions; ride share deep‑links first; quotes/booking in phase 2.
- Reminders and check‑in QR (if tickets imported or issued).

### 10) Promoter Onboarding and Catalog Ingestion
- Self‑serve promoter portal (MVP light); events CRUD; sessions and tiers; media upload.
- Bulk upload/CSV; admin ingestion from public pages (phase 2 AI extract + review).
- Moderation and verification tiers.

### 11) Messaging & Notifications
- Group chat; FCM notifications: invites, RSVPs, order/split reminders, schedule changes.

### 12) KYC, Trust & Safety, Moderation
- Promoter verification; age‑restricted events handling; content moderation; dispute flows for refunds (phase 2).

### 13) Localization & Accessibility
- fr‑MA, ar‑MA (RTL), en; Dynamic Type, VoiceOver; accessible seat/tier selection.

### 14) Observability & Analytics
- Events: event_viewed, event_saved, rsvp_created, order_created, split_paid, order_confirmed, ride_quote_requested, ai_query_run, ai_suggestion_clicked, refund.
- BigQuery dashboards by city; social influence metrics.

### 15) Security & Firestore Rules (Outline)
- Users write groups/RSVPs; orders only by group participants; promoters write their events.
- Splits and orders server‑only; webhooks update order state; consent for social signals.

### 16) UX Flows (MVP)
- Seeker → AI Ask/Search → Event Detail → Save/Group → Invite/RSVP → Ticket link/import → Split (if applicable) → Ride plan → Attend → Review.
- Promoter: Create event → Publish → Manage sessions/tiers → Receive orders → (Phase 2 payouts).

### 17) Integration with Super App Navigation
- Add Events tile in `FeatureNavigationView` → `EventsFeature` root.
- Deep links: `liive://events/event/{id}`, `liive://events/group/{id}`.

### 18) Rollout Plan
- Phase 0: Seed events; search + groups + external tickets linking; AI prototype; reminders.
- Phase 1: Casablanca pilot; equal split tracking; ride deep‑links; promoter self‑serve basics.
- Phase 2: Rabat; in‑app ticket orders, split payment intents, seat tiers; group ride quotes.

### 19) Testing Strategy
- Unit: order FSM, split logic, session capacity, ranking, AI tool contracts.
- E2E: search → save → group → order/link → split → reminders → ride.
- Security rules and webhooks; load tests on announcement spikes.

### 20) Project Plan & Milestones (Indicative)
- Week 1–2: Models, schema, discovery UI, groups/RSVPs.
- Week 3–4: Sessions + ranking; external ticket links/import; notifications; AI MVP.
- Week 5–6: Promoter self‑serve; analytics; pilot readiness.
- Week 7–8 (Phase 2): In‑app orders + split intents; seat tiers; ride quotes.

### 21) Open Questions
- Ticketing integrations priority (Ticketmaster‑like vs local providers); QR import formats.
- Seat maps scope for Phase 2; refund/resale policies.
- Social signals strength vs privacy expectations; consent UX.

### Appendix A — Service Protocol (Sketch)
```swift
public protocol EventsServicing {
  // Discovery & Search
  func searchEvents(_ query: String, filters: EventFilters) async throws -> [Event]
  func getEvent(id: String) async throws -> Event?

  // Groups & RSVPs
  func createAttendanceGroup(_ draft: AttendanceGroupDraft) async throws -> AttendanceGroup
  func inviteFriends(groupId: String, userIds: [String]) async throws

  // Tickets & Orders
  func linkExternalTickets(_ link: TicketLink) async throws -> TicketLinkResult
  func createTicketOrder(_ req: TicketOrderRequest) async throws -> TicketOrder
  func createSplitIntent(_ req: SplitIntentRequest) async throws -> SplitIntent
  func confirmOrder(orderId: String) async throws -> TicketOrder

  // Updates
  var groupUpdates: AnyPublisher<AttendanceGroup, Never> { get }
  var orderUpdates: AnyPublisher<TicketOrder, Never> { get }
}
```

### Appendix B — AI Orchestrator Contracts (Sketch)
```swift
public protocol EventsAI {
  func answer(_ query: String, context: RecContext) async throws -> AIResponse
  func createWatcher(criteria: EventAlertCriteria) async throws -> EventAlert
  func proposeGroupSession(groupId: String, constraints: ScheduleConstraints) async throws -> [ProposedSession]
}

public protocol ParentAIClient {
  func requestUserTraits(scopes: [TraitScope]) async throws -> (traits: UserTraits, consentId: String)
}
```

### Appendix C — Firestore Collections (Sketch)
```text
eventPromoters/{promoterId}
events/{eventId}
eventSessions/{sessionId}
attendanceGroups/{groupId}
ticketOrders/{orderId}
splitIntents/{splitId}
partnerRequests/{requestId}
reviews/{reviewId}
consentGrants/{grantId}
userTraits/{userId}
interactions/{interactionId}
```




