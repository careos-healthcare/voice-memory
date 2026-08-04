#!/usr/bin/env bash
#
# Fast, diff-aware V1 release checks.
#
# Looks at what actually changed, formats those Dart files, runs only the
# focused suites for the affected retained areas, then the architecture guards.
# TypeScript checks run only when backend files changed.
#
# A timeout is a failure. This script never reports one as a pass.
#
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_APP="$REPO_ROOT/apps/voicememory_mobile"
LOG_DIR="$REPO_ROOT/artifacts/fast-v1-checks"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/$RUN_ID.log"

# Per-suite ceiling in seconds. Tune with FAST_V1_TIMEOUT.
SUITE_TIMEOUT="${FAST_V1_TIMEOUT:-600}"

mkdir -p "$LOG_DIR"

FAILURES=()

log() { printf '%s\n' "$*" | tee -a "$LOG_FILE"; }
section() { log ""; log "=== $* ==="; }

# Portable timeout: prefer coreutils, fall back to a background watchdog.
run_with_timeout() {
  local seconds="$1"; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout --preserve-status "$seconds" "$@"
    return $?
  fi
  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout --preserve-status "$seconds" "$@"
    return $?
  fi
  "$@" &
  local pid=$!
  ( sleep "$seconds"; kill -9 "$pid" 2>/dev/null ) &
  local watchdog=$!
  wait "$pid"
  local status=$?
  kill "$watchdog" 2>/dev/null
  wait "$watchdog" 2>/dev/null
  return $status
}

# Runs a command, records failure, and distinguishes a timeout from a fail.
guard() {
  local name="$1"; shift
  section "$name"
  local output
  output="$(run_with_timeout "$SUITE_TIMEOUT" "$@" 2>&1)"
  local status=$?
  printf '%s\n' "$output" >>"$LOG_FILE"
  if [[ $status -eq 124 || $status -eq 137 ]]; then
    log "TIMEOUT after ${SUITE_TIMEOUT}s: $name"
    FAILURES+=("$name (TIMEOUT)")
    return 1
  fi
  # A Dart/Flutter test host that dies during loading exits non-zero but can
  # still print a success-looking tail. Treat loader breakage as a failure.
  if printf '%s' "$output" | grep -qiE 'Failed to load|loading .* failed|Compilation failed|Unhandled exception'; then
    log "LOADER ERROR: $name"
    FAILURES+=("$name (LOADER ERROR)")
    return 1
  fi
  if [[ $status -ne 0 ]]; then
    log "FAIL ($status): $name"
    printf '%s\n' "$output" | tail -n 30 | tee -a "$LOG_FILE" >/dev/null
    FAILURES+=("$name")
    return 1
  fi
  log "PASS: $name"
  return 0
}

cd "$REPO_ROOT"

section "changed files"
CHANGED="$(git status --porcelain=v1 | awk '{ $1=""; sub(/^ +/, ""); print }' | sed 's/.* -> //')"
if [[ -z "$CHANGED" ]]; then
  CHANGED="$(git diff --name-only HEAD~1 2>/dev/null || true)"
fi
printf '%s\n' "$CHANGED" | tee -a "$LOG_FILE"

CHANGED_DART=()
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  [[ "$path" == *.dart ]] || continue
  [[ -f "$REPO_ROOT/$path" ]] || continue
  CHANGED_DART+=("$REPO_ROOT/$path")
done <<<"$CHANGED"

BACKEND_CHANGED=0
FLUTTER_CHANGED=0
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  case "$path" in
    app/api/*|lib/server/*|lib/sync/*|scripts/*|config/*|package.json|tsconfig.json|next.config.ts)
      BACKEND_CHANGED=1 ;;
    apps/voicememory_mobile/*) FLUTTER_CHANGED=1 ;;
  esac
done <<<"$CHANGED"

section "format changed Dart files"
if [[ ${#CHANGED_DART[@]} -gt 0 ]]; then
  (cd "$FLUTTER_APP" && dart format "${CHANGED_DART[@]}") | tee -a "$LOG_FILE"
else
  log "No changed Dart files."
fi

# Maps a changed path to the focused suites that cover it.
declare -a SUITES=()
add_suite() {
  local suite="$1"
  [[ -f "$FLUTTER_APP/$suite" ]] || return 0
  for existing in "${SUITES[@]:-}"; do
    [[ "$existing" == "$suite" ]] && return 0
  done
  SUITES+=("$suite")
}

while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  case "$path" in
    *storage/journal_store.dart|*archive_ownership/*|*journal/migration/*|*sync_service.dart|*composition/account_services.dart)
      add_suite "test/archive_account_isolation_test.dart"
      add_suite "test/archive_ownership_decision_sheet_test.dart"
      add_suite "test/sync_service_test.dart"
      add_suite "test/journal_store_test.dart" ;;
  esac
  case "$path" in
    *explainable_conclusion/*|*post_save_experience_coordinator.dart)
      add_suite "test/semantic_conclusion_gate_test.dart"
      add_suite "test/auditable_personal_change_test.dart"
      add_suite "test/explainable_conclusion_validator_v1_test.dart"
      add_suite "test/post_save_experience_coordinator_test.dart" ;;
  esac
  case "$path" in
    *features/changes/*|*belief_changes_screen.dart)
      add_suite "test/change_thread_projection_test.dart"
      add_suite "test/change_thread_ui_test.dart"
      add_suite "test/belief_changes_screen_v1_test.dart" ;;
  esac
  case "$path" in
    *features/weekly_review/*) add_suite "test/weekly_review_test.dart" ;;
  esac
  case "$path" in
    *voice_capture/*|*recording_state_controller.dart|*audio_vault*)
      add_suite "test/capture_pipeline_audio_vault_test.dart"
      add_suite "test/temp_recording_cleanup_test.dart" ;;
  esac
  case "$path" in
    *features/recording/*|*post_capture*|*processing_preferences/*)
      add_suite "test/post_capture_disposition_test.dart"
      add_suite "test/journal_audio_security_test.dart"
      add_suite "test/ai_processing_controls_test.dart" ;;
  esac
  case "$path" in
    *features/performance/*|*startup/*|*main.dart|*composition/*)
      add_suite "test/capture_performance_test.dart"
      add_suite "test/cold_start_service_gating_test.dart" ;;
  esac
  case "$path" in
    *features/adaptive_question/*) add_suite "test/adaptive_question_test.dart" ;;
  esac
  case "$path" in
    *features/structured_markers/*) add_suite "test/structured_markers_test.dart" ;;
  esac
  case "$path" in
    *widgets/record/*) add_suite "test/evidence_card_test.dart" ;;
  esac
  case "$path" in
    *archive_export/*|*private_data_service.dart|*export_screen.dart)
      add_suite "test/export_round_trip_test.dart"
      add_suite "test/private_data_service_test.dart" ;;
  esac
  case "$path" in
    *features/product_metrics/*|*analytics/*)
      add_suite "test/product_metrics_test.dart"
      add_suite "test/product_analytics_test.dart"
      add_suite "test/analytics_source_audit_test.dart" ;;
  esac
  case "$path" in
    *features/study_mode/*) add_suite "test/study_mode_test.dart" ;;
  esac
  case "$path" in
    *monetization/*|*subscriptions/*|*paywall*) add_suite "test/access_policy_engine_test.dart" ;;
  esac
  # Consumer-visible copy is guarded centrally; any surface edit must clear it.
  case "$path" in
    *copy/*|*onboarding/*|*_copy.dart|*product_contract.dart)
      add_suite "test/consumer_copy_banned_words_test.dart"
      add_suite "test/product_positioning_copy_test.dart"
      add_suite "test/privacy_copy_policy_test.dart" ;;
  esac
  case "$path" in
    *theme/*|*widgets/*|*screens/*)
      add_suite "test/archive_ownership_decision_sheet_test.dart"
      add_suite "test/accessibility_matrix_test.dart" ;;
  esac
done <<<"$CHANGED"

section "focused Flutter suites"
if [[ ${#SUITES[@]} -gt 0 ]]; then
  log "Selected: ${SUITES[*]}"
  ( cd "$FLUTTER_APP" && exec flutter test "${SUITES[@]}" --reporter=compact ) >/tmp/fast_v1_focused.log 2>&1 &
  focused_pid=$!
  wait "$focused_pid"
  focused_status=$?
  cat /tmp/fast_v1_focused.log >>"$LOG_FILE"
  if [[ $focused_status -ne 0 ]]; then
    log "FAIL: focused Flutter suites"
    tail -n 40 /tmp/fast_v1_focused.log | tee -a "$LOG_FILE" >/dev/null
    FAILURES+=("focused Flutter suites")
  else
    log "PASS: focused Flutter suites"
  fi
elif [[ $FLUTTER_CHANGED -eq 1 ]]; then
  log "Flutter changed but no mapped suite; running analyze only."
else
  log "No Flutter changes."
fi

if [[ $FLUTTER_CHANGED -eq 1 ]]; then
  guard "flutter analyze" bash -c "cd '$FLUTTER_APP' && flutter analyze --no-fatal-infos"
fi

section "architecture guards"
if [[ -f "$REPO_ROOT/scripts/check-backend-allowlist.mjs" ]]; then
  guard "backend route allowlist" node "$REPO_ROOT/scripts/check-backend-allowlist.mjs"
else
  log "SKIP: scripts/check-backend-allowlist.mjs not present."
fi
if [[ -f "$REPO_ROOT/scripts/check-release-identity.mjs" ]]; then
  guard "release identity" node "$REPO_ROOT/scripts/check-release-identity.mjs"
else
  log "SKIP: scripts/check-release-identity.mjs not present."
fi
if [[ -f "$REPO_ROOT/scripts/owner-scope-guard.test.ts" ]]; then
  guard "owner scope guard" npm run --silent test:owner-scope-guard
fi
if [[ -f "$REPO_ROOT/scripts/validate-archive-me-v1-capabilities.mjs" ]]; then
  guard "V1 capability contract" node "$REPO_ROOT/scripts/validate-archive-me-v1-capabilities.mjs"
fi
if [[ -f "$REPO_ROOT/scripts/validate-archive-me-v1-anti-features.mjs" ]]; then
  guard "V1 anti-feature contract" node "$REPO_ROOT/scripts/validate-archive-me-v1-anti-features.mjs"
fi

if [[ $BACKEND_CHANGED -eq 1 ]]; then
  guard "typescript" npx --no-install tsc --noEmit
  guard "eslint" npm run --silent lint
else
  section "backend"
  log "No backend changes; TypeScript checks skipped."
fi

section "result"
log "Log: $LOG_FILE"
if [[ ${#FAILURES[@]} -gt 0 ]]; then
  log "FAILED (${#FAILURES[@]}):"
  for failure in "${FAILURES[@]}"; do log "  - $failure"; done
  exit 1
fi
log "All selected checks passed."
exit 0
