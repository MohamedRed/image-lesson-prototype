# Debate Feature – Master TODO List

Related specs:
- [Firestore schema](./firestore_schema.md)
- [API contracts](./api_contracts.md)
- [LiveKit Cloud config](./livekit_cloud_config.md)
- [CDN auth spec](./cdn_auth_spec.md)
- [Web UI components](./ui_components_web.md)
- [Security rules](./security_rules.md)
- [Observability & SLOs](./observability_slos.md)

Guiding principles:
1. Keep every Swift/TypeScript file ≤ 100 lines; split into modules when exceeded.
2. Remove legacy/un-used code while refactoring.
3. Capture hard problems & fixes in `docs/common_error.md`.
4. Default to Firebase v2 (auth v1) on backend; prefer modular, test-driven code.

---

## Phase 0 – Discovery & Planning
- [ ] Finalize problem statement, success metrics & KPIs (engagement, claim-accuracy, retention).
- [ ] Define **Community Guidelines** & strike policy draft.
- [ ] Select STT provider (Whisper vs Deepgram) based on latency & cost analysis.
- [ ] Validate Grok API feasibility / fallback model.
- [ ] UX wireframes for Debate Lobby & Room (Figma).
- [ ] Security & privacy assessment (PII in transcripts, storage rules).

## Phase 1 – MVP (Audio-only, ≤4 speakers)
### iOS Client (`Packages/DebateFeature`)

#### Media & Document Sharing
- [ ] Support screen share / document share track via LiveKit (Egress/Ingress APIs).
- [ ] Allow debater to upload PDFs, images, or video snippets to Cloud Storage; generate thumbnails.
- [ ] Viewer side panel `SharedMediaView` lists shared items in chronological order; tap to open inline.
- [ ] Permissions: only debaters and moderator can share; spectators view-only.
- [ ] Smart prefetch for images/PDF first pages to reduce latency.
- [ ] Scaffold Swift Package `DebateFeature` mirroring RideSharingFeature structure.
- [ ] Implement `DebateLobbyView` (list, create, join debates).
- [ ] Implement `DebateRoomView` with:
  - [ ] LiveKit tiles (audio avatars only).
  - [ ] Real-time caption overlay.
  - [ ] Mic on/off, leave button.
- [ ] `DebateViewModel` → join LK room, publish mic, observe captions/events.
- [ ] Unit tests for ViewModel networking & state changes.
- [ ] TimelineView: per-debater timeline (selectable tabs or overlay); events appear as markers with color-coding (verified true/false/unknown).
- [ ] TimelineEventDetail sheet: shows event details with fact-check badge and sources; if multiple debaters reference the same historical date, user can toggle between their perspectives.
- [ ] Ability for debater to add event cards during their turn.
- [ ] Real-time sync of new events via LiveKit data track or Firestore listener.

### Web Client (Next.js/React)
- [ ] Boot Next.js app with Firebase Auth (web) and Firestore SDK; SSR enabled for replay pages.
- [ ] Spectator Web MVP: HLS player via `hls.js` (LL-HLS optional), captions overlay, reactions bar.
- [ ] LiveKit JS SDK for data track (real-time events: timeline updates, moderation notices).
- [ ] `SharedMediaPanel` lists PDFs/images/video; inline viewers for images/PDF first page.
- [ ] `TimelineView` per-debater with markers; `EventDetails` drawer shows sources + fact-check.
- [ ] Entitlements gate (subscription/ticket) pre-playback; handle signed playback URLs.
- [ ] Responsive layout (desktop-first), keyboard shortcuts, accessibility (WCAG AA), safe color contrasts.
- [ ] Basic SEO: replay detail pages SSR, OpenGraph/Twitter cards, sitemap.
- [ ] Optional PWA install for desktop with offline shell for catalog.

#### UI Framework (shadcn/ui + Tailwind + Radix UI)
- [ ] Add TailwindCSS; install and init `shadcn/ui` CLI; generate `tailwind.config.ts` with CSS variables for theming.
- [ ] Generate base components: Button, Input, Label, Tabs, Dialog, Drawer, Sheet, Tooltip, Toast, DropdownMenu, ScrollArea, Skeleton, Accordion, Avatar, Badge.
- [ ] Define design tokens (spacing, radii, z-index, brand colors) and dark mode via `class` strategy.
- [ ] Build page shell: AppHeader, LeftNav (collapsible), RightPanel (summaries/media), Content area.
- [ ] Map feature UIs to shadcn primitives:
  - [ ] VideoPageLayout using `ResizablePanel` (or CSS grid) + `ScrollArea`.
  - [ ] TimelineView using `Tabs` (per debater) + `ScrollArea` + `Tooltip` for markers.
  - [ ] EventDetails using `Sheet`/`Dialog` with `Accordion` for sources.
  - [ ] SharedMediaPanel using `Accordion` + previews; open media in `Dialog`.
  - [ ] CommentSummaryPanel using `Accordion`/`Collapsible`; Toasts for actions.
  - [ ] WatchPartyLobby using `Avatar`, `Badge`, `Dialog` for invites.
- [ ] Accessibility pass: focus rings, skip links, color contrast, keyboard navigation for Dialog/Sheet/Tabs.
- [ ] Storybook (optional) to snapshot critical components (Timeline marker, Summary item, Media card).

### Backend (Cloud Functions)

#### Media & Document Sharing
- [ ] Cloud Storage bucket `debateMedia/{debateId}/` with object-level security rules (read: all viewers, write: debaters/moderator).
- [ ] Callable `uploadSharedMedia` returns signed URL for direct upload; stores metadata in `sharedMedia/{mediaId}` (type, url, ownerUid, createdAt).
- [ ] LiveKit data track event broadcast when new media posted; clients update list.
- [ ] Scheduled cleanup job deletes unreferenced media after debate + 30 days.
- [ ] Create Firestore collection design `debates/{debateId}` & security rules.
- [ ] Endpoint `getDebateToken` for LiveKit (Firebase callable).
- [ ] Function `onSpeechChunk.ts` → receives audio chunk, triggers STT, stores transcript.
- [ ] Basic `moderatorWorker.ts` → profanity/slur detection, sends mute via LiveKit REST.
- [ ] Jest tests for STT and moderator logic.

#### Timeline & Debate Scope
- [ ] `debates/{id}` fields `timeframeStart`, `timeframeEnd` set at schedule time.
- [ ] Collection `timelines/{speakerUid}/events/{eventId}` (under `debates/{id}`) with: historicalDate, title, description, sources[], isWithinScope, factCheckStatus.

- [ ] Callable `addTimelineEvent(debateId, speakerUid, eventPayload)` validates historicalDate within timeframe and stores under the speaker's timeline.

- [ ] Fact-checker updates each event's `factCheckStatus` field; timelines overlay allows cross-speaker comparison.
- [ ] Cloud Function listens to outside-scope attempts and warns moderator AI.
- [ ] Nightly BigQuery export of verified events for analytics.

### DevOps
- [ ] Update Terraform `infra/` for new secrets (STT API keys, Grok tokens).
- [ ] Add CI step running DebateFunction test suite.
- [ ] Cloud Scheduler archival job: move `debates/{id}` docs older than 30 days to `archivedDebates/{id}` (retain minimal fields for replay catalog, delete heavy transcripts if size >X MB).

### Product Ops
- [ ] Prepare internal beta test with 10 users.
- [ ] Gather feedback on latency, UI, moderation accuracy.

## Phase 2 – Fact Checking & Reputation
### Backend
- [ ] `factCheckerWorker.ts` → batch claims every speech turn, call Grok, update `claimStatus`.
- [ ] Store fact-check response JSON in `messages/{messageId}` sub-doc.
- [ ] Cloud Function to recompute debater rating nightly.

### iOS Client
- [ ] Side panel UI for claims list with status chips (verified / needs source / false).
- [ ] Like button per speaker; write to `debateReactions/{uid}`.
- [ ] Display speaker rating badge sourced from profile doc.

### Trust & Safety
- [ ] Implement three-strike mute logic; persist under `userProfiles/{uid}/mutes`.
- [ ] Admin dashboard for dispute review (could be Firebase Console custom page).

## Phase 3 – Ticketed Premier Debates & Replay Catalog
### Payments
- [ ] Stripe price IDs: `MONTHLY_REPLAY_SUB`, `DEBATE_EVENT_{id}` (one-off).
- [ ] Extend price catalog to include `DEBATE_QNA_PASS_{debateId}` for paid live Q&A participation.
- [ ] Extend `StripeTicketService` for entitlement checks.
- [ ] Implement `buyQnASlot()` in `StripeTicketService` and backend entitlement validation.
- [ ] Webhook `handleDebateTicketWebhook.ts` to grant Firestore entitlement.

### Debate Requests & Scheduling
- [ ] Firestore collection `debateRequests/{reqId}`: requesterUid, targetDebaterUid(s), topic, proposedDatetime, status (pending/accepted/declined).
- [ ] Cloud Function `createDebateRequest` (callable) → validates optional payment, writes request doc.
- [ ] Notification trigger to alert target debater(s); auto-expire after 72 h.
- [ ] When accepted, backend auto-creates `debates/{debateId}` doc and schedules LiveKit room.
- [ ] iOS `RequestDebateView` → pick debater, topic, preferred time, pay (if required).
- [ ] iOS `DebaterInboxView` → list incoming requests, Accept/Decline.
- [ ] Stripe SKU `DEBATE_REQUEST_{debaterUid}` for paid one-on-one or panel requests.
- [ ] Integration tests for full request lifecycle and entitlement checks.

### Replays
- [ ] Record LK room via LiveKit recording API; upload to Cloud Storage.
- [ ] Generate HLS VOD URL, store in `debates/{id}/meta.replayURL`.
- [ ] iOS `ReplayListView` in a separate `DebateReplayFeature` package.
- [ ] Add **Watch Party** mode:
  - [ ] Backend: create `watchParties/{partyId}` docs with hostUid, debateId, isLive, startedAt, isPublic, capacity.
  - [ ] LiveKit room reuse (separate metadata track to sync playback position for VOD).
  - [ ] iOS `WatchPartyLobbyView` → join via link, show participant tiles.
  - [ ] Playback sync logic for replays (host authoritative timestamp, clients seek).
  - [ ] Public matchmaking:
    - [ ] Cloud Function `joinOrCreatePublicWatchParty(debateId, filters)` → ranks open parties by:
        1. Overlap in `userProfiles/{uid}.interestVectors` (history-based embedding) with other participants.
        2. Mandatory same `gender` attribute.
        3. Optional filters: ageBracket, locale, language.
    - [ ] Extend `userProfiles` schema: `gender` (required), `ageBracket`, `interestVectors` (updated nightly via BigQuery job).
    - [ ] iOS “Watch with others” flow: user chooses filters (gender pre-selected & locked), then matchmaking call.
    - [ ] Display remaining seats and filter summary; allow invite link sharing once inside party.
    - [ ] Feedback loop for matchmaking quality:
        - [ ] Capture implicit signals: watch duration vs planned length, party exit rate, mute/leave events.
        - [ ] Optional 1-tap satisfaction prompt after session (👍/👎) with skip default.
        - [ ] BigQuery pipeline aggregates signals into `matchQualityScore` per party.
        - [ ] Retrain similarity weights weekly via Vertex AI pipeline (or Cloud Functions + sklearn) to optimize NDCG/CTR.
        - [ ] Deploy updated weight tensor to `remoteConfig` for on-device scoring.
        - [ ] A/B test new weights with 10% traffic rollout; monitor retention & satisfaction KPIs.
  - [ ] **Personalized Discovery / Recommendations**:
    - [ ] BigQuery + Matrix Factorization (or embeddings) pipeline to compute `recommendedDebates[{uid}]` dataset daily.
    - [ ] Store top N debateIds per user in Firestore `userRecommendations/{uid}` (fields: debateIds[], modelVersion, generatedAt).
    - [ ] Cloud Function `getRecommendations()` callable delivers paged list, fallback to popular if cold-start.
    - [ ] iOS Replay Store: “For You” carousel surfaced above categories.
    - [ ] Feedback loop:
        1. Implicit signals: watch completion %, likes, skips, time-to-first-exit.
        2. BigQuery aggregates interaction metrics; Vertex AI pipeline retrains embeddings weekly.
        3. ModelVersion served via `remoteConfig`; A/B test improvements.
  - [ ] **Engagement Metrics & Commenting**:
    - [ ] Real-time live watcher count: store in `debates/{id}/stats.currentViewers`, update via Cloud Function listening to LiveKit webhooks (participant_joined/left).
    - [ ] Replay stats: increment `stats.totalViews` when replay HLS manifest is requested; cache per session to avoid duplicates.
    - [ ] Like/Dislike endpoints: callable `setDebateReaction(debateId, like|dislike)` writes to `debateReactions` sub-coll; Cloud Function updates `stats.likes` / `stats.dislikes` counters.
    - [ ] Scale path: if writes exceed 5 k/sec, migrate reaction counters to Redis (write-through) or Cloud Spanner; Firestore updated asynchronously for analytics.
    - [ ] Comments: sub-collection `comments/{commentId}` with authorUid, text, createdAt, sentiment.
    - [ ] AI summary pipeline:
        - [ ] Cloud Function `summarizeComments` triggered when new comments ≥ N (e.g., 10) **or** every 5 min fallback cron—keeps summaries near-real-time.
        - [ ] Use LLM (Grok) to produce JSON array of opinion clusters with fields: `summary`, `likeCount`, `dislikeCount`, `commentCount`; where like/dislike counts are aggregated from comments mapping to that cluster.
    - [ ] iOS UI:
        - [ ] Live badge showing currentViewers during live debate.
        - [ ] Replay metadata row: totalViews • likes • dislikes.
        - [ ] Comment sheet lists each summary bullet with “👍 likeCount  👎 dislikeCount  • commentCount comments”; user can:
            - Tap 👍/👎 to react to the summary cluster (writes to `commentSummaryReactions/{clusterId}/{uid}`; Cloud Function tallies counts).
            - Tap "Comment" to add reply attached to this cluster.
        - [ ] Provide "General Comment" action for remarks not tied to a cluster; store in `unclassifiedComments/{commentId}`; classification function runs when queue ≥ K comments (e.g., 20) or at 5 min interval to assign them to clusters or spawn new ones.
        - [ ] iOS UI displays only AI summary clusters with reaction counts; no raw comments list in standard view.
        - [ ] Admin/Moderator view retains ability to inspect raw comments if needed.

## Phase 4 – Video, Audience Tiles, HLS Egress & Scalability
- [ ] Switch LK publish to video + audio; adapt UI grid.
- [ ] Audience video tiles: max 12 on screen, rest in audio-only.
- [ ] Applause / reaction overlay (throttled to 1 event/sec per user).
- [ ] Integrate LiveKit **HLS Egress** service (LiveKit Cloud):
    - [ ] Enable HLS Egress in LiveKit Cloud dashboard; configure template to stream `debate/{id}` composited track with ABR ladder.
    - [ ] Cloud Storage bucket `debate-hls-output/{debateId}` as origin; set Lifecycle to retain 30 days.
    - [ ] CDN (CloudFront or Cloudflare) distribution in front of bucket; low TTL for manifest, longer for segments.
    - [ ] Spectator client: HLS player (AVPlayer) fallback to LL-HLS if enabled.
    - [ ] Fallback to RTMP if HLS setup fails during beta.
- [ ] Access control: signed URL tokens for paywalled debates, enforced at CDN edge.
- [ ] Performance load-test: 10k → 100k spectators via CDN using k6 or JMeter.
- [ ] Update cost model and monitoring dashboards (egress GB, CDN GB, transcode minutes).
- [ ] Shard Firestore counters (likes, viewerCount) with 1K-shard pattern OR switch to Redis write-through when concurrency grows.
- [ ] Pub/Sub ingestion pipeline for high-volume comments → batch Firestore writes to avoid hot spots.
- [ ] Prometheus + Grafana dashboards: SFU CPU/mem, egress drop-frames, CDN hit rate (export via LiveKit Cloud metrics API and GCP metrics).
- [ ] Chaos test suite: randomly terminate LiveKit Cloud regions (use LK Cloud failover API) and disable egress to verify auto-recovery.
- [ ] Budget alerts & daily cost report to Looker (BigQuery scheduled query + Cloud Billing export).

## Phase 5 – Public Launch
- [ ] Marketing site update & App Store screenshots.
- [ ] Legal review (ToS, privacy, content licensing).
- [ ] Incident response run-book for moderation failures.
- [ ] Post-launch analytics dashboard (BigQuery + Looker).

---

### Ongoing Maintenance
- [ ] Keep all debate-related files ≤100 lines; refactor when exceeded.
- [ ] Update `docs/common_error.md` with solved issues.
- [ ] Weekly code health triage: remove dead code, upgrade deps, run tests.

---

_Last updated: <!-- YYYY-MM-DD --> 