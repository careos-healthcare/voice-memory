#!/usr/bin/env bash
# Zip the monorepo for review, leaving dependency and build caches out.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT="${1:-$ROOT/thoughtprint-review.zip}"

# -y stores symlinks as links, so lib/features/* stays a link into
# retired_sprawl instead of copying that tree a second time.
# apps/web and apps/api are named first so the review bundle always
# contains both apps, not only whatever `.` happens to expand to.
for required in apps/web apps/api; do
  if [[ ! -d "$ROOT/$required" ]]; then
    echo "Review package source is missing $ROOT/$required" >&2
    exit 1
  fi
done

zip -ry "$OUT" apps/web apps/api . \
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
  -x '*/.env' '*/.env.*' '.env' '.env.*' \
  -x "$(basename "$OUT")"

for required in apps/web apps/api; do
  if ! zipinfo -1 "$OUT" | grep -Eq "(^|/)${required}/"; then
    echo "Review package is missing ${required}" >&2
    exit 1
  fi
done

echo "Wrote $OUT"
