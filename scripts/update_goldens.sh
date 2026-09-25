#!/usr/bin/env bash
# Refresh Flutter golden images after a recording-screen change.
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/apps/mobile"

echo "Review the images in failures/ visually before committing to ensure the new recording redesign is captured."
flutter test --update-goldens
