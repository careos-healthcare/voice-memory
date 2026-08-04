#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"
APP_ROOT="${REPO_ROOT}/apps/voicememory_mobile"
OUTPUT_ROOT="${REPO_ROOT}/dist/genesis"
TARGETS="android,linux,windows,ios,macos"
DRY_RUN=0
LEGACY_ANDROID=0
ALLOW_MISSING_PACKAGERS=0
SKIP_SIGNING=0
ALLOW_DIRTY=0

usage() {
  cat <<'EOF'
Usage: build_genesis.sh [options]
  --dry-run                       Verify tools and paths without building.
  --targets LIST                  Comma-separated android,ios,macos,linux,windows.
  --source-date-epoch SECONDS     Fixed Unix build timestamp.
  --legacy-android                Include armeabi-v7a in the fat APK.
  --allow-missing-packagers       Keep raw desktop bundles if wrapper tools are absent.
  --skip-signing                  Produce unsigned/development artifacts where supported.
  --allow-dirty                   Permit a non-reproducible build from a dirty tree.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --targets) shift; TARGETS="${1:?Missing target list}" ;;
    --source-date-epoch) shift; SOURCE_DATE_EPOCH="${1:?Missing epoch}" ;;
    --legacy-android) LEGACY_ANDROID=1 ;;
    --allow-missing-packagers) ALLOW_MISSING_PACKAGERS=1 ;;
    --skip-signing) SKIP_SIGNING=1 ;;
    --allow-dirty) ALLOW_DIRTY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 64 ;;
  esac
  shift
done

if [[ ! -f "${APP_ROOT}/pubspec.yaml" ]]; then
  echo "Flutter app not found at ${APP_ROOT}" >&2
  exit 66
fi

export TZ=UTC
export LC_ALL=C
export LANG=C
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(git -C "${REPO_ROOT}" log -1 --format=%ct 2>/dev/null || echo 0)}"
export GENESIS_BUILD_TIMESTAMP="${SOURCE_DATE_EPOCH}"
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
export FASTLANE_SKIP_UPDATE_CHECK=1
export FASTLANE_OPT_OUT_USAGE=1
export COCOAPODS_DISABLE_STATS=true
export BUNDLE_DISABLE_VERSION_CHECK=true
export PUB_ENVIRONMENT="genesis:offline"
export GRADLE_OPTS="${GRADLE_OPTS:-} -Dorg.gradle.offline=true -Dorg.gradle.caching=false -Dorg.gradle.parallel=false"
export PYTHONHASHSEED=0
export ZERO_AR_DATE=1
export ARFLAGS="${ARFLAGS:-crD}"
# Fail closed if any nested tool ignores its own offline switch.
export http_proxy="http://127.0.0.1:9"
export https_proxy="http://127.0.0.1:9"
export HTTP_PROXY="${http_proxy}"
export HTTPS_PROXY="${https_proxy}"
export ALL_PROXY="socks5://127.0.0.1:9"
export NO_PROXY="localhost,127.0.0.1"
export CFLAGS="${CFLAGS:-} -O3 -DNDEBUG -ffile-prefix-map=${REPO_ROOT}=. -fdebug-prefix-map=${REPO_ROOT}=."
export CXXFLAGS="${CXXFLAGS:-} -O3 -DNDEBUG -ffile-prefix-map=${REPO_ROOT}=. -fdebug-prefix-map=${REPO_ROOT}=."

has_target() {
  case ",${TARGETS}," in
    *,"$1",*) return 0 ;;
    *) return 1 ;;
  esac
}

command_path() {
  command -v "$1" 2>/dev/null || true
}

host_os="$(uname -s)"
case ",${TARGETS}," in
  *,android,*|*,linux,*|*,windows,*|*,ios,*|*,macos,*) ;;
  *) echo "No supported Genesis target was selected." >&2; exit 64 ;;
esac
IFS=',' read -r -a selected_targets <<< "${TARGETS}"
for selected_target in "${selected_targets[@]}"; do
  case "${selected_target}" in
    android|linux|windows|ios|macos) ;;
    *) echo "Unsupported Genesis target: ${selected_target}" >&2; exit 64 ;;
  esac
done
if [[ "${host_os}" == "Linux" ]]; then
  export LDFLAGS="${LDFLAGS:-} -Wl,--build-id=sha1"
fi
if has_target android; then
  if [[ -n "${GENESIS_JAVA_HOME:-}" ]]; then
    export JAVA_HOME="${GENESIS_JAVA_HOME}"
  elif [[ "${host_os}" == "Darwin" &&
          -x "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java" ]]; then
    export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
  fi
  if [[ -n "${JAVA_HOME:-}" ]]; then
    export PATH="${JAVA_HOME}/bin:${PATH}"
  fi
fi

echo "Genesis root: ${REPO_ROOT}"
echo "Flutter: $(command_path flutter)"
echo "Python: $(command_path python3)"
echo "Host: ${host_os}"
echo "Targets: ${TARGETS}"
echo "SOURCE_DATE_EPOCH: ${SOURCE_DATE_EPOCH}"
echo "Network policy: offline pub cache, --no-pub builds, analytics disabled"

[[ -n "$(command_path flutter)" ]] || { echo "flutter is required" >&2; exit 69; }
[[ -n "$(command_path python3)" ]] || { echo "python3 is required" >&2; exit 69; }

if has_target android; then
  echo "Android SDK: ${ANDROID_SDK_ROOT:-${ANDROID_HOME:-unconfigured}}"
  echo "Android Java: ${JAVA_HOME:-unconfigured}"
  echo "Android signing: $([[ -f "${APP_ROOT}/android/key.properties" ]] && echo local-key.properties || echo unavailable)"
fi
if has_target ios || has_target macos; then
  echo "Xcode: $(command_path xcodebuild)"
  echo "codesign: $(command_path codesign)"
fi
if has_target linux; then
  echo "appimagetool: $(command_path appimagetool)"
fi
if has_target windows; then
  echo "makeappx: $(command_path makeappx)"
  echo "signtool: $(command_path signtool)"
fi

if [[ "${DRY_RUN}" -eq 1 ]]; then
  if [[ -n "$(git -C "${REPO_ROOT}" status --porcelain)" ]]; then
    echo "Source tree: dirty (a real build requires --allow-dirty or a clean tree)"
  else
    echo "Source tree: clean"
  fi
  echo "Dry run complete; no build, signing, packaging, or network operation was performed."
  exit 0
fi

if [[ "${ALLOW_DIRTY}" -eq 0 &&
      -n "$(git -C "${REPO_ROOT}" status --porcelain)" ]]; then
  echo "Genesis release builds require a clean tracked source tree." >&2
  echo "Commit/stash changes, or pass --allow-dirty for a non-reproducible diagnostic build." >&2
  exit 65
fi

mkdir -p "${OUTPUT_ROOT}/artifacts" "${OUTPUT_ROOT}/metadata"
rm -f "${OUTPUT_ROOT}/artifacts/"*

run_flutter() {
  (
    cd "${APP_ROOT}"
    flutter "$@"
  )
}

offline_prepare() {
  run_flutter pub get --offline
}

copy_artifact() {
  local source="$1"
  local name="$2"
  [[ -f "${source}" ]] || { echo "Missing artifact: ${source}" >&2; exit 66; }
  cp "${source}" "${OUTPUT_ROOT}/artifacts/${name}"
  normalize_path "${OUTPUT_ROOT}/artifacts/${name}"
}

normalize_path() {
  local target="$1"
  TARGET="${target}" SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH}" \
    python3 - <<'PY'
import os
import pathlib
epoch = int(os.environ["SOURCE_DATE_EPOCH"])
target = pathlib.Path(os.environ["TARGET"])
paths = [target]
if target.is_dir():
    paths.extend(sorted(target.rglob("*"), key=lambda path: str(path), reverse=True))
for path in paths:
    try:
        os.utime(path, (epoch, epoch), follow_symlinks=False)
    except FileNotFoundError:
        pass
PY
}

write_runtime_capabilities() {
  local platform="$1"
  local destination="$2"
  local source="${APP_ROOT}/native/runners/${platform}"
  mkdir -p "${destination}"
  PLATFORM="${platform}" SOURCE="${source}" DESTINATION="${destination}" \
    python3 - <<'PY'
import json, os, pathlib, shutil
platform = os.environ["PLATFORM"]
source = pathlib.Path(os.environ["SOURCE"])
destination = pathlib.Path(os.environ["DESTINATION"])
patterns = {
    "linux": ("*.so",),
    "macos": ("*.dylib", "*.framework"),
    "windows": ("*.dll",),
}
copied = []
if source.is_dir():
    for pattern in patterns.get(platform, ()):
        for item in sorted(source.rglob(pattern)):
            relative = item.relative_to(source)
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            if item.is_dir():
                shutil.copytree(item, target, dirs_exist_ok=True)
            else:
                shutil.copy2(item, target)
            copied.append(str(relative))
(destination / "genesis_runtime_capabilities.json").write_text(
    json.dumps({
        "schemaVersion": 1,
        "platform": platform,
        "available": copied,
        "unavailable": [] if copied else ["mlx", "coreml", "vulkan"],
        "policy": "capability-gated; absent runners are never advertised",
    }, sort_keys=True, separators=(",", ":")) + "\n",
    encoding="utf-8",
)
PY
}

build_android() {
  local platforms="android-arm64,android-x64"
  if [[ "${LEGACY_ANDROID}" -eq 1 ]]; then
    platforms="android-arm,${platforms}"
    export GENESIS_ANDROID_LEGACY_ABIS=true
  else
    export GENESIS_ANDROID_LEGACY_ABIS=false
  fi
  if [[ "${SKIP_SIGNING}" -eq 0 && ! -f "${APP_ROOT}/android/key.properties" ]]; then
    echo "Android Genesis releases require local android/key.properties." >&2
    exit 78
  fi
  export GENESIS_REQUIRE_RELEASE_SIGNING="$([[ "${SKIP_SIGNING}" -eq 0 ]] && echo true || echo false)"
  run_flutter build apk --release --no-pub --target-platform "${platforms}" \
    --dart-define="GENESIS_BUILD_TIMESTAMP=${SOURCE_DATE_EPOCH}"
  run_flutter build appbundle --release --no-pub --target-platform "${platforms}" \
    --dart-define="GENESIS_BUILD_TIMESTAMP=${SOURCE_DATE_EPOCH}"
  copy_artifact "${APP_ROOT}/build/app/outputs/flutter-apk/app-release.apk" "archiveme-genesis.apk"
  copy_artifact "${APP_ROOT}/build/app/outputs/bundle/release/app-release.aab" "archiveme-genesis.aab"
}

build_ios() {
  [[ "${host_os}" == "Darwin" ]] || { echo "iOS builds require macOS." >&2; exit 69; }
  if [[ "${SKIP_SIGNING}" -eq 1 ]]; then
    run_flutter build ios --release --no-pub --no-codesign \
      --dart-define="GENESIS_BUILD_TIMESTAMP=${SOURCE_DATE_EPOCH}"
    local staging="${OUTPUT_ROOT}/ios-unsigned"
    rm -rf "${staging}"
    mkdir -p "${staging}/Payload"
    cp -R "${APP_ROOT}/build/ios/iphoneos/Runner.app" "${staging}/Payload/"
    STAGING="${staging}" SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH}" python3 - <<'PY'
import os, pathlib
epoch = int(os.environ["SOURCE_DATE_EPOCH"])
for path in pathlib.Path(os.environ["STAGING"]).rglob("*"):
    os.utime(path, (epoch, epoch), follow_symlinks=False)
PY
    (cd "${staging}" && zip -X -q -r "${OUTPUT_ROOT}/artifacts/archiveme-genesis.ipa" Payload)
  else
    [[ -f "${GENESIS_IOS_EXPORT_OPTIONS_PLIST:-}" ]] || {
      echo "GENESIS_IOS_EXPORT_OPTIONS_PLIST must point to local manual-signing export options." >&2
      exit 78
    }
    run_flutter build ipa --release --no-pub \
      --export-options-plist="${GENESIS_IOS_EXPORT_OPTIONS_PLIST}" \
      --dart-define="GENESIS_BUILD_TIMESTAMP=${SOURCE_DATE_EPOCH}"
    local ipa_files=("${APP_ROOT}"/build/ios/ipa/*.ipa)
    [[ -f "${ipa_files[0]}" ]] || { echo "Signed IPA was not produced." >&2; exit 66; }
    copy_artifact "${ipa_files[0]}" "archiveme-genesis.ipa"
  fi
}

build_macos() {
  [[ "${host_os}" == "Darwin" ]] || { echo "macOS builds require macOS." >&2; exit 69; }
  run_flutter build macos --release --no-pub \
    --dart-define="GENESIS_BUILD_TIMESTAMP=${SOURCE_DATE_EPOCH}"
  local app="${APP_ROOT}/build/macos/Build/Products/Release/voicememory_mobile.app"
  [[ -d "${app}" ]] || app="${APP_ROOT}/build/macos/Build/Products/Release/ArchiveMe.app"
  [[ -d "${app}" ]] || { echo "macOS app bundle not found." >&2; exit 66; }
  write_runtime_capabilities macos "${app}/Contents/Frameworks/GenesisRunners"
  if [[ "${SKIP_SIGNING}" -eq 0 ]]; then
    [[ -n "${GENESIS_MACOS_SIGN_IDENTITY:-}" ]] || {
      echo "GENESIS_MACOS_SIGN_IDENTITY is required for local macOS signing." >&2
      exit 78
    }
    codesign --force --deep --options runtime --timestamp=none \
      --sign "${GENESIS_MACOS_SIGN_IDENTITY}" "${app}"
  fi
  normalize_path "${app}"
  local dmg="${OUTPUT_ROOT}/artifacts/archiveme-genesis.dmg"
  hdiutil create -quiet -ov -format UDZO -srcfolder "${app}" -volname "ArchiveMe Genesis" "${dmg}"
  if [[ "${SKIP_SIGNING}" -eq 0 ]]; then
    codesign --force --timestamp=none --sign "${GENESIS_MACOS_SIGN_IDENTITY}" "${dmg}"
  fi
  normalize_path "${dmg}"
}

build_linux() {
  [[ "${host_os}" == "Linux" ]] || { echo "Linux builds require a Linux host." >&2; exit 69; }
  run_flutter build linux --release --no-pub \
    --dart-define="GENESIS_BUILD_TIMESTAMP=${SOURCE_DATE_EPOCH}"
  local bundle="${APP_ROOT}/build/linux/x64/release/bundle"
  write_runtime_capabilities linux "${bundle}/lib/genesis_runners"
  local appdir="${OUTPUT_ROOT}/ArchiveMe.AppDir"
  rm -rf "${appdir}"
  mkdir -p "${appdir}/usr/bin" "${appdir}/usr/lib" "${appdir}/usr/share/archiveme"
  cp -R "${bundle}/." "${appdir}/usr/share/archiveme/"
  cat > "${appdir}/AppRun" <<'EOF'
#!/bin/sh
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
exec "$HERE/usr/share/archiveme/voicememory_mobile" "$@"
EOF
  chmod +x "${appdir}/AppRun"
  cat > "${appdir}/archiveme.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=ArchiveMe
Exec=voicememory_mobile
Icon=archiveme
Categories=Utility;
EOF
  cp "${APP_ROOT}/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png" \
    "${appdir}/archiveme.png"
  normalize_path "${appdir}"
  if [[ -n "$(command_path appimagetool)" ]]; then
    ARCH=x86_64 appimagetool "${appdir}" "${OUTPUT_ROOT}/artifacts/archiveme-genesis.AppImage"
    normalize_path "${OUTPUT_ROOT}/artifacts/archiveme-genesis.AppImage"
  elif [[ "${ALLOW_MISSING_PACKAGERS}" -eq 1 ]]; then
    tar --sort=name --mtime="@${SOURCE_DATE_EPOCH}" --owner=0 --group=0 --numeric-owner \
      -C "${bundle}" -czf "${OUTPUT_ROOT}/artifacts/archiveme-genesis-linux.tar.gz" .
    normalize_path "${OUTPUT_ROOT}/artifacts/archiveme-genesis-linux.tar.gz"
  else
    echo "appimagetool is required for Linux AppImage packaging." >&2
    exit 69
  fi
}

build_windows() {
  case "${host_os}" in MINGW*|MSYS*|CYGWIN*|Windows_NT) ;; *)
    echo "Windows builds require a Windows host." >&2; exit 69 ;;
  esac
  export CL="${CL:-} /O2 /DNDEBUG /Brepro /pathmap:${REPO_ROOT}=."
  export LINK="${LINK:-} /Brepro"
  run_flutter build windows --release --no-pub \
    --dart-define="GENESIS_BUILD_TIMESTAMP=${SOURCE_DATE_EPOCH}"
  local bundle="${APP_ROOT}/build/windows/x64/runner/Release"
  write_runtime_capabilities windows "${bundle}/genesis_runners"
  [[ -n "$(command_path makeappx)" ]] || { echo "makeappx is required." >&2; exit 69; }
  mkdir -p "${bundle}/Assets"
  cp "${APP_ROOT}/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png" \
    "${bundle}/Assets/AppIcon.png"
  cat > "${bundle}/AppxManifest.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
         xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10">
  <Identity Name="com.voicememory.mobile"
            Publisher="${GENESIS_WINDOWS_PUBLISHER:-CN=ArchiveMe Local}"
            Version="${GENESIS_WINDOWS_VERSION:-0.2.0.0}" />
  <Properties>
    <DisplayName>ArchiveMe</DisplayName>
    <PublisherDisplayName>ArchiveMe</PublisherDisplayName>
    <Logo>Assets\AppIcon.png</Logo>
  </Properties>
  <Resources><Resource Language="en-us" /></Resources>
  <Applications>
    <Application Id="ArchiveMe" Executable="voicememory_mobile.exe" EntryPoint="Windows.FullTrustApplication">
      <uap:VisualElements DisplayName="ArchiveMe" Description="Private local-first memory archive"
          BackgroundColor="transparent"
          Square150x150Logo="Assets\AppIcon.png"
          Square44x44Logo="Assets\AppIcon.png" />
    </Application>
  </Applications>
  <Capabilities><Capability Name="internetClient" /></Capabilities>
</Package>
EOF
  normalize_path "${bundle}"
  local msix="${OUTPUT_ROOT}/artifacts/archiveme-genesis.msix"
  makeappx pack /d "${bundle}" /p "${msix}" /o
  if [[ "${SKIP_SIGNING}" -eq 0 ]]; then
    [[ -n "${GENESIS_WINDOWS_CERT_PFX:-}" && -n "${GENESIS_WINDOWS_CERT_PASSWORD:-}" ]] || {
      echo "Local Windows certificate variables are required." >&2; exit 78;
    }
    signtool sign /fd SHA256 /f "${GENESIS_WINDOWS_CERT_PFX}" \
      /p "${GENESIS_WINDOWS_CERT_PASSWORD}" "${msix}"
  fi
  normalize_path "${msix}"
}

offline_prepare
has_target android && build_android
has_target ios && build_ios
has_target macos && build_macos
has_target linux && build_linux
has_target windows && build_windows

SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH}" OUTPUT_ROOT="${OUTPUT_ROOT}" \
TARGETS="${TARGETS}" REPO_ROOT="${REPO_ROOT}" ALLOW_DIRTY="${ALLOW_DIRTY}" \
  python3 - <<'PY'
import hashlib, json, os, pathlib, subprocess
root = pathlib.Path(os.environ["OUTPUT_ROOT"])
repo = pathlib.Path(os.environ["REPO_ROOT"])
artifacts = []
for path in sorted((root / "artifacts").iterdir(), key=lambda p: p.name):
    if not path.is_file():
        continue
    hasher = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(chunk)
    digest = hasher.hexdigest()
    artifacts.append({"name": path.name, "bytes": path.stat().st_size, "sha256": digest})
manifest = {
    "schemaVersion": 1,
    "sourceDateEpoch": int(os.environ["SOURCE_DATE_EPOCH"]),
    "sourceCommit": subprocess.check_output(
        ["git", "-C", str(repo), "rev-parse", "HEAD"], text=True
    ).strip(),
    "targets": os.environ["TARGETS"].split(","),
    "hashAlgorithm": "SHA-256",
    "artifacts": artifacts,
    "reproducibility": {
        "unsignedPayloads": "best-effort deterministic",
        "signedArtifacts": "signatures may contain platform-controlled nondeterminism",
        "dirtyTreeAllowed": os.environ["ALLOW_DIRTY"] == "1",
        "networkUsed": False,
    },
}
(root / "genesis_manifest.json").write_text(
    json.dumps(manifest, sort_keys=True, separators=(",", ":")) + "\n",
    encoding="utf-8",
)
PY

"${SCRIPT_DIR}/verify_genesis_manifest.py" \
  "${OUTPUT_ROOT}/genesis_manifest.json" "${OUTPUT_ROOT}/artifacts"

echo "Genesis artifacts and manifest written to ${OUTPUT_ROOT}"
