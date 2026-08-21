#!/usr/bin/env bash
#
# ArchiveMe — trial execution sanity check.
#
# Confirms the loop-critical tests pass and the trial-run docs exist before a
# real 5-user trial. Exits non-zero if any check fails.
#
# Usage:  ./tool/run_trial_execution_check.sh
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

FAILURES=0
section() { printf '\n=== %s ===\n' "$1"; }
pass()    { printf '  [PASS] %s\n' "$1"; }
fail()    { printf '  [FAIL] %s\n' "$1"; FAILURES=$((FAILURES + 1)); }

run_step() {
  local label="$1"; shift
  section "$label"
  if "$@"; then pass "$label"; else fail "$label"; fi
}

# 1. Static analysis
run_step "flutter analyze lib/" flutter analyze lib/

# 2. Loop-critical tests
TESTS=(
  test/critical_consumer_flow_test.dart
  test/trial_reset_full_clear_test.dart
  test/trial_summary_engine_test.dart
  test/trial_summary_exporter_test.dart
  test/consumer_copy_banned_words_test.dart
  test/app_router_guards_test.dart
)
for t in "${TESTS[@]}"; do
  if [[ -f "$t" ]]; then
    run_step "flutter test $t" flutter test "$t"
  else
    section "flutter test $t"; fail "missing test file: $t"
  fi
done

# 3. Required trial docs exist
section "required trial docs exist"
for d in \
  docs/TRIAL_EXECUTION_RUNBOOK.md \
  docs/TRIAL_OBSERVATION_TEMPLATE.md \
  docs/TRIAL_DECISION_RULES.md; do
  if [[ -f "$d" ]]; then pass "$d"; else fail "missing doc: $d"; fi
done

# Summary
section "summary"
if [[ "$FAILURES" -eq 0 ]]; then
  echo "All trial execution checks passed."
  exit 0
else
  echo "$FAILURES trial execution check(s) failed."
  exit 1
fi
