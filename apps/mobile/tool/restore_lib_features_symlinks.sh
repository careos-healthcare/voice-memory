#!/usr/bin/env bash
# Restores lib/features/* symlinks from retired_sprawl/lib_features so imports
# like package:archiveme_mobile/features/<name>/... resolve for tests and builds.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

IMPORTED="$(mktemp)"
EXISTING="$(mktemp)"
ALL_IMPORTED="$(mktemp)"
trap 'rm -f "$IMPORTED" "$EXISTING" "$ALL_IMPORTED"' EXIT

grep -roh "package:archiveme_mobile/features/[^'\"]*" lib/ test/ \
  | sed 's|package:archiveme_mobile/features/||' \
  | cut -d/ -f1 \
  | sort -u > "$ALL_IMPORTED"

ls lib/features/ 2>/dev/null | sort -u > "$EXISTING" || true

linked=0
while read -r feature; do
  if [[ -e "lib/features/$feature" ]]; then
    continue
  fi
  if [[ -d "retired_sprawl/lib_features/$feature" ]]; then
    ln -s "../../retired_sprawl/lib_features/$feature" "lib/features/$feature"
    linked=$((linked + 1))
  else
    echo "missing in retired_sprawl: $feature" >&2
  fi
done < <(comm -23 "$ALL_IMPORTED" "$EXISTING")

# Merge partial dirs that keep V1-local files (onboarding/ui, insights models).
if [[ -d retired_sprawl/lib_features/onboarding ]]; then
  rsync -a --ignore-existing retired_sprawl/lib_features/onboarding/ lib/features/onboarding/
fi
if [[ -d retired_sprawl/lib_features/insights ]]; then
  rsync -a \
    --exclude='archive_insight.dart' \
    --exclude='insight_evidence.dart' \
    retired_sprawl/lib_features/insights/ lib/features/insights/
fi

for extra in media blind_spots notifications image_evidence; do
  if [[ ! -e "lib/features/$extra" && -d "retired_sprawl/lib_features/$extra" ]]; then
    ln -s "../../retired_sprawl/lib_features/$extra" "lib/features/$extra"
    linked=$((linked + 1))
  fi
done

echo "Linked $linked feature modules from retired_sprawl."
