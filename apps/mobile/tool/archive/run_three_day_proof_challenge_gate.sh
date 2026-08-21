#!/bin/bash
# Three day proof challenge gate v1 — future acquisition without V1 changes.
#
# Usage:
#   ./tool/run_three_day_proof_challenge_gate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Three day proof challenge gate tests"
flutter test test/three_day_proof_challenge_gate_test.dart

echo ""
echo "Three day proof challenge gate validation passed."
