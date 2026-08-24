#!/usr/bin/env bash
# Phase 3 V1 screen consolidation.
#
# Production `/record` and `/quick-capture` route through the live thin host
# at features/capture/screens/live_capture_host.dart. That host delegates to
# CaptureScreenHost (one widget) — it does not copy the retired adapter graph.
#
# This script is idempotent documentation: it rewrites leftover
# screens/record_screen.dart imports and refuses to recreate that barrel.
#
# Usage:
#   bash scripts/consolidate_v1_screens_phase3.sh
#   bash scripts/consolidate_v1_screens_phase3.sh --dry-run
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE="$ROOT/apps/mobile"
DRY_RUN=0

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

if [[ ! -d "$MOBILE/lib" ]]; then
  echo "error: expected $MOBILE/lib" >&2
  exit 1
fi

if [[ -L "$MOBILE/lib/features/capture_flow" ]]; then
  echo "OK  capture_flow remains a symlink"
else
  echo "error: features/capture_flow is not a symlink — refuse to continue" >&2
  exit 1
fi

if [[ -f "$MOBILE/lib/screens/record_screen.dart" ]]; then
  echo "WARN lib/screens/record_screen.dart still exists — delete after import rewrite"
else
  echo "OK  lib/screens/record_screen.dart already deleted"
fi

python3 - "$MOBILE" "$DRY_RUN" <<'PY'
import os
import sys

mobile, dry_run_s = sys.argv[1], sys.argv[2]
dry_run = dry_run_s == "1"

OLD = "package:archiveme_mobile/screens/record_screen.dart"
NEW = "package:archiveme_mobile/features/recording/recording_screen.dart"
SKIP_DIR_PARTS = {"retired_sprawl", ".dart_tool", "build", ".git"}

changed = 0
for root, dirs, files in os.walk(mobile):
    parts = set(root.split(os.sep))
    if parts & SKIP_DIR_PARTS:
        dirs[:] = []
        continue
    dirs[:] = [d for d in dirs if d not in SKIP_DIR_PARTS]
    for name in files:
        if not name.endswith(".dart"):
            continue
        path = os.path.join(root, name)
        rel = os.path.relpath(path, mobile).replace(os.sep, "/")
        try:
            text = open(path, encoding="utf-8").read()
        except OSError:
            continue
        if OLD not in text:
            continue
        print(f"REWRITE  {rel}")
        changed += 1
        if not dry_run:
            open(path, "w", encoding="utf-8").write(text.replace(OLD, NEW))

print(f"rewritten_files={changed}")
PY
