#!/usr/bin/env python3
"""Export project text files into at most 3 bundled files for upload."""

from __future__ import annotations

import os
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = Path.home() / "Desktop" / "upload1"

IGNORE_DIR_NAMES = {
    ".git",
    ".dart_tool",
    "build",
    "node_modules",
    "Pods",
    ".idea",
    ".vscode",
    "dist",
    ".next",
    "coverage",
    ".gradle",
    "__pycache__",
    ".cursor",
    ".pub-cache",
    "DerivedData",
    ".symlinks",
    "ephemeral",
}

IGNORE_FILE_NAMES = {
    "pubspec.lock",
    "package-lock.json",
    "yarn.lock",
    "Podfile.lock",
    "Gemfile.lock",
    "Cargo.lock",
    "composer.lock",
    "pnpm-lock.yaml",
}

IGNORE_SUFFIXES = (
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".webp",
    ".ico",
    ".bmp",
    ".tiff",
    ".svg",
    ".woff",
    ".woff2",
    ".ttf",
    ".eot",
    ".otf",
    ".mp3",
    ".mp4",
    ".wav",
    ".mov",
    ".avi",
    ".pdf",
    ".zip",
    ".tar",
    ".gz",
    ".bz2",
    ".7z",
    ".jar",
    ".aar",
    ".apk",
    ".ipa",
    ".xcarchive",
    ".lock",
    ".g.dart",
    ".freezed.dart",
    ".mocks.dart",
    ".arb",
    ".bin",
    ".exe",
    ".dll",
    ".so",
    ".dylib",
    ".class",
    ".o",
    ".a",
    ".keystore",
    ".jks",
    ".p12",
    ".pem",
    ".der",
    ".cer",
    ".plist",
    ".xcuserstate",
    ".xcworkspace",
    ".xcodeproj",
    ".pbxproj",
    ".storyboard",
    ".xcassets",
    ".nib",
    ".car",
    ".db",
    ".sqlite",
    ".sqlite3",
)

SOURCE_EXTENSIONS = {
    ".dart",
    ".ts",
    ".tsx",
    ".js",
    ".jsx",
    ".mjs",
    ".cjs",
    ".swift",
    ".kt",
    ".kts",
    ".java",
    ".py",
    ".rb",
    ".go",
    ".rs",
    ".h",
    ".hpp",
    ".m",
    ".mm",
    ".c",
    ".cpp",
    ".cc",
    ".cs",
    ".sql",
    ".graphql",
    ".gql",
    ".sh",
    ".bash",
    ".zsh",
    ".fish",
    ".gradle",
    ".groovy",
    ".xml",
    ".html",
    ".htm",
    ".css",
    ".scss",
    ".sass",
    ".less",
    ".vue",
    ".svelte",
    ".proto",
    ".cmake",
    ".md",
    ".txt",
    ".rst",
    ".csv",
    ".tsv",
}

CONFIG_EXTENSIONS = {
    ".yaml",
    ".yml",
    ".json",
    ".toml",
    ".ini",
    ".cfg",
    ".conf",
    ".properties",
    ".env",
    ".editorconfig",
    ".gitattributes",
    ".gitmodules",
}

CONFIG_FILE_NAMES = {
    "Dockerfile",
    "docker-compose.yml",
    "docker-compose.yaml",
    "Makefile",
    "Gemfile",
    "Rakefile",
    ".gitignore",
    ".dockerignore",
    ".npmrc",
    ".nvmrc",
    ".tool-versions",
    "analysis_options.yaml",
    "pubspec.yaml",
    "melos.yaml",
    "l10n.yaml",
    "build.yaml",
    "AGENTS.md",
    "CLAUDE.md",
    "README.md",
    "LICENSE",
    "LICENSE.md",
}

BUNDLE_FILES = {
    "source_code": OUTPUT_DIR / "source_code.txt",
    "config_and_meta": OUTPUT_DIR / "config_and_meta.txt",
    "remaining_files": OUTPUT_DIR / "remaining_files.txt",
}

MAX_TEXT_BYTES = 2 * 1024 * 1024  # skip very large single files


def should_skip_path(path: Path) -> bool:
    for part in path.parts:
        if part in IGNORE_DIR_NAMES:
            return True
    return False


def should_skip_file(path: Path) -> bool:
    name = path.name
    lower = name.lower()

    if name in IGNORE_FILE_NAMES:
        return True
    if lower.endswith(IGNORE_SUFFIXES):
        return True
    if name.startswith(".") and name not in {
        ".gitignore",
        ".dockerignore",
        ".editorconfig",
        ".gitattributes",
        ".gitmodules",
        ".npmrc",
        ".nvmrc",
        ".tool-versions",
        ".env.example",
    }:
        return True
    if path.suffix.lower() in {ext.lstrip(".") for ext in IGNORE_SUFFIXES if ext.startswith(".")}:
        pass  # handled by endswith above

    return False


def is_probably_text(path: Path) -> bool:
    try:
        size = path.stat().st_size
        if size == 0:
            return True
        if size > MAX_TEXT_BYTES:
            return False
        with path.open("rb") as handle:
            chunk = handle.read(8192)
        if b"\x00" in chunk:
            return False
        return True
    except OSError:
        return False


def categorize(path: Path) -> str:
    rel = path.relative_to(PROJECT_ROOT)
    suffix = path.suffix.lower()
    name = path.name

    if suffix in CONFIG_EXTENSIONS or name in CONFIG_FILE_NAMES:
        return "config_and_meta"
    if suffix in SOURCE_EXTENSIONS:
        parts = set(rel.parts)
        if parts & {"lib", "src", "app", "apps", "test", "tests", "integration_test", "bin", "scripts"}:
            return "source_code"
        if any(part.startswith("api") or part.endswith("api") for part in rel.parts):
            return "source_code"
        return "remaining_files"
    return "remaining_files"


def read_text(path: Path) -> str | None:
    for encoding in ("utf-8", "utf-8-sig", "latin-1"):
        try:
            return path.read_text(encoding=encoding)
        except UnicodeDecodeError:
            continue
        except OSError:
            return None
    return None


def collect_files() -> dict[str, list[Path]]:
    buckets: dict[str, list[Path]] = {
        "source_code": [],
        "config_and_meta": [],
        "remaining_files": [],
    }

    for root, dirnames, filenames in os.walk(PROJECT_ROOT):
        root_path = Path(root)
        dirnames[:] = sorted(
            d for d in dirnames if d not in IGNORE_DIR_NAMES and not d.startswith(".")
        )
        dirnames[:] = [d for d in dirnames if d not in IGNORE_DIR_NAMES]

        for filename in sorted(filenames):
            path = root_path / filename
            if should_skip_path(path) or should_skip_file(path):
                continue
            if not is_probably_text(path):
                continue
            bucket = categorize(path)
            buckets[bucket].append(path)

    for bucket in buckets:
        buckets[bucket].sort(key=lambda p: str(p.relative_to(PROJECT_ROOT)))
    return buckets


def write_bundle(bucket_name: str, paths: list[Path]) -> None:
    out_path = BUNDLE_FILES[bucket_name]
    included = 0
    skipped = 0

    with out_path.open("w", encoding="utf-8") as out:
        out.write(f"# Bundle: {bucket_name}\n")
        out.write(f"# Project: {PROJECT_ROOT.name}\n")
        out.write(f"# Files: {len(paths)}\n\n")

        for path in paths:
            rel = path.relative_to(PROJECT_ROOT)
            content = read_text(path)
            if content is None:
                skipped += 1
                continue
            out.write(f"=== FILE: {rel.as_posix()} ===\n")
            out.write(content)
            if not content.endswith("\n"):
                out.write("\n")
            out.write("\n")
            included += 1

    size_kb = out_path.stat().st_size / 1024
    print(f"Wrote {out_path} ({included} files, {skipped} skipped, {size_kb:.1f} KB)")


def main() -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"Exporting {PROJECT_ROOT} -> {OUTPUT_DIR}")

    buckets = collect_files()
    for bucket_name, paths in buckets.items():
        write_bundle(bucket_name, paths)

    total_files = sum(len(v) for v in buckets.values())
    print(f"Done. {total_files} files bundled into {len(BUNDLE_FILES)} files.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
