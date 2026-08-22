#!/bin/bash
# Product language consistency guard v1 — proof-trail language wins in core surfaces.
#
# Usage:
#   ./tool/run_product_language_consistency_guard.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Product language consistency guard tests"
flutter test \
  test/product_language_consistency_guard_test.dart \
  test/pro_promise_copy_audit_test.dart

echo ""
echo "Product language consistency guard validation passed."
