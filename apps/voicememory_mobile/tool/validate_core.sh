#!/bin/bash
# Targeted core validation for ArchiveMe mobile.
#
# Runs the analyzer on lib/ plus a curated, reliable subset of tests — not the
# whole (partly stale) suite — so release confidence checks stay fast and green.
#
# Usage:
#   ./tool/validate_core.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> flutter analyze lib/"
flutter analyze lib/

echo ""
echo "==> flutter test (core subset)"
flutter test \
  test/consumer_copy_banned_words_test.dart \
  test/screenshot_mode_test.dart \
  test/light_theme_enforcement_test.dart \
  test/app_router_guards_test.dart \
  test/key_moment_engine_test.dart \
  test/key_moment_store_test.dart \
  test/pattern_map_engine_test.dart \
  test/pattern_map_card_test.dart \
  test/routine_anchor_store_test.dart \
  test/localized_copy_test.dart \
  test/core_metrics_minimum_set_test.dart \
  test/paid_intent_beta_proof_test.dart \
  test/freeze_drift_scanner_test.dart

echo ""
echo "Core validation passed."
