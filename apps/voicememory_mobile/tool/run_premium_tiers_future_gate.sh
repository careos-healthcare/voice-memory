#!/bin/bash
# Premium tiers future gate v1 — prevent higher-tier complexity before simple Pro converts.
#
# Usage:
#   ./tool/run_premium_tiers_future_gate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Premium tiers future gate tests"
flutter test test/premium_tiers_future_gate_test.dart

echo ""
echo "Premium tiers future gate validation passed."
