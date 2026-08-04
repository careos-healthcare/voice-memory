#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="$ROOT/tool/validate_revenuecat_configuration.sh"

REVENUECAT_PURCHASES_ENABLED=true \
REVENUECAT_IOS_API_KEY=appl_fixture_public_key \
  "$VALIDATOR" --platform ios --paid

REVENUECAT_PURCHASES_ENABLED=true \
REVENUECAT_ANDROID_API_KEY=goog_fixture_public_key \
  "$VALIDATOR" --platform android --paid

if env -u REVENUECAT_IOS_API_KEY \
    REVENUECAT_PURCHASES_ENABLED=true \
    "$VALIDATOR" --platform ios --paid; then
  echo "Expected paid iOS configuration without a key to fail" >&2
  exit 1
fi

REVENUECAT_PURCHASES_ENABLED=false \
  "$VALIDATOR" --platform ios --free

echo "RevenueCat configuration gate fixtures passed"
