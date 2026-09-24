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
  -x '*/Pods/*' 'Pods/*' \
  -x '*/.symlinks/*' '.symlinks/*' \
  -x '*/ephemeral/*' 'ephemeral/*' \
  -x '*/.dart_tool/*' '.dart_tool/*' \
  -x "$(basename "$OUT")"

echo "Wrote $OUT"
