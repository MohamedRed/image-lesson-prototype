## Home Services Marketplace (Morocco) — Implementation Plan

A concise, complete plan to build a Home Services category (painting, plumbing, electrical, cleaning, etc.) with bidding and negotiation, localized for Morocco. Designed to be executable by an engineering team or automation agent.

---

## Scope and Outcomes (MVP)
- Customer can post RFQ with photos, location, and budget range; receives 3–6 bids within hours.
- Pros (self‑entrepreneurs) see a job feed, submit bids, and negotiate via guided counters.
- Booking creates a simple contract and deposit escrow (or cash toggle) with completion confirmation.
- Ratings/reviews on completion; basic disputes with evidence.
- Localized payments (MAD), Darija/FR copy, city/arrondissement geo filters.
- Admin can manage categories, moderate RFQs, and handle disputes.

---

## Architecture Overview
- Client: iOS app modules (Customer + Pro mode) using Firestore and callable HTTPS Functions.
- Backend: Firebase (Firestore, Storage, Auth, Functions, Scheduler, FCM), BigQuery for analytics.
- Payments: PSP adapter (MAD), escrow holds/releases, cash-on-completion supported.
- Observability: Metrics + tracing to BigQuery/Prometheus; alerts for liquidity/disputes.

---

## Firestore Data Model
- `serviceCategories/{categoryId}`: name, icon, attributesSchema, isActive, displayOrder
- `proProfiles/{proId}`: userId, skills[], serviceArea, verificationTier, rating, jobsCount, badges[], availability, languages[]
- `rfqs/{rfqId}`: customerId, categoryId, scope{}, location{lat,lng,city}, media[], budgetRange{min,max,MAD}, siteVisitRequested, status[draft|open|awarded|cancelled], createdAt, expiresAt
- `rfqs/{rfqId}/bids/{bidId}`: proId, amountMAD, timelineDays, includesMaterials, visitRequired, message, status[active|countered|accepted|withdrawn|expired], counters{customer:n,pro:n}, autoAcceptAbove, createdAt, expiresAt
- `contracts/{contractId}`: rfqId, customerId, proId, agreedScope{}, priceMAD, milestones[], startAt, cancellationPolicy, status[pending|active|completed|cancelled], createdAt
- `escrows/{escrowId}`: contractId, amounts[{milestoneId,amount,status[pending|held|released|refunded]}], paymentMethod[cash|card|wallet], holdbacks, pspRefs{}
- `messages/{threadId}/items/{messageId}`: rfqId|contractId, fromUserId, text, attachments[], type[chat|counter|system], piiRedactionState
- `reviews/{reviewId}`: contractId, fromUserId, toUserId, rating, text, categoryId, createdAt
- `disputes/{disputeId}`: contractId, side[customer|pro], reason, evidence[], status, resolution
- Storage buckets: `rfq-media/`, `dispute-evidence/`

Indexes (add to `firestore.indexes.json`):
- `rfqs`: (status ASC, categoryId ASC, location.city ASC, createdAt DESC)
- `bids`: (rfqId ASC, status ASC, createdAt DESC)
- `proProfiles`: (skills ARRAY_CONTAINS, serviceArea.city ASC, rating DESC)

---

## Security Rules Summary
- Customers: CRUD their RFQs while status ∈ {draft, open}; read bids for their RFQs.
- Pros: Read RFQ summaries in their skills/service area; create/update own bids; cannot read other pros’ bids.
- Contracts/Escrows/Messages: visible only to party members; server‑only writes for escrow mutations.
- Reviews: each side can write once post‑completion; public aggregates via Cloud Function only.
- Admin: bypass via custom claims; audit logs on sensitive actions.

---

## Cloud Functions Modules and APIs (TypeScript)
Create `backend/functions/src/home-services/` with:
- `categories.ts`: list and admin CRUD.
- `rfq.ts`: create/update/open/close RFQs; media handling; site‑visit scheduling hooks.
- `matching.ts`: on RFQ open/update → match by skills/geo/availability; dedupe and throttle; send notifications.
- `bids.ts`: submit, withdraw, counter; enforce caps (max 3 rounds/side) and expiries.
- `contracts.ts`: accept bid → create contract; cancel; (phase 2: change orders).
- `payments.ts`: create escrow intents, webhooks, release/refund; cash toggle receipts.
- `messages.ts`: chat endpoints; PII redaction and link/number masking.
- `verification.ts`: KYC doc flows; restricted storage handling.
- `reviews.ts`: create and aggregate; fraud heuristics.
- `disputes.ts`: open/assign/resolve with evidence.
- `tasks.ts`: scheduled jobs (RFQ/Bid expiry, auto‑accept, payout retries).
- `metrics.ts`: business/ops metrics export to BigQuery.

Callable/HTTP contracts:
// POST /home/rfq
createRfq(data: {categoryId: string; scope: Record<string, any>; location: {lat:number; lng:number; city:string}; budgetRange?: {min:number; max:number}; siteVisitRequested?: boolean; media?: string[] }): { rfqId: string }

// GET /home/rfq/:id
getRfq(rfqId: string): Rfq

// POST /home/bid
submitBid(data: {rfqId: string; amountMAD: number; timelineDays: number; includesMaterials?: boolean; visitRequired?: boolean; message?: string; autoAcceptAbove?: number}): { bidId: string }

// POST /home/bid/counter
counterBid(data: {bidId: string; newAmountMAD?: number; newTimelineDays?: number}): { bidId: string }

// POST /home/contract/accept
acceptBid(data: {bidId: string; depositPercent?: number}): { contractId: string; escrowId?: string }

// POST /home/payment/escrow
createEscrow(data: {contractId: string; method: 'card'|'wallet'|'cash'; milestones?: Array<{id:string; amount:number}>}): { escrowId: string }

// POST /home/contract/complete
completeContract(data: {contractId: string}): { released: boolean }

// POST /home/review
createReview(data: {contractId: string; rating: number; text?: string}): { reviewId: string }

Scheduled jobs (Cloud Scheduler): expireOpenRfqs, expireBids, autoAcceptBestOffer, retryPayouts.

---

## Payments and Escrow
Payment Provider interface:
export interface PaymentProvider {
  createPaymentIntent(args: {amount: number; currency: 'MAD'; metadata: any}): Promise<{id:string; clientSecret?:string}>
  captureHold(args: {intentId: string}): Promise<void>
  refund(args: {paymentId: string; amount?: number}): Promise<void>
  createTransfer(args: {amount: number; destination: string}): Promise<{id:string}>
}
- MAD currency; cards/wallets via Moroccan PSP; cash completion allowed.
- Small jobs: 20–40% deposit; larger jobs: milestone escrow.
- Payouts same/next‑day; holdbacks available during disputes.

---

## Matching and Notifications
- Matching: intersect skills and service radius (city/arrondissement), availability; cap N pros per RFQ; cooldowns to avoid spam.
- Notifications: FCM topics per category/city + direct device tokens; masked SMS fallback (optional).

---

## iOS Client (Swift Packages)
Create:
- Packages/HomeServicesService/
  - HomeServicesService.swift: protocol for RFQ, Bids, Contracts, Payments.
  - FirestoreHomeServicesService.swift: Firestore + Functions integration; PII masking failsafe.
- Packages/HomeServicesFeature/
  - Views: BrowseCategoriesView, PostRfqWizardView, RfqDetailView, BidsListView, NegotiationView, BookingSummaryView, ContractProgressView, ChatView, ReviewView.
  - ViewModels: RfqViewModel, BidsViewModel, NegotiationViewModel, ContractViewModel, ChatViewModel, ReviewViewModel.

Minimal protocol:
protocol HomeServicesService {
  func listCategories() async throws -> [ServiceCategory]
  func createRfq(_ rfq: RfqDraft) async throws -> Rfq
  func listBids(rfqId: String) async throws -> [Bid]
  func submitBid(_ bid: NewBid) async throws -> Bid
  func counterBid(_ counter: Counter) async throws -> Bid
  func acceptBid(_ bidId: String, depositPercent: Int?) async throws -> Contract
  func createEscrow(_ req: EscrowRequest) async throws -> Escrow
  func completeContract(_ contractId: String) async throws
  func createReview(_ review: NewReview) async throws -> Review
}

---

## Admin Console (MVP)
- Category management (schema/forms), RFQ moderation queue, disputes dashboard, pro verification review.
- Can be a minimal web console or driven via Firebase Console + scripts initially.

---

## Trust & Safety
- KYC: national ID + selfie; optional business verification; tiers with badges.
- Chat PII redaction (phones/links), masked phone calls, on‑platform messaging.
- Reputation per category; fraud heuristics for price/timeline anomalies.

---

## Analytics & Observability
- Export rfqs, bids, contracts, escrows, reviews to BigQuery.
- Metrics: time‑to‑first-bid, bids/RFQ, RFQ→hire, escrow adoption, dispute rate, cancellation, take rate, cash share.
- Dashboards and alerts (Looker/Grafana) for liquidity and disputes.

---

## Local Dev & Scripts
- Extend env/secrets for PSP keys, verification provider, SMS mask.
- Add Firestore indexes and Storage rules.
- Scripts in scripts/home-services/:
  - seed-categories.js, seed-pros.js, seed-rfqs.js
  - run-local.sh (emulators, functions, webhook emulator)

Commands:
# Functions
cd backend/functions && npm i && npm run build && npm run serve

# Seeds (examples)
node scripts/home-services/seed-categories.js
node scripts/home-services/seed-pros.js

---

## Testing Plan
- Unit (backend): bid/counter caps, matching filters, escrow state machine, payouts/refunds, webhooks.
- Emulator E2E: RFQ → 2 bids → counter → accept → deposit → complete → payout → reviews; plus expiries/withdrawals/disputes.
- Security rules: isolation between pros; private contracts.
- iOS unit/UI: RFQ wizard validation, bid submission, negotiation rounds, offline drafts, chat masking.

---

## Timeline (8–10 weeks)
- W1: Schema, rules, categories, indexes, seeds, metrics scaffold.
- W2–3: RFQ + matching + notifications; Pro job feed; bids list.
- W3–4: Bidding + counters + expiries; chat + masking.
- W4–5: Accept/contract + simple escrow (deposit/complete); cash toggle.
- W5–6: Reviews + reputation; admin moderation; basic disputes.
- W6–7: iOS polish; localization (Darija/FR); site‑visit flows.
- W8–9: PSP integration; payouts; receipts.
- W10: Hardening, performance, dashboards; pilot readiness.

---

## Acceptance Criteria (MVP)
- Casablanca: Customer posts Painting RFQ with photos; 3+ pros notified; ≥2 bids < 30 min.
- Up to 3 counters per side; booking with deposit or cash toggle; contract created.
- Completion triggers payout (or cash logged); both sides review.
- Security rules enforced; admin can resolve a dispute; all actions auditable.

---

## Morocco Configuration
- Currency: MAD; price guidance bands per category.
- Negotiation: 3 rounds/side, 24–48h bid expiry; creditable site‑visit fee.
- Language: Darija + French; city/arrondissement filters.
- Payments: cards/wallets + cash completion; encourage escrow via small fee discount.

---

## Folder Scaffold (to create)
backend/functions/src/home-services/
  bids.ts
  categories.ts
  contracts.ts
  disputes.ts
  matching.ts
  messages.ts
  payments.ts
  rfq.ts
  reviews.ts
  tasks.ts
  verification.ts
  metrics.ts
scripts/home-services/
  seed-categories.js
  seed-pros.js
  seed-rfqs.js
Packages/HomeServicesService/
Packages/HomeServicesFeature/

---

## Open Questions
- PSP choice(s) for MAD cards and mobile wallets; payout rails and fees.
- First six categories and city rollout order.
- Fee model mix (commission vs subscription) and promo policy for escrow adoption.
