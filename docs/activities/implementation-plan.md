## Activities — Implementation Plan

### 1) Vision, Goals, and Success Metrics
- **Vision**: Enable friends and families to discover, plan, and book fun activities together (sports, games, workshops, culture), with AI assistance for inspiration, partner‑matching, scheduling, and logistics. Foster real‑world connections through seamless coordination and fair price‑splitting.
- **Differentiators**:
  - **Friend‑centric planning**: deep integration with the Friends feature for invites, RSVPs, shared preferences, and group chat.
  - **AI concierge**: talk to an assistant to describe what you want; it finds options, matches partners, proposes times/locations, and manages alerts.
  - **Smart logistics**: weather‑aware suggestions, budget‑aware options, and one‑tap ride planning via the existing Ride Sharing feature.
  - **Fair payment flows**: single booking with automatic split payments/settlements among the group.
- **Primary goals (MVP)**:
  - Discovery/search of nearby and online activities (city‑first, extendable beyond city).
  - Create groups, invite friends, find partners for specific activities (e.g., paddle/tennis).
  - Book a session (or request to book) and split the price among participants.
  - AI assistant for inspiration (“we like paddle under 150 MAD this weekend near Maarif”).
  - Activity detail with availability slots, rules, price, map, and provider info.
- **Success metrics (MVP)**:
  - Weekly Active Groups (WAG) ≥ 1,000 in pilot city.
  - Search→Group creation ≥ 25%; Group→Booking ≥ 15%.
  - ≥ 40% of sessions originate from AI queries; satisfaction ≥ 4.4/5.
  - Split payment completion ≥ 90% before session start.

### 2) Personas and Key User Stories
- **Organizer** (social planner): finds ideas, creates a group, invites friends, books once, splits costs.
- **Joiner** (friend/family): views options, signals availability, pays share, rides together.
- **Partner Seeker**: posts “Looking for paddle partners Friday 6–8pm, Maarif; intermediate.”
- **Provider** (venues/companies): publishes offerings, schedules, pricing; receives bookings and payouts.
- **AI Concierge**: understands preferences, constraints, and weather to propose plans; keeps watching and notifies.

Key stories:
- “Show me 2‑hour paddle slots under 200 MAD this Saturday in Maarif; invite Yasmine and Ali; split evenly.”
- “Find me board‑game cafés near me tonight; joiner count 3–5; budget under 100 MAD/person.”
- “I need partners for early‑morning runs; match me with similar pace in Anfa, weekdays.”
- “Provider uploads class schedule; bookings fill seats; payouts processed automatically.”

### 3) MVP Scope
- Cities: start Casablanca (arrondissements), then Rabat.
- Activity catalog: curated seed providers (sports venues, game cafés, workshops) + simple provider self‑serve.
- Grouping: create group, invite friends (Friends feature), partner requests (public discoverable posts), group chat.
- Booking: request/confirm with provider; hold required seats; split payments (even split MVP; custom split in Phase 2).
- Logistics: map + meet‑up suggestions; ride sharing link out/integration (phase 1 suggestions, phase 2 deep API).
- AI assistant: NL search; watcher alerts; weather/budget/friend‑preference reasoning; partner matching intent.
- Localization: fr‑MA, ar‑MA (RTL), fallback en.
- Non‑goals (MVP): refunds automation beyond basic; complex recurring events; marketplace for equipment rentals.

### 4) Architecture Overview
- **Reuse existing foundations**:
  - Firebase (Auth, Firestore, Functions, Storage, Messaging), BigQuery for analytics/ML, Mapbox for maps/geocoding.
  - iOS Swift Packages pattern (Feature + Service) and Combine data bindings.
  - Payments and notifications services from backend shared libs (`services/payments/stripeService.ts`, `services/notifications/fcmService.ts`).
  - Radar location helpers (`services/location/radarService.ts`) for geo and meet‑up safety.
- **New Swift packages**:
  - `Packages/ActivitiesService` — models, service protocol, Firestore/Functions implementation, partner‑matching/search, AI client surface.
  - `Packages/ActivitiesFeature` — SwiftUI flows: discovery, activity detail, group planning, partner finder, booking/checkout, split payments, AI assistant UI.
- **Backend**:
  - `backend/functions/src/activities` — catalog ingest, search, partner requests, group management, booking state machine, split payments, notifications, AI orchestrator tools.
  - Optional Cloud Run for heavy jobs: provider web ingestion, schedule normalization, vector indexing.
- **AI**:
  - `Activities AI` (app‑scoped): tools for search, partner match, scheduling, weather/budget reasoning, route planning, and split logic explanations.
  - `Parent AI` (cross‑app): broker consented traits (fitness level, interests, budget band) from Friends/Health if granted; handled via `consentGrants`.

Proposed repo structure snippet:
```
docs/
  activities/
    implementation-plan.md
    client_server_responsibility_plan.md
Packages/
  ActivitiesService/
    Package.swift
    Sources/ActivitiesService/
      ActivitiesModels.swift
      ActivitiesService.swift
      FirestoreActivitiesService.swift
      SearchAndMatchClient.swift
      SplitPaymentsEngine.swift
      ActivitiesAIClient.swift
  ActivitiesFeature/
    Sources/ActivitiesFeature/
      ActivitiesRootView.swift
      DiscoveryView.swift
      ActivityDetailView.swift
      GroupPlanner/
        CreateGroupView.swift
        InviteFriendsView.swift
        PartnerFinderView.swift
      Booking/
        AvailabilityPickerView.swift
        SplitPaymentView.swift
        CheckoutSummaryView.swift
      Chat/
        GroupChatView.swift
      ActivitiesViewModel.swift
backend/
  functions/
    src/activities/
      catalog.ts
      search.ts
      partner.ts
      groups.ts
      booking.ts
      splitPayments.ts
      notifications.ts
      ai_orchestrator.ts
      providersOnboarding.ts
```

### 5) Data Model (Firestore‑first)
- `activitiesProviders`
  - id, name, type[venue|company|individual], contact, geo{lat,lng,city,neighborhood}, amenities[], rating, verificationTier, payoutAccount?, isActive
- `activities` (offerings)
  - id, providerId, title, category[sport|game|workshop|culture|outdoor|other], description, images[], rules[], minParticipants, maxParticipants, pricePerUnit (MAD), unit[person|team|slot|hour], durationMinutes, location{lat,lng,address,neighborhood?}, tags[], ageRestrictions?, skillLevel?, equipmentNeeded?
- `activitySessions`
  - activityId, startAt, endAt, capacity, priceOverride?, bookingWindow{opensAt,closesAt}, status[open|limited|full|closed]
- `groups`
  - id, organizerId, name, activityId?, sessionId?, cityId, status[planning|booking|confirmed|completed|cancelled], preferences{timeBands, budgetBand, skillLevel}, invitedUserIds[], participantUserIds[], partnerRequestId?, chatThreadId, createdAt
- `partnerRequests`
  - id, organizerId, activityCategory, cityId, neighborhood?, skillLevel?, message, desiredWindow{from,to}, preferredDays[], frequency[one_off|recurring], status[open|matched|closed], createdAt
- `bookings`
  - groupId, activityId, sessionId, providerId, organizerId, participants[], totalAmount, currency, status[pending|awaiting_split|confirmed|cancelled|refunded], paymentIntentId?, settlement{splits[], fees[], collectedAt}
- `splitIntents`
  - bookingId, shareType[even|custom], shares[{userId,amount}]; status[pending|paid|expired]; expiresAt
- `reviews`
  - bookingId, fromUserId, toProviderId, rating, text, createdAt
- `interactions`
  - userId, type(view/save/invite/accept/decline/book/pay), entityId, entityType(activity|group|booking|partnerRequest), ts, context
- `consentGrants`
  - userId, scope (e.g., activities:health_profile_read), status (granted|revoked), createdAt, expiresAt?
- `userTraits` (cross‑app signals)
  - userId, traits{ favoriteSports[], preferredDays[], budgetBand, avgPace?, health: {vo2Max?, weeklyActiveMins?}}, updatedAt, provenance{app, scope, consentId}

Indexes: composite by cityId+category+createdAt; sessions by activityId+startAt; partnerRequests by cityId+category+status; groups by organizerId+status.

### 6) AI Assistant (Concierge)
- **Capabilities**:
  - NL search (“looking for paddle under 150 MAD Friday evening near Maarif”).
  - Partner matching: match by skills, availability, distance, friend‑of‑friend; dedupe.
  - Scheduling: propose times based on calendars (optional), provider availability, weather forecast.
  - Budget/weather reasoning: present tradeoffs with reason codes.
  - Persistent watchers: subscribe to partnerRequests or new sessions; notify when match/slot appears.
  - Route planning: suggest meet‑up points; propose rides using Ride Sharing hooks.
- **Implementation**:
  - On‑device: quick intent detection, lightweight re‑rank.
  - Cloud: LLM orchestrator with tools: `searchActivities`, `createPartnerRequest`, `proposeGroupSchedule`, `reserveSession`, `createSplitIntent`, `requestRidePlan`, `getUserTraits(scoped)`.
  - Reason codes returned to UI (“budget fit for 100 MAD/person”, “rain expected; suggests indoor option”).
- **Privacy & Consent**:
  - Cross‑app data (e.g., Health or Friends signals) only via explicit `consentGrants` scopes.

### 7) Discovery, Search, Ranking, Personalization
- Index Firestore→external index (Algolia/Typesense/ES) + vector store for embeddings; store geo for radius and neighborhood faceting.
- Ranking pipeline:
  - Base score: text relevance + geo proximity + availability + price fit.
  - Personalization: category affinity, time‑of‑day/day‑of‑week, group size patterns, friend participation.
  - Diversity and novelty: MMR‑style; ensure variety and “new to you.”
  - Weather‑aware boost/demotion (indoor/outdoor).

### 8) Booking, Split Payments, and Settlement
- Booking state machine (server authoritative): pending → awaiting_split → confirmed → completed/cancelled → refunded.
- Split flows (MVP): equal split; organizer pays deposit optional; booking confirmed when all shares paid or organizer covers remainder.
- Payment provider: reuse `services/payments/stripeService.ts` (cards) now; support cash in person for certain activities later; evaluate local PSP for wallets (phase 2).
- Webhooks: confirm booking on successful intents; auto‑expire unpaid split intents; partial refunds policy.

### 9) Logistics and Ride Sharing Integration
- Meet‑up suggestions: safe/public spots via Radar + Mapbox; distance/time estimates.
- Ride Sharing: phase 1 deep‑link to Ride feature with prefilled pickup/dropoff; phase 2 callable `rideSharing.createGroupRideQuote` to estimate cost and allow booking a pooled ride.
- Post‑booking: reminders, live route suggestions, check‑in QR (optional).

### 10) Provider Onboarding and Catalog Ingestion
- Self‑serve portal (MVP light): provider profile, offerings CRUD, session schedules, media upload, payout onboarding (phase 2).
- Bulk upload/CSV; optional connectors to aggregator APIs.
- AI ingestion (phase 2): crawl website/Google Business pages; extract offering, schedule, pricing; human‑in‑the‑loop review; dedupe.
- Verification tiers and moderation queue.

### 11) Messaging & Notifications
- Group chat (in‑app) tied to `groups`/`bookings`.
- FCM notifications: invites, RSVPs, split payment reminders, booking confirmations, schedule changes.
- Anti‑fraud: link/phone masking; rate limits.

### 12) KYC, Trust & Safety, Moderation
- Provider verification tiers; bank/payout KYC in phase 2.
- Content moderation for images/text; forbidden experiences policy; age gates where needed.
- Dispute flows (phase 2): refund/partial refund windows; evidence collection.

### 13) Health & Progress Tracking (Optional MVP+)
- HealthKit (opt‑in): track activity minutes, steps, heart rate ranges for relevant activities; surface streaks/progress.
- AI coaching nudges: consistency prompts based on user goals; privacy‑first, on‑device summaries when feasible.

### 14) Localization & Accessibility
- fr‑MA, ar‑MA (RTL), en fallback; localized categories and units.
- Dynamic Type, VoiceOver labels, high‑contrast; map annotations accessible.

### 15) Observability & Analytics
- Events: activity_viewed, partner_request_created, group_created, invite_sent, invite_accepted, split_created, split_paid, booking_confirmed, ride_quote_requested, ai_query_run, ai_suggestion_clicked, cancellation, refund.
- BigQuery export; city dashboards; weather impact analysis; partner‑match latency.

### 16) Security & Firestore Rules (Outline)
- Users can read activities; write their groups/partnerRequests; bookings only by group participants.
- Provider offerings writable by provider accounts; moderated fields restricted.
- Split writes server‑only; client proposes shares, backend persists and validates.
- Consent scopes enforced for cross‑app traits; audit trails recorded.

### 17) UX Flows (MVP)
- Organizer: Discover → AI ask → Create Group → Invite friends/Partner Finder → Pick slot → Split → Book → Ride plan → Enjoy → Review.
- Joiner: Accept invite → Select availability → Pay share → Ride plan → Attend → Review.
- Provider: Create offerings → Publish sessions → Receive bookings → Manage capacity → Payouts (phase 2).

### 18) Integration with Super App Navigation
- Add Activities tile in `FeatureNavigationView` → `ActivitiesFeature` root.
- Deep links: `liive://activities/activity/{id}`, `liive://activities/group/{id}`, `liive://activities/partner/{id}`.

### 19) Rollout Plan
- Phase 0: Internal sandbox; seed providers; test split payments; weather logic; AI assistant prototype.
- Phase 1: Casablanca pilot (2–3 neighborhoods); equal split; ride deep‑links; simple provider self‑serve.
- Phase 2: Rabat; provider payouts (Stripe Connect); group ride quotes/booking; AI ingestion; custom split.
- Phase 3: Scale categories and providers; health integrations; richer coaching.

### 20) Testing Strategy
- Unit: booking FSM, split calculations, partner matching, weather constraints, AI tool contracts.
- Emulator/E2E: group creation → invites → split → booking → webhook confirmations → ride deep‑link.
- Security rules: provider vs user isolation; split/booking invariants.
- Load: search spikes, split reminders fan‑out, schedule refresh jobs.

### 21) Project Plan & Milestones (Indicative)
- Week 1–2: Models, service protocol, Firestore schema, discovery UI, partnerRequests, group basics.
- Week 3–4: Booking/sessions + split payments (equal); notifications; AI concierge MVP.
- Week 5–6: Provider self‑serve; search ranking; weather/budget reasoning; pilot readiness.
- Week 7–8 (Phase 2 start): Payouts (Connect), group ride quotes, ingestion pipeline, custom splits.

### 22) Open Questions
- Preferred PSP(s) for MAD cards/wallets and payout rails; fee model for groups/providers.
- Provider cancellation/refund policies; rescheduling windows; no‑show handling.
- Partner matching safety: verification tiers; reporting and blocking protocols.
- Vector index stack choice and multilingual embedding model.

### Appendix A — Service Protocol (Sketch)
```swift
public protocol ActivitiesServicing {
  // Discovery & Search
  func searchActivities(_ query: String, filters: ActivityFilters) async throws -> [Activity]
  func getActivity(id: String) async throws -> Activity?

  // Groups & Partners
  func createGroup(_ draft: GroupDraft) async throws -> Group
  func inviteFriends(groupId: String, userIds: [String]) async throws
  func createPartnerRequest(_ draft: PartnerRequestDraft) async throws -> PartnerRequest
  func listPartnerRequests(cityId: String, category: ActivityCategory?) async throws -> [PartnerRequest]

  // Booking & Split
  func listAvailability(activityId: String, from: Date, to: Date) async throws -> [ActivitySession]
  func createBooking(_ req: BookingRequest) async throws -> Booking
  func createSplitIntent(_ req: SplitIntentRequest) async throws -> SplitIntent
  func confirmBooking(bookingId: String) async throws -> Booking

  // Reviews
  func createReview(_ review: NewReview) async throws -> Review

  // Updates
  var groupUpdates: AnyPublisher<Group, Never> { get }
  var bookingUpdates: AnyPublisher<Booking, Never> { get }
}
```

### Appendix B — AI Orchestrator Contracts (Sketch)
```swift
public protocol ActivitiesAI {
  func answer(_ query: String, context: RecContext) async throws -> AIResponse
  func createWatcher(criteria: ActivityAlertCriteria) async throws -> ActivityAlert
  func proposeSchedule(groupId: String, constraints: ScheduleConstraints) async throws -> [ProposedSlot]
  func matchPartners(requestId: String) async throws -> [PartnerCandidate]
}

public protocol ParentAIClient {
  func requestUserTraits(scopes: [TraitScope]) async throws -> (traits: UserTraits, consentId: String)
}
```

### Appendix C — Firestore Collections (Sketch)
```text
activitiesProviders/{providerId}
activities/{activityId}
activitySessions/{sessionId}
groups/{groupId}
partnerRequests/{requestId}
bookings/{bookingId}
splitIntents/{splitId}
reviews/{reviewId}
consentGrants/{grantId}
userTraits/{userId}
interactions/{interactionId}
```




