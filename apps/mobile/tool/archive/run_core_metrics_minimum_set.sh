#!/bin/bash
# Core metrics minimum set v2 — classifier, dashboard wiring, and CI bundle.
#
# Usage:
#   ./tool/run_core_metrics_minimum_set.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Core metrics minimum set v2 tests"
flutter test \
  test/core_metrics_minimum_set_test.dart \
  test/testflight_analytics_dashboard_test.dart \
  test/paid_intent_beta_proof_test.dart

echo ""
echo "Core metrics minimum set validation passed."
