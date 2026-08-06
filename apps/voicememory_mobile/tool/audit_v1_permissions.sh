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
    android.permission.INTERNET|android.permission.RECORD_AUDIO|android.permission.USE_BIOMETRIC|com.android.vending.BILLING)
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

echo "OK — native permissions match V1 capability registry"
