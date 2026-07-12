#!/bin/bash
# Return tomorrow ritual gate v1 — future retention without daily homework.
#
# Usage:
#   ./tool/run_return_tomorrow_ritual_gate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Return tomorrow ritual gate tests"
flutter test test/return_tomorrow_ritual_gate_test.dart

echo ""
echo "Return tomorrow ritual gate validation passed."
