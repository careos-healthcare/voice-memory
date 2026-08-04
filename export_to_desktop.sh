#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TARGET_DIR="${HOME}/Desktop/upload1"

mkdir -p "${TARGET_DIR}"
rm -f "${TARGET_DIR}"/*.txt

PROJECT_ROOT="${PROJECT_ROOT}" TARGET_DIR="${TARGET_DIR}" python3 - <<'PY'
from __future__ import annotations

import os
import pathlib
import re

root = pathlib.Path(os.environ["PROJECT_ROOT"]).resolve()
target = pathlib.Path(os.environ["TARGET_DIR"]).resolve()
outputs = {
    1: target / "01_architecture_ui.txt",
    2: target / "02_core_native.txt",
    3: target / "03_configs_tests.txt",
}

ignored_directories = {
    ".git",
    ".dart_tool",
    ".data",
    ".gradle",
    ".next",
    ".plugin_symlinks",
    ".symlinks",
    ".turbo",
    ".vercel",
    ".idea",
    ".vscode",
    "build",
    "dist",
    "node_modules",
    "Pods",
    "DerivedData",
    "ephemeral",
    "coverage",
    "playwright-report",
    "test-results",
    "temp",
    "tmp",
    "xcuserdata",
    "vendor",
}
binary_suffixes = {
    ".7z", ".a", ".aar", ".aab", ".ai", ".apk", ".app", ".avif", ".bin",
    ".bmp", ".class", ".db", ".dmg", ".dll", ".doc", ".docx", ".dylib",
    ".eot", ".epub", ".exe", ".flac", ".gif", ".gz", ".heic", ".ico", ".ipa",
    ".jar", ".jpeg", ".jpg", ".keystore", ".lockb", ".m4a", ".mkv", ".mov",
    ".mp3", ".mp4", ".msix", ".o", ".otf", ".pdf", ".png", ".pyc", ".pyd",
    ".so", ".sqlite", ".sqlite3", ".tar", ".tiff", ".ttf", ".wav", ".webm",
    ".webp", ".woff", ".woff2", ".xcarchive", ".xls", ".xlsx", ".zip",
}
ui_segments = {
    "app", "components", "design", "features", "presentation", "screens",
    "shared", "styles", "theme", "ui", "widgets",
}
core_segments = {
    "backend", "core", "engines", "infrastructure", "native", "packages",
    "services", "storage", "wasm", "webassembly",
}
config_names = {
    ".editorconfig", ".env.example", ".gitattributes", ".gitignore",
    ".metadata", "analysis_options.yaml", "app.json", "build.gradle",
    "build.gradle.kts", "cmakelists.txt", "fastfile", "gemfile",
    "gradle.properties", "makefile", "package.json", "package-lock.json",
    "podfile", "pubspec.lock", "pubspec.yaml", "settings.gradle",
    "settings.gradle.kts", "tsconfig.json", "vercel.json",
}


def category(relative: pathlib.PurePosixPath) -> int:
    parts = relative.parts
    lowered = tuple(part.lower() for part in parts)
    name = relative.name.lower()

    if "test" in lowered or "tests" in lowered or "integration_test" in lowered:
        return 3
    if (
        "scripts" in lowered
        or "tool" in lowered
        or "docs" in lowered
        or ".github" in lowered
        or name in config_names
        or name.startswith(("readme", "license", "changelog"))
    ):
        return 3

    # Explicit mobile source assignments from the export contract.
    joined = "/" + "/".join(lowered) + "/"
    if "/lib/features/" in joined or "/lib/shared/" in joined:
        return 1
    if "/lib/core/" in joined or "/lib/services/" in joined:
        return 2

    if any(part in ui_segments for part in lowered):
        return 1
    if any(part in core_segments for part in lowered):
        return 2
    if relative.suffix.lower() in {
        ".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".m", ".mm",
        ".rs", ".wat", ".wasm",
    }:
        return 2
    return 3


def readable_text(path: pathlib.Path) -> str | None:
    if path.suffix.lower() in binary_suffixes:
        return None
    try:
        data = path.read_bytes()
    except (OSError, PermissionError):
        return None
    if b"\x00" in data:
        return None
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        return None


files: list[pathlib.Path] = []
for directory, subdirectories, filenames in os.walk(root, followlinks=False):
    subdirectories[:] = sorted(
        name
        for name in subdirectories
        if name not in ignored_directories and not name.startswith("Directory:")
    )
    base = pathlib.Path(directory)
    for filename in sorted(filenames):
        if filename.startswith(".env") and filename != ".env.example":
            continue
        if filename in {
            "local.properties",
            ".flutter-plugins",
            ".flutter-plugins-dependencies",
        } or filename.startswith(".flutter-plugins-dependencies "):
            continue
        if (
            base == root / "apps" / "voicememory_mobile"
            and re.match(r"\d+_", filename)
        ):
            continue
        path = base / filename
        if path.is_symlink() or path.resolve() == pathlib.Path(__file__).resolve():
            continue
        files.append(path)

# Include this script itself; it is part of the readable root configuration.
script_path = root / "export_to_desktop.sh"
if script_path.is_file() and script_path not in files:
    files.append(script_path)

handles = {
    index: output.open("w", encoding="utf-8", newline="\n")
    for index, output in outputs.items()
}
counts = {1: 0, 2: 0, 3: 0}
try:
    for path in sorted(files, key=lambda item: item.relative_to(root).as_posix()):
        text = readable_text(path)
        if text is None:
            continue
        relative = pathlib.PurePosixPath(path.relative_to(root).as_posix())
        index = category(relative)
        handle = handles[index]
        handle.write(f"=== {relative.as_posix()} ===\n")
        handle.write(text)
        if text and not text.endswith("\n"):
            handle.write("\n")
        handle.write("\n")
        counts[index] += 1
finally:
    for handle in handles.values():
        handle.close()

for index, output in outputs.items():
    print(f"{output}: {counts[index]} files, {output.stat().st_size} bytes")
PY

shopt -s nullglob
txt_files=("${TARGET_DIR}"/*.txt)
if [[ "${#txt_files[@]}" -ne 3 ]]; then
  echo "Expected exactly three .txt files, found ${#txt_files[@]}." >&2
  exit 1
fi

echo "Codebase export complete: ${TARGET_DIR}"
