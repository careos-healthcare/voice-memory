#!/usr/bin/env bash
# Run ArchiveMe mobile in 5-user activation trial mode (local-only, Record-first).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEVICE_ARGS=()
if [[ -n "${1:-}" ]]; then
  DEVICE_ARGS=(-d "$1")
fi

flutter run "${DEVICE_ARGS[@]}" \
  --dart-define=ARCHIVEME_TRIAL_MODE=true
