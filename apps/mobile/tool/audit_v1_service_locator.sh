#!/usr/bin/env bash
# Fails if V1 critical-path sources reference AppServices.instance directly.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

REGISTRY="$ROOT/lib/core/di/v1_critical_path_files.dart"
[[ -f "$REGISTRY" ]] || { echo "error: missing v1_critical_path_files.dart" >&2; exit 1; }

fail() {
  echo "error: $1" >&2
  exit 1
}

echo "==> V1 critical paths must not use AppServices.instance"
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  file="$ROOT/$path"
  [[ -f "$file" ]] || fail "critical path file missing: $path"
  if grep -q 'AppServices\.instance' "$file"; then
    fail "AppServices.instance in $path — inject V1AccountDependencies"
  fi
done < <(grep -oE "lib/[^'\"]+\.dart" "$REGISTRY")

echo "OK — no service-locator access on V1 critical paths"
