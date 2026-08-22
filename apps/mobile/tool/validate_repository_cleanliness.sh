#!/usr/bin/env bash
# Records Git status, runs a test command, and fails if the working tree changed.
#
# Usage:
#   bash tool/validate_repository_cleanliness.sh [--] [flutter test args...]
#
# Default command: focused V1 + delete-account + privacy tests.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$APP_DIR/../.." && pwd)"

cd "$APP_DIR"

status_file="$(mktemp)"
trap 'rm -f "$status_file"' EXIT

git -C "$REPO_ROOT" status --porcelain=v1 -uall >"$status_file"

if (("$#" > 0)); then
  if [[ "${1:-}" == "--" ]]; then
    shift
  fi
  TEST_CMD=(flutter test "$@")
else
  TEST_CMD=(
    flutter test
    test/delete_account_confirmation_test.dart
    test/privacy_copy_policy_test.dart
    test/v1_navigation_guard_test.dart
    test/v1_router_graph_reduction_test.dart
    test/v1_record_controllers_wiring_test.dart
    test/privacy_contract_test.dart
  )
fi

echo "==> repository cleanliness: running ${TEST_CMD[*]}"
"${TEST_CMD[@]}"

after_file="$(mktemp)"
trap 'rm -f "$status_file" "$after_file"' EXIT
git -C "$REPO_ROOT" status --porcelain=v1 -uall >"$after_file"

if ! diff -u "$status_file" "$after_file"; then
  echo "error: git working tree changed during test run" >&2
  exit 1
fi

bash tool/validate_no_stray_test_artifacts.sh
bash "$REPO_ROOT/scripts/validate-mobile-clean-working-tree.sh"

echo "OK — repository cleanliness preserved"
