#!/usr/bin/env bash
# Release gate: Android release builds must never fall back to the debug keystore.
#
# This is a credential-free static check. It does not require key.properties or
# a keystore on disk. Run from apps/mobile:
#   bash tool/validate_android_release_signing.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ANDROID_DIR="$APP_DIR/android"
GRADLE_FILE="$ANDROID_DIR/app/build.gradle.kts"
GITIGNORE_FILE="$ANDROID_DIR/.gitignore"
EXAMPLE_FILE="$ANDROID_DIR/key.properties.example"

failures=()

fail() {
  failures+=("$1")
}

if [[ ! -f "$GRADLE_FILE" ]]; then
  echo "validate_android_release_signing: missing $GRADLE_FILE" >&2
  exit 1
fi

gradle_src="$(cat "$GRADLE_FILE")"

# Forbidden: assigning the debug signing config to release builds.
if grep -q 'signingConfigs\.getByName("debug")' <<<"$gradle_src"; then
  fail 'android/app/build.gradle.kts must not assign signingConfigs.getByName("debug") to release'
fi

if grep -q 'signingConfig = signingConfigs\.debug' <<<"$gradle_src"; then
  fail "android/app/build.gradle.kts must not assign signingConfigs.debug to release"
fi

# Required: explicit fail-fast when release credentials are absent.
if ! grep -q 'gradle.taskGraph.whenReady' <<<"$gradle_src"; then
  fail "android/app/build.gradle.kts must register gradle.taskGraph.whenReady release guard"
fi

if ! grep -q 'Release signing is not configured' <<<"$gradle_src"; then
  fail "android/app/build.gradle.kts must throw a clear message when release signing is missing"
fi

# Required: example + gitignore patterns for local secrets.
if [[ ! -f "$EXAMPLE_FILE" ]]; then
  fail "missing android/key.properties.example"
else
  for token in storePassword keyPassword keyAlias storeFile; do
    if ! grep -q "^${token}=" "$EXAMPLE_FILE"; then
      fail "android/key.properties.example missing placeholder $token"
    fi
  done
  if grep -vq 'REPLACE\|absolute/path' "$EXAMPLE_FILE"; then
    : # placeholders present
  fi
fi

if [[ ! -f "$GITIGNORE_FILE" ]]; then
  fail "missing android/.gitignore"
else
  for pattern in key.properties '*.jks' '*.keystore'; do
    if ! grep -q "$pattern" "$GITIGNORE_FILE"; then
      fail "android/.gitignore must ignore $pattern"
    fi
  done
fi

# Identity sanity checks (credential-free).
if ! grep -q 'applicationId = "com.voicememory.mobile"' <<<"$gradle_src"; then
  fail 'expected applicationId com.voicememory.mobile in build.gradle.kts'
fi

if ! grep -q 'namespace = "com.voicememory.mobile"' <<<"$gradle_src"; then
  fail 'expected namespace com.voicememory.mobile in build.gradle.kts'
fi

manifest="$ANDROID_DIR/app/src/main/AndroidManifest.xml"
if [[ -f "$manifest" ]] && ! grep -q 'android:label="ArchiveMe"' "$manifest"; then
  fail 'main AndroidManifest.xml must label the app ArchiveMe'
fi

if ((${#failures[@]} > 0)); then
  echo "validate_android_release_signing FAILED:" >&2
  for item in "${failures[@]}"; do
    echo "  - $item" >&2
  done
  exit 1
fi

echo "validate_android_release_signing ok"
