#!/usr/bin/env bash
# Design-token guard (Objective 5).
#
# Raw color literals (`Color(0x...)`, ad hoc `Colors.xyz`) are only allowed
# inside the authoritative palette/token definition directories
# (lib/theme/**, lib/design/**). Everywhere else, production code should
# reference a named token (AppColors.*, theme.colorScheme.*, etc.) so a
# color's semantic meaning (error/destructive/locked/proof-confidence/...)
# is documented once and reused everywhere.
#
# This repo currently has a large pre-existing backlog of raw literals
# (see docs/DESIGN_TOKEN_AUDIT.md for the full count/history), so this guard
# is a *ratchet*: it fails if the count goes UP from the checked-in baseline
# in tool/raw_color_baseline_count.txt, not if it's merely nonzero. Every
# screen you touch for other reasons should migrate its literals to tokens
# and lower the baseline; new files should not add new literals at all.
#
# Usage:
#   ./tool/validate_no_raw_colors.sh            # check against baseline
#   ./tool/validate_no_raw_colors.sh --update   # rewrite the baseline to the current count
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BASELINE_FILE="tool/raw_color_baseline_count.txt"
PATTERN='Color\(0x[0-9A-Fa-f]{6,8}\)|\bColors\.[a-zA-Z][a-zA-Z0-9]*'

current=$(
  rg -o -e "$PATTERN" lib --type dart \
    -g '!lib/theme/**' \
    -g '!lib/design/**' \
    | wc -l | tr -d ' '
)

if [[ "${1:-}" == "--update" ]]; then
  echo "$current" > "$BASELINE_FILE"
  echo "Updated $BASELINE_FILE to $current"
  exit 0
fi

if [[ ! -f "$BASELINE_FILE" ]]; then
  echo "error: missing $BASELINE_FILE — run '$0 --update' once to create it." >&2
  exit 1
fi

baseline=$(tr -d '[:space:]' < "$BASELINE_FILE")

echo "Raw color literals outside lib/theme|design: $current (baseline: $baseline)"

if (( current > baseline )); then
  echo >&2
  echo "error: raw color literal count increased ($baseline -> $current)." >&2
  echo "New/edited production code must use a named token from lib/theme/app_colors.dart" >&2
  echo "instead of a raw Color(0x...) or Colors.xyz literal. If you legitimately reduced" >&2
  echo "the count elsewhere in this change and are confident the increase is intentional" >&2
  echo "(e.g. adding a real new token constant), run:" >&2
  echo "  ./tool/validate_no_raw_colors.sh --update" >&2
  exit 1
fi

if (( current < baseline )); then
  echo "Count decreased ($baseline -> $current) — consider running with --update to lock in the improvement."
fi

echo "OK"
