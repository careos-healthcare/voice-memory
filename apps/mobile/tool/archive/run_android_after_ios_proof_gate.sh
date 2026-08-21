#!/bin/bash
# Android after iOS proof gate v1 — block Android until iOS purchase/restore proven.
#
# Usage:
#   ./tool/run_android_after_ios_proof_gate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Android after iOS proof gate tests"
flutter test test/android_after_ios_proof_gate_test.dart

echo ""
echo "Android after iOS proof gate validation passed."
