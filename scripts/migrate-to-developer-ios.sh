#!/usr/bin/env bash
# Migrate voice-memory off iCloud-synced Desktop and rebuild iOS release without
# File Provider xattrs on Flutter.framework.
set -euo pipefail

SRC="${HOME}/Desktop/voice-memory"
DEST="${HOME}/Developer/voice-memory"
MOBILE="${DEST}/apps/voicememory_mobile"

echo "=== 1. Verify source ==="
if [[ ! -d "${SRC}/.git" ]]; then
  echo "ERROR: Expected git repo at ${SRC}" >&2
  exit 1
fi
echo "Source: ${SRC}"
echo "Target: ${DEST}"

if [[ -e "${DEST}" ]]; then
  echo "ERROR: ${DEST} already exists. Remove or rename it before running." >&2
  exit 1
fi

echo "=== 2. Create ~/Developer and rsync ==="
mkdir -p "${HOME}/Developer"
rsync -a \
  --exclude '.DS_Store' \
  "${SRC}/" \
  "${DEST}/"

echo "=== 3. Strip extended attributes on new copy ==="
xattr -cr "${DEST}"

echo "=== 4. Remove iCloud conflict duplicates in ios/Flutter ==="
FLUTTER_IOS="${MOBILE}/ios/Flutter"
rm -f \
  "${FLUTTER_IOS}/Generated 2.xcconfig" \
  "${FLUTTER_IOS}/Generated 3.xcconfig" \
  "${FLUTTER_IOS}/Flutter 2.podspec" \
  "${FLUTTER_IOS}/flutter_export_environment 2.sh" \
  "${FLUTTER_IOS}/flutter_export_environment 3.sh" \
  2>/dev/null || true

# Remove iCloud "build 2" style duplicates if present
rm -rf "${MOBILE}/build 2" 2>/dev/null || true

echo "=== 5. Clean and rebuild iOS (release) ==="
export COPYFILE_DISABLE=1
export COPY_EXTENDED_ATTRIBUTES_DISABLE=1

cd "${MOBILE}"
flutter clean
rm -rf build
rm -rf ios/Pods ios/.symlinks ios/Podfile.lock

flutter pub get
(cd ios && pod install)
flutter build ios --release

echo "=== 6. Verify Flutter.framework xattrs ==="
FW="${MOBILE}/build/ios/Release-iphoneos/Flutter.framework/Flutter"
if [[ ! -f "${FW}" ]]; then
  echo "ERROR: Expected ${FW} after build" >&2
  exit 1
fi

echo "Binary real path: $(realpath "${FW}")"
XATTR_OUT="$(xattr -l "${FW}" 2>&1 || true)"
echo "${XATTR_OUT}"

if echo "${XATTR_OUT}" | grep -q 'com.apple.fileprovider.fpfs#P'; then
  echo "FAIL: com.apple.fileprovider.fpfs#P still present" >&2
  exit 1
fi
if echo "${XATTR_OUT}" | grep -q 'com.apple.FinderInfo'; then
  echo "FAIL: com.apple.FinderInfo still present" >&2
  exit 1
fi

echo "=== 7. Quick codesign smoke test ==="
codesign --force --sign - "${FW}"

echo ""
echo "SUCCESS: iOS release build completed under ${DEST}"
echo "Next steps:"
echo "  - Open ${DEST} in Cursor/Xcode (not Desktop copy)"
echo "  - cd ${MOBILE} for future builds"
echo "  - After confirming, you may remove ${SRC}"
