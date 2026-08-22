#!/usr/bin/env bash
# Fail if production lib/ imports the non-shipping research package.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# A missing or moved lib/ made `grep -rq` return non-zero exactly like a clean
# scan, so this printed OK with exit 0 having read nothing. Count the scan set
# first: an empty one is a broken check, not a passing one.
# `|| true` inside the group: without it `pipefail` kills the script on the
# failing grep before the guard below can say why.
scanned=$( { grep -rl "" --include='*.dart' lib/ 2>/dev/null || true; } | wc -l | tr -d ' ')
if (( scanned == 0 )); then
  echo "error: scanned 0 dart files under lib/ — scan root missing or unreadable" >&2
  exit 1
fi

if grep -rq "package:archiveme_research" lib/ 2>/dev/null; then
  echo "error: production lib/ must not import archiveme_research" >&2
  exit 1
fi

echo "OK — production lib/ does not import archiveme_research ($scanned dart files scanned)"
