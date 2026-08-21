#!/bin/bash
# Loop packs future gate v1 — acquisition angles without V1 UI.
#
# Usage:
#   ./tool/run_loop_packs_future_gate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Loop packs future gate tests"
flutter test test/loop_packs_future_gate_test.dart

echo ""
echo "Loop packs future gate validation passed."
