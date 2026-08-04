#!/usr/bin/env bash
#
# ArchiveMe — App Store readiness check.
#
# Runs analyze + the critical test set, then verifies that screenshot/trial
# modes are not hardcoded on, required docs exist, and Info-Release.plist carries the
# microphone permission string. Exits non-zero if any check fails.
#
# Usage:  ./tool/run_app_store_readiness_check.sh
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

# 2. Critical tests
TESTS=(
  test/critical_consumer_flow_test.dart
  test/trial_reset_full_clear_test.dart
  test/consumer_copy_banned_words_test.dart
  test/screenshot_mode_test.dart
  test/light_theme_enforcement_test.dart
  test/app_router_guards_test.dart
)
for t in "${TESTS[@]}"; do
  if [[ -f "$t" ]]; then
    run_step "flutter test $t" flutter test "$t"
  else
    section "flutter test $t"; fail "missing test file: $t"
  fi
done

# 3. Screenshot / trial mode are not hardcoded on
section "screenshot/trial mode not hardcoded on"
if grep -Eqs "VOICE_MEMORY_SCREENSHOT_MODE'[^)]*defaultValue:[[:space:]]*true" lib/config/screenshot_mode.dart; then
  fail "ScreenshotMode default is true"
else
  pass "ScreenshotMode default is false"
fi
if grep -Eqs "ARCHIVEME_TRIAL_MODE'[^)]*defaultValue:[[:space:]]*true" lib/config/trial_mode.dart; then
  fail "TrialMode default is true"
else
  pass "TrialMode default is false"
fi

# 4. Required docs exist
section "required docs exist"
for d in \
  docs/APP_STORE_COPY.md \
  docs/PRIVACY_CHECKLIST.md \
  docs/APP_REVIEW_NOTES.md \
  docs/SCREENSHOT_CAPTURE_PLAN.md; do
  if [[ -f "$d" ]]; then pass "$d"; else fail "missing doc: $d"; fi
done

# 5. Release Info.plist permission strings
section "Info-Release.plist permission strings"
if grep -q "NSMicrophoneUsageDescription" ios/Runner/Info-Release.plist; then
  pass "NSMicrophoneUsageDescription present"
else
  fail "NSMicrophoneUsageDescription missing"
fi

# Summary
section "summary"
if [[ "$FAILURES" -eq 0 ]]; then
  echo "All readiness checks passed."
  exit 0
else
  echo "$FAILURES readiness check(s) failed."
  exit 1
fi
