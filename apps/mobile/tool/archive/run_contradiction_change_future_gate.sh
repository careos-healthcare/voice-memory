#!/bin/bash
# Contradiction change future gate v1 — future premium change detection only.
#
# Usage:
#   ./tool/run_contradiction_change_future_gate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Contradiction change future gate tests"
flutter test test/contradiction_change_future_gate_test.dart

echo ""
echo "Contradiction change future gate validation passed."
