# Debate App – Implementation README (for code generation)

Follow these placement and naming rules. This app coexists with other apps in a super-app monorepo.

## Targets & Placement
- iOS: create/modify `Packages/DebateFeature` only. Do not touch RideSharing packages.
- Web: create `apps/web/debate` (Next.js). Shared web components go under `apps/web/shared` or `packages/web-ui`.
- Backend: add new code under `backend/functions/src/debate/` and `backend/functions/src/shared/` for common utilities.
- Infra: put debate-specific resources under `infra/apps/debate/`.
- Docs: keep all debate docs in `docs/debate/`.

## Dependencies
- iOS: LiveKit iOS SDK, Firebase iOS SDK.
- Web: Next.js, Firebase Web SDK, LiveKit JS SDK, `hls.js`, shadcn/ui + Tailwind.
- Backend: Firebase Admin SDK, LiveKit Server SDK (for token/egress), Stripe, Pub/Sub, BigQuery.

## Must-read Specs
- Firestore schema: `docs/debate/firestore_schema.md`
- API contracts: `docs/debate/api_contracts.md`
- LiveKit Cloud config: `docs/debate/livekit_cloud_config.md`
- CDN auth: `docs/debate/cdn_auth_spec.md`
- Web UI contracts: `docs/debate/ui_components_web.md`
- Security rules: `docs/debate/security_rules.md`
- Observability & SLOs: `docs/debate/observability_slos.md`

## Conventions
- Prefix services and topics with `debate-` (e.g., `debate-summarizer`).
- Firestore collection paths must match the schema; avoid creating new top-level collections.
- Keep files ≤ 100 lines; split modules when needed (ViewModel, View, Service, Types).

## Done Criteria
- Unit tests for all functions (Jest) and core ViewModels (iOS/web).
- Lint passes and no new warnings.
- Dashboards/alerts created as per observability doc.
- Security rules updated and verified with emulator tests.

## Notes
- Live spectators watch via HLS; do not attempt to join WebRTC room on web unless on-stage.
- For performance, batch Firestore writes via Pub/Sub consumers where indicated.