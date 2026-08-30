#!/usr/bin/env bash
# Fails when flutter test leaves stray JSON artifacts in the package root.
#
# Relative journal/prefs paths are sandboxed under AppServices.resetForTest, but
# this guard catches regressions that write timestamped *.json into the checkout.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# A committed file is not a test dump, whatever its name. Cross-check each
# find hit against the index so package.json and tracked caches stay legal.
violations=()
while IFS= read -r -d '' file; do
  base=$(basename "$file")
  case "$base" in
    pubspec.yaml|analysis_options.yaml) continue ;;
  esac
  rel="${file#./}"
  if git ls-files --error-unmatch -- "$rel" >/dev/null 2>&1; then
    continue
  fi
  violations+=("$file")
done < <(find . -maxdepth 1 -type f -name '*.json' -print0)

if ((${#violations[@]} > 0)); then
  echo "error: stray JSON artifacts in package root (${#violations[@]}):" >&2
  printf '  %s\n' "${violations[@]}" >&2
  exit 1
fi

echo "OK — no stray JSON in package root"
