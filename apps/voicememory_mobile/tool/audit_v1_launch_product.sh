#!/usr/bin/env bash
# Launch-product focus audit — surfaces, copy, and startup aligned to V1 contract.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONTRACT="$ROOT/lib/core/config/v1_launch_product_contract.dart"
fail() {
  echo "error: $1" >&2
  exit 1
}

echo "==> launch product contract exists"
[[ -f "$CONTRACT" ]] || fail "missing v1_launch_product_contract.dart"

echo "==> required V1 contract docs"
for doc in V1_PRODUCT_CONTRACT V1_ROUTE_INVENTORY V1_DATA_FLOW V1_PRIVACY_BOUNDARY V1_RELEASE_CHECKLIST; do
  [[ -f "$ROOT/docs/${doc}.md" ]] || fail "missing docs/${doc}.md"
done

echo "==> paywall must not promise quarantined features"
PAYWALL="$ROOT/lib/features/paywall_value_sharpening/paywall_value_sharpening_copy.dart"
grep -q 'Weekly archive reviews' "$PAYWALL" && fail "paywall still promises weekly archive reviews"
grep -q 'Timeline views over time' "$PAYWALL" && fail "paywall still promises timeline views"

echo "==> account screen must not show AI accuracy dashboard"
ACCOUNT="$ROOT/lib/screens/account_screen.dart"
grep -q 'AiAccuracyFeedbackStore' "$ACCOUNT" && fail "account still imports AiAccuracyFeedbackStore"
grep -q 'AI Accuracy' "$ACCOUNT" && fail "account still shows AI Accuracy copy"

echo "==> startup uses staged coordinator"
grep -q 'V1StartupCoordinator' "$ROOT/lib/startup/archive_me_startup.dart" || fail "bootstrap missing coordinator"

echo "==> curiosity snapshot not launched on V1-only cold start"
grep -q '!V1FeatureFlags.enableV1Only' "$ROOT/lib/router/app_router.dart" || \
  fail "router must gate curiosity notification redirect for V1"

echo "OK — launch product audit passed"
