#!/usr/bin/env python3
"""Export every lib/*.dart source file into ten Apple Notes-friendly text files."""

from __future__ import annotations

import re
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path


APP_ROOT = Path(__file__).resolve().parents[1]
LIB_ROOT = APP_ROOT / "lib"
OUTPUT_ROOT = Path.home() / "Desktop" / "app22"

OUTPUTS = {
    "01": "01_Core_and_Main.txt",
    "02": "02_UI_Components.txt",
    "03": "03_Transcription_and_Audio.txt",
    "04": "04_State_and_Riverpod.txt",
    "05": "05_Services_and_Storage.txt",
    "06": "06_Screens_and_Navigation.txt",
    "07": "07_Intelligence_and_Analysis.txt",
    "08": "08_Life_OS_Graph_and_Local_AI.txt",
    "09": "09_Monetization_Privacy_and_Onboarding.txt",
    "10": "10_Features_Models_and_Utilities.txt",
}

DECLARATION = re.compile(
    r"^(?:(?:abstract|base|final|sealed|interface)\s+)*"
    r"(?:class|enum|mixin|extension)\s+"
)


def contains_any(value: str, terms: tuple[str, ...]) -> bool:
    return any(term in value for term in terms)


def group_for(relative_path: Path) -> str:
    value = relative_path.as_posix().lower()
    parts = set(relative_path.parts)
    name = relative_path.name.lower()

    if parts & {"widgets", "design", "theme"}:
        return "02"

    if (
        parts & {"audio", "record"}
        or contains_any(
            value,
            (
                "transcription_queue/",
                "voice_capture/",
                "live_audio/",
                "recording",
                "microphone",
                "speech",
                "whisper",
            ),
        )
    ):
        return "03"

    if contains_any(
        name,
        (
            "_provider.dart",
            "_providers.dart",
            "_notifier.dart",
            "_controller.dart",
        ),
    ) or parts & {"providers", "state"}:
        return "04"

    if parts & {"services", "storage", "repositories", "infrastructure", "network", "push"}:
        return "05"

    if parts & {"screens", "router"}:
        return "06"

    if contains_any(
        value,
        (
            "knowledge_graph",
            "personal_knowledge",
            "life_os",
            "llama",
            "vector",
            "embedding",
            "cloud_sync",
            "graph/",
            "graph_",
        ),
    ):
        return "08"

    if contains_any(
        value,
        (
            "billing/",
            "monetization/",
            "paywall",
            "subscription",
            "revenuecat",
            "onboarding/",
            "privacy",
            "backup",
            "disaster_recovery",
            "export",
            "entitlement",
            "app_lock",
        ),
    ):
        return "09"

    if contains_any(
        value,
        (
            "analysis",
            "analyzer",
            "analyst",
            "insight",
            "comparison",
            "pattern",
            "evolution",
            "prediction",
            "sentiment",
            "identity",
            "life_chapter",
            "timeline",
            "coach",
            "story_engine",
            "archive_engine",
        ),
    ) or name.endswith("_engine.dart"):
        return "07"

    if parts & {"core", "config", "startup", "api", "auth", "security", "product"} or name in {
        "main.dart",
        "app.dart",
    }:
        return "01"

    return "10"


def notes_body(source: str) -> str:
    rendered: list[str] = []
    declaration_count = 0
    for line in source.splitlines():
        if DECLARATION.match(line):
            if declaration_count:
                rendered.extend(("", "---", ""))
            declaration_count += 1
        rendered.append(line)
    return "\n".join(rendered).rstrip() + "\n"


def output_header(title: str, count: int, generated_at: str) -> str:
    return (
        f"{title}\n"
        f"{'=' * len(title)}\n\n"
        "ArchiveMe / VoiceMemory Dart source export for Apple Notes\n"
        f"Generated: {generated_at}\n"
        f"Source: {LIB_ROOT}\n"
        f"Dart files in this volume: {count}\n"
        "Format: UTF-8 plain text; each source file starts with its relative path.\n\n"
    )


def file_block(relative_path: Path, source: str) -> str:
    divider = "=" * 88
    return (
        f"{divider}\n"
        f"FILE: lib/{relative_path.as_posix()}\n"
        f"{divider}\n\n"
        f"{notes_body(source)}\n"
        "--- END OF FILE ---\n\n"
    )


def main() -> None:
    dart_files = sorted(path for path in LIB_ROOT.rglob("*.dart") if path.is_file())
    if not dart_files:
        raise SystemExit(f"No Dart files found under {LIB_ROOT}")

    grouped: dict[str, list[Path]] = {key: [] for key in OUTPUTS}
    for source_path in dart_files:
        relative_path = source_path.relative_to(LIB_ROOT)
        grouped[group_for(relative_path)].append(source_path)

    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    exported_paths: list[str] = []

    for key, output_name in OUTPUTS.items():
        output_path = OUTPUT_ROOT / output_name
        paths = grouped[key]
        with output_path.open("w", encoding="utf-8", newline="\n") as output:
            output.write(output_header(output_name.removesuffix(".txt"), len(paths), generated_at))
            for source_path in paths:
                relative_path = source_path.relative_to(LIB_ROOT)
                source = source_path.read_text(encoding="utf-8", errors="replace")
                output.write(file_block(relative_path, source))
                exported_paths.append(relative_path.as_posix())

    counts = Counter(exported_paths)
    duplicates = [path for path, count in counts.items() if count != 1]
    expected = {path.relative_to(LIB_ROOT).as_posix() for path in dart_files}
    actual = set(exported_paths)
    if duplicates or actual != expected:
        missing = sorted(expected - actual)
        unexpected = sorted(actual - expected)
        raise SystemExit(
            "Export verification failed: "
            f"duplicates={duplicates[:5]}, missing={missing[:5]}, unexpected={unexpected[:5]}"
        )

    print(f"Exported {len(dart_files)} Dart files into {len(OUTPUTS)} text files.")
    print(f"Output directory: {OUTPUT_ROOT}")
    for key, output_name in OUTPUTS.items():
        output_path = OUTPUT_ROOT / output_name
        print(
            f"  {output_name}: {len(grouped[key])} Dart files, "
            f"{output_path.stat().st_size:,} bytes"
        )


if __name__ == "__main__":
    main()
