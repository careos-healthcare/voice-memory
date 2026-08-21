#!/bin/bash
# Run ArchiveMe on a physical iPad/iPhone for RevenueCat sandbox proof.
#
# Usage:
#   export REVENUECAT_IOS_API_KEY="appl_xxx"
#   bash tool/run_revenuecat_sandbox_proof_ipad.sh [-- EXTRA_FLAGS...]
#
# Override device with IPAD_DEVICE_ID=<udid>.
# Everything after `--` is passed straight through to `flutter run`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

if [ -z "${REVENUECAT_IOS_API_KEY:-}" ]; then
  echo "REVENUECAT_IOS_API_KEY is required for sandbox proof."
  echo "Example: export REVENUECAT_IOS_API_KEY=\"appl_xxx\""
  exit 1
fi

if [ "${1:-}" = "--" ]; then
  shift
fi

DEVICE_ARGS=()
if [ -n "${IPAD_DEVICE_ID:-}" ]; then
  DEVICE_ARGS=(-d "$IPAD_DEVICE_ID")
else
  PHYSICAL_IOS="$(flutter devices 2>/dev/null | grep -E 'ios|iPhone|iPad' | grep -v 'simulator' | head -1 | sed -E 's/.*• ([^ ]+) •.*/\1/' || true)"
  if [ -n "$PHYSICAL_IOS" ]; then
    DEVICE_ARGS=(-d "$PHYSICAL_IOS")
    echo "Using physical iOS device: $PHYSICAL_IOS"
  else
    echo "No physical iOS device detected. Set IPAD_DEVICE_ID or connect an iPad/iPhone."
    echo ""
    flutter devices
    exit 1
  fi
fi

echo "RevenueCat sandbox proof — iOS physical device"
echo "API key: set (not printed)"
echo ""

flutter run "${DEVICE_ARGS[@]}" \
  --dart-define=REVENUECAT_IOS_API_KEY="$REVENUECAT_IOS_API_KEY" \
  "$@"
