#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${HOME}/Desktop/upload1"
ADB_PULL_PATH="/storage/emulated/0/Android/data/com.voicememory.app/files/voicememory_visual_audit"
API_BASE_URL="${SCREENSHOT_API_BASE_URL:-https://voice-memory-iota.vercel.app}"

mkdir -p "$OUTPUT_DIR"

cd "$APP_DIR"

echo "ArchiveMe full visual audit"
echo "Output: $OUTPUT_DIR"
echo ""

pick_device() {
  if [ -n "${VISUAL_AUDIT_DEVICE_ID:-}" ]; then
    echo "$VISUAL_AUDIT_DEVICE_ID"
    return
  fi
  if flutter devices 2>/dev/null | grep -qE '[[:space:]]macos[[:space:]]'; then
    echo "macos"
    return
  fi
  flutter devices 2>/dev/null | awk '/android/ {print $5; exit}'
}

DEVICE_ID="$(pick_device)"
if [ -z "${DEVICE_ID:-}" ]; then
  echo "No device found."
  exit 1
fi

echo "Using device: $DEVICE_ID"
echo ""

DART_DEFINES=(
  --dart-define=VISUAL_AUDIT=true
  --dart-define=VOICE_MEMORY_API_BASE_URL="$API_BASE_URL"
)

if [ "$DEVICE_ID" = "macos" ]; then
  flutter test integration_test/full_visual_audit_test.dart -d macos \
    "${DART_DEFINES[@]}" \
    --dart-define=VISUAL_AUDIT_OUTPUT_DIR="$OUTPUT_DIR" "$@"
else
  flutter test integration_test/full_visual_audit_test.dart -d "$DEVICE_ID" \
    "${DART_DEFINES[@]}" \
    --dart-define=VISUAL_AUDIT_OUTPUT_DIR="$OUTPUT_DIR" "$@"
  echo ""
  echo "Pulling device audit tree to $OUTPUT_DIR ..."
  if command -v adb >/dev/null 2>&1; then
    adb -s "$DEVICE_ID" pull "$ADB_PULL_PATH/." "$OUTPUT_DIR/" || {
      echo "adb pull failed — files may still be on device at:"
      echo "  $ADB_PULL_PATH"
    }
  fi
fi

echo ""
echo "Audit output: $OUTPUT_DIR"
echo "Report: $OUTPUT_DIR/audit/report.md"
