#!/usr/bin/env bash
# Validates native permission declarations against V1CapabilityRegistry.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MANIFEST="$ROOT/android/app/src/main/AndroidManifest.xml"
PLIST="$ROOT/ios/Runner/Info.plist"
REGISTRY="$ROOT/lib/core/config/v1_capability_registry.dart"

fail() {
  echo "error: $1" >&2
  exit 1
}

[[ -f "$MANIFEST" ]] || fail "missing AndroidManifest.xml"
[[ -f "$PLIST" ]] || fail "missing Info.plist"
[[ -f "$REGISTRY" ]] || fail "missing v1_capability_registry.dart"

echo "==> Android permission allowlist"
while IFS= read -r perm; do
  [[ -z "$perm" ]] && continue
  if ! grep -q "$perm" "$MANIFEST"; then
    fail "required Android permission missing: $perm"
  fi
done < <(grep -o "android.permission.[^'\"]*" "$REGISTRY" | sort -u)

while IFS= read -r perm; do
  [[ -z "$perm" ]] && continue
  case "$perm" in
    android.permission.INTERNET|android.permission.RECORD_AUDIO|android.permission.USE_BIOMETRIC)
      ;;
    com.android.vending.BILLING)
      if grep -q "storeBilling = true" "$REGISTRY"; then
        :
      elif grep -q "$perm" "$MANIFEST"; then
        fail "BILLING permission in manifest while storeBilling is disabled"
      fi
      ;;
    *)
      if grep -q "$perm" "$MANIFEST"; then
        fail "unexpected Android permission in manifest: $perm"
      fi
      ;;
  esac
done < <(grep -oE 'android\.permission\.[A-Z_]+|com\.android\.vending\.BILLING' "$MANIFEST" | sort -u)

echo "==> iOS usage description allowlist"
while IFS= read -r key; do
  [[ -z "$key" ]] && continue
  if ! grep -q "<key>$key</key>" "$PLIST"; then
    fail "required iOS usage description missing: $key"
  fi
done < <(grep -o "NS[A-Za-z]*UsageDescription" "$REGISTRY" | sort -u)

if grep -q "speechRecognition = false" "$REGISTRY"; then
  if grep -q "NSSpeechRecognitionUsageDescription" "$PLIST"; then
    fail "NSSpeechRecognitionUsageDescription present while speechRecognition is disabled"
  fi
fi

for blocked in NSCameraUsageDescription NSPhotoLibraryUsageDescription NSLocationWhenInUseUsageDescription NSBluetoothAlwaysUsageDescription; do
  if grep -q "<key>$blocked</key>" "$PLIST"; then
    fail "disabled capability key present in Info.plist: $blocked"
  fi
done

echo "==> Excluded native capabilities (widgets, local notification receivers)"
if grep -q "TodayCheckWidgetProvider" "$MANIFEST"; then
  fail "Android widget receiver present while nativeExtensions is disabled"
fi
if grep -q "ScheduledNotificationBootReceiver" "$MANIFEST"; then
  fail "Android notification boot receiver present while notifications is disabled"
fi
if grep -q "RECEIVE_BOOT_COMPLETED" "$MANIFEST"; then
  fail "RECEIVE_BOOT_COMPLETED present while notifications is disabled"
fi

PBXPROJ="$ROOT/ios/Runner.xcodeproj/project.pbxproj"
RUNNER_ENTITLEMENTS="$ROOT/ios/Runner/Runner.entitlements"
MAIN_ACTIVITY="$ROOT/android/app/src/main/kotlin/com/voicememory/mobile/MainActivity.kt"

if grep -q "name = TodayCheckWidget;" "$PBXPROJ"; then
  fail "TodayCheckWidget native target present while nativeExtensions is disabled"
fi
if grep -q "path = TodayCheckWidget;" "$PBXPROJ"; then
  fail "TodayCheckWidget group present in Xcode project while nativeExtensions is disabled"
fi
if grep -q "ObjectiveWidgetStorage.swift in Sources" "$PBXPROJ"; then
  fail "ObjectiveWidgetStorage compiled into Runner while nativeExtensions is disabled"
fi
if grep -q "group.com.voicememory.mobile" "$RUNNER_ENTITLEMENTS"; then
  fail "App Group entitlement present while nativeExtensions is disabled"
fi
if grep -q "archive_me/current_objective_widget" "$MAIN_ACTIVITY"; then
  fail "Widget method channel present in MainActivity while nativeExtensions is disabled"
fi

PUBSPEC="$ROOT/pubspec.yaml"
if grep -q "flutter_local_notifications" "$PUBSPEC"; then
  fail "flutter_local_notifications in pubspec while notifications is disabled"
fi
if grep -R "package:flutter_local_notifications" "$ROOT/lib" 2>/dev/null; then
  fail "flutter_local_notifications import found under lib/ while notifications is disabled"
fi

echo "OK — native permissions match V1 capability registry"
