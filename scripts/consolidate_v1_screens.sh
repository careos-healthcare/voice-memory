#!/usr/bin/env bash
# Phase 1 V1 screen consolidation.
#
# Moves real screen files into the 14 live feature dirs (or lib/billing/screens/)
# and leaves a one-line package-export barrel at the old path.
#
# Idempotent: already-moved pairs are skipped. Refuses to clobber an existing
# destination. Never writes into a symlink feature dir, never creates a 15th
# feature, and never copies a symlink target (capture_flow / account_migration).
#
# Usage (from repo root or anywhere):
#   bash scripts/consolidate_v1_screens.sh
#   bash scripts/consolidate_v1_screens.sh --dry-run
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT/apps/mobile/lib"
DRY_RUN=0
MOVED=0
SKIPPED=0
FAILED=0

LIVE_FEATURES='archive auth belief_changes belief_evidence capture caregiver_grant fact_ledger insights onboarding quick_capture record search settings sync'

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

if [[ ! -d "$LIB" ]]; then
  echo "error: expected $LIB" >&2
  exit 1
fi

is_live_feature() {
  local name="$1"
  case " $LIVE_FEATURES " in
    *" $name "*) return 0 ;;
    *) return 1 ;;
  esac
}

is_barrel() {
  local file="$1"
  [[ -f "$file" && ! -L "$file" ]] || return 1
  local exports imports lines
  exports="$(grep -c '^export ' "$file" || true)"
  imports="$(grep -c '^import ' "$file" || true)"
  lines="$(grep -cve '^[[:space:]]*$' "$file" || true)"
  [[ "$exports" -ge 1 && "$imports" -eq 0 && "$lines" -le 8 ]]
}

barrel_points_at() {
  local file="$1"
  local dest_rel="$2"
  grep -q "package:archiveme_mobile/${dest_rel}" "$file"
}

assert_dest_allowed() {
  local dest_rel="$1"
  if [[ "$dest_rel" == features/* ]]; then
    local feat
    feat="$(echo "$dest_rel" | awk -F/ '{print $2}')"
    if ! is_live_feature "$feat"; then
      echo "REFUSE: destination would create/use non-live feature '$feat'" >&2
      return 1
    fi
    if [[ -L "$LIB/features/$feat" ]]; then
      echo "REFUSE: features/$feat is a symlink — will not write through it" >&2
      return 1
    fi
    if [[ ! -d "$LIB/features/$feat" ]]; then
      echo "REFUSE: live feature dir missing: features/$feat" >&2
      return 1
    fi
  elif [[ "$dest_rel" == billing/* ]]; then
    if [[ -L "$LIB/billing" ]]; then
      echo "REFUSE: lib/billing is a symlink" >&2
      return 1
    fi
    if [[ ! -d "$LIB/billing" ]]; then
      echo "REFUSE: lib/billing is missing" >&2
      return 1
    fi
  else
    echo "REFUSE: destination not under features/ or billing/: $dest_rel" >&2
    return 1
  fi
}

write_barrel() {
  local src_abs="$1"
  local dest_rel="$2"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  barrel  $src_abs -> package:archiveme_mobile/${dest_rel}"
    return 0
  fi
  printf "export 'package:archiveme_mobile/%s';\n" "$dest_rel" > "$src_abs"
}

move_one() {
  local src_rel="$1"
  local dest_rel="$2"
  local src_abs="$LIB/$src_rel"
  local dest_abs="$LIB/$dest_rel"

  if ! assert_dest_allowed "$dest_rel"; then
    FAILED=$((FAILED + 1))
    return 1
  fi

  if [[ -L "$src_abs" ]]; then
    echo "SKIP  $src_rel  (source is a symlink — will not promote target)"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi

  if [[ -e "$dest_abs" ]]; then
    if [[ -L "$dest_abs" ]]; then
      echo "REFUSE: destination is a symlink: $dest_rel" >&2
      FAILED=$((FAILED + 1))
      return 1
    fi
    if [[ -f "$src_abs" ]] && is_barrel "$src_abs" && barrel_points_at "$src_abs" "$dest_rel"; then
      echo "SKIP  $src_rel  (already barreled to $dest_rel)"
      SKIPPED=$((SKIPPED + 1))
      return 0
    fi
    if [[ ! -e "$src_abs" ]]; then
      echo "SKIP  $src_rel  (already at $dest_rel, source gone)"
      SKIPPED=$((SKIPPED + 1))
      return 0
    fi
    echo "REFUSE: would clobber existing $dest_rel" >&2
    FAILED=$((FAILED + 1))
    return 1
  fi

  if [[ ! -f "$src_abs" ]]; then
    echo "error: source missing: $src_rel" >&2
    FAILED=$((FAILED + 1))
    return 1
  fi

  if is_barrel "$src_abs"; then
    echo "SKIP  $src_rel  (already a barrel; not copying)"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi

  echo "MOVE  $src_rel -> $dest_rel"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    MOVED=$((MOVED + 1))
    return 0
  fi

  mkdir -p "$(dirname "$dest_abs")"
  if command -v git >/dev/null && git -C "$ROOT" ls-files --error-unmatch "$LIB/$src_rel" >/dev/null 2>&1; then
    git -C "$ROOT" mv "$src_abs" "$dest_abs"
  else
    mv "$src_abs" "$dest_abs"
  fi
  write_barrel "$src_abs" "$dest_rel"
  MOVED=$((MOVED + 1))
}

echo "Phase 1 V1 screen consolidation (dry_run=$DRY_RUN)"
echo "lib: $LIB"
echo

# --- onboarding ---
move_one screens/onboarding_screen.dart \
  features/onboarding/screens/onboarding_screen.dart
move_one screens/onboarding/backlog_import_screen.dart \
  features/onboarding/screens/backlog_import_screen.dart

# --- archive ---
move_one screens/archive_belief_screen.dart \
  features/archive/screens/archive_belief_screen.dart
move_one screens/entry_detail_screen.dart \
  features/archive/screens/entry_detail_screen.dart
move_one screens/beliefs_screen.dart \
  features/archive/screens/beliefs_screen.dart
move_one screens/belief_detail_screen.dart \
  features/archive/screens/belief_detail_screen.dart
move_one screens/sample_archive_context_screen.dart \
  features/archive/screens/sample_archive_context_screen.dart

# --- belief_changes ---
move_one screens/belief_changes_screen.dart \
  features/belief_changes/screens/belief_changes_screen.dart

# --- belief_evidence ---
move_one screens/belief_evidence_screen.dart \
  features/belief_evidence/screens/belief_evidence_screen.dart
move_one screens/archive_evidence_context_screen.dart \
  features/belief_evidence/screens/archive_evidence_context_screen.dart

# --- auth ---
move_one screens/account_screen.dart \
  features/auth/screens/account_screen.dart
move_one screens/account_auth_screen.dart \
  features/auth/screens/account_auth_screen.dart
move_one screens/delete_account_screen.dart \
  features/auth/screens/delete_account_screen.dart

# --- settings ---
move_one screens/settings_screen.dart \
  features/settings/screens/settings_screen.dart
move_one screens/security_settings_screen.dart \
  features/settings/screens/security_settings_screen.dart
move_one screens/export_screen.dart \
  features/settings/screens/export_screen.dart
move_one screens/journal_bulk_export_screen.dart \
  features/settings/screens/journal_bulk_export_screen.dart
move_one screens/memory_transparency_screen.dart \
  features/settings/screens/memory_transparency_screen.dart
move_one screens/consent_audit_screen.dart \
  features/settings/screens/consent_audit_screen.dart
move_one screens/about_screen.dart \
  features/settings/screens/about_screen.dart
move_one screens/support_feedback_screen.dart \
  features/settings/screens/support_feedback_screen.dart
move_one screens/terms_screen.dart \
  features/settings/screens/terms_screen.dart
move_one screens/privacy_screen.dart \
  features/settings/screens/privacy_screen.dart

# --- billing (NOT features/paywall or features/billing) ---
move_one screens/paywall_screen.dart \
  billing/screens/paywall_screen.dart
move_one screens/pricing_screen.dart \
  billing/screens/pricing_screen.dart
move_one screens/restore_purchases_screen.dart \
  billing/screens/restore_purchases_screen.dart
move_one screens/billing_settings_screen.dart \
  billing/screens/billing_settings_screen.dart
move_one screens/revenuecat_verification_screen.dart \
  billing/screens/revenuecat_verification_screen.dart

# --- capture UI already living as a real file (legacy / blocked) ---
move_one screens/quick_text_capture_screen.dart \
  features/capture/screens/legacy/quick_text_capture_screen.dart

# --- cheap collapses already proposed ---
move_one ui/screens/settings/privacy_security_screen.dart \
  features/settings/screens/privacy_security_screen.dart
move_one widgets/account/privacy_trust_centre_screen.dart \
  features/settings/ui/privacy_trust_centre_screen.dart
move_one widgets/security/setup_pin_screen.dart \
  features/settings/security/setup_pin_screen.dart
move_one widgets/security/app_lock_screen.dart \
  features/settings/security/app_lock_screen.dart
move_one security/secure_database_unlock_screen.dart \
  features/auth/security/secure_database_unlock_screen.dart
move_one features/caregiver_grant/caregiver_grant_disclosure_screen.dart \
  features/caregiver_grant/screens/caregiver_grant_disclosure_screen.dart

echo
echo "moved=$MOVED skipped=$SKIPPED failed=$FAILED"
echo
echo "Intentionally left in lib/screens/:"
echo "  record_screen.dart (barrel → capture_flow / recording; no symlink promotion)"
echo "  offline_sync_verification_screen.dart (already barreled → features/sync/screens/)"
echo "  live_voice_session_screen.dart (quarantined / unrouted)"
echo "  comparison_engine_screen.dart (quarantined / unrouted)"

if [[ "$FAILED" -ne 0 ]]; then
  exit 1
fi
