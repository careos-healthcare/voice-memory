#!/bin/bash
# Referral after proof gate v1 — future referral only after proof value.
#
# Usage:
#   ./tool/run_referral_after_proof_gate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Referral after proof gate tests"
flutter test test/referral_after_proof_gate_test.dart

echo ""
echo "Referral after proof gate validation passed."
