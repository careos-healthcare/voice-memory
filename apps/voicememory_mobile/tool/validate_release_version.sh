#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version_line="$(ruby -ne 'puts $1 if $_ =~ /^version:\s*(\S+)/' "$ROOT/pubspec.yaml")"

if [[ ! "$version_line" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[1-9][0-9]*$ ]]; then
  echo "pubspec.yaml must contain a release version like 1.2.3+45" >&2
  exit 1
fi

version_name="${version_line%%+*}"
build_number="${version_line##*+}"
if ! rg -q "expectedVersion = '$version_name'" \
    "$ROOT/lib/features/submission/app_store_submission_copy.dart"; then
  echo "AppStoreSubmissionCopy.expectedVersion does not match $version_name" >&2
  exit 1
fi
if ! rg -q "expectedBuildNumber = $build_number" \
    "$ROOT/lib/features/submission/app_store_submission_copy.dart"; then
  echo "AppStoreSubmissionCopy.expectedBuildNumber does not match $build_number" >&2
  exit 1
fi

echo "Release version valid: $version_line"
