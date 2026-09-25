#!/usr/bin/env bash
# Refresh Flutter golden images for the release suite.
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/apps/mobile"

flutter test test/release/ --update-goldens
echo "ACTION REQUIRED: Open the failures/ directory and visually review each image before committing."
