#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="${1:-$HERE/build/LlamaMobile.xcframework}"

"$HERE/build_ios_slice.sh" iphoneos arm64
"$HERE/build_ios_slice.sh" iphonesimulator arm64
"$HERE/build_ios_slice.sh" iphonesimulator x86_64

mkdir -p "$HERE/build/iphonesimulator-universal"
xcrun lipo -create \
  "$HERE/build/iphonesimulator-arm64/libllama_mobile.a" \
  "$HERE/build/iphonesimulator-x86_64/libllama_mobile.a" \
  -output "$HERE/build/iphonesimulator-universal/libllama_mobile.a"

rm -rf "$OUTPUT"
xcodebuild -create-xcframework \
  -library "$HERE/build/iphoneos-arm64/libllama_mobile.a" \
  -headers "$HERE/.." \
  -library "$HERE/build/iphonesimulator-universal/libllama_mobile.a" \
  -headers "$HERE/.." \
  -output "$OUTPUT"
echo "$OUTPUT"
