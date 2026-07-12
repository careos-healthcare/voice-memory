#!/bin/bash
# Price objection feedback gate v1 — collect why users do not buy after Pro tap.
#
# Usage:
#   ./tool/run_price_objection_feedback_gate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Price objection feedback gate tests"
flutter test test/price_objection_feedback_gate_test.dart

echo ""
echo "Price objection feedback gate validation passed."
