#!/usr/bin/env bash
# Phase 2 V1 screen consolidation.
#
# 1) Rewrite package/relative/File() references from Phase-1 barrels to the
#    canonical destinations created in Phase 1.
# 2) Delete those one-line barrels once nothing production/test imports them.
# 3) Optionally copy GuestDataMigrationScreen into live features/auth/screens/.
#
# Does NOT promote capture_flow (compile graph is the whole retired module).
# Does NOT replace feature symlinks. Does NOT edit privacy_copy_policy.dart.
#
# Usage:
#   bash scripts/consolidate_v1_screens_phase2.sh
#   bash scripts/consolidate_v1_screens_phase2.sh --dry-run
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE="$ROOT/apps/mobile"
LIB="$MOBILE/lib"
DRY_RUN=0

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

if [[ ! -d "$LIB" ]]; then
  echo "error: expected $LIB" >&2
  exit 1
fi

echo "Phase 2 V1 screen consolidation (dry_run=$DRY_RUN)"
echo "mobile: $MOBILE"
echo

python3 - "$MOBILE" "$DRY_RUN" <<'PY'
import os
import sys

mobile, dry_run_s = sys.argv[1], sys.argv[2]
dry_run = dry_run_s == "1"

# old_rel (under lib/) -> dest_rel (under lib/)
# Longer keys first when substituting so onboarding/backlog wins over onboarding.
BARREL_MAP = {
    "screens/onboarding/backlog_import_screen.dart":
        "features/onboarding/screens/backlog_import_screen.dart",
    "screens/onboarding_screen.dart":
        "features/onboarding/screens/onboarding_screen.dart",
    "screens/archive_belief_screen.dart":
        "features/archive/screens/archive_belief_screen.dart",
    "screens/entry_detail_screen.dart":
        "features/archive/screens/entry_detail_screen.dart",
    "screens/beliefs_screen.dart":
        "features/archive/screens/beliefs_screen.dart",
    "screens/belief_detail_screen.dart":
        "features/archive/screens/belief_detail_screen.dart",
    "screens/sample_archive_context_screen.dart":
        "features/archive/screens/sample_archive_context_screen.dart",
    "screens/belief_changes_screen.dart":
        "features/belief_changes/screens/belief_changes_screen.dart",
    "screens/belief_evidence_screen.dart":
        "features/belief_evidence/screens/belief_evidence_screen.dart",
    "screens/archive_evidence_context_screen.dart":
        "features/belief_evidence/screens/archive_evidence_context_screen.dart",
    "screens/account_screen.dart":
        "features/auth/screens/account_screen.dart",
    "screens/account_auth_screen.dart":
        "features/auth/screens/account_auth_screen.dart",
    "screens/delete_account_screen.dart":
        "features/auth/screens/delete_account_screen.dart",
    "screens/settings_screen.dart":
        "features/settings/screens/settings_screen.dart",
    "screens/security_settings_screen.dart":
        "features/settings/screens/security_settings_screen.dart",
    "screens/export_screen.dart":
        "features/settings/screens/export_screen.dart",
    "screens/journal_bulk_export_screen.dart":
        "features/settings/screens/journal_bulk_export_screen.dart",
    "screens/memory_transparency_screen.dart":
        "features/settings/screens/memory_transparency_screen.dart",
    "screens/consent_audit_screen.dart":
        "features/settings/screens/consent_audit_screen.dart",
    "screens/about_screen.dart":
        "features/settings/screens/about_screen.dart",
    "screens/support_feedback_screen.dart":
        "features/settings/screens/support_feedback_screen.dart",
    "screens/terms_screen.dart":
        "features/settings/screens/terms_screen.dart",
    "screens/privacy_screen.dart":
        "features/settings/screens/privacy_screen.dart",
    "screens/paywall_screen.dart":
        "billing/screens/paywall_screen.dart",
    "screens/pricing_screen.dart":
        "billing/screens/pricing_screen.dart",
    "screens/restore_purchases_screen.dart":
        "billing/screens/restore_purchases_screen.dart",
    "screens/billing_settings_screen.dart":
        "billing/screens/billing_settings_screen.dart",
    "screens/revenuecat_verification_screen.dart":
        "billing/screens/revenuecat_verification_screen.dart",
    "screens/quick_text_capture_screen.dart":
        "features/capture/screens/legacy/quick_text_capture_screen.dart",
    "ui/screens/settings/privacy_security_screen.dart":
        "features/settings/screens/privacy_security_screen.dart",
    "widgets/account/privacy_trust_centre_screen.dart":
        "features/settings/ui/privacy_trust_centre_screen.dart",
    "widgets/security/setup_pin_screen.dart":
        "features/settings/security/setup_pin_screen.dart",
    "widgets/security/app_lock_screen.dart":
        "features/settings/security/app_lock_screen.dart",
    "security/secure_database_unlock_screen.dart":
        "features/auth/security/secure_database_unlock_screen.dart",
    "features/caregiver_grant/caregiver_grant_disclosure_screen.dart":
        "features/caregiver_grant/screens/caregiver_grant_disclosure_screen.dart",
}

# Barrels we keep on disk even after import rewrite.
KEEP_BARREL_RELS = {
    "screens/record_screen.dart",
    "screens/offline_sync_verification_screen.dart",
    "screens/live_voice_session_screen.dart",
    "screens/comparison_engine_screen.dart",
    # privacy_copy_policy.dart still lists this path; that file is frozen.
    "screens/privacy_screen.dart",
}

SKIP_REWRITE_FILES = {
    "lib/security/privacy_copy_policy.dart",
}

SKIP_DIR_PARTS = {
    "retired_sprawl",
    ".dart_tool",
    "build",
    ".git",
}

# Longest old_rel first to avoid prefix collisions.
ORDERED = sorted(BARREL_MAP.items(), key=lambda kv: -len(kv[0]))


def is_barrel_file(path):
    try:
        with open(path, encoding="utf-8") as f:
            raw = f.read()
    except OSError:
        return False
    if os.path.islink(path):
        return False
    lines = [ln for ln in raw.splitlines() if ln.strip()]
    exports = sum(1 for ln in lines if ln.startswith("export "))
    imports = sum(1 for ln in lines if ln.startswith("import "))
    return exports >= 1 and imports == 0 and len(lines) <= 8


def should_skip_dir(dirpath):
    parts = set(dirpath.split(os.sep))
    return bool(parts & SKIP_DIR_PARTS)


def rewrite_text(text):
    changed = 0
    for old_rel, dest_rel in ORDERED:
        pkg_old = f"package:archiveme_mobile/{old_rel}"
        pkg_new = f"package:archiveme_mobile/{dest_rel}"
        if pkg_old in text:
            n = text.count(pkg_old)
            text = text.replace(pkg_old, pkg_new)
            changed += n
        lib_old = f"lib/{old_rel}"
        lib_new = f"lib/{dest_rel}"
        if lib_old in text:
            n = text.count(lib_old)
            text = text.replace(lib_old, lib_new)
            changed += n
    return text, changed


rewrite_files = 0
rewrite_hits = 0
skipped_policy = 0

for root, dirs, files in os.walk(mobile):
    if should_skip_dir(root):
        dirs[:] = []
        continue
    dirs[:] = [d for d in dirs if d not in SKIP_DIR_PARTS]
    for name in files:
        if not name.endswith(".dart"):
            continue
        path = os.path.join(root, name)
        rel = os.path.relpath(path, mobile).replace(os.sep, "/")
        if rel in SKIP_REWRITE_FILES:
            skipped_policy += 1
            continue
        # Do not rewrite the barrel files themselves.
        lib_rel = rel[4:] if rel.startswith("lib/") else None
        if lib_rel in BARREL_MAP and is_barrel_file(path):
            continue
        try:
            with open(path, encoding="utf-8") as f:
                original = f.read()
        except OSError:
            continue
        updated, hits = rewrite_text(original)
        if hits == 0:
            continue
        rewrite_files += 1
        rewrite_hits += hits
        print(f"REWRITE  {rel}  ({hits})")
        if not dry_run:
            with open(path, "w", encoding="utf-8") as f:
                f.write(updated)

print()
print(f"rewritten_files={rewrite_files} replacement_hits={rewrite_hits} skipped_policy={skipped_policy}")
print()

deleted = 0
kept = 0
missing = 0
for old_rel in BARREL_MAP:
    path = os.path.join(mobile, "lib", old_rel)
    if old_rel in KEEP_BARREL_RELS:
        if os.path.isfile(path):
            print(f"KEEP    lib/{old_rel}")
            kept += 1
        else:
            print(f"MISSING lib/{old_rel} (keep-list)")
            missing += 1
        continue
    if not os.path.isfile(path):
        print(f"SKIP    lib/{old_rel}  (already gone)")
        continue
    if not is_barrel_file(path):
        print(f"REFUSE  lib/{old_rel}  (not a one-line barrel)")
        continue
    print(f"DELETE  lib/{old_rel}")
    deleted += 1
    if not dry_run:
        os.remove(path)

print()
print(f"deleted_barrels={deleted} kept_barrels={kept} missing_keep={missing}")
PY

# --- GuestDataMigrationScreen: copy out of the account_migration symlink ---
# Never write through the symlink. Coordinator stays imported from the
# existing retired module (already used by live settings).
GUEST_SRC="$MOBILE/retired_sprawl/lib_features/account_migration/guest_data_migration_screen.dart"
GUEST_DEST="$LIB/features/auth/screens/guest_data_migration_screen.dart"
echo
if [[ ! -L "$LIB/features/account_migration" ]]; then
  echo "REFUSE: features/account_migration is not a symlink — skip guest copy" >&2
elif [[ ! -f "$GUEST_SRC" ]]; then
  echo "REFUSE: guest source missing: $GUEST_SRC" >&2
elif [[ -e "$GUEST_DEST" ]]; then
  echo "SKIP  guest_data_migration_screen.dart  (already at features/auth/screens/)"
else
  echo "COPY  retired account_migration/guest_data_migration_screen.dart -> features/auth/screens/"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    cp "$GUEST_SRC" "$GUEST_DEST"
  fi
fi

# Capture promotion is intentionally omitted: CaptureScreen pulls the entire
# 22-file capture_flow graph (controller, adapters, panels, cards).
echo
echo "capture_flow promotion: BLOCKED (full retired compile graph)"
echo "record_screen.dart remains a barrel to capture_flow + recording"
