#!/bin/bash
# Cross device continuity future gate v1 — future only until technically proven.
#
# Usage:
#   ./tool/run_cross_device_continuity_future_gate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Cross device continuity future gate tests"
flutter test test/cross_device_continuity_future_gate_test.dart

echo ""
echo "Cross device continuity future gate validation passed."
