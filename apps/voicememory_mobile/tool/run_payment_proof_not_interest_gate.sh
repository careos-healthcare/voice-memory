#!/bin/bash
# Payment proof not interest gate v1 — separate idea interest from payment proof.
#
# Usage:
#   ./tool/run_payment_proof_not_interest_gate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Payment proof not interest gate tests"
flutter test test/payment_proof_not_interest_gate_test.dart

echo ""
echo "Payment proof not interest gate validation passed."
