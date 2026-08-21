#!/bin/bash
# Widget release risk gate v1 — ensure widgets cannot block TestFlight.
#
# Usage:
#   ./tool/run_widget_release_risk_gate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Widget release risk gate tests"
flutter test \
  test/widget_release_risk_gate_test.dart \
  test/beta_release_artifacts_test.dart \
  test/excluded_native_capability_cleanup_test.dart \
  test/release_identity_consistency_test.dart

echo ""
echo "Widget release risk gate validation passed."
