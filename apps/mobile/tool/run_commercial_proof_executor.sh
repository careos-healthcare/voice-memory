#!/bin/bash
# Commercial proof executor v1 — one executable release checklist.
#
# Usage:
#   ./tool/run_commercial_proof_executor.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Commercial proof executor tests"
flutter test test/commercial_proof_executor_test.dart

echo ""
echo "Commercial proof executor validation passed."
