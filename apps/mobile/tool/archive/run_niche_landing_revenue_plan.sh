#!/bin/bash
# Niche landing revenue plan v1 — acquisition pages without app V1 surfaces.
#
# Usage:
#   ./tool/run_niche_landing_revenue_plan.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Niche landing revenue plan tests"
flutter test test/niche_landing_revenue_plan_test.dart

echo ""
echo "Niche landing revenue plan validation passed."
