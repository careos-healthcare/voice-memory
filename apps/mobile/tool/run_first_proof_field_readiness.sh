#!/bin/bash
# First proof field readiness v1 — beta measurement and repair routing only.
#
# Usage:
#   ./tool/run_first_proof_field_readiness.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> First proof field readiness tests"
flutter test test/first_proof_field_readiness_test.dart

echo ""
echo "First proof field readiness validation passed."
