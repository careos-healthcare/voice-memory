#!/usr/bin/env bash
# Preflight iOS release build + focused suite. Does not upload to TestFlight.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

COMMIT_SHA="$(git rev-parse HEAD)"
echo "==> release preflight @ ${COMMIT_SHA:0:12}"

echo "==> release:verify-focused-beta (informational — may exit non-zero)"
npm run release:verify-focused-beta || true

echo "==> focused release suite"
cd apps/mobile
flutter test \
  test/ios_testflight_submission_readiness_test.dart \
  test/release_identity_consistency_test.dart \
  test/app_store_rc_polish_test.dart \
  test/mobile_production_readiness_test.dart \
  test/consumer_visible_branding_test.dart \
  test/first_run_payoff_walkthrough_test.dart \
  test/archive_home_priority_test.dart \
  test/next_evidence_plan_test.dart \
  test/archive_watchlist_test.dart \
  test/archive_depth_test.dart \
  test/archive_milestones_test.dart \
  test/shareable_archive_proof_test.dart \
  test/archive_export_pack_test.dart \
  test/launch_hardening_test.dart \
  test/revenuecat_release_config_test.dart \
  test/pro_value_packaging_test.dart

echo "==> V1 production graph"
bash tool/validate_v1_production_graph.sh

echo "==> flutter build ios --release --no-codesign"
flutter build ios --release --no-codesign \
  --dart-define=VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app \
  --dart-define=SOURCE_COMMIT_SHA="$COMMIT_SHA"

echo "OK — iOS preflight complete. Archive in Xcode from ios/Runner.xcworkspace for TestFlight upload."
