#!/bin/bash
# Post-proof Pro CTA hardening v1 — Pro CTA after value, not before.
#
# Usage:
#   ./tool/run_post_proof_pro_cta_hardening.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Post-proof Pro CTA hardening tests"
flutter test test/post_proof_pro_cta_hardening_test.dart

echo ""
echo "Post-proof Pro CTA hardening validation passed."
