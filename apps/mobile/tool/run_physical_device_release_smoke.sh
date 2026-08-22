#!/bin/bash
# Physical device smoke proof v1 — automated checklist + RevenueCat no-crash guard.
#
# Safe for CI: runs unit tests only, not on-device automation.
#
# Usage:
#   ./tool/run_physical_device_release_smoke.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Physical device smoke proof tests"
flutter test \
  test/physical_device_smoke_proof_test.dart

echo ""
echo "==> RevenueCat missing-key no-crash guard"
flutter test test/revenuecat_sandbox_proof_test.dart --name "missing RevenueCat key does not crash initialize"

echo ""
echo "Physical device release smoke validation passed."
