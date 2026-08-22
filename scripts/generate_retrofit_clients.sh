#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOBILE="$ROOT/apps/mobile"

echo "Regenerating Retrofit clients from lib/api/retrofit/*.dart"
cd "$MOBILE"
dart run build_runner build --delete-conflicting-outputs \
  --build-filter="lib/api/retrofit/*.dart"

echo "Done. Validate with: dart test test/core/network/openapi_retrofit_parity_test.dart"
