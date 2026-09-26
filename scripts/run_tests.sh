#!/usr/bin/env bash
# Run the journal encryption unit tests, then the full journal pipeline.
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/apps/mobile"

echo "=== Stage 1: unit tests (E2EE) ==="
flutter test test/core/crypto/e2e_encryption_test.dart

echo "=== Stage 2: integration tests (journal pipeline) ==="
flutter test integration_test/full_journal_pipeline_test.dart

echo "=== All test stages passed ==="
