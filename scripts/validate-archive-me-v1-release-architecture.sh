#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

node scripts/archive-me-v1-release-architecture.mjs --check
node --test scripts/archive-me-v1-release-architecture.test.mjs

if command -v flutter >/dev/null 2>&1; then
  (
    cd apps/voicememory_mobile
    flutter test \
      test/v1_navigation_guard_test.dart \
      test/v1_permission_envelope_test.dart \
      test/v1_scope_cut_test.dart \
      test/navigation/primary_navigation_shell_test.dart
  )
else
  echo "flutter is not on PATH; skipped focused Dart architecture guards" >&2
fi
