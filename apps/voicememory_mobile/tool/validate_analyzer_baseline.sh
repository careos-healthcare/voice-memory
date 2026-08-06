#!/usr/bin/env bash
# Analyzer gate for validate_core.sh — zero errors/warnings; info ratchet baseline.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BASELINE_FILE="tool/analyzer_info_baseline.txt"
OUTPUT="$(mktemp)"
FINGERPRINTS="$(mktemp)"
trap 'rm -f "$OUTPUT" "$FINGERPRINTS"' EXIT

flutter analyze lib/ test/ >"$OUTPUT" 2>&1 || true

errors=$(grep -c " error •" "$OUTPUT" 2>/dev/null || true)
warnings=$(grep -c " warning •" "$OUTPUT" 2>/dev/null || true)
info_count=$(grep -c " info •" "$OUTPUT" 2>/dev/null || true)

errors=${errors:-0}
warnings=${warnings:-0}
info_count=${info_count:-0}

echo "Analyzer: errors=$errors warnings=$warnings info=$info_count"

if (( errors > 0 )); then
  echo >&2
  echo "error: analyzer reported $errors error(s):" >&2
  grep " error •" "$OUTPUT" >&2 || true
  exit 1
fi

if (( warnings > 0 )); then
  echo >&2
  echo "error: analyzer reported $warnings warning(s):" >&2
  grep " warning •" "$OUTPUT" >&2 || true
  exit 1
fi

grep " info •" "$OUTPUT" | sed -E 's/^ *info • .* • ([^ ]+) • ([0-9]+) • ([a-z_0-9]+)$/\1:\2:\3/' | sort -u >"$FINGERPRINTS"

if [[ "${1:-}" == "--update-info-baseline" ]]; then
  cp "$FINGERPRINTS" "$BASELINE_FILE"
  fp_count=$(wc -l <"$BASELINE_FILE" | tr -d ' ')
  echo "Updated $BASELINE_FILE ($fp_count info fingerprints)"
  exit 0
fi

if [[ ! -f "$BASELINE_FILE" ]]; then
  echo "error: missing $BASELINE_FILE — run '$0 --update-info-baseline' once." >&2
  exit 1
fi

new_count=0
while IFS= read -r fp; do
  [[ -z "$fp" ]] && continue
  if ! grep -Fxq "$fp" "$BASELINE_FILE"; then
    echo "  $fp" >&2
    new_count=$((new_count + 1))
  fi
done <"$FINGERPRINTS"

if (( new_count > 0 )); then
  echo >&2
  echo "error: $new_count new info-level analyzer finding(s) not in baseline" >&2
  exit 1
fi

baseline_count=$(wc -l <"$BASELINE_FILE" | tr -d ' ')
current_count=$(wc -l <"$FINGERPRINTS" | tr -d ' ')
echo "OK (info baseline $baseline_count fingerprints, current $current_count)"
