#!/bin/bash
# Run ArchiveMe with the clean confirmed-repeat demo archive for screenshots
# and short screen recordings.
#
# Usage:
#   ./tool/run_archive_me_demo.sh [-- EXTRA_FLAGS...]
#
# Override simulator with ARCHIVE_ME_DEMO_DEVICE, e.g.:
#   ARCHIVE_ME_DEMO_DEVICE="iPhone 17 Pro Max" ./tool/run_archive_me_demo.sh
#
# Everything after `--` is passed to `flutter run`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

DEVICE="${ARCHIVE_ME_DEMO_DEVICE:-iPhone 17 Pro}"

if [ "${1:-}" = "--" ]; then
  shift
fi

echo "Running ArchiveMe demo archive (confirmed repeat proof)"
echo "Simulator: $DEVICE"
echo ""
echo "Screens to capture:"
echo "  • Record — confirmed repeat + evidence timeline"
echo "  • Patterns — belief proof (\"Your archive currently believes…\")"
echo ""

flutter run -d "$DEVICE" \
  --dart-define=VOICE_MEMORY_SCREENSHOT_MODE=true \
  --dart-define=VOICE_MEMORY_SCREENSHOT_DEMO=confirmed_repeat \
  "$@"
