#!/bin/bash
# Run ArchiveMe on an iPhone simulator in screenshot mode.
#
# Usage:
#   ./tool/run_ios_screenshot.sh [-- EXTRA_FLAGS...]
#
# Everything after `--` is passed straight through to `flutter run`, so you can
# add more screenshot dart-defines, e.g.:
#   ./tool/run_ios_screenshot.sh -- --dart-define=VOICE_MEMORY_SCREENSHOT_KEY_MOMENTS=true
#   ./tool/run_ios_screenshot.sh -- --dart-define=VOICE_MEMORY_SCREENSHOT_PATTERN_MAP=true
#
# Override the simulator with SCREENSHOT_DEVICE_ID=<udid> if needed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

# Default iPhone simulator udid (override with SCREENSHOT_DEVICE_ID).
DEVICE_ID="${SCREENSHOT_DEVICE_ID:-FD4ABE51-C41F-4A82-9139-616701C87C30}"

# Drop a leading `--` separator so callers can write: script -- --dart-define=...
if [ "${1:-}" = "--" ]; then
  shift
fi

echo "Running ArchiveMe in screenshot mode"
echo "Simulator: $DEVICE_ID"
echo ""

flutter run -d "$DEVICE_ID" \
  --dart-define=VOICE_MEMORY_SCREENSHOT_MODE=true \
  "$@"
