#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUDIT="$ROOT/tool/audit_v1_permissions.sh"
FORBIDDEN="$ROOT/tool/fixtures/v1_permissions_forbidden_android.xml"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

cat >"$TEMP_DIR/allowed.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.USE_BIOMETRIC" />
    <uses-permission android:name="com.android.vending.BILLING" />
    <application>
        <activity android:name="com.voicememory.mobile.MainActivity" />
    </application>
</manifest>
XML

"$AUDIT" --android-manifest "$TEMP_DIR/allowed.xml"

if "$AUDIT" --android-manifest "$FORBIDDEN"; then
  echo "Expected forbidden permission fixture to fail" >&2
  exit 1
fi

cat >"$TEMP_DIR/Info-allowed.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>NSMicrophoneUsageDescription</key><string>Record when requested.</string>
  <key>NSFaceIDUsageDescription</key><string>Unlock when enabled.</string>
</dict></plist>
PLIST
cat >"$TEMP_DIR/Entitlements-allowed.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict/></plist>
PLIST
"$AUDIT" --ios-only \
  --ios-info "$TEMP_DIR/Info-allowed.plist" \
  --ios-entitlements "$TEMP_DIR/Entitlements-allowed.plist"

cat >"$TEMP_DIR/Entitlements-forbidden.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.application-groups</key>
  <array><string>group.com.voicememory.mobile</string></array>
</dict></plist>
PLIST
if "$AUDIT" --ios-only \
    --ios-info "$TEMP_DIR/Info-allowed.plist" \
    --ios-entitlements "$TEMP_DIR/Entitlements-forbidden.plist"; then
  echo "Expected forbidden iOS entitlement fixture to fail" >&2
  exit 1
fi

echo "V1 permission audit fixture tests passed"
