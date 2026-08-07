#!/usr/bin/env bash
# Fail if production lib/ imports the non-shipping research package.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if grep -rq "package:archiveme_research" lib/ 2>/dev/null; then
  echo "error: production lib/ must not import archiveme_research" >&2
  exit 1
fi

echo "OK — production lib/ does not import archiveme_research"
