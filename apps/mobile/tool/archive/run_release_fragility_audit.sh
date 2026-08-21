#!/bin/bash
# Release fragility audit v1 — operational risks that survive green tests.
#
# Usage:
#   ./tool/run_release_fragility_audit.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Release fragility audit tests"
flutter test test/release_fragility_audit_test.dart

echo ""
echo "Release fragility audit validation passed."
