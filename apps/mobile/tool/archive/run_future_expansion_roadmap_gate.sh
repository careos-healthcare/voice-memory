#!/bin/bash
# Future expansion roadmap gate v1 — capture ideas without V1 surfacing.
#
# Usage:
#   ./tool/run_future_expansion_roadmap_gate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Future expansion roadmap gate tests"
flutter test test/future_expansion_roadmap_gate_test.dart

echo ""
echo "Future expansion roadmap gate validation passed."
