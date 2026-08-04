#!/usr/bin/env python3
"""Generate 10 macOS TextEdit-compatible RTF product review files from all Dart sources."""

from __future__ import annotations

import os
import re
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

WORKSPACE = Path(__file__).resolve().parents[1]
OUTPUT_DIR = Path.home() / "Desktop" / "app22"
PART_COUNT = 10
PREVIEW_LINES = 12
MAX_WIDGETS = 8
MAX_CLASSES = 8
MAX_FEATURES = 6

SKIP_DIRS = {
    ".git",
    ".dart_tool",
    "build",
    ".next",
    "node_modules",
    "Pods",
    ".symlinks",
    "ephemeral",
}

WIDGET_PATTERNS = [
    (re.compile(r"class\s+(\w+)\s+extends\s+StatelessWidget"), "StatelessWidget"),
    (re.compile(r"class\s+(\w+)\s+extends\s+StatefulWidget"), "StatefulWidget"),
    (re.compile(r"class\s+(\w+)\s+extends\s+ConsumerWidget"), "ConsumerWidget"),
    (re.compile(r"class\s+(\w+)\s+extends\s+ConsumerStatefulWidget"), "ConsumerStatefulWidget"),
]

CLASS_PATTERN = re.compile(r"^(?:abstract\s+)?(?:sealed\s+)?class\s+(\w+)", re.MULTILINE)
FEATURE_PATTERNS = [
    re.compile(r"GoRoute\s*\(\s*path:\s*'([^']+)'"),
    re.compile(r"context\.(?:push|go)\(\s*'([^']+)'"),
    re.compile(r"static const String (\w+) = '([^']{8,120})'"),
]


def should_skip(path: Path) -> bool:
    return any(part in SKIP_DIRS for part in path.parts)


def classify_role(rel: str, source: str) -> str:
    lower = rel.lower()
    name = Path(rel).name.lower()

    if "/test/" in lower or name.endswith("_test.dart"):
        return "Test"
    if "/integration_test/" in lower:
        return "Integration Test"
    if "/screens/" in lower or name.endswith("_screen.dart"):
        return "UI Screen"
    if "/widgets/" in lower or "/presentation/" in lower:
        return "UI Component"
    if "/models/" in lower or name.endswith("_model.dart"):
        return "Domain Model"
    if "/domain/" in lower:
        return "Domain"
    if (
        "/services/" in lower
        or "/infrastructure/" in lower
        or "/application/" in lower
        or name.endswith("_service.dart")
        or name.endswith("_store.dart")
        or name.endswith("_engine.dart")
        or name.endswith("_repository.dart")
        or name.endswith("_client.dart")
        or name.endswith("_provider.dart")
    ):
        return "Service"
    if "/storage/" in lower or "/api/" in lower:
        return "Service"
    if "/copy.dart" in lower or "/constants.dart" in lower or name.endswith("_copy.dart"):
        return "Copy / Constants"
    if "/router/" in lower or name == "app_router.dart":
        return "Navigation / Router"
    if "/theme/" in lower or "/design/" in lower:
        return "Design System"
    if "/billing/" in lower or "/security/" in lower:
        return "Platform / Billing / Security"
    if "State<" in source or "ChangeNotifier" in source or "Cubit" in source or "Bloc" in source:
        return "State Management"
    if "/features/" in lower:
        return "Feature Module"
    if "/lib/" in lower:
        return "Utility / Library"
    return "Utility"


def extract_widgets(source: str) -> list[str]:
    found: list[str] = []
    for pattern, kind in WIDGET_PATTERNS:
        for match in pattern.finditer(source):
            found.append(f"{match.group(1)} ({kind})")
    return found[:MAX_WIDGETS]


def extract_classes(source: str) -> list[str]:
    classes = CLASS_PATTERN.findall(source)
    return classes[:MAX_CLASSES]


def extract_features(source: str) -> list[str]:
    features: list[str] = []
    for pattern in FEATURE_PATTERNS:
        for match in pattern.finditer(source):
            if len(match.groups()) == 1:
                features.append(f"Route: {match.group(1)}")
            else:
                features.append(f"Copy {match.group(1)}: {match.group(2)[:80]}")
    return features[:MAX_FEATURES]


def rtf_escape(text: str) -> str:
    out: list[str] = []
    for ch in text:
        code = ord(ch)
        if ch == "\\":
            out.append("\\\\")
        elif ch == "{":
            out.append("\\{")
        elif ch == "}":
            out.append("\\}")
        elif ch == "\n":
            out.append("\\par\n")
        elif 32 <= code <= 126:
            out.append(ch)
        else:
            out.append(f"\\u{code}?")
    return "".join(out)


def read_preview(path: Path) -> tuple[int, str, list[str], list[str], list[str], list[str]]:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        return 0, f"[Unreadable: {exc}]", [], [], [], []

    lines = text.splitlines()
    line_count = len(lines)
    preview = "\n".join(lines[:PREVIEW_LINES])
    if line_count > PREVIEW_LINES:
        preview += f"\n... ({line_count - PREVIEW_LINES} more lines)"

    return (
        line_count,
        preview,
        extract_widgets(text),
        extract_classes(text),
        extract_features(text),
        lines,
    )


def collect_dart_files() -> list[Path]:
    files: list[Path] = []
    for root, dirnames, filenames in os.walk(WORKSPACE):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            if not name.endswith(".dart"):
                continue
            path = Path(root) / name
            if should_skip(path):
                continue
            files.append(path)
    files.sort(key=lambda p: str(p.relative_to(WORKSPACE)).lower())
    return files


def chunk_evenly(items: list[Path], parts: int) -> list[list[Path]]:
    chunks: list[list[Path]] = [[] for _ in range(parts)]
    for index, item in enumerate(items):
        chunks[index % parts].append(item)
    return chunks


def write_rtf_part(
    part_number: int,
    chunk: list[Path],
    total_files: int,
    role_counter: Counter[str],
) -> None:
    output_path = OUTPUT_DIR / f"Product_Review_Part_{part_number}.rtf"
    generated = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    chunk_lines = 0
    chunk_roles: Counter[str] = Counter()

    body: list[str] = []
    body.append("{\\rtf1\\ansi\\deff0")
    body.append("{\\fonttbl{\\f0 Helvetica;}{\\f1 Courier;}}")
    body.append("\\f0\\fs28\\b Voice Memory / ArchiveMe Product Review\\b0\\fs22\\par")
    body.append(f"\\b Part {part_number} of {PART_COUNT}\\b0\\par")
    body.append(f"Generated: {rtf_escape(generated)}\\par")
    body.append(f"Workspace: {rtf_escape(str(WORKSPACE))}\\par")
    body.append(f"Files in this part: {len(chunk)} of {total_files}\\par\\par")

    body.append("\\b Executive summary (this part)\\b0\\par")
    body.append(
        rtf_escape(
            "This document audits Dart sources in the voice-memory monorepo: Flutter mobile "
            "(ArchiveMe), shared patterns, tests, and integration harnesses. Each entry lists "
            "path, line count, architectural role, detected widgets/classes, user-facing "
            "features, and a code preview."
        )
        + "\\par\\par"
    )

    for index, path in enumerate(chunk, start=1):
        rel = str(path.relative_to(WORKSPACE))
        line_count, preview, widgets, classes, features, _ = read_preview(path)
        role = classify_role(rel, preview)
        chunk_lines += line_count
        chunk_roles[role] += 1
        role_counter[role] += 1

        body.append("\\b")
        body.append(rtf_escape(f"{index}. {rel}"))
        body.append("\\b0\\par")
        body.append(rtf_escape(f"Lines: {line_count} | Role: {role}"))
        body.append("\\par")

        if widgets:
            body.append(rtf_escape("UI widgets: " + "; ".join(widgets)))
            body.append("\\par")
        if classes:
            body.append(rtf_escape("Classes: " + ", ".join(classes)))
            body.append("\\par")
        if features:
            body.append(rtf_escape("User features / routes / copy: " + " | ".join(features)))
            body.append("\\par")

        body.append("\\b Code preview\\b0\\par")
        body.append("\\f1\\fs18 ")
        body.append(rtf_escape(preview))
        body.append("\\f0\\fs22\\par\\par")

    body.append("\\b Part statistics\\b0\\par")
    body.append(rtf_escape(f"Total lines in part: {chunk_lines}"))
    body.append("\\par")
    for role, count in sorted(chunk_roles.items(), key=lambda item: (-item[1], item[0])):
        body.append(rtf_escape(f"- {role}: {count} files"))
        body.append("\\par")
    body.append("}")

    output_path.write_text("".join(body), encoding="utf-8")


def main() -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    files = collect_dart_files()
    if not files:
        print("No Dart files found.", file=sys.stderr)
        return 1

    chunks = chunk_evenly(files, PART_COUNT)
    role_counter: Counter[str] = Counter()

    for part_number, chunk in enumerate(chunks, start=1):
        write_rtf_part(part_number, chunk, len(files), role_counter)
        print(f"Wrote Product_Review_Part_{part_number}.rtf ({len(chunk)} files)")

    summary_path = OUTPUT_DIR / "Product_Review_Index.txt"
    summary_path.write_text(
        "\n".join(
            [
                f"Generated: {datetime.now(timezone.utc).isoformat()}",
                f"Workspace: {WORKSPACE}",
                f"Total Dart files: {len(files)}",
                f"Parts: {PART_COUNT}",
                "",
                "Role distribution (all files):",
                *[f"  {role}: {count}" for role, count in role_counter.most_common()],
            ]
        ),
        encoding="utf-8",
    )
    print(f"Index: {summary_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
