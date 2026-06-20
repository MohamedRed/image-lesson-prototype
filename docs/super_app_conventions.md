# Super App Conventions (Monorepo)

This repository hosts multiple apps (features) sharing infra and libraries. Use these conventions to add new apps cleanly.

## Top-level Layout
- apps/
  - web/
    - debate/ (Next.js web client for Debate)
    - ride-sharing/ (Next.js web client for Ride Sharing) [future]
  - ios/
    - DebateFeature (SPM package)
    - RideSharingFeature (SPM package)
- backend/
  - functions/
    - src/
      - debate/ (debate-specific functions)
      - rides/ (ride-sharing-specific functions)
      - shared/ (auth utils, types, tracing)
  - services/ (optional long-running workers)
- infra/
  - apps/
    - debate/ (debate-specific TF or Helm overlays)
    - ride-sharing/
  - modules/ (shared TF modules)
  - environments/ (dev/staging/prod)
- docs/
  - debate/ (debate specs)
  - ride-sharing/
  - super_app_conventions.md (this file)

## Naming
- Cloud resources prefixed by app: debate-*, rides-* (e.g., `debate-egress`, `rides-api`).
- Firestore collections namespaced: `debates/*`, `rides/*`, `watchParties/*` (generic) vs app-specific.
- LiveKit rooms: `debate_{debateId}`; tokens scoped per room.
- Cloud Run/Functions services: `debate-<service>`, `rides-<service>`.

## iOS
- Each app is an independent Swift Package under `Packages/` with `Feature` suffix.
- Shared iOS utilities belong in a `Packages/SharedKit` package.
- App-entry targets import features as needed (super-app shell selects feature).

## Web
- Next.js apps under `apps/web/<app>` with shared UI in `apps/web/shared` or `packages/web-ui`.
- Use shadcn/ui + Tailwind; keep components generic in shared when feasible.

## Backend
- Functions grouped under `backend/functions/src/<app>`.
- Shared utilities under `backend/functions/src/shared` (auth, firestore helpers, tracing).
- Pub/Sub topics and schedulers namespaced per app (e.g., `debate-summarizer`).

## Infrastructure
- Terraform state and variables per environment.
- App overlays: `infra/apps/<app>` include only app-specific resources (secrets, schedulers, Cloud Run services).

## Configuration
- Env files per app:
  - `docs/debate/env_and_secrets.md` (truth)
  - `.env.debate.local` for local dev (not committed)
- Feature flags per app in Remote Config or a config collection `config/<app>`.

## Code Ownership
- CODEOWNERS can map `/backend/functions/src/debate/*` to debate team leads.

## Acceptance
- No file > 100 lines without deliberate modularization.
- New app must provide: docs/ (schema, APIs), infra overlays, CI targets, and security rules deltas.