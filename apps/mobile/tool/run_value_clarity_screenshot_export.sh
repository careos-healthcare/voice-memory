#!/bin/bash
# Value-clarity PNGs — fails in ~45s if headless toImage hangs (use simulator + manual capture as fallback).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT="${HOME}/Desktop/upload12/screenshots"

mkdir -p "$OUT"
cd "$APP_DIR"

echo "Trying headless PNG export (45s cap; often hangs on macOS VM)…"
export EXPORT_VALUE_CLARITY_PNG=1
if flutter test test/export_value_clarity_png_test.dart --plain-name "export value clarity screens"; then
  echo "Done. Check: $OUT/value-empty-state.png value-archive-hero.png value-changes-story.png"
  exit 0
fi

echo ""
echo "Automated export failed (toImage hang in widget tests)."
echo "Capture manually on simulator:"
echo "  open -a Simulator"
echo "  cd $APP_DIR && flutter run -d 'iPhone 17 Pro'"
echo "  Patterns tab (empty), belief hero, Changes story → save to:"
echo "  $OUT"
exit 1
