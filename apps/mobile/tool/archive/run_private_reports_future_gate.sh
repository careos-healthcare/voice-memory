#!/bin/bash
# Private reports future gate v1 — later upgrade, not launch headline.
#
# Usage:
#   ./tool/run_private_reports_future_gate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Private reports future gate tests"
flutter test test/private_reports_future_gate_test.dart

echo ""
echo "Private reports future gate validation passed."
