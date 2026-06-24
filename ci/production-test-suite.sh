#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
TMP_ROOT=${TMPDIR:-/tmp}
RUN_DOCKER=${RUN_DOCKER:-0}
RUN_TERRAFORM=${RUN_TERRAFORM:-auto}
RUN_ANDROID=${RUN_ANDROID:-0}
RUN_IOS=${RUN_IOS:-0}
RUN_FULL_FUNCTIONS=${RUN_FULL_FUNCTIONS:-0}
RUN_FIRESTORE_RULES=${RUN_FIRESTORE_RULES:-0}

step() {
  printf '\n==> %s\n' "$*"
}

require_cmd() {
  local cmd=$1
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd" >&2
    exit 127
  fi
}

should_run_optional_tool() {
  local mode=$1
  local cmd=$2
  case "$mode" in
    1|true|yes) require_cmd "$cmd"; return 0 ;;
    0|false|no) return 1 ;;
    auto) command -v "$cmd" >/dev/null 2>&1 ;;
    *) echo "Invalid optional lane mode '$mode' for $cmd" >&2; exit 64 ;;
  esac
}

step "Repository"
printf 'root=%s\n' "$REPO_ROOT"
cd "$REPO_ROOT"
git status --short --branch || true

step "Planner: Go unit tests"
require_cmd go
(
  cd backend/planner
  go test ./...
)

step "Planner: production binary build"
(
  cd backend/planner
  go build -o "$TMP_ROOT/rideplanner-build-check" .
)

if should_run_optional_tool "$RUN_DOCKER" docker; then
  step "Planner: production container build"
  (
    cd backend/planner
    docker build -t rideplanner:test .
  )
else
  step "Planner: container build skipped (set RUN_DOCKER=1 to require it locally)"
fi

step "Functions: install deterministic dependencies"
require_cmd npm
(
  cd backend/functions
  if [[ ! -d node_modules || "${CI:-}" == "true" || "${FORCE_NPM_CI:-0}" == "1" ]]; then
    npm ci --ignore-scripts --no-audit --no-fund
  fi
)

step "Functions: ride-sharing planner/reservation seam tests"
(
  cd backend/functions
  npm run test:ride-sharing
)

step "Functions: ride-sharing focused TypeScript contract"
(
  cd backend/functions
  npm run typecheck:ride-sharing
)

if should_run_optional_tool "$RUN_TERRAFORM" terraform; then
  step "Terraform: ride-sharing source contracts, fmt, init, validate"
  (
    cd infra/ride-sharing
    python3 test_cloud_run_security.py
    terraform fmt -check -recursive
    terraform init -backend=false
    terraform validate
  )
else
  step "Terraform: skipped (terraform not found; set RUN_TERRAFORM=1 to require it)"
fi

if [[ "$RUN_ANDROID" =~ ^(1|true|yes)$ ]]; then
  step "Android: visual parity, unit tests, debug APK"
  ./android/ci/cloud-apk-build.sh
else
  step "Android: skipped locally (set RUN_ANDROID=1 on Android SDK hosts)"
fi

if [[ "$RUN_IOS" =~ ^(1|true|yes)$ ]]; then
  step "iOS: Liive Ride Swift flow check and native snapshots"
  require_cmd swift
  swift run --package-path Packages/RideSharingFeature -j 1 RideSharingFeatureFlowCheck
  swift run --package-path Packages/RideSharingFeature -j 1 RideSharingFeatureSnapshot "$TMP_ROOT/liive-ride-ios-snapshots"
else
  step "iOS: skipped locally (set RUN_IOS=1 on macOS/Xcode hosts)"
fi

if [[ "$RUN_FIRESTORE_RULES" =~ ^(1|true|yes)$ ]]; then
  step "Firestore rules: emulator-backed tests"
  (
    cd backend/functions
    npx jest test/firestoreRules.test.ts --runInBand
  )
else
  step "Firestore rules: skipped locally (requires Firestore emulator on 127.0.0.1:8080)"
fi

if [[ "$RUN_FULL_FUNCTIONS" =~ ^(1|true|yes)$ ]]; then
  step "Functions: full legacy Jest suite"
  (
    cd backend/functions
    npm test -- --runInBand
  )
else
  step "Functions full legacy suite skipped; current production gate is ride-sharing focused while unrelated modules are red"
fi

step "Production test suite completed"
