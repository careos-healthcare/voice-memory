#!/bin/bash
# Archive memory after V1 gate — future enhancement after V1 proof.
#
# Usage:
#   ./tool/run_archive_memory_after_v1_gate.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> Archive memory after V1 gate tests"
flutter test test/archive_memory_after_v1_gate_test.dart

echo ""
echo "Archive memory after V1 gate validation passed."
