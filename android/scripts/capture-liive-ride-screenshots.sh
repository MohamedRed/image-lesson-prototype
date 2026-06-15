#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Capture Liive Ride Android screenshots from a connected emulator/device.

Usage:
  android/scripts/capture-liive-ride-screenshots.sh [--serial SERIAL] [--out DIR] [--skip-build]

Environment:
  ADB      adb binary to use. Defaults to adb on PATH.
  GRADLE   gradle binary to use. Defaults to gradle on PATH.

The script installs the debug app by default, clears app state, drives:
destination -> options -> pool matching -> enroute -> complete, and writes PNGs.
USAGE
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ADB="${ADB:-adb}"
GRADLE="${GRADLE:-gradle}"
PACKAGE="com.liive.ride"
ACTIVITY="com.liive.ride/.MainActivity"
OUT_DIR="${TMPDIR:-/tmp}/liive-ride-screenshots"
SERIAL="${ANDROID_SERIAL:-}"
SKIP_BUILD=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --serial)
      SERIAL="$2"
      shift 2
      ;;
    --out)
      OUT_DIR="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

pick_serial() {
  if [[ -n "$SERIAL" ]]; then
    echo "$SERIAL"
    return
  fi
  "$ADB" devices | awk '/\tdevice$/ { print $1; exit }'
}

SERIAL="$(pick_serial)"
if [[ -z "$SERIAL" ]]; then
  echo "No connected Android device found. Start an emulator or pass --serial." >&2
  exit 1
fi

adb_device() {
  "$ADB" -s "$SERIAL" "$@"
}

wait_for_boot() {
  adb_device wait-for-device
  for _ in {1..90}; do
    if [[ "$(adb_device shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; then
      return
    fi
    sleep 2
  done
  echo "Timed out waiting for Android boot completion on $SERIAL." >&2
  exit 1
}

capture() {
  local name="$1"
  mkdir -p "$OUT_DIR"
  adb_device exec-out screencap -p > "$OUT_DIR/$name.png"
  echo "captured $OUT_DIR/$name.png"
}

tap_text() {
  local needle="$1"
  local dump="$OUT_DIR/ui.xml"
  adb_device exec-out uiautomator dump /dev/tty > "$dump"
  local xy
  xy="$(python3 - "$dump" "$needle" <<'PY'
import re
import sys
import xml.etree.ElementTree as ET

path, needle = sys.argv[1], sys.argv[2].lower()
root = ET.parse(path).getroot()
for node in root.iter("node"):
    haystacks = [
        node.attrib.get("text", ""),
        node.attrib.get("content-desc", ""),
    ]
    if any(needle in value.lower() for value in haystacks):
        match = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.attrib.get("bounds", ""))
        if match:
            x1, y1, x2, y2 = map(int, match.groups())
            print(f"{(x1 + x2) // 2} {(y1 + y2) // 2}")
            sys.exit(0)
print("")
PY
)"
  if [[ -z "$xy" ]]; then
    echo "Could not find tappable text/content-desc containing '$needle'." >&2
    exit 1
  fi
  adb_device shell input tap $xy
}

wait_for_boot

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  (cd "$ANDROID_DIR" && "$GRADLE" :app:installDebug --no-daemon --console=plain)
fi

adb_device shell pm clear "$PACKAGE" >/dev/null
adb_device shell am start -n "$ACTIVITY" >/dev/null
sleep 2
capture "01-destination"

tap_text "Union Square"
sleep 1
capture "02-options-premium"

tap_text "Pool"
sleep 1
capture "03-options-pool"

tap_text "Confirm Pickup"
sleep 1
capture "04-matching"

sleep 4
capture "05-enroute"

sleep 12
capture "06-complete"

echo "Liive Ride Android screenshots written to $OUT_DIR"
