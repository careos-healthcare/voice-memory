#!/bin/bash
# Secrets rotation launch gate v1 — production submission blocker.
#
# Usage:
#   ./tool/run_secrets_rotation_launch_gate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Secrets rotation launch gate tests"
flutter test test/secrets_rotation_launch_gate_test.dart

echo ""
echo "Secrets rotation launch gate validation passed."
