## AI Tutor — KnowledgeQuest Framework: Full Implementation Plan

### One‑line
Fully playable, historically grounded 3D quests that teach any subject by putting the learner in the founder’s shoes. Episodes are data‑driven, cite sources, and run inside the iOS app via Unity.

### Goals
- Deliver a domain‑agnostic, reusable framework for “learn by doing” quests.
- Maintain historical fidelity: canon first, contested/unknown labeled, citations on demand.
- Provide plug‑in mechanics (debate, command, experiment, policy, trial, fieldwork) that compose per episode.
- Ship a vertical slice in full 3D with Unity as a Library integrated into the iOS app.
- Capture learning analytics and generate spaced‑repetition “insight cards.”

### Non‑goals
- Creating a generic shooter. Violence is toned and abstracted; focus is on leadership, reasoning, ethics, and trade‑offs.
- Freeform sandbox without constraints. A constraint engine enforces era‑appropriate limits.
- Inventing alternate histories in the canonical run. “What‑if” is optional and clearly labeled after completing canon.

---

## Architecture Overview

### High‑level components
- Unity Client (iOS): 3D runtime, mechanics, UI, save system.
- Content Service (Firebase): Episode JSON + asset bundles delivery, versioning.
- Truth & Retrieval (RAG): Curated corpora per episode, vector search, citation enforcement.
- Constraint Engine: Rules that bound mechanics by era tech, costs, law, norms.
- Assessment & Insights: Competency mapping, reflection, spaced‑repetition items.
- Telemetry & Analytics: Client events → Firebase → BigQuery; dashboards for learning and fun.
- Admin Console: Author episodes, attach sources, validate, and publish.

### Data flow
1) App fetches the Episode manifest (JSON) → downloads Unity Addressables bundles.
2) Player interacts with mechanics; NPC dialog queries RAG middleware with retrieval‑only corpora.
3) Constraint Engine validates choices and drives deterministic effects.
4) Outcomes logged; Assessment produces insight cards; state saved to Firestore.
5) Telemetry exported to BigQuery; dashboards track engagement and learning.

---

## Integration With Existing Stack (explicit mapping)

### Reuse and alignment with repo structure
- Backend functions live under `backend/functions/src/ai-tutor/` following the feature-folder pattern used by `ride-sharing/`, `marketplace/`, `home-services/`.
- Shared utilities reused:
  - `backend/functions/src/shared/analytics.ts`: emit `aiTutor.*` events (extend the existing event map, reuse BigQuery export path).
  - `backend/functions/src/shared/audit.ts`: audit admin publishing actions and content edits.
  - `backend/functions/src/shared/bigQueryExport.ts`: piggyback export settings; no new pipeline.
  - `backend/functions/src/services/notifications/*`: optional push reminders for spaced‑repetition insight cards.
  - Follow existing testing conventions in `backend/functions/test/*` with `aiTutor/*.test.ts`.
- New service module placement (consistent with `services/*` pattern):
  - `backend/functions/src/services/rag/`: vector index adapter, retrieval+citation enforcement.
  - `backend/functions/src/services/content/`: signed URL generation for Addressables, manifest versioning helpers.

### API surface (Functions) and where code lives
- `backend/functions/src/ai-tutor/index.ts` exports HTTPS/callable handlers:
  - `listEpisodesHttp` (HTTPS): list published episodes; reads from `aiTutorEpisodes/*`.
  - `getEpisodeConfigHttp` (HTTPS): return manifest JSON and signed bundle URLs.
  - `ragQueryHttp` (HTTPS): retrieval‑only NPC dialogue; requires episode/npc scope; cites sources.
  - `validateEpisodeCallable` (Callable, admin): run validators on drafts.
  - `logTelemetryHttp` (HTTPS): batch ingest gameplay/learning events.
- Wire up in `backend/functions/firebase.json` as needed; reuse project‑level `firebase.json` routing if present.

### Data model and security rules reuse
- Firestore collections (extend existing rules files `firestore.rules` / `backend/functions/firestore.rules`):
  - `aiTutorEpisodes/{episodeId}`: read if `published == true`; write restricted to admins.
  - `aiTutorSaves/{userId}/{slot}`: read/write only by `request.auth.uid == userId`.
  - `aiTutorTelemetry/{dateShard}/{sessionId}`: write by service account/functions only.
- Keep validation server‑side (publish flow), not in Unity.

### Admin console alignment
- Extend `admin-console/` with `ai-tutor/` views:
  - Use `admin-console/shared/auth.js` and `shared/components/nav.js` for auth/nav.
  - Pages: episode list, editor (JSON + assets), validator results, publish.
  - Upload to Cloud Storage via signed URLs provided by `content` service.

### iOS app integration
- Unity embedded as Library inside the existing iOS workspace; exposed via a new SwiftUI screen under the Home dashboard.
- No reuse of image lesson prototype code; clean module and bridge (`EpisodeRunnerView`) for AI Tutor only.

---

## Unity Client (iOS) — Systems

### Engine & integration
- Unity 2022/2023 LTS with URP and Addressables.
- Build Unity as a Library; embed into the iOS app (SwiftUI host) using `UnityFramework`.
- Bi‑directional bridge:
  - iOS → Unity: start/stop mission, pass user/session, deep links.
  - Unity → iOS: open external UI (profile, purchases), background downloads, auth tokens.
- Scene management: boot scene → main menu → EpisodeRunner loads per‑episode Addressables.

### Core subsystems
- Episode Runner: Loads Episode JSON, mounts environments, wires mechanics and UI overlays.
- Mechanics Orchestrator: Registers mechanics modules and their inputs/outputs; exposes events.
- Dialogue & Debate System:
  - UI: claim slots, evidence cards, counterarguments, citations on tap.
  - Backend integration: RAG middleware returns candidate claims with sources and confidence; client enforces “no‑source, no‑claim.”
- Command Map:
  - Layers: logistics, morale, reputation, sanctity/safety.
  - Actions: allocate resources, issue conduct rules, negotiate ceasefires.
- Experiment/Builder:
  - Parameterized mini‑simulations (e.g., epidemiology sampling, printing press setup, lab tuning).
  - Deterministic and auditable; exposes results and uncertainties.
- Policy Board:
  - Sliders/choices (e.g., tax rates, site protections) bounded by constraints; transparent trade‑offs.
- Courtroom/Trial:
  - Turn‑based procedures, objections, precedence/evidence decks.
- Fieldwork/Map:
  - Waypoint tasks, interviews, sampling; risk and time costs.
- Evidence Board:
  - Pin artifacts, contradictions, unknowns; link to claims and NPC stances.
- Insight & Reflection:
  - End‑scene reflection yields insight cards mapped to learning objectives; cards feed spaced repetition later.

### UI & UX
- Third‑person camera with contextual overlays (command stats, objectives, citations).
- Canon vs What‑if mode indicators; speculative/contested labels on UI elements.
- Accessibility: scalable fonts, color‑safe palettes, reduced‑violence mode.

### Performance targets (iPhone 13+)
- 60 FPS target (fallback 30 FPS), URP medium tier.
- 400–600 MB runtime memory budget for Unity content; async streaming for large sets.
- LODs + occlusion culling; mobile‑friendly shaders; texture atlasing.

---

## Backend & Services (Firebase + GCP)

### Storage & delivery
- Cloud Storage: `gs://content/ai-tutor/{episodeId}/` for Addressables bundles, media, and references.
- Firestore:
  - `aiTutorEpisodes/{episodeId}`: metadata, versions, publishing state.
  - `aiTutorSaves/{userId}/{slot}`: save data, progress, insight cards.
- CDN: Firebase Hosting or Cloud CDN for fast asset delivery.

### Cloud Functions (TypeScript)
- `listEpisodes()` HTTPS: list public episodes with versions and sizes.
- `getEpisodeConfig(episodeId)` HTTPS: return JSON manifest signed URLs for bundles.
- `ragQuery(episodeId, npcId, prompt, context)` HTTPS: retrieval‑only chat with citations.
- `validateEpisode(episodeId)` Admin callable: run static checks (missing citations, broken references, constraint violations).
- `logTelemetry(events[])` HTTPS: batch ingest client events with schema validation.

### Retrieval‑Augmented Generation (RAG)
- Curated corpus per episode: primary sources, reputable scholarship; stored in Storage.
- Embedding + vector index: Vertex AI Matching Engine or a managed vector store.
- Middleware:
  - Strict retrieval mode: answers constrained to retrieved chunks; source links mandatory.
  - Refusal policy: reply with “unknown/contested” when evidence sparse or conflicting.
  - Claim scoring: confidence and source tier weighting; surfaced to client UI.

### Analytics
- Client events → Functions → BigQuery.
- Dashboards (Looker Studio): completion, time‑in‑scene, hint usage, debate quality, retention.

---

## Backend vs Frontend Responsibilities (clear split)

### Backend (do here)
- RAG retrieval, claim generation, source citation enforcement, and confidence scoring.
- Episode manifest delivery and Cloud Storage signed URL generation.
- Content validation (missing citations, broken references, rule conflicts) and publish workflow.
- Telemetry ingestion, aggregation, and export to BigQuery.
- Security rules and access control for saves, episodes, and telemetry.
- Optional spaced‑repetition scheduling via notifications.

### Frontend (Unity client; do NOT do here)
- No direct LLM calls and no raw retrieval; only consumes backend‑validated, cited responses.
- No direct access to buckets; only uses signed URLs and manifests from backend.
- Presentation, local input handling, moment‑to‑moment simulation bounded by downloaded rules.
- Client‑side constraint checks for responsiveness; results re‑validated server‑side on critical submissions.

---

## Content Model (Data‑Driven Episodes)

### Episode JSON (v1)
```json
{
  "id": "string",
  "title": "string",
  "domain": "history|science|philosophy|art|law|other",
  "era": "string",
  "summary": "string",
  "learning_objectives": ["reason_about_evidence", "tradeoff_analysis"],
  "constraints": ["tech_limit", "law", "resource_scarcity"],
  "mechanics": ["debate_mode", "command_map", "experiment_builder"],
  "artifacts": [
    { "id": "a1", "type": "primary_source", "title": "string", "uri": "gs://...", "citation": "string" }
  ],
  "npcs": [
    { "id": "patriarch", "persona": "skeptical", "knowledge_base": ["a1"], "allowed_topics": ["terms", "sanctity"] }
  ],
  "scenes": [
    {
      "id": "negotiation_hall",
      "environment": "assetBundle://levante/hall_v1",
      "goals": ["agree_terms", "maintain_trust"],
      "beats": [
        { "id": "opening", "mechanic": "debate_mode", "evidence": ["a1"] },
        { "id": "terms", "mechanic": "policy_board", "sliders": ["tax_rate", "site_protection"] }
      ],
      "fail_states": ["breach_of_terms", "riot"]
    }
  ],
  "decisions": [
    { "id": "worship_precedent", "options": ["A", "B"], "effects": { "reputation": "+10", "precedent": "strict" } }
  ],
  "canon": [
    { "claim": "keys_accepted_from_city", "source": "al-Tabari", "confidence": 0.9 }
  ],
  "contested": [
    { "claim": "location_of_prayer", "sources": ["A", "B"], "confidence": 0.5 }
  ],
  "assessment": {
    "rubrics": ["evidence_use", "ethical_consideration", "constraint_respect"],
    "insight_cards": ["principle_of_sanctity", "conduct_under_power"]
  },
  "version": 1
}
```

### Constraint Engine (rulesets)
- Declarative rules per episode, e.g., max troop numbers, allowed tech, legal/religious bounds.
- Checked client‑side for fast feedback; re‑validated server‑side for integrity.
- Violations: blocked or labeled as what‑if (if enabled post‑canon).

### Truth & Citation Model
- Source tiers: primary > peer‑reviewed > reputable encyclopedia.
- Every significant claim references one or more sources; confidence displayed.
- NPC dialog limited to the episode’s corpus; unknown/contested allowed and labeled.

### Assessment Model
- Map decisions and performance into competencies (e.g., evidence use, trade‑off reasoning, ethical consideration).
- Generate insight cards (short prompts) for spaced repetition outside the mission.

---

## Admin & Authoring

### Web Admin (extend existing admin console)
- Create/edit episodes, upload artifacts, attach citations, define constraints and scenes.
- Validator suite: missing citations, orphan assets, broken links, rule conflicts.
- Draft → Review → Publish workflow; versioning with rollback.

### Content pipeline
- Unity Addressables for environments, props, characters; Cloud Storage buckets by episode/version.
- Naming: `episodes/{id}/v{n}/bundles/*`, `episodes/{id}/v{n}/manifest.json`, `episodes/{id}/v{n}/sources/*`.
- Localization‑ready text assets.

---

## iOS Integration (Unity as a Library)

### Steps
1) Create a Unity project (URP, iOS platform) and set Addressables.
2) Implement the Episode Runner and at least two mechanics (Debate, Command).
3) Build iOS as a Library (UnityFramework). Import into the Xcode workspace.
4) Add a SwiftUI wrapper that presents/dismisses the Unity view.
5) Bridge methods: startMission(episodeId), pause/resume, save/quit.
6) Handle background downloads and authentication token passing.

### Bridge contract (high‑level)
```text
iOS -> Unity:
  initialize(sessionToken, userId)
  startMission(episodeId)
  pause(), resume()
  requestSave(slot)

Unity -> iOS:
  missionCompleted(resultSummary)
  requestRagQuery(npcId, prompt)
  openExternalUrl(url)
  logEvents(batch)
```

---

## Security, Safety, and Ethics
- Strict source curation; retrieval to a whitelisted corpus only.
- Sensitive topics reviewed by human editors; multi‑viewpoint summaries.
- On‑device parental controls: reduced‑violence mode default for children.
- Privacy: minimal PII; COPPA/GDPR compliant; per‑feature data retention policy.

---

## Testing & QA
- Unit tests for mechanics; simulation determinism tests for the constraint engine.
- Golden tests for dialogue given fixed retrieval chunks.
- Playtest protocol: completion rate, average time, hint usage, fun rating, next‑day retention quiz.
- Performance profiling: memory, FPS, load times, shader variants.

---

## Roadmap & Milestones

### Phase 0 — Spike (1–2 weeks)
- Unity as a Library prototype; bidirectional bridge; Hello world Episode JSON load.
- RAG middleware stub with hardcoded citations.

### Phase 1 — Vertical Slice (4–6 weeks)
- Mechanics: Debate Mode + Command Map complete.
- One environment (approach + gate/courtyard) + negotiation chamber.
- Episode: “Omar enters Jerusalem — Entry & Covenant” 20–25 min.
- Citations on tap; canon/contested labels; one fail state.
- Telemetry to BigQuery; baseline dashboards.

### Phase 2 — Alpha (6–8 weeks)
- Add Fieldwork/Map or Policy Board; save/resume; localization scaffolding.
- Second episode in a different domain (e.g., John Snow’s Broad Street pump).
- Admin validator and publish flow.

### Phase 3 — Beta (8–12 weeks)
- Third episode (e.g., Socrates’ trial) to validate generality.
- Accessibility polish; device matrix performance passes; what‑if unlocks.
- Analytics‑driven tuning; spaced repetition companion flow.

---

## Acceptance Criteria (Vertical Slice)
- Unity mission launches from the iOS app and returns control on completion.
- Two mechanics (Debate + Command) working with constraint‑bounded effects.
- Episode content loaded from JSON + Addressables; citations visible and clickable.
- Canonical outcome achievable; at least one clearly labeled contested element.
- Telemetry emitted and visible in dashboards; insight cards generated post‑mission.
- 30–60 FPS on target devices; memory within budget; no major crashes in 30‑minute playtests.

---

## Example Episodes (for generality)
- History/Leadership: Omar enters Jerusalem (entry, covenant, governance).
- Public Health: John Snow and the Broad Street pump (field data vs doctrine).
- Philosophy: Trial of Socrates (argumentation under civic scrutiny).
- Technology: Gutenberg’s press (materials, business model, censorship).
- Art: Salon des Refusés (patronage vs innovation).

---

## Open Decisions
- Vector store choice (Vertex AI Matching Engine vs managed third‑party).
- Voice acting scope in the vertical slice (TTS vs recorded).
- Device baseline (iPhone 12/13+); quality tiers and dynamic resolution.

---

## Appendices

### A) Telemetry Event Schema (outline)
```json
{
  "session_id": "uuid",
  "user_id": "anon_or_hash",
  "episode_id": "string",
  "events": [
    { "t": 0.0, "type": "scene_enter", "scene": "entry" },
    { "t": 12.4, "type": "debate_claim", "claim_id": "c42", "sources": ["a1","a3"] },
    { "t": 130.1, "type": "decision", "id": "worship_precedent", "choice": "A" },
    { "t": 820.5, "type": "mission_complete", "score": 0.78 }
  ]
}
```

### B) Firestore Layout (outline)
```text
aiTutorEpisodes/{episodeId}
  - version, title, domain, era, published, bundles[], sources[]
aiTutorSaves/{userId}/{slot}
  - episodeId, checkpoint, inventory, insightCards[], lastPlayedAt
aiTutorTelemetry/{dateShard}/{sessionId}
  - summary, aggregates
```

### C) Unity Addressables Conventions
- Groups per episode and per shared assets; separate scenes, characters, props.
- Use labels: `env`, `npc`, `ui`, `audio`, `shared`.
- Include content hash in bundle names; manifest stored alongside.

### D) Content Quality & Sourcing Guidelines
- Cite primary sources when available; otherwise peer‑reviewed secondary sources.
- Label contested or unknown claims with confidence and cite both sides.
- Be respectful on sensitive topics; use advisory reviewers.

---

Prepared for implementation in the iOS app with Unity as a Library, Firebase backend, and an extensible, citation‑driven content model designed to support any knowledge domain.


