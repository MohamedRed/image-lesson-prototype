# Production Test Suite

This repository now has a single production readiness gate for the Ride Sharing product path. It combines the deterministic backend, infrastructure, Android, and iOS checks that are required before treating a change as production-ready.

## CI workflow

Workflow: `.github/workflows/production-test-suite.yml`

It runs on:

- pushes to `main`, `develop`, and `codex/**`
- pull requests targeting `main`
- manual `workflow_dispatch`
- weekly scheduled drift checks

## Required lanes

| Lane | What it proves | CI command |
|---|---|---|
| Suite contract | The production suite cannot silently drop a critical lane/path trigger | `python3 scripts/verify-production-test-suite.py` |
| Planner | Go planner tests, deployable binary, and production container still build | `go test ./...`, `go build -o /tmp/rideplanner-build-check .`, `docker build -t rideplanner:test .` |
| Functions | Firebase planner/reservation seam remains aligned with reservation-critical IDs, retry behavior, gender/premium/curb/resource filters | `npm run test:ride-sharing`, `npm run typecheck:ride-sharing` |
| Terraform | Ride-sharing IaC source contracts, formatting, provider init, and validation | `python3 test_cloud_run_security.py`, `terraform fmt -check -recursive`, `terraform init -backend=false`, `terraform validate` |
| Android | Native visual parity check, unit tests, debug APK build, optional Appetize upload | `./android/ci/cloud-apk-build.sh` |
| iOS | Swift feature flow check and native snapshot render | `swift run --package-path Packages/RideSharingFeature ...` |

## Local usage

Default local command, suitable for Linux backend validation:

```bash
./ci/production-test-suite.sh
```

Optional strict lanes:

```bash
RUN_DOCKER=1 ./ci/production-test-suite.sh       # require local planner Docker build
RUN_TERRAFORM=1 ./ci/production-test-suite.sh    # require local Terraform validate even if terraform is absent
RUN_ANDROID=1 ./ci/production-test-suite.sh      # require Android SDK/JDK host validation
RUN_IOS=1 ./ci/production-test-suite.sh          # require macOS/Xcode Swift validation
```

Optional non-default checks:

```bash
RUN_FIRESTORE_RULES=1 ./ci/production-test-suite.sh  # requires Firestore emulator on 127.0.0.1:8080
RUN_FULL_FUNCTIONS=1 ./ci/production-test-suite.sh   # runs the legacy whole-functions Jest suite
```

## Current boundary

The production suite deliberately gates the Ride Sharing product path instead of the whole historical Firebase functions workspace. The full legacy functions suite is currently red because unrelated modules reference missing or incomplete sources/dependencies; use `RUN_FULL_FUNCTIONS=1` only when working that broader cleanup.

For Ride Sharing release confidence, use the required lanes above plus any human approval gates for deploys, merges to `main`, production data changes, secrets, billing, cloud, DNS, or outbound actions.
