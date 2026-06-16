#!/bin/bash
# Build, install, and launch the ArchiveMe Android debug build.
#
# Usage:
#   tool/run_android_debug.sh [DEVICE_ID]
#
# If DEVICE_ID is omitted, the only connected Android device is used. If more
# than one is connected, pass the id explicitly (see `flutter devices`).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

# The launchable package. NOTE: com.voicememory.mobile is NOT launchable.
PACKAGE="com.voicememory.app"
APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"

if ! command -v adb >/dev/null 2>&1; then
  echo "Error: adb not found on PATH. Install the Android SDK platform-tools." >&2
  exit 1
fi

DEVICE_ID="${1:-}"

if [ -z "$DEVICE_ID" ]; then
  # Collect attached devices (state == "device"), skipping the header line.
  mapfile -t DEVICES < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')
  case "${#DEVICES[@]}" in
    0)
      echo "Error: no Android device found." >&2
      echo "  - Start an emulator or connect a phone with USB debugging." >&2
      echo "  - Then check: flutter devices" >&2
      exit 1
      ;;
    1)
      DEVICE_ID="${DEVICES[0]}"
      ;;
    *)
      echo "Error: more than one device connected. Pass a device id:" >&2
      printf '  %s\n' "${DEVICES[@]}" >&2
      echo "Usage: tool/run_android_debug.sh DEVICE_ID" >&2
      exit 1
      ;;
  esac
fi

echo "Target device: $DEVICE_ID"
echo "Package:       $PACKAGE"
echo ""

echo "==> Building debug APK"
flutter build apk --debug

if [ ! -f "$APK_PATH" ]; then
  echo "Error: expected APK not found at $APK_PATH" >&2
  exit 1
fi

echo ""
echo "==> Installing (non-streaming) on $DEVICE_ID"
# --no-streaming avoids 'failed to install' streaming errors on some devices.
if ! adb -s "$DEVICE_ID" install -r -d --no-streaming "$APK_PATH"; then
  echo "Error: adb install failed on $DEVICE_ID." >&2
  echo "  - Confirm the device is authorized: adb devices" >&2
  echo "  - Retry after: adb -s $DEVICE_ID uninstall $PACKAGE" >&2
  exit 1
fi

echo ""
echo "==> Launching $PACKAGE"
adb -s "$DEVICE_ID" shell monkey -p "$PACKAGE" 1 >/dev/null

echo ""
echo "Done. $PACKAGE launched on $DEVICE_ID."
