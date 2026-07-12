#!/bin/bash
# B2B workplace pressure future gate v1 — future landing positioning only.
#
# Usage:
#   ./tool/run_b2b_workplace_pressure_future_gate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> B2B workplace pressure future gate tests"
flutter test test/b2b_workplace_pressure_future_gate_test.dart

echo ""
echo "B2B workplace pressure future gate validation passed."
