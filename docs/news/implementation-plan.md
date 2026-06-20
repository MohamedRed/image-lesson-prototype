## News & Perspectives — Implementation Plan

### 1) Vision, Goals, and Success Metrics
- **Vision**: Inform users with balanced, contextualized news that broadens understanding and fosters unity. Each news event is enriched with historical context and multiple perspectives (geographies, ideologies, stakeholder groups) with citations and safety guardrails.
- **Primary goals (MVP)**:
  - Curate a feed of clustered news events (not raw articles), each with: article roll‑up, AI historical context, and at least three perspectives.
  - Provide two sections: **Good News** (positive impact, progress, solutions) and **Challenging News** (issues with constructive solution ideas).
  - Reusable **Comment Service** shared across features (Debates, News, Marketplace, etc.).
- **Success metrics (MVP)**:
  - ≥ 35% of event opens show at least one perspective tab interaction.
  - ≥ 25% of users engage with Good News weekly; ≥ 10% submit a constructive solution on Challenging News.
  - ≥ 80% of AI summaries include at leas Uh. t two citations; user trust rating ≥ 4.4/5.

### 2) Personas and Key User Stories
- **Curious Reader**: Wants concise, neutral context and to compare viewpoints quickly.
- **Concerned Citizen**: Wants constructive solution ideas and ways to help.
- **Optimist**: Seeks positive, humanity‑affirming stories with impact stats.
- **Moderator/Admin**: Curates sources, moderates comments, tunes perspective taxonomy, handles flags.
- **Researcher (internal)**: Analyzes coverage gaps and quality metrics.

### 3) MVP Scope
- Multiple connectors with pluggable architecture; start with `newsapi.org` (Everything/Top Headlines). Add Event Registry, GDELT, Newscatcher in phases.
- Event clustering and dedupe; per‑event article roll‑up UI.
- AI enrichment per event: historical context, 3+ perspectives, citation list, confidence.
- Good vs Challenging classification and solutions section.
- Comment threads per event using a reusable Comment Service.
- iOS integration (Swift packages): `NewsService`, `NewsFeature` with Good/Challenging tabs.

Non‑goals (MVP): personalized ranking, full‑text search, long‑form editorial, creator monetization, on‑device summarization.

### 4) Architecture Overview
- **Backend (Firebase Functions)**
  - `backend/functions/src/news/`
    - `ingest.ts`: connectors, fetch/normalize, dedupe, clustering, upsert events+articles.
    - `enrich.ts`: AI historical context, perspective generation, good/challenging classification, solutions draft.
    - `api.ts`: HTTP/callables for listing events, details, articles, user interactions.
    - `moderation.ts`: source allowlist, flags, retraction workflow.
  - Shared services reused:
    - `shared/{analytics.ts, audit.ts, idempotency.ts, metrics.ts, bigQueryExport.ts, rateLimit.ts}`
    - Debate fact‑check patterns from `debate/factCheckerWorker.ts` (adapted to news claims where feasible).
  - New shared:
    - `services/comments/` (see section 7) for reusable comments across features.
- **Data flow**
  1) Schedulers call `ingestNews` per connector → normalized articles.
  2) Dedupe + cluster into `newsEvents` (by title similarity + URL canonical + embeddings if available).
  3) `enrichNewsEvent` generates context, perspectives, solutions; stores citations/provenance.
  4) Clients fetch events list, then event detail + articles + perspectives, and attach comments.
- **Why backend‑first**: source keys, rate limits, clustering, AI costs, moderation, and security must be controlled server‑side. Clients only read preprocessed data and post comments via callables.

### 5) Data Model (Firestore‑first)
- `newsEvents/{eventId}`
  - `title`: string
  - `topicKey`: string (slug from clustering)
  - `clusterId`: string (from external API if provided; else internal hash)
  - `summary`: string (neutral, 3–6 sentences)
  - `historicalContext`: { text: string, citations: [{title, url}], generatedAt, model, confidence: number }
  - `perspectives`: [
    { id, label, axes: { geography?: string, ideology?: string, stakeholder?: string }, summary: string, citations: [{title, url}], confidence: number }
  ]
  - `goodness`: 'good' | 'challenging' | 'neutral'
  - `solutions`: [{ title: string, description: string, feasibility: string, citations: [{title,url}] }]
  - `impact`: { peopleAffected?: number, regions?: [string], domains?: [string] }
  - `tags`: [string]
  - `regions`: [string]
  - `languages`: [string]
  - `firstSeenAt`: timestamp
  - `lastUpdatedAt`: timestamp
  - `provenance`: { connectors: [string], method: 'llm_enrich_v1', safetyNotes?: string }
- `newsEvents/{eventId}/articles/{articleId}`
  - `sourceId`, `sourceName`, `author?`, `title`, `url`, `publishedAt`, `language?`, `country?`, `imageUrl?`
  - `summary?`, `biasLabels?`: [string] (when provided by connector)
  - `canonicalFingerprint`: string (URL/domain+title hash)
  - `dedupeGroup?`: string
- `newsEvents/{eventId}/comments/{commentId}` — via Comment Service schema (see section 7)
- Optional: `newsWatchers/{uid}` with topic/region preferences (phase 2 personalization)

Indexes (firestore.indexes):
- `newsEvents`: (lastUpdatedAt DESC), (goodness ASC, lastUpdatedAt DESC), (regions ARRAY_CONTAINS, lastUpdatedAt DESC), (tags ARRAY_CONTAINS, lastUpdatedAt DESC)
- `articles`: (eventId ASC, publishedAt DESC)

### 6) Connectors and Ingestion
- **Connector interface**
  ```ts
  export interface NewsConnector {
    name: string
    fetchBatch(params: FetchParams): Promise<NormalizedArticle[]> // normalized fields
    rateLimit?: { perMinute: number }
  }
  ```
- **Initial**: `NewsAPIConnector` (TopHeadlines, Everything) with source/domain filters; retries + backoff.
- **Planned**: `EventRegistryConnector` (event clusters), `GDELTConnector` (global events), `NewscatcherConnector`.
- **Dedupe**: canonical URL normalization + title MinHash; if available, use external `eventId`/`clusterId` from provider.
- **Clustering (internal fallback)**: Jaccard similarity on shingles + simple TF‑IDF/embedding cosine (phase 2) → assign `topicKey` and `clusterId`.
- **Scheduling**: Cloud Scheduler every 5–10 minutes per connector; stagger jobs; idempotency keys per batch window.

### 7) Reusable Comment Service (Cross‑Feature)
- **Goals**: Unified API and schema for comments, reactions, clustering/summaries, moderation, and rate limits across Debates, News, Marketplace, Home Services.
- **Backend location**: `backend/functions/src/services/comments/` with:
  - `comments.ts`: `submitComment`, `listComments`, `deleteOwnComment`, `setCommentReaction` (like/dislike), `summarizeComments` (cron or threshold), rate limit.
  - `rules_spec.md` and shared rules helpers.
- **Thread model**: comments live under the parent entity as a subcollection to keep data locality and rules simple.
  - Path convention: `/{parentCollection}/{parentId}/comments/{commentId}`.
  - Fields: `{ authorUid, authorName, text, createdAt, sentiment?, clusterId?, replyTo?, reactionCounts{like,dislike}, flags{spam,hate,offtopic}? }`.
  - Reactions per user under `comments/{commentId}/reactions/{uid}` with `{ value: 1|0|-1 }` (or like/dislike only for MVP).
- **Summaries/clusters**: background function computes opinion clusters and a brief summary (reuse pattern from `docs/debate/debate_feature_todo.md` and `submitComment` in debate backend), stored at parent level: `commentSummary: ClusterSummary[]`.
- **Security/limits**:
  - Auth required; length ≤ 2000; per‑user write quota (e.g., 10/min/thread) via `rateLimit.ts` counters.
  - Moderation hooks: bad‑word and link filters, AI moderation (phase 2), admin takedown.
- **iOS**: provide a small `CommentThreadView` and `CommentService` protocol used by News and Debates.

### 8) AI Enrichment Pipeline (Context + Perspectives)
- **Historical context**: neutral background and timeline with citations from ingested articles; avoid speculation; include what’s known/unknown.
- **Perspective taxonomy (configurable)**:
  - Axes: `geography` (e.g., Western, East Asia, MENA, Sub‑Saharan Africa, Global South), `ideology` (e.g., liberal, conservative, libertarian, social), `stakeholder` (e.g., government, industry, NGO, local community).
  - Start with 3–5 curated perspectives per event; expand dynamically if event warrants.
- **Generation**: Use neutral LLM (e.g., Grok) with strict system prompt:
  - Require balanced framing, state assumptions, highlight areas of agreement/disagreement, avoid stereotyping, cite sources.
  - Output JSON with `summary`, `axes`, `citations`, `confidence`.
- **Good vs Challenging**: classify via rules+LLM using article signals (keywords, tone), with human override. For Challenging items, generate a `solutions` list with feasibility.
- **Provenance**: store `model`, `version`, `promptHash`, `inputArticleIds`, and `citations[]` per output.
- **Fact‑checking**: adapt `factCheckerWorker` approach for key claims (phase 2) and label confidence; defer to human if low confidence.

### 9) APIs and Contracts (HTTP + Callable)
- Base path: `/news/*` (HTTP onRequest; authenticated where needed; public reads allowed for events/articles). Idempotency via header.
- Endpoints (MVP):
  - `GET /news/events?goodness=good|challenging|all&region=...&tag=...&limit=...&cursor=...`
    - Returns paginated `NewsEventSummary`.
  - `GET /news/events/:eventId`
    - Returns `NewsEventDetail` including `perspectives`, `historicalContext`, `solutions`.
  - `GET /news/events/:eventId/articles`
    - Returns paginated articles (deduped, newest first).
  - `POST /news/events/:eventId/comment` (auth)
    - Body: `{ text: string, replyTo?: string }` → `{ commentId }` (routes to Comment Service).
  - `POST /news/comments/:commentId/react` (auth)
    - Body: `{ value: 1 | 0 | -1 }`.
  - Admin (auth+role): `POST /news/events/:eventId/refresh`, `POST /news/events/:eventId/regenerate`.
- Schedulers:
  - `ingestNews` per connector (5–10 min), `dedupeAndCluster` (after ingest), `enrichEvents` (cron + on‑write), `summarizeComments` (threshold/cron), `cleanupOldArticles`.

### 10) Security Rules (Outline)
- `newsEvents` readable by all; writes server‑only.
- `articles` readable by all; writes server‑only.
- `comments` create/read for authed users; deletions: owner or admin; reactions: user owns own reaction doc.
- Use helpers similar to `docs/debate/security_rules.md` and extend with rate limiting via backend.

### 11) iOS Client (Swift Packages)
- Create:
  - `Packages/NewsService/`
    - `NewsService.swift` (protocol), `FirestoreNewsService.swift` (or Functions client), models.
  - `Packages/NewsFeature/`
    - Views: `NewsRootView` (segmented Good/Challenging), `EventListView`, `EventDetailView` with `PerspectiveTabs`, `HistoricalContextView`, `SolutionsView`, `ArticleListView`, `CommentThreadView` (reused component), `SettingsView` (perspective preferences).
    - ViewModels: `NewsFeedViewModel`, `EventDetailViewModel`, `CommentThreadViewModel` (shared).
- Navigation: add tile in `FeatureNavigationView` → `NewsRootView`.
- Strings: fr‑MA, ar‑MA (RTL), en fallback. Accessibility: Dynamic Type, VoiceOver, color contrast.

### 12) Analytics & Observability
- Events: `news_event_impression`, `news_event_opened`, `news_perspective_selected`, `news_context_expanded`, `news_solution_viewed`, `news_article_clicked`, `comment_posted`, `comment_reacted`.
- Reuse `shared/analytics.ts` + BigQuery export. Dashboards: coverage by region, goodness share, perspective interaction rate, citations density.

### 13) Moderation, Safety, and Ethics
- Comment moderation: banned words, link masking, rate limiting; AI moderation (phase 2). Report/flag flow with admin queue.
- AI outputs: bias and harm safeguards in prompts; avoid stereotyping groups; always cite; label uncertainties and limitations.
- Source curation: allowlist serious outlets initially; expand; expose provenance in UI.
- Retractions: if a story is retracted, mark event and show correction banner.

### 14) Infra, Keys, and Local Dev
- Secrets in Secret Manager: `NEWSAPI_KEY`, `EVENTREGISTRY_KEY?`, etc. Accessed via `shared/secretManager.ts`.
- Config via `remoteConfig`/env for connector toggles and rate limits.
- Local dev: emulator + stub connectors; seed script to create sample events.
- Repos/paths to create:
  ```text
  backend/functions/src/news/ingest.ts
  backend/functions/src/news/enrich.ts
  backend/functions/src/news/api.ts
  backend/functions/src/news/moderation.ts
  backend/functions/src/services/comments/comments.ts
  scripts/news/seed-news.js
  Packages/NewsService/
  Packages/NewsFeature/
  ```

### 15) Rollout Plan
- Phase 0: Internal sandbox with stubbed events; validate perspective taxonomy, UI flows, and citations.
- Phase 1 (MVP): NewsAPI connector + basic clustering; Good/Challenging tabs; 3+ perspectives; comments; Casablanca/Rabat locales.
- Phase 2: Add Event Registry clusters; improved clustering with embeddings; AI moderation; watchers/notifications; personalization.
- Phase 3: Deeper fact‑checking flows; quality ranking; cross‑feature comment unification complete; scale sources.

### 16) Testing Strategy
- Unit (backend): normalization, dedupe, clustering, enrichment formatting, rate limiting, security rules.
- Integration: emulators for ingest→cluster→enrich→API; comment flows with quotas.
- Load: ingestion bursts, perspective generation batching, comment spikes.
- iOS: snapshot tests for EventList/Detail, perspective tabs, comment composer; offline caching.

### 17) Open Questions
- Perspective taxonomy: initial set and labeling UX; do we let users configure prominence?
- Coverage balance: which regional outlets to prioritize initially? Allow user source controls?
- Good/Challenging labeling governance: editor overrides vs. automated; transparency.
- Fact‑checking scope and latency: which events/claims get checked automatically?
- Legal/compliance for article excerpts and thumbnails per source licensing.

---

### Appendix A — News Service Protocol (Sketch)
```swift
public protocol NewsServicing {
  func listEvents(filter: NewsFilter, cursor: String?) async throws -> (events: [NewsEventSummary], nextCursor: String?)
  func getEvent(id: String) async throws -> NewsEventDetail
  func listArticles(eventId: String, cursor: String?) async throws -> (articles: [NewsArticle], nextCursor: String?)
  // Comments (reused service)
  func postComment(eventId: String, text: String, replyTo: String?) async throws -> String
  func reactToComment(commentId: String, value: Int) async throws
}
```

### Appendix B — Firestore Collections (Sketch)
```text
newsEvents/{eventId}
  articles/{articleId}
  comments/{commentId}
```

### Appendix C — Perspective Output Schema (Sketch)
```json
{
  "id": "string",
  "label": "East Asia | Government",
  "axes": { "geography": "East Asia", "stakeholder": "Government" },
  "summary": "...",
  "citations": [{"title": "...", "url": "https://..."}],
  "confidence": 0.78
}
```











