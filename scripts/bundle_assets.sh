#!/usr/bin/env bash
# Stage quantised release assets and reject unstripped model binaries.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS="$ROOT/apps/mobile/assets"
STAGING="${1:-$ROOT/build/release-assets}"
VAULT="$ASSETS/sample_vault/sample_vault.db"
REQUIRE_ONNX="${REQUIRE_ONNX:-0}"

fail() {
  echo "error: $1" >&2
  exit 1
}

is_quantised_onnx() {
  local base
  base="$(basename "$1" | tr '[:upper:]' '[:lower:]')"
  case "$base" in
    *fp32*|*fp16*|*float32*|*full*)
      return 1
      ;;
  esac
  case "$base" in
    *int8*|*q8*|*q4*|*quant*)
      return 0
      ;;
  esac
  return 1
}

stage_gzip() {
  local source="$1"
  local name="$2"
  local packed="$STAGING/$name.gz"
  gzip -n -9 -c "$source" > "$packed"
  gzip -t "$packed"
  local original packed_size
  original="$(wc -c < "$source" | tr -d ' ')"
  packed_size="$(wc -c < "$packed" | tr -d ' ')"
  if [[ "$packed_size" -ge "$original" ]]; then
    if [[ "$original" -lt 4096 ]]; then
      rm -f "$packed"
      cp "$source" "$STAGING/$name"
      echo "staged $name unchanged ($original bytes; already smaller than a gzip header)"
      return
    fi
    fail "$name did not shrink when compressed ($original -> $packed_size)"
  fi
  local restored
  restored="$(mktemp)"
  gzip -dc "$packed" > "$restored"
  cmp -s "$source" "$restored" || fail "$name gzip round-trip changed bytes"
  rm -f "$restored"
  echo "staged $name.gz ($original -> $packed_size bytes)"
}

[[ -f "$VAULT" ]] || fail "missing $VAULT"
header="$(head -c 15 "$VAULT")"
[[ "$header" == "SQLite format 3" ]] || fail "sample_vault.db is not a SQLite database"
if head -c 40 "$VAULT" | grep -q "git-lfs"; then
  fail "sample_vault.db is a Git LFS pointer, not the database"
fi

mkdir -p "$STAGING"
stage_gzip "$VAULT" "sample_vault.db"

onnx_count=0
while IFS= read -r model; do
  [[ -z "$model" ]] && continue
  onnx_count=$((onnx_count + 1))
  if head -c 40 "$model" | grep -q "git-lfs"; then
    fail "$model is a Git LFS pointer"
  fi
  if ! is_quantised_onnx "$model"; then
    fail "$model is not a quantised ONNX binary (expected int8, q8, or q4 in the name)"
  fi
  stage_gzip "$model" "$(basename "$model")"
done < <(find "$ASSETS" -type f -name '*.onnx' | sort)

if [[ "$onnx_count" -eq 0 ]]; then
  if [[ "$REQUIRE_ONNX" == "1" ]]; then
    fail "no offline ONNX models under $ASSETS"
  fi
  echo "no offline ONNX models under $ASSETS; vault staging only"
fi

echo "release assets ready in $STAGING"
