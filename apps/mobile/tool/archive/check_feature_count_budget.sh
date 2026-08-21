#!/usr/bin/env bash
# Fails when lib/features top-level module count grows without updating the budget.
#
# Decrease .feature_count_budget when modules are removed/consolidated.
# Increase it only deliberately when a new module is approved (net consolidation
# should still trend down over time).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUDGET_FILE=".feature_count_budget"
if [[ ! -f "$BUDGET_FILE" ]]; then
  echo "FAIL: missing $BUDGET_FILE (expected baseline feature dir count)" >&2
  exit 1
fi

BUDGET="$(tr -d '[:space:]' <"$BUDGET_FILE")"
CURRENT="$(find lib/features -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d '[:space:]')"

echo "Feature module count: current=$CURRENT budget=$BUDGET"

if (( CURRENT > BUDGET )); then
  echo "FAIL: net new feature dir added without consolidation (current $CURRENT > budget $BUDGET)" >&2
  echo "Remove or attic a module, or bump $BUDGET_FILE with justification." >&2
  exit 1
fi

if (( CURRENT < BUDGET )); then
  echo "NOTE: count dropped ($CURRENT < $BUDGET). Update $BUDGET_FILE to ratchet the budget down."
fi

echo "OK: feature count within budget"
