#!/bin/bash
# V1 TestFlight / App Store build with fixed dart-defines.
#
# Usage:
#   ./tool/run_v1_testflight_build.sh              # flutter build ipa (default)
#   ./tool/run_v1_testflight_build.sh -- ios       # flutter build ios --release (Xcode archive)
#   REVENUECAT_IOS_API_KEY=appl_xxx ./tool/run_v1_testflight_build.sh
#   SKIP_CLEAN=1 ./tool/run_v1_testflight_build.sh
#   BUILD_NUMBER=50 ./tool/run_v1_testflight_build.sh
#
# Always sets:
#   VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app
#   ARCHIVEME_APP_REVIEW_MODE=true
#
# Intentionally omitted (V1 TestFlight defaults):
#   ARCHIVEME_TRIAL_MODE, VOICE_MEMORY_SCREENSHOT_MODE, ENABLE_LIVE_VOICE_CAPTURE
#
# After IPA build: upload via Xcode Organizer or Transporter.
# After ios build: open ios/Runner.xcworkspace → Product → Archive → Upload.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

API_BASE_URL="${VOICE_MEMORY_API_BASE_URL:-https://voice-memory-iota.vercel.app}"
TARGET="${V1_TESTFLIGHT_TARGET:-ipa}"

if [ "${1:-}" = "--" ]; then
  shift
  TARGET="${1:-ipa}"
  shift || true
fi

VERSION_LINE="$(grep '^version:' pubspec.yaml | head -1 | awk '{print $2}')"
MARKETING_VERSION="${VERSION_LINE%%+*}"
PUBSPEC_BUILD="${VERSION_LINE#*+}"
BUILD_NUMBER="${BUILD_NUMBER:-$PUBSPEC_BUILD}"

DART_DEFINES=(
  --dart-define="VOICE_MEMORY_API_BASE_URL=$API_BASE_URL"
  --dart-define=ARCHIVEME_APP_REVIEW_MODE=true
)

if [ -n "${REVENUECAT_IOS_API_KEY:-}" ]; then
  DART_DEFINES+=(--dart-define="REVENUECAT_IOS_API_KEY=$REVENUECAT_IOS_API_KEY")
elif [ -n "${REVENUECAT_API_KEY:-}" ]; then
  DART_DEFINES+=(--dart-define="REVENUECAT_IOS_API_KEY=$REVENUECAT_API_KEY")
fi

echo "ArchiveMe V1 TestFlight build"
echo "  version:      $MARKETING_VERSION ($BUILD_NUMBER)"
echo "  API base URL: $API_BASE_URL"
echo "  App Review:   enabled (Settings → ARCHIVEME-REVIEW-2026)"
echo "  Live voice:   off (default)"
echo "  RevenueCat:   ${REVENUECAT_IOS_API_KEY:+set via env}${REVENUECAT_IOS_API_KEY:-${REVENUECAT_API_KEY:+set via REVENUECAT_API_KEY}}${REVENUECAT_IOS_API_KEY:-${REVENUECAT_API_KEY:-not set — billing-off build}}"
echo "  target:       $TARGET"
echo ""

if [ "${SKIP_CLEAN:-}" != "1" ]; then
  flutter clean
fi

flutter pub get

BUILD_ARGS=(--build-number="$BUILD_NUMBER" "${DART_DEFINES[@]}" "$@")

case "$TARGET" in
  ipa)
    echo "Running: flutter build ipa ${BUILD_ARGS[*]}"
    flutter build ipa "${BUILD_ARGS[@]}"
    echo ""
    echo "IPA output: build/ios/ipa/"
    ;;
  ios)
    echo "Running: flutter build ios --release ${BUILD_ARGS[*]}"
    flutter build ios --release "${BUILD_ARGS[@]}"
    echo ""
    echo "Next: open ios/Runner.xcworkspace → Product → Archive → Upload"
    ;;
  *)
    echo "Unknown target: $TARGET (expected: ipa or ios)"
    exit 1
    ;;
esac
