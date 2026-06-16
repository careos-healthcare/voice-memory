#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
UPLOADS_DIR="${HOME}/Desktop/uploads"
ADB_PULL_PATH="/storage/emulated/0/Android/data/com.voicememory.app/files/voicememory_screenshots"
# Default: production host (session check succeeds without a local server).
# Override for local backend, e.g. SCREENSHOT_API_BASE_URL=http://192.168.1.10:3000
API_BASE_URL="${SCREENSHOT_API_BASE_URL:-https://voice-memory-iota.vercel.app}"
DART_DEFINES=(--dart-define=VOICE_MEMORY_API_BASE_URL="$API_BASE_URL")

mkdir -p "$UPLOADS_DIR"

cd "$APP_DIR"

echo "ArchiveMe screenshot capture"
echo "Mac output: $UPLOADS_DIR"
echo ""

pick_device() {
  if [ -n "${SCREENSHOT_DEVICE_ID:-}" ]; then
    echo "$SCREENSHOT_DEVICE_ID"
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
  echo "No device found. Connect a device or start the macOS simulator target."
  exit 1
fi

echo "Using device: $DEVICE_ID"
echo ""

if [ "$DEVICE_ID" = "macos" ]; then
  flutter test integration_test/full_app_screenshot_test.dart -d macos \
    "${DART_DEFINES[@]}" \
    --dart-define=SCREENSHOT_OUTPUT_DIR="$UPLOADS_DIR" "$@"
else
  flutter test integration_test/full_app_screenshot_test.dart -d "$DEVICE_ID" \
    "${DART_DEFINES[@]}" "$@"
  echo ""
  echo "Pulling device screenshots to $UPLOADS_DIR ..."
  if command -v adb >/dev/null 2>&1; then
    adb -s "$DEVICE_ID" pull "$ADB_PULL_PATH/." "$UPLOADS_DIR/" || {
      echo "adb pull failed — copy manually from device path:"
      echo "  $ADB_PULL_PATH"
    }
  else
    echo "adb not found — screenshots remain on device at:"
    echo "  $ADB_PULL_PATH"
  fi
fi

echo ""
echo "Done. PNGs should be under: $UPLOADS_DIR"
