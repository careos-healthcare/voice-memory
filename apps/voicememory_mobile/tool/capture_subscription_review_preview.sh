#!/bin/bash
# Capture App Store subscription review paywall → ~/Desktop/app21/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_ROOT="${SUBSCRIPTION_REVIEW_PREVIEW_OUT:-${HOME}/Desktop/app21}"
GOLDEN_NAME="subscription_review_preview.png"
SCREENSHOT_NAME="Subscription_Review_Preview.png"

mkdir -p "$OUTPUT_ROOT"
DEST="$OUTPUT_ROOT/$SCREENSHOT_NAME"
GOLDEN_SRC="$APP_DIR/test/$GOLDEN_NAME"

cd "$APP_DIR"

echo "ArchiveMe subscription review preview"
echo "Output: $OUTPUT_ROOT"
echo ""

export SUBSCRIPTION_REVIEW_PREVIEW_OUT="$OUTPUT_ROOT"

echo "Rendering golden (393×852)..."
flutter test test/export_subscription_review_preview_png_test.dart --update-goldens "$@"

if [ ! -f "$GOLDEN_SRC" ]; then
  echo "Golden not found: $GOLDEN_SRC"
  exit 1
fi

cp "$GOLDEN_SRC" "$DEST"
echo "Copied $GOLDEN_SRC → $DEST"

echo ""
echo "Done. Screenshot:"
echo "  $DEST"
ls -la "$DEST"
