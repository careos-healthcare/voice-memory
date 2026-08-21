#!/bin/bash
# V1 visible surface reducer — keep first-release journey small.
#
# Usage:
#   ./tool/run_v1_visible_surface_reducer.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> V1 visible surface reducer tests"
flutter test test/v1_visible_surface_reducer_test.dart

echo ""
echo "V1 visible surface reducer validation passed."
