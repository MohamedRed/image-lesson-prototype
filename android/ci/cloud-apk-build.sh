#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd -P)
ANDROID_PROJECT="$REPO_ROOT/android"
WRAPPER="$ANDROID_PROJECT/gradlew"

ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [[ -z "$ANDROID_SDK_ROOT" ]]; then
  echo "ANDROID_SDK_ROOT or ANDROID_HOME must point to an Android SDK" >&2
  exit 2
fi

export ANDROID_SDK_ROOT
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

if [[ ! -x "$WRAPPER" ]]; then
  echo "Missing executable Gradle wrapper at $WRAPPER" >&2
  exit 2
fi

if ! command -v sdkmanager >/dev/null 2>&1; then
  echo "sdkmanager was not found under $ANDROID_HOME/cmdline-tools/latest/bin" >&2
  exit 2
fi

printf 'sdk.dir=%s\n' "$ANDROID_HOME" > "$ANDROID_PROJECT/local.properties"

set +o pipefail
yes | sdkmanager --licenses >/dev/null
license_status=${PIPESTATUS[1]}
set -o pipefail
if (( license_status != 0 )); then
  echo "Android SDK license acceptance failed" >&2
  exit "$license_status"
fi

sdkmanager \
  "platform-tools" \
  "platforms;android-36" \
  "build-tools;35.0.0" \
  "build-tools;36.0.0"

COMMON_GRADLE_ARGS=(
  -p "$ANDROID_PROJECT"
  --no-daemon
  --no-configuration-cache
  --console=plain
  --stacktrace
)

python3 "$SCRIPT_DIR/visual-parity-check.py"
"$WRAPPER" "${COMMON_GRADLE_ARGS[@]}" :app:testDebugUnitTest
"$WRAPPER" "${COMMON_GRADLE_ARGS[@]}" :app:assembleDebug

shopt -s nullglob
apks=("$ANDROID_PROJECT"/app/build/outputs/apk/debug/*.apk)
if (( ${#apks[@]} == 0 )); then
  echo "assembleDebug completed but no debug APK was found" >&2
  exit 3
fi

printf 'Built debug APK artifacts:\n'
for apk in "${apks[@]}"; do
  ls -lh "$apk"
done
