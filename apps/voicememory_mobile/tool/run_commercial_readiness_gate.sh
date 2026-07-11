#!/bin/bash
# Commercial readiness gate v1 — product-ready vs commercially ready.
#
# Usage:
#   ./tool/run_commercial_readiness_gate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Commercial readiness gate tests"
flutter test \
  test/commercial_readiness_gate_test.dart \
  test/paid_intent_beta_proof_test.dart \
  test/secrets_rotation_launch_gate_test.dart

echo ""
echo "Commercial readiness gate validation passed."
