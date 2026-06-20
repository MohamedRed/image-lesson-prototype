I'll scan the repo to locate the Home Services feature on iOS and backend, including models, services, and any Firestore/Cloud Functions usage, so I can propose improvements grounded in what's already built.
Search files...
Ran tool
Ran tool
Ran tool

I'm going to open the key Home Services files on iOS and backend (protocol, Firestore implementation, UI entry, and Cloud Functions index) to assess the current state and pinpoint gaps and opportunities.
Ran tool
Ran tool
Ran tool
Ran tool
Ran tool

I'll read the key Home Services client models and views plus backend functions to assess current capabilities and spot gaps.
Ran tool
Ran tool
Ran tool
Ran tool
Ran tool

I’m going to open the remaining backend Home Services modules (callables, rfq, bids) to verify what’s implemented and identify gaps like missing AI endpoints or messaging inconsistencies.
Ran tool
Ran tool
Ran tool

I'll open `FeatureNavigationView.swift` to confirm the container still uses the mock service even when real is requested, so I can call out that wiring gap precisely.
Ran tool

I scanned the iOS Home Services packages and the backend Cloud Functions; below are the concrete findings and the highest‑leverage improvements on top of what you’ve built.

### What’s solid today
- End-to-end scaffolding exists: categories → RFQ → bids/negotiation → contract → escrow → reviews → messaging, plus matching, expiry tasks, wallet/commission, and BigQuery exports.
- iOS modules are split cleanly: `HomeServicesService` (protocol + Firestore impl + mocks) and `HomeServicesFeature` (views + view model).
- Backend has a callable-first API surface with metrics wrappers; matching and maintenance tasks are in place.

### Priority gaps to fix (schema alignment + wiring)
- Use real service in the app container
```162:169:/Users/mrr/liive-ios/image-lesson-prototype/FeatureNavigationView.swift
if useRealService {
    // For real service, would create FirestoreHomeServicesService
    HomeServicesMainView(service: MockHomeServicesService())
} else {
    // Use mock service for demo
    HomeServicesMainView(service: MockHomeServicesService())
}
```
- iOS model vs backend field mismatches (these will 100% break decoding once you wire the real service):
  - Bid amount/timeline
```432:441:/Users/mrr/liive-ios/Packages/HomeServicesService/Sources/HomeServicesService/HomeServicesModels.swift
public struct Bid: Codable, Identifiable {
    ...
    public var amountMAD: Double
    public var timelineDays: Int
```
```220:233:/Users/mrr/liive-ios/backend/functions/src/home-services/callables.ts
const bidData = {
  ...
  priceMAD: Number(amountMAD),
  timeline: timelineDays ? { estimatedDays: timelineDays, ... } : null,
  status: 'submitted',
```
  - Review fields
```547:557:/Users/mrr/liive-ios/Packages/HomeServicesService/Sources/HomeServicesService/HomeServicesModels.swift
public struct Review: Codable, Identifiable {
    public var fromUserId: String
    public var toUserId: String
```
```646:656:/Users/mrr/liive-ios/backend/functions/src/home-services/callables.ts
const review = {
  reviewerId: userId,
  revieweeId: isCustomer ? contract.proId : contract.customerId,
  reviewerRole: ...
```
  - Message fields
```583:592:/Users/mrr/liive-ios/Packages/HomeServicesService/Sources/HomeServicesService/HomeServicesModels.swift
public struct Message: Codable, Identifiable {
    public var threadId: String
    public var fromUserId: String
```
```675:686:/Users/mrr/liive-ios/backend/functions/src/home-services/callables.ts
const messageData = {
  conversationId,
  conversationType,
  senderId: userId,
```
  - Contract status
```481:486:/Users/mrr/liive-ios/Packages/HomeServicesService/Sources/HomeServicesService/HomeServicesModels.swift
public enum ContractStatus: String, Codable { case pending, active, completed, cancelled }
```
```370:379:/Users/mrr/liive-ios/backend/functions/src/home-services/callables.ts
const contractData = {
  ...
  status: 'pending_payment',
```
  - Escrow shape
```512:525:/Users/mrr/liive-ios/Packages/HomeServicesService/Sources/HomeServicesService/HomeServicesModels.swift
public struct Escrow: Codable, Identifiable {
    public var amounts: [EscrowAmount]
    public var paymentMethod: PaymentMethod
```
```551:560:/Users/mrr/liive-ios/backend/functions/src/home-services/callables.ts
const escrowData = {
  paymentMethod: { type: method, provider: null, last4: null },
  status: 'pending',
```
  - RFQ budget fields (client uses min/max; backend persists minMAD/maxMAD). Same alignment issue for reviews/messages.

- Real-time updates are customer-only
```74:96:/Users/mrr/liive-ios/Packages/HomeServicesService/Sources/HomeServicesService/FirestoreHomeServicesService.swift
// Listens to rfqs and contracts for customerId == current user; no pro/bids/messages listeners
```

- Minor API quirk: iOS passes `proId` to `listAvailableRFQs` callable, but backend uses auth.uid and ignores `proId`.

### Recommended fixes (fast, high ROI)
- Wire up real service in the app container
  - Use `FirestoreHomeServicesService()` when `useRealService == true`. Add environment switch for emulator vs prod.

- Add a mapping layer in `FirestoreHomeServicesService`
  - Introduce DTOs mirroring backend responses and map to your domain models, or update models to match backend. Do not decode backend documents directly into domain models as-is.
  - Map examples:
    - `priceMAD -> amountMAD`
    - `timeline.estimatedDays -> timelineDays`
    - `reviewerId/revieweeId -> fromUserId/toUserId`
    - `senderId -> fromUserId`, `conversationId -> threadId`
    - `status: 'pending_payment' -> .pending`
    - `paymentMethod.type -> paymentMethod` (or store full object if you want provider meta)
    - `budgetRange.minMAD/maxMAD -> budgetRange.min/max`

- Expand real-time listeners
  - Add listeners for:
    - Bids addressed to the customer’s RFQs
    - Contracts for pros (`proId == current user`)
    - Messages by conversation for both RFQ and Contract threads

- Implement photo upload in the Post RFQ wizard
  - Use `FirebaseStorage` to upload selected images and set `uploadedMediaUrls` before calling `createRFQ`.

- Fix `searchPros` Firestore query
  - Current query uses `isNotEqualTo` + ordering; ensure indexes or simplify to avoid invalid composite constraints.

### AI upgrades you can layer on this base
- Snap‑to‑Scope (MVP): iOS captures photos; callable `aiDescribeScope` returns normalized scope JSON, suggested title/description, and budget range. Pre-fill step 2 of the wizard.
- Conversational Estimator: callable `aiEstimateJob` given text+media returns price range and duration; show range + confidence and clarify questions.
- Matching 2.0: compute embeddings for `scope.description` and pro `portfolio/skills`; prefer providers with similar historical embeddings; fall back to current filters.
- AR quantities (phase 2): For painting/tiling, use ARKit to generate area/length -> pass as scope attributes; material quantities and budget auto-calc.

### UX improvements
- Negotiation UI: show counter history, “Accept/Counter/Decline” for both sides; surface `maxNegotiationRounds`.
- Contract/escrow: show deposit progress and milestone statuses; handle cash vs card paths cleanly.
- Messaging: single thread per RFQ/Contract with read receipts; PII redaction badge when applied.

### Backend hardening
- Security rules: enforce role-based access for rfqs/bids/messages/escrows; deny field mutations like `customerId`, `status` transitions client-side.
- Idempotency: for create endpoints (rfq/bid/escrow) accept `clientRequestId`.
- Indexes: add composites for common queries (rfqs by city/status/createdAt; bids by rfqId/createdAt; contracts by proId/customerId/createdAt).
- Observability: extend BigQuery exports to include funnel metrics (RFQ→bid→accept→escrow→complete), add error labels for negotiation limits/payment errors.

### Suggested next steps (1–2 weeks)
- Week 1
  - Wire `FirestoreHomeServicesService` in `FeatureNavigationView`.
  - Add DTOs + mapping in service; align all read/write fields.
  - Implement Storage uploads in Post RFQ flow.
  - Add pro/bid/message listeners; fix `searchPros` query.
- Week 2
  - Add callable `aiDescribeScope` and integrate into the wizard (photo → prefill).
  - Add callable `aiEstimateJob`; surface estimate + confidence.
  - Polish negotiation UI; add deposit flow UI for card/cash.

- Optional Week 3
  - Embeddings-based matching; A/B vs current matcher.
  - AR measurement for paint/tiling categories.

- Compliance
  - Update Firestore rules for home-services; add tests.
  - Ensure content moderation on images/text (reuse marketplace moderation if present).

Summary:
- The core flow is well scaffolded across iOS and backend, but the client models don’t match backend shapes; fix mapping and wire the real service first. Then add photo upload and real-time listeners for pro/bids/messages. Layer in AI Snap‑to‑Scope and the Conversational Estimator as callables, and evolve matching with embeddings. This sequence will make the feature usable with the current backend and quickly “AI‑first” without heavy rewrites.