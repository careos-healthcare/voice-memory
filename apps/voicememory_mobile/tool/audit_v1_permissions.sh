#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_MANIFEST=""
IOS_APP=""
IOS_INFO=""
IOS_ENTITLEMENTS=""
AUDIT_ANDROID=true
AUDIT_IOS=false

usage() {
  echo "Usage: $0 [--android-manifest PATH] [--ios-app PATH]"
  echo "          [--ios-info PATH --ios-entitlements PATH] [--ios-only]"
}

while (($#)); do
  case "$1" in
    --android-manifest) ANDROID_MANIFEST="$2"; shift 2 ;;
    --ios-app) IOS_APP="$2"; AUDIT_IOS=true; shift 2 ;;
    --ios-info) IOS_INFO="$2"; AUDIT_IOS=true; shift 2 ;;
    --ios-entitlements) IOS_ENTITLEMENTS="$2"; AUDIT_IOS=true; shift 2 ;;
    --ios-only) AUDIT_ANDROID=false; AUDIT_IOS=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if $AUDIT_ANDROID && [[ -z "$ANDROID_MANIFEST" ]]; then
  ANDROID_MANIFEST="$(python3 - "$ROOT" <<'PY'
import glob
import os
import sys

root = sys.argv[1]
patterns = [
    "build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml",
    "build/app/intermediates/merged_manifests/release/*/AndroidManifest.xml",
    "build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml",
]
for pattern in patterns:
    matches = glob.glob(os.path.join(root, pattern))
    if matches:
        print(matches[-1])
        break
PY
)"
fi

if $AUDIT_IOS && [[ -n "$IOS_APP" ]]; then
  IOS_INFO="${IOS_INFO:-$IOS_APP/Info.plist}"
  if [[ -d "$IOS_APP/PlugIns" ]] &&
      compgen -G "$IOS_APP/PlugIns/*.appex" >/dev/null; then
    echo "V1 permission audit failed: embedded app extensions are forbidden" >&2
    exit 1
  fi
  if [[ -z "$IOS_ENTITLEMENTS" ]] && command -v codesign >/dev/null 2>&1; then
    SIGNED_ENTITLEMENTS="$(mktemp)"
    trap 'rm -f "$SIGNED_ENTITLEMENTS"' EXIT
    if codesign -d --entitlements :- "$IOS_APP" \
        >"$SIGNED_ENTITLEMENTS" 2>/dev/null; then
      IOS_ENTITLEMENTS="$SIGNED_ENTITLEMENTS"
    else
      IOS_ENTITLEMENTS="$ROOT/ios/Runner/Runner-Release.entitlements"
    fi
  fi
fi

python3 - \
  "$AUDIT_ANDROID" "$ANDROID_MANIFEST" \
  "$AUDIT_IOS" "$IOS_INFO" "$IOS_ENTITLEMENTS" <<'PY'
import os
import plistlib
import sys
import xml.etree.ElementTree as ET

audit_android = sys.argv[1] == "true"
android_manifest = sys.argv[2]
audit_ios = sys.argv[3] == "true"
ios_info = sys.argv[4]
ios_entitlements = sys.argv[5]
violations = []

android_allowlist = {
    "android.permission.INTERNET",
    "android.permission.RECORD_AUDIO",
    "android.permission.USE_BIOMETRIC",
    "com.android.vending.BILLING",
}
ios_usage_allowlist = {
    "NSMicrophoneUsageDescription",
    "NSFaceIDUsageDescription",
}
automatic_entitlements = {
    "application-identifier",
    "com.apple.developer.team-identifier",
    "get-task-allow",
}

if audit_android:
    if not android_manifest or not os.path.isfile(android_manifest):
        violations.append("Android merged Release manifest was not found")
    else:
        root = ET.parse(android_manifest).getroot()
        android = "{http://schemas.android.com/apk/res/android}"
        permissions = {
            node.attrib.get(android + "name", "")
            for node in root
            if node.tag in ("uses-permission", "uses-permission-sdk-23")
        }
        permissions.discard("")
        extra = sorted(permissions - android_allowlist)
        missing = sorted(android_allowlist - permissions)
        if extra:
            violations.append("forbidden Android permissions: " + ", ".join(extra))
        if missing:
            violations.append("missing Android permissions: " + ", ".join(missing))

        forbidden_component_tokens = (
            "health",
            "bluetooth",
            "workmanager",
            "firebase.messaging",
            "flutterlocalnotifications",
            "background_downloader",
            "geolocator",
            "imagepicker",
            "moduledependencies",
            "nsd",
            "webrtc",
            "ShareReceiverActivity",
            "WidgetProvider",
        )
        for node in root.iter():
            if node.tag not in ("activity", "activity-alias", "service", "receiver", "provider"):
                continue
            name = node.attrib.get(android + "name", "")
            if any(token.lower() in name.lower() for token in forbidden_component_tokens):
                violations.append(f"forbidden Android component: {name}")

        print("Android V1 permissions:")
        for permission in sorted(permissions):
            print(f"  {permission}")

if audit_ios:
    if not ios_info or not os.path.isfile(ios_info):
        violations.append("iOS Release Info.plist was not found")
    else:
        with open(ios_info, "rb") as handle:
            info = plistlib.load(handle)
        usage_keys = {key for key in info if key.startswith("NS") and key.endswith("UsageDescription")}
        extra_usage = sorted(usage_keys - ios_usage_allowlist)
        missing_usage = sorted(ios_usage_allowlist - usage_keys)
        if extra_usage:
            violations.append("forbidden iOS usage descriptions: " + ", ".join(extra_usage))
        if missing_usage:
            violations.append("missing iOS usage descriptions: " + ", ".join(missing_usage))
        for key in (
            "NSBonjourServices",
            "NSLocalNetworkUsageDescription",
            "UIBackgroundModes",
            "BGTaskSchedulerPermittedIdentifiers",
        ):
            if key in info:
                violations.append(f"forbidden iOS Info.plist capability: {key}")
        print("iOS V1 usage descriptions:")
        for key in sorted(usage_keys):
            print(f"  {key}")

    if not ios_entitlements or not os.path.isfile(ios_entitlements):
        violations.append("iOS Release entitlements were not found")
    elif os.path.getsize(ios_entitlements):
        with open(ios_entitlements, "rb") as handle:
            entitlements = plistlib.load(handle)
        forbidden = sorted(set(entitlements) - automatic_entitlements)
        if forbidden:
            violations.append("forbidden iOS entitlements: " + ", ".join(forbidden))
        print("iOS V1 explicit entitlements:")
        if not entitlements:
            print("  (none)")
        for key in sorted(entitlements):
            print(f"  {key}")
    elif ios_entitlements.endswith("Runner-Release.entitlements"):
        print("iOS V1 explicit entitlements:")
        print("  (none; no-codesign build, audited configured Release file)")
    else:
        print("iOS V1 explicit entitlements:")
        print("  (none)")

if violations:
    for violation in violations:
        print(f"V1 permission audit failed: {violation}", file=sys.stderr)
    raise SystemExit(1)

print("V1 permission audit passed")
PY
