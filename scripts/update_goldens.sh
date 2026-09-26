#!/usr/bin/env bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/apps/mobile"

flutter test test/release/
status=$?
failures="$ROOT/apps/mobile/test/release/failures/"
echo "$failures"
read -r confirm
if [ "$confirm" = "yes" ]; then
  flutter test test/release/ --update-goldens
  rm -rf test/release/failures
else
  exit "$status"
fi
