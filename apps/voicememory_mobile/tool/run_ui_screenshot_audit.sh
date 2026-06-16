#!/bin/bash
# Production UI screenshot audit — captures PNGs + markdown reports under ~/Desktop/upload12/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_ROOT="${HOME}/Desktop/upload12"
SCREENSHOTS_DIR="${OUTPUT_ROOT}/screenshots"
ADB_PULL_PATH="/storage/emulated/0/Download/voicememory_upload12"
API_BASE_URL="${SCREENSHOT_API_BASE_URL:-https://voice-memory-iota.vercel.app}"

mkdir -p "$SCREENSHOTS_DIR"

cd "$APP_DIR"

echo "ArchiveMe UI screenshot audit"
echo "Output: $OUTPUT_ROOT"
echo "Screenshots: $SCREENSHOTS_DIR"
echo ""

pick_device() {
  if [ -n "${UI_SCREENSHOT_DEVICE_ID:-}" ]; then
    echo "$UI_SCREENSHOT_DEVICE_ID"
    return
  fi
  local devices
  devices="$(flutter devices --machine 2>/dev/null || true)"
  if [ -n "$devices" ]; then
    if command -v python3 >/dev/null 2>&1; then
      local picked
      picked="$(printf '%s' "$devices" | python3 -c "
import json, sys
raw = sys.stdin.read().strip()
if not raw: sys.exit(1)
devices = json.loads(raw)
for prefer in ('macos',):
  for d in devices:
    if d.get('targetPlatform') == 'darwin' and d.get('emulator') is False:
      print('macos'); sys.exit(0)
for d in devices:
  if d.get('platform') == 'android' and d.get('emulator') is False:
    print(d.get('id', '')); sys.exit(0)
for d in devices:
  print(d.get('id', '')); sys.exit(0)
" 2>/dev/null || true)"
      if [ -n "$picked" ]; then
        echo "$picked"
        return
      fi
    fi
  fi
  if flutter devices 2>/dev/null | grep -q 'macos'; then
    echo "macos"
    return
  fi
  flutter devices 2>/dev/null | awk '/android-arm64/ {print $4; exit}'
}

DEVICE_ID="$(pick_device)"
if [ -z "${DEVICE_ID:-}" ]; then
  echo "No device found. Connect a device or enable macOS desktop."
  exit 1
fi

echo "Using device: $DEVICE_ID"
echo ""

DART_DEFINES=(
  --dart-define=VISUAL_AUDIT=true
  --dart-define=VOICE_MEMORY_SCREENSHOT_MODE=true
  --dart-define=VOICE_MEMORY_SCREENSHOT_RECORD_VIEW=return_day
  --dart-define=VOICE_MEMORY_API_BASE_URL="$API_BASE_URL"
  --dart-define=UI_SCREENSHOT_AUDIT_ROOT="$OUTPUT_ROOT"
)

if [ "$DEVICE_ID" = "macos" ]; then
  flutter test integration_test/ui_screenshot_audit_test.dart -d macos \
    "${DART_DEFINES[@]}" "$@"
else
  flutter test integration_test/ui_screenshot_audit_test.dart -d "$DEVICE_ID" \
    "${DART_DEFINES[@]}" "$@"
  echo ""
  echo "Pulling device audit output to $OUTPUT_ROOT ..."
  if command -v adb >/dev/null 2>&1; then
    adb -s "$DEVICE_ID" pull "$ADB_PULL_PATH/." "$OUTPUT_ROOT/" || {
      echo "adb pull failed — on-device path:"
      echo "  $ADB_PULL_PATH"
    }
  fi
fi

echo ""
echo "Done."
echo "  Screenshots: $SCREENSHOTS_DIR"
echo "  Index:       $OUTPUT_ROOT/UI_SCREENSHOT_INDEX.md"
echo "  Findings:    $OUTPUT_ROOT/UI_AUDIT_FINDINGS.md"
echo "  JSON:        $OUTPUT_ROOT/ui_screenshot_audit.json"
