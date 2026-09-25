#!/usr/bin/env bash
# Build the public beta iOS IPA and Android App Bundle from the reviewed profile.
# Flags come from config/launch_profiles/beta_1.json, which matches apps/mobile/config/launch_profile.json.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${1:-$ROOT/config/launch_profiles/beta_1.json}"

if [[ ! -f "$PROFILE" ]]; then
  echo "Launch profile not found: $PROFILE" >&2
  exit 1
fi

cd "$ROOT/apps/mobile"

flutter build ipa --release --dart-define-from-file="$PROFILE"
flutter build appbundle --release --dart-define-from-file="$PROFILE"
