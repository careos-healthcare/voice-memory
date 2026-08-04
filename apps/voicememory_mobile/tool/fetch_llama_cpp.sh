#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK="$ROOT/third_party/llama.cpp.lock.json"
DEST="$ROOT/third_party/llama.cpp"
ARCHIVE="$(mktemp "${TMPDIR:-/tmp}/archiveme-llama.XXXXXX.tar.gz")"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/archiveme-llama.XXXXXX")"
trap 'rm -f "$ARCHIVE"; rm -rf "$STAGING"' EXIT

read_lock() {
  /usr/bin/python3 - "$LOCK" "$1" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    print(json.load(handle)[sys.argv[2]])
PY
}

COMMIT="$(read_lock commit)"
URL="$(read_lock archive)"
EXPECTED_SHA="$(read_lock archiveSha256)"

if [[ -e "$DEST" ]]; then
  echo "error: $DEST already exists; vendored source is never overwritten" >&2
  exit 2
fi

curl --fail --location --proto '=https' --tlsv1.2 "$URL" --output "$ARCHIVE"
ACTUAL_SHA="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
  echo "error: llama.cpp archive checksum mismatch" >&2
  exit 3
fi

tar -xzf "$ARCHIVE" -C "$STAGING" --strip-components=1
if [[ ! -f "$STAGING/LICENSE" || ! -f "$STAGING/include/llama.h" ]]; then
  echo "error: archive does not contain expected llama.cpp source" >&2
  exit 4
fi

# The mobile build enables only the llama/ggml libraries. Keep their build
# metadata, source, public headers, notices, and licenses; discard apps,
# examples, model fixtures, conversion tools, docs, and tests.
for entry in "$STAGING"/*; do
  name="$(basename "$entry")"
  case "$name" in
    AUTHORS|CMakeLists.txt|LICENSE|README.md|cmake|ggml|include|licenses|src)
      ;;
    *)
      rm -rf "$entry"
      ;;
  esac
done

mkdir -p "$(dirname "$DEST")"
mv "$STAGING" "$DEST"
echo "Fetched verified llama.cpp source at commit $COMMIT"
