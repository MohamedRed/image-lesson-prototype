#!/usr/bin/env python3
"""Source-level contract for the production test suite wiring.

This intentionally uses only the Python standard library so it can run before
Node, Go, Terraform, Android, or Xcode toolchains are installed.
"""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github" / "workflows" / "production-test-suite.yml"
LOCAL_SUITE = ROOT / "ci" / "production-test-suite.sh"
DOC = ROOT / "docs" / "production-test-suite.md"
FUNCTIONS_PACKAGE = ROOT / "backend" / "functions" / "package.json"

checks = []


def require_file(path: Path) -> str:
    if not path.exists():
        checks.append((False, f"missing file: {path.relative_to(ROOT)}"))
        return ""
    text = path.read_text(encoding="utf-8")
    checks.append((True, f"found {path.relative_to(ROOT)}"))
    return text


def require(text: str, needle: str, label: str) -> None:
    checks.append((needle in text, label))


workflow = require_file(WORKFLOW)
local_suite = require_file(LOCAL_SUITE)
doc = require_file(DOC)
package_json = require_file(FUNCTIONS_PACKAGE)

for job in [
    "suite-contract",
    "planner",
    "functions",
    "terraform",
    "android",
    "ios",
]:
    require(workflow, f"  {job}:", f"workflow contains required job '{job}'")

for command, label in [
    ("python3 scripts/verify-production-test-suite.py", "workflow runs suite contract"),
    ("go test ./...", "workflow runs planner Go tests"),
    ("go build -o /tmp/rideplanner-build-check .", "workflow builds planner binary"),
    ("docker build -t rideplanner:test .", "workflow builds planner container"),
    ("npm run test:ride-sharing", "workflow runs ride-sharing seam tests"),
    ("npm run typecheck:ride-sharing", "workflow typechecks ride-sharing seam"),
    ("terraform fmt -check -recursive", "workflow checks Terraform formatting"),
    ("terraform init -backend=false", "workflow initializes Terraform without backend"),
    ("terraform validate", "workflow validates Terraform"),
    ("./android/ci/cloud-apk-build.sh", "workflow builds Android debug APK"),
    ("swift run --package-path Packages/RideSharingFeature", "workflow runs Swift package checks"),
]:
    require(workflow, command, label)

for path_glob in [
    "backend/planner/**",
    "backend/functions/src/ride-sharing/**",
    "backend/functions/test/ridePlannerClient.test.ts",
    "backend/functions/test/reserveResourcesTx.test.ts",
    "infra/ride-sharing/**",
    "android/**",
    "Packages/RideSharingFeature/**",
    "Liive Ride Design System/**",
    "ci/production-test-suite.sh",
    "scripts/verify-production-test-suite.py",
]:
    require(workflow, path_glob, f"workflow path trigger covers {path_glob}")

for local_command in [
    "go test ./...",
    "go build -o \"$TMP_ROOT/rideplanner-build-check\" .",
    "npm run test:ride-sharing",
    "npm run typecheck:ride-sharing",
    "terraform validate",
    "./android/ci/cloud-apk-build.sh",
    "swift run --package-path Packages/RideSharingFeature",
]:
    require(local_suite, local_command, f"local suite contains {local_command}")

for script in ["test:ride-sharing", "typecheck:ride-sharing"]:
    require(package_json, f'"{script}"', f"functions package exposes {script}")

for doc_phrase in [
    "Production Test Suite",
    "Planner",
    "Functions",
    "Terraform",
    "Android",
    "iOS",
    "RUN_DOCKER=1",
    "RUN_ANDROID=1",
    "RUN_IOS=1",
]:
    require(doc, doc_phrase, f"docs mention {doc_phrase}")

failed = [label for ok, label in checks if not ok]
for ok, label in checks:
    print(("PASS" if ok else "FAIL") + f": {label}")

if failed:
    print("\nProduction test suite contract failed:", file=sys.stderr)
    for label in failed:
        print(f"- {label}", file=sys.stderr)
    sys.exit(1)

print("\nProduction test suite contract passed.")
