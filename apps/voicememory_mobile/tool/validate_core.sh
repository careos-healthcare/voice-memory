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

echo "==> flutter analyze lib/ (errors/warnings gate + info baseline)"
bash tool/validate_analyzer_baseline.sh

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
  test/freeze_drift_scanner_test.dart

echo ""
echo "==> Pro access enforcement audit CI bundle"
bash tool/run_pro_access_enforcement_audit.sh

echo ""
echo "==> Widget release risk gate"
bash tool/run_widget_release_risk_gate.sh

echo ""
echo "==> Product language consistency guard"
bash tool/run_product_language_consistency_guard.sh

echo ""
echo "==> First proof field readiness"
bash tool/run_first_proof_field_readiness.sh

echo ""
echo "==> Commercial readiness gate"
bash tool/run_commercial_readiness_gate.sh

echo ""
echo "==> Physical device smoke proof"
bash tool/run_physical_device_release_smoke.sh

echo ""
echo "==> Secrets rotation launch gate"
bash tool/run_secrets_rotation_launch_gate.sh

echo ""
echo "==> Payment proof not interest gate"
bash tool/run_payment_proof_not_interest_gate.sh

echo ""
echo "==> V1 visible surface reducer"
bash tool/run_v1_visible_surface_reducer.sh

echo ""
echo "==> Commercial proof executor"
bash tool/run_commercial_proof_executor.sh

echo ""
echo "==> RevenueCat live proof runner"
bash tool/run_revenuecat_live_proof_checklist.sh

echo ""
echo "==> Stray test artifact guard"
bash tool/validate_no_stray_test_artifacts.sh

echo ""
echo "==> Research package import guard"
bash tool/validate_no_research_imports.sh

echo ""
echo "==> Repository cleanliness (git + stray artifacts)"
bash tool/validate_repository_cleanliness.sh

echo ""
echo "Core validation passed."
