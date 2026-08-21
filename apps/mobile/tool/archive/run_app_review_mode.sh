#!/bin/bash
# Run ArchiveMe with App Store Review Access enabled in Settings.
#
# Usage:
#   ./tool/run_app_review_mode.sh [-- EXTRA_FLAGS...]
#
# After launch:
#   1. Settings → App Review Access
#   2. Enter review code: ARCHIVEME-REVIEW-2026
#   3. Open Archive tab to review sample entries and proof
#
# Override simulator with APP_REVIEW_DEVICE, e.g.:
#   APP_REVIEW_DEVICE="iPhone 17 Pro Max" ./tool/run_app_review_mode.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

DEVICE="${APP_REVIEW_DEVICE:-iPhone 17 Pro}"

if [ "${1:-}" = "--" ]; then
  shift
fi

echo "Running ArchiveMe in App Review mode"
echo "Simulator: $DEVICE"
echo ""
echo "Reviewer path:"
echo "  • Settings → App Review Access → ARCHIVEME-REVIEW-2026"
echo "  • Archive tab — sample entries + evidence proof"
echo "  • /subscription — paywall (no auto-dismiss in review mode)"
echo ""

flutter run -d "$DEVICE" \
  --dart-define=ARCHIVEME_APP_REVIEW_MODE=true \
  "$@"
