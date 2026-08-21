#!/bin/bash
# Annual plan future gate v1 — annual plan as future revenue test only.
#
# Usage:
#   ./tool/run_annual_plan_future_gate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Annual plan future gate tests"
flutter test test/annual_plan_future_gate_test.dart

echo ""
echo "Annual plan future gate validation passed."
