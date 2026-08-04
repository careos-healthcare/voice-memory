#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLATFORM="${1:?usage: build_ios_slice.sh <iphoneos|iphonesimulator> <arch>}"
REQUESTED_ARCH="${2:-}"
NATIVE_ARCH="${3:-}"
XCODE_ARCHS="${4:-}"

ARCH="$REQUESTED_ARCH"
if [[ -z "$ARCH" || "$ARCH" == "undefined_arch" ]]; then
  for candidate in "$NATIVE_ARCH" $XCODE_ARCHS "$(uname -m)"; do
    if [[ "$candidate" == "arm64" || "$candidate" == "x86_64" ]]; then
      ARCH="$candidate"
      break
    fi
  done
fi
if [[ "$ARCH" != "arm64" && "$ARCH" != "x86_64" ]]; then
  echo "error: unable to resolve active Apple architecture" >&2
  exit 2
fi

BUILD_DIR="$ROOT/native/ios/.cmake/$PLATFORM-$ARCH"
OUTPUT_DIR="$ROOT/native/ios/build/$PLATFORM"

CMAKE_BIN="${CMAKE:-}"
if [[ -z "$CMAKE_BIN" ]]; then
  CMAKE_BIN="$(command -v cmake || true)"
fi
if [[ -z "$CMAKE_BIN" ]]; then
  ANDROID_SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
  SDK_CMAKE="$ANDROID_SDK/cmake/3.22.1/bin/cmake"
  if [[ -x "$SDK_CMAKE" ]]; then
    CMAKE_BIN="$SDK_CMAKE"
  fi
fi
if [[ -z "$CMAKE_BIN" || ! -x "$CMAKE_BIN" ]]; then
  echo "error: CMake 3.22+ is required (set CMAKE=/absolute/path/to/cmake)" >&2
  exit 2
fi

case "$PLATFORM" in
  iphoneos) SDK="iphoneos" ;;
  iphonesimulator) SDK="iphonesimulator" ;;
  *) echo "error: unsupported Apple platform $PLATFORM" >&2; exit 2 ;;
esac

SDK_PATH="$(xcrun --sdk "$SDK" --show-sdk-path)"
"$CMAKE_BIN" -S "$ROOT/native" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT="$SDK_PATH" \
  -DCMAKE_OSX_ARCHITECTURES="$ARCH" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
  -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=YES \
  -DCMAKE_INSTALL_NAME_DIR="@rpath" \
  -DBUILD_SHARED_LIBS=OFF \
  -DGGML_NATIVE=OFF \
  -DGGML_METAL=ON \
  -DGGML_METAL_EMBED_LIBRARY=ON \
  -DGGML_ACCELERATE=ON \
  -DLLAMA_BUILD_TESTS=OFF \
  -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_SERVER=OFF
"$CMAKE_BIN" --build "$BUILD_DIR" \
  --config Release \
  --target llama_mobile_core \
  --parallel

mkdir -p "$OUTPUT_DIR"
/usr/bin/python3 - "$BUILD_DIR" "$OUTPUT_DIR/libllama_mobile.a" <<'PY'
import os
import subprocess
import sys

build_dir, output = sys.argv[1:]
archives = []
for root, _, files in os.walk(build_dir):
    for name in files:
        if name.endswith(".a"):
            archives.append(os.path.join(root, name))
archives.sort()
if not archives:
    raise SystemExit("error: CMake produced no static archives")
subprocess.run(
    ["xcrun", "libtool", "-static", "-o", output, *archives],
    check=True,
)
PY

echo "$OUTPUT_DIR/libllama_mobile.a"
