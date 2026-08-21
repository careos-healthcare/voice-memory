#!/bin/bash
# Belief-first onboarding — captures onboarding-1.png … onboarding-5.png
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_ROOT="${HOME}/Desktop/upload12"
API_BASE_URL="${SCREENSHOT_API_BASE_URL:-https://voice-memory-iota.vercel.app}"

mkdir -p "${OUTPUT_ROOT}/screenshots"

cd "$APP_DIR"

pick_device() {
  if [ -n "${UI_SCREENSHOT_DEVICE_ID:-}" ]; then
    echo "$UI_SCREENSHOT_DEVICE_ID"
    return
  fi
  if flutter devices 2>/dev/null | grep -q 'macos'; then
    echo "macos"
    return
  fi
  flutter devices 2>/dev/null | awk '/iPhone|android/ {print $4; exit}'
}

DEVICE_ID="$(pick_device)"
if [ -z "${DEVICE_ID:-}" ]; then
  echo "No device found."
  exit 1
fi

echo "Onboarding screenshot audit"
echo "Device: $DEVICE_ID"
echo "Output: ${OUTPUT_ROOT}/screenshots/onboarding-{1..5}.png"
echo ""

DART_DEFINES=(
  --dart-define=VISUAL_AUDIT=true
  --dart-define=VOICE_MEMORY_API_BASE_URL="$API_BASE_URL"
  --dart-define=UI_SCREENSHOT_AUDIT_ROOT="$OUTPUT_ROOT"
)

if [ "$DEVICE_ID" = "host-export" ]; then
  flutter test test/export_onboarding_pages_png_test.dart "$@"
else
  flutter test integration_test/onboarding_screenshot_test.dart -d "$DEVICE_ID" \
    "${DART_DEFINES[@]}" "$@" || {
    echo ""
    echo "Integration capture failed — falling back to host PNG export..."
    flutter test test/export_onboarding_pages_png_test.dart "$@"
  }
fi

echo ""
echo "Done. See ${OUTPUT_ROOT}/screenshots/onboarding-*.png"
