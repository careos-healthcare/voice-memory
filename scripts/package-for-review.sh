#!/usr/bin/env bash
# Zip the monorepo for review, leaving dependency and build caches out.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT="${1:-$ROOT/thoughtprint-review.zip}"

zip -r "$OUT" . \
  -x '*/node_modules/*' 'node_modules/*' \
  -x '*/.git/*' '.git/*' \
  -x '*/build/*' 'build/*' \
  -x '*/.dart_tool/*' '.dart_tool/*' \
  -x '*/ios/Pods/*' 'ios/Pods/*' \
  -x '*/ios/.symlinks/*' 'ios/.symlinks/*' \
  -x '*/ios/Flutter/ephemeral/*' 'ios/Flutter/ephemeral/*' \
  -x '*/android/.gradle/*' 'android/.gradle/*' \
  -x '*/android/.kotlin/*' 'android/.kotlin/*' \
  -x '*/linux/flutter/ephemeral/*' 'linux/flutter/ephemeral/*' \
  -x "$(basename "$OUT")"

echo "Wrote $OUT"
