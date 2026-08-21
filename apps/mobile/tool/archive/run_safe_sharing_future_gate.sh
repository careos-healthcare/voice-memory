#!/bin/bash
# Safe sharing future gate v1 — future growth sharing without private text leak.
#
# Usage:
#   ./tool/run_safe_sharing_future_gate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Safe sharing future gate tests"
flutter test test/safe_sharing_future_gate_test.dart

echo ""
echo "Safe sharing future gate validation passed."
