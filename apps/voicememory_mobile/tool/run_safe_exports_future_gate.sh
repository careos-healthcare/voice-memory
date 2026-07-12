#!/bin/bash
# Safe exports future gate v1 — future paid expansion, not launch promise.
#
# Usage:
#   ./tool/run_safe_exports_future_gate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Safe exports future gate tests"
flutter test test/safe_exports_future_gate_test.dart

echo ""
echo "Safe exports future gate validation passed."
