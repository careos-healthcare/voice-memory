#!/bin/bash
# RevenueCat live proof runner v1 — automated checklist + missing-key guard.
#
# Safe for CI: runs unit tests only, not on-device automation.
#
# Usage:
#   ./tool/run_revenuecat_live_proof_checklist.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> RevenueCat live proof runner tests"
flutter test test/revenuecat_live_proof_runner_test.dart

echo ""
echo "==> RevenueCat missing-key no-crash guard"
flutter test test/revenuecat_live_proof_runner_test.dart \
  --name "missing RevenueCat key does not crash initialize"

echo ""
echo "RevenueCat live proof checklist validation passed."
