#!/usr/bin/env bash
# Restores lib/features/* symlinks from retired_sprawl/lib_features so imports
# like package:archiveme_mobile/features/<name>/... resolve for tests and builds.
# Also regenerates the matching analyzer exclude list in analysis_options.yaml.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ANALYSIS_OPTIONS="analysis_options.yaml"

IMPORTED="$(mktemp)"
EXISTING="$(mktemp)"
ALL_IMPORTED="$(mktemp)"
SYMLINKED="$(mktemp)"
trap 'rm -f "$IMPORTED" "$EXISTING" "$ALL_IMPORTED" "$SYMLINKED"' EXIT

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
  # --ignore-existing is load-bearing: without it a re-run overwrites live V1 files
  # with their retired counterparts, so the analyzer count moves without anyone
  # editing code. Only files missing locally may be filled in from retired_sprawl.
  rsync -a --ignore-existing \
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

# The analyzer follows these symlinks and reports retired code under
# lib/features/<name>/..., so `retired_sprawl/**` alone excludes nothing. Keep one
# lib/features exclude per symlink so the list never drifts from what is on disk.
if [[ ! -f "$ANALYSIS_OPTIONS" ]]; then
  echo "missing $ROOT/$ANALYSIS_OPTIONS: cannot sync analyzer excludes" >&2
  exit 1
fi

for entry in lib/features/*; do
  [[ -L "$entry" ]] || continue
  case "$(readlink "$entry")" in
    *retired_sprawl/*) basename "$entry" ;;
  esac
done | LC_ALL=C sort -u > "$SYMLINKED"

excluded="$(wc -l < "$SYMLINKED" | tr -d '[:space:]')"

python3 - "$ANALYSIS_OPTIONS" "$SYMLINKED" <<'PY'
"""Rewrite the generated lib/features exclude block in analysis_options.yaml."""

import os
import re
import sys

BEGIN = "# BEGIN generated: lib/features symlink excludes (restore_lib_features_symlinks.sh)"
END = "# END generated"
GENERATED_ITEM = re.compile(r"^\s*-\s*lib/features/[^/\s]+/\*\*\s*$")
EXCLUDE_KEY = re.compile(r"^(\s*)exclude:\s*$")
LIST_ITEM = re.compile(r"^(\s*)-\s")

options_path, features_path = sys.argv[1], sys.argv[2]


def fail(message):
    sys.exit(f"{options_path}: {message}")


with open(features_path, encoding="utf-8") as handle:
    features = [line.strip() for line in handle if line.strip()]

with open(options_path, encoding="utf-8") as handle:
    lines = handle.read().splitlines(keepends=True)

# Locate the `exclude:` key and the extent of its block (ends at the first
# non-blank line indented no deeper than the key itself).
key_index = None
for index, line in enumerate(lines):
    match = EXCLUDE_KEY.match(line)
    if match:
        key_index, key_indent = index, len(match.group(1))
        break
if key_index is None:
    fail("no `exclude:` key found; refusing to guess where excludes belong")

stop = key_index + 1
last_content = key_index
while stop < len(lines):
    line = lines[stop]
    if line.strip():
        if len(line) - len(line.lstrip()) <= key_indent:
            break
        last_content = stop
    stop += 1
stop = last_content + 1

body = lines[key_index + 1:stop]
indent = next(
    (LIST_ITEM.match(line).group(1) for line in body if LIST_ITEM.match(line)),
    " " * (key_indent + 2),
)
block = (
    [f"{indent}{BEGIN}\n"]
    + [f"{indent}- lib/features/{name}/**\n" for name in features]
    + [f"{indent}{END}\n"]
)

begin_at = next((i for i, line in enumerate(body) if line.strip() == BEGIN), None)
end_at = next((i for i, line in enumerate(body) if line.strip() == END), None)
if (begin_at is None) != (end_at is None):
    fail("found only one of the generated block markers; fix it by hand")
if begin_at is not None:
    if end_at < begin_at:
        fail("generated block markers are out of order; fix them by hand")
    new_body = body[:begin_at] + block + body[end_at + 1:]
else:
    # First run: adopt any hand-added lib/features excludes into the block,
    # keeping every other exclude (retired_sprawl/**, one-offs) in place.
    kept, insert_at = [], None
    for line in body:
        if GENERATED_ITEM.match(line):
            if insert_at is None:
                insert_at = len(kept)
            continue
        kept.append(line)
    if insert_at is None:
        insert_at = len(kept)
    new_body = kept[:insert_at] + block + kept[insert_at:]

updated = lines[:key_index + 1] + new_body + lines[stop:]
if updated == lines:
    sys.exit(0)

# Temp file plus atomic move so a failure never leaves a truncated config.
temp_path = f"{options_path}.tmp.{os.getpid()}"
try:
    with open(temp_path, "w", encoding="utf-8") as handle:
        handle.writelines(updated)
    os.replace(temp_path, options_path)
except BaseException:
    if os.path.exists(temp_path):
        os.remove(temp_path)
    raise
PY

echo "Synced $excluded symlink excludes into $ANALYSIS_OPTIONS."
