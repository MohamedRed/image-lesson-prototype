## Friends & Real‑World Chat – Complete Implementation Plan

### Executive summary

Build a privacy‑respecting, action‑oriented Friends system that turns chats into real‑world and co‑present experiences. The feature integrates deeply with existing modules (Ride Sharing, Debates/LiveKit, AI Tutor, Food Delivery, Marketplace, Home Services, Activities/Events, Tourism, Health/Meals) so people can decide in chat and immediately do things together.

Outcomes:
- 1:1 and group chat with action cards that launch feature flows.
- Co‑presence: voice/video rooms, co‑watch, and screen share via LiveKit.
- Social graph (friend requests, circles), invitations, and contact import with privacy safeguards.
- Notifications, deep links, presence/typing, moderation, and safety.
- Modular iOS SPM packages and Firebase backend aligned with repo conventions.

---

## Product pillars

- Real‑world first: every chat can seamlessly spin up a plan, booking, or watch‑together.
- Low friction: import phone contacts, deep‑link invites, share from any feature into a chat.
- Safety by design: robust reporting, block lists, scoped sharing, and sane defaults.
- Ownership and consent: explicit friend relationships and clear privacy controls.

---

## iOS architecture (Feature + Service)

### Packages

```
Packages/
├── FriendsService/                 # Realtime + backend integration (Firestore, Functions, LiveKit)
└── FriendsFeature/                 # SwiftUI UI + ViewModels + navigation and share intents
```

Conventions: follow `docs/super_app_conventions.md` and `ios_styleguide.md` (MVVM, single public factory, dependency injection).

### Public API surface

```swift
// FriendsFeature
public enum FriendsViewFactory {
    @MainActor public static func make(service: FriendsServicing) -> AnyView
}

// FriendsService
@MainActor
public protocol FriendsServicing: Sendable {
    // Graph
    func requestFriend(_ userId: String) async throws
    func respondToRequest(_ requestId: String, accept: Bool) async throws
    func blockUser(_ userId: String) async throws
    var friendUpdates: AnyPublisher<FriendEvent, Never> { get }

    // Conversations
    func openConversation(with userIds: [String]) async throws -> Conversation
    func loadConversations() async throws -> [Conversation]
    var conversationUpdates: AnyPublisher<ConversationEvent, Never> { get }

    // Messages
    func send(_ message: MessageDraft, to conversationId: String) async throws
    func listMessages(conversationId: String, pageSize: Int) async throws -> [Message]
    var messageUpdates: AnyPublisher<Message, Never> { get }

    // Presence & typing
    func setPresence(_ status: PresenceStatus) async
    func setTyping(in conversationId: String, isTyping: Bool) async

    // Watch‑together / calls (LiveKit)
    func joinRoom(conversationId: String) async throws
    func leaveRoom() async
    func toggleMicrophone() async
    func toggleCamera() async
    func startScreenShare() async throws
    func stopScreenShare() async

    // Invitations & contacts
    func createInviteLink(context: InviteContext?) async throws -> URL
    func importContacts(_ hashes: [String]) async throws -> [MatchedContact]
}
```

Use `LiveKitCoreService(feature: "friends")` for rooms: `friends_{conversationId}`. Reuse NotificationCenter patterns from Food Delivery for navigation actions from push notifications.

### ViewModel state & key screens

- FriendsRootView (tabs): Chats, Friends, Invites.
- ChatListView, ConversationView (messages, composer, action bar), GroupDetailsView.
- FriendRequestsView, MutualsView, Blocks & PrivacyView.
- WatchPartyView (LiveKit tiles + party controls), ScreenShare onboarding (ReplayKit broadcast extension, later phase).

State machine example:

```swift
public final class FriendsViewModel: ObservableObject {
    public enum State { case loading, chatList, conversation(Conversation), watchParty(conversationId: String), error(String) }
    @Published public var state: State = .loading
    // handle(event:) routes UI intents → service calls
}
```

### Navigation integration

- Add a `friends` feature tile in `HomeDashboard*View` and route in `FeatureNavigationView`.
- Provide “Share to Chat” from other features using a shared `ShareToFriends` helper that opens a recipient picker, then creates/sends an `ActionCard` message.
- Deep links `liive://friends/invite/{code}` and universal links for onboarding; post notifications to bring the app into a specific conversation.

---

## Backend architecture (Firebase + Functions)

### Firestore schema (baseline)

```text
users/{uid}
  profile: { displayName, photoURL, city, … }
  friends: { counts: { total, pending }, circles: { family: [uid], close: [uid], … } }
  privacy: { showStatus: true, readReceipts: true }
  blocks: [uid]

friendships/{pairId}
  users: [uidA, uidB]           // sorted
  status: 'pending'|'accepted'|'blocked'
  requestedBy: uid
  createdAt, updatedAt

conversations/{id}
  type: 'direct'|'group'|'party'
  participants: [uid]
  admins: [uid]
  title: string?                // for groups
  lastMessageAt, unreadCount: { [uid]: number }
  linkedFeature: { kind: string, id: string }? // ride, event, order, debate, etc.

conversations/{id}/messages/{id}
  senderId: uid
  type: 'text'|'image'|'voice'|'location'|'action'|'system'
  content: string               // text or JSON for action payload
  attachments: [{ url, thumbURL, kind }]
  action: { kind, refId, refKind, meta }
  createdAt, editedAt?, deletedAt?

presence/{uid}
  status: 'online'|'away'|'dnd'|'offline'
  lastActiveAt

typing/{conversationId}/{uid}
  isTyping: boolean

invites/{code}
  inviterId: uid
  usedBy: [uid]
  maxUses: number
  createdAt, expiresAt

watchParties/{id}  (optional if not reusing conversations of type 'party')
  conversationId
  roomName: string              // LiveKit room
  playback: { state, positionMs, mediaURL, updatedAt }
```

Notes:
- Reuse/align with existing Marketplace conversations but separate to `conversations` root for social messaging.
- Media stored in Cloud Storage with signed URLs; Functions sanitize EXIF and generate thumbnails.

### Cloud Functions modules

- friends/graph.ts: request/accept/decline/block/unblock; dedupe; analytics events.
- friends/conversations.ts: open/close conversation; create group; admin controls; fan‑out unread counts; push notifications via `services/notifications/fcmService.ts`.
- friends/messages.ts: validate content (anti‑spam, link/PII masking policy), persist messages, attachments pipeline, notify participants, rate‑limit.
- friends/presence.ts: write presence/typing (via callable or security‑scoped updates). Consider RTDB for low‑latency presence if needed.
- friends/invites.ts: create/resolve invite codes; deep link payloads; referral attribution.
- friends/contacts.ts: accept hashed phone numbers; return matches; never store raw address books; TTL cache for upload sessions.
- friends/watchParty.ts: create/delete party; LiveKit token minting (reuse `shared/livekitToken.ts`); forward data‑track events for playback sync; optional HLS egress.

### Security rules (high level)

- Only participants can read a conversation and its messages; writes limited to participants; admins can manage group members.
- Friendship docs writable only by involved users for request/accept; server‑only writes for system fields.
- Presence readable by friends only (configurable); typing readable by conversation participants.
- Invites readable by code; writes restricted to inviter and cloud logic.

---

## Realtime media and co‑presence (LiveKit)

- Room naming: `friends_{conversationId}` scoped via `LiveKitCoreService(feature: "friends")`.
- Roles: member (publish/sub), spectator (sub only), bot (moderation/bridge).
- Data tracks for watch‑party control: `media_control { action: 'play|pause|seek', atMs }`, `party_meta`.
- Screen sharing: adopt ReplayKit Broadcast Upload Extension in a later milestone; start with camera+mic and co‑watch of in‑app sources (Debates HLS, AI Tutor sessions) via shared URLs.
- Push to join: VoIP or high‑priority FCM to bring users into the room; follow patterns in `VoIPNotificationService`.

---

## Core user flows

### Onboarding & growth

- Contact import: hash phone numbers locally (SHA‑256 with salt/pepper managed server‑side) → callable returns matches and suggested invites.
- Invites: share deep links with preview; QR codes for in‑person adds; optional referral rewards.
- Find friends: search by handle/phone/email (confirmed by owner), mutuals.

### Social graph

- Requests with mutual confirmation; optional “circles” for scoped sharing (close friends, family, colleagues).
- Block/report with immediate hard mute and evidence capture.

### Chat & action cards

- Message types: text, image, voice note, location, action card, system.
- Action cards launch integrated features: ride together, order together, book event/activity, co‑watch debate/news, AI Tutor session, marketplace item, home‑service visit, trip plan, meal plan/health goal.
- Read receipts and typing (user‑controlled).

### Co‑watch and calls

- Tap “Watch together” → creates/joins LiveKit; if content is a Debate or AI Tutor session, link doc with media source and sync via data tracks.
- Screen share (later): Broadcast Extension; permission and safety overlays.

---

## Integrations with existing features (entry points and chat actions)

- Ride Sharing: share live location, propose pickup time, “Request group ride” action → prefilled ride request for participants; join LiveKit voice during pickup.
- Debates (Live): share a debate; “Watch together” opens party with HLS for spectators and optional A/V for chat members; use existing `DebateLiveKitService` patterns.
- AI Tutor (Image Lesson): “Study together” launches a shared session; reuse `GliteImageLessonService` for LiveKit and data handlers.
- Food Delivery: “Order together” with group cart; split bill (Stripe Connect in future); status notifications post to conversation thread.
- Marketplace: share listing; open buyer/seller thread if needed; keep friends chat separate while deep‑linking.
- Home Services: propose a visit/booking from chat; attach RFQ summary in action card.
- Activities/Events/Tourism: plan together with date/time/location poll; export to calendar; attach booking confirmation.
- Meals/Health: share meal plans/goals/progress snapshots with privacy scopes (circle‑only); motivational nudges via notifications.

Implementation pattern: every feature exposes “Share to Friends” intent returning a serializable `ActionCardPayload { kind, refId, meta }` rendered by FriendsFeature.

---

## Notifications and deep links

- Use `backend/functions/src/services/notifications/fcmService.ts` to send participant‑scoped notifications with dedupe and rate limits.
- Device token management follows existing patterns in feature services; add friends‑specific topics if needed.
- Deep links: `liive://friends/convo/{id}`, `liive://friends/invite/{code}`; universal link handlers open directly into conversation or invite accept flow.

---

## Privacy, security, and moderation

- Data minimization: do not persist raw address books; only salted hashes and ephemeral upload sessions.
- Controls: read receipts, presence visibility (friends/all/none), circles default for sensitive actions.
- Reporting & blocking: one‑tap; server auto‑mutes pending review; capture message/window evidence.
- Content safety: text/image scanning (heuristics + allowlist of safe domains), rate limits per user/convo, link/PII masking rules similar to Home Services.
- Storage: signed URLs; EXIF stripping; virus scanning hooks (future).
- Compliance: age gates, COPPA/GDPR toggles, data export/delete endpoints.

---

## Analytics and success metrics

- Core KPIs: weekly active friends dyads, action‑card CTR, watch‑party starts/participant minutes, rides/orders/events launched from chat, invite conversion rate, abuse reports per 1k messages.
- Export: Functions stream selected events to BigQuery (see patterns in Home Services metrics exporters).

---

## Performance, offline, and reliability

- Firestore offline cache for messages; enqueue outbound messages while offline.
- Message pagination with query cursors; prefetch thread heads in ChatList.
- Attachments: background uploads; retries; thumbnail placeholders.
- Presence: RTDB/Firestore hybrid (optional) if sub‑second needed; otherwise Firestore is sufficient for MVP.

---

## Phased milestones and rollout

1) Foundation (Week 1–2)
- Packages scaffolding; navigation tile; empty states.
- Firestore security rules and minimal Functions for conversations/messages.

2) 1:1 chat MVP (Week 3–4)
- Text + image + read receipts + typing; notifications; deep links; contact import MVP (hashed).

3) Groups + action cards (Week 5–6)
- Group creation/admin; action cards for Ride, Debates, AI Tutor, Food Delivery.

4) LiveKit co‑presence (Week 7–8)
- Voice/video join; watch‑party data tracks; “Watch together” for Debates and AI Tutor.

5) Invitations & growth (Week 9)
- Invite links, QR, referral attribution; improved contact matching.

6) Safety & moderation (Week 10)
- Report/block flows; automated throttles; audit dashboards.

7) Expansion (continuous)
- Screen share via ReplayKit; trip planning; polls; bill split; tourism itineraries; health/meal nudges.

Acceptance gates: crash‑free sessions ≥ 99.5%, <300 ms p50 send→receive on Wi‑Fi, action‑card CTR ≥ 20% in friend dyads, abuse reports < 1/1k msgs.

---

## Engineering tasks (high level)

- iOS
  - Create `FriendsService` (Firestore + Functions + LiveKitCore integration).
  - Create `FriendsFeature` (UI, ViewModels, action‑card renderer, shared picker UI).
  - Add `friends` to dashboard and `FeatureNavigationView`.
  - “Share to Friends” helpers for other features; common `ActionCardPayload`.
  - Push handling and deep links → navigation to conversation.

- Backend
  - New Functions namespace `backend/functions/src/friends/` with modules above; reuse shared libs.
  - Firestore rules for `conversations/*`, `messages/*`, `friendships/*`, `presence/*`, `invites/*`.
  - LiveKit token endpoint (feature="friends").
  - Contact matching callable (hashed).
  - Notification fan‑out using existing FCM service.

---

## Risks & mitigations

- Privacy (contacts): one‑way hash with salted pepper; ephemeral uploads; explicit consent.
- Abuse/spam: throttles, rate limits, content heuristics, reports, block lists.
- Complexity of integrations: standardize `ActionCardPayload` and a minimal per‑feature adapter.
- LiveKit at scale: begin with audio + data tracks; add video/HLS gradually; monitor via LiveKit Cloud.

---

## Appendix

### ActionCardPayload (example)

```json
{ "kind": "ride_request", "refId": "<rideDraftId>", "meta": { "pickup": {"lat":0, "lng":0}, "etaMin": 12 } }
```

### Deep link patterns

- `liive://friends/convo/{conversationId}` → open conversation.
- `liive://friends/invite/{code}` → accept invite and suggest friends.

### LiveKit data events (party)

```text
media_control { action: 'play'|'pause'|'seek', positionMs }
party_meta    { title, mediaURL, postedBy }
```



