#!/usr/bin/env bash
# Zip the tracked tree only. git archive never includes untracked files or .git/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

git archive --format=zip --output=thoughtprint-source.zip HEAD

forbidden="$(unzip -Z1 thoughtprint-source.zip | grep -E '(^|/)\.(data|vercel|git)(/|$)' || true)"
if [[ -n "$forbidden" ]]; then
  echo "Refusing zip; it contains .data/, .vercel/, or .git/:" >&2
  printf '%s\n' "$forbidden" >&2
  exit 1
fi

echo "Archive excludes .data/, .vercel/, and .git/."
