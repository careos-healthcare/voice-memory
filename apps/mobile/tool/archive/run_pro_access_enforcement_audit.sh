#!/bin/bash
# Pro access enforcement audit v3 — store readiness bridge + CI enforcement bundle.
#
# Usage:
#   ./tool/run_pro_access_enforcement_audit.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Pro access enforcement audit v3 tests"
flutter test \
  test/pro_access_enforcement_audit_test.dart \
  test/store_readiness_single_source_test.dart \
  test/revenuecat_sandbox_proof_test.dart

echo ""
echo "Pro access enforcement audit validation passed."
