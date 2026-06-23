#!/usr/bin/env bash
# Fail if Flutter test-generated journal/prefs files pollute the mobile app tree.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE="$ROOT/apps/voicememory_mobile"

if [[ ! -d "$MOBILE" ]]; then
  echo "error: mobile app directory not found: $MOBILE" >&2
  exit 1
fi

shopt -s nullglob
generated=("$MOBILE"/*_journal.json "$MOBILE"/*_prefs.json)
shopt -u nullglob

if ((${#generated[@]} > 0)); then
  echo "error: generated journal/prefs files found in $MOBILE:" >&2
  printf '  %s\n' "${generated[@]}" >&2
  echo "Remove them before commit or export. They should be gitignored." >&2
  exit 1
fi

tracked=$(
  git -C "$ROOT" ls-files -- \
    'apps/voicememory_mobile/*_journal.json' \
    'apps/voicememory_mobile/*_prefs.json' \
    'apps/voicememory_mobile/_journal.json' \
    'apps/voicememory_mobile/_prefs.json' 2>/dev/null || true
)

if [[ -n "$tracked" ]]; then
  echo "error: generated journal/prefs files are tracked in git:" >&2
  echo "$tracked" | sed 's/^/  /' >&2
  exit 1
fi

echo "ok: mobile working tree has no generated journal/prefs files"
