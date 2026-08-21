#!/usr/bin/env bash
# Runs the first-pattern QA harness and prints accuracy + failures.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter test test/first_pattern_quality_runner_test.dart --plain-name "prints QA report"
