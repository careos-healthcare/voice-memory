#!/usr/bin/env python3
"""Remove orphaned tempDir declarations after sandbox migration."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "test"


def cleanup(text: str) -> str:
    # Drop unused late tempDir declarations.
    text = re.sub(r"\n  late Directory tempDir;\n", "\n", text)
    text = re.sub(r"\n    late Directory tempDir;\n", "\n", text)
    text = re.sub(r"\n      late Directory tempDir;\n", "\n", text)
    # Drop unused main-level sandbox when never referenced.
    if "late TestStorageSandbox sandbox;" in text and not re.search(
        r"\bsandbox\.", text
    ):
        text = re.sub(r"\n  late TestStorageSandbox sandbox;\n", "\n", text)
        text = re.sub(r"\n\n  tearDown\(\(\) => sandbox\.dispose\(\)\);\n", "\n", text)
    return text


def main() -> None:
    changed = 0
    for path in sorted(ROOT.rglob("*.dart")):
        original = path.read_text()
        updated = cleanup(original)
        if updated != original:
            path.write_text(updated)
            changed += 1
    print(f"cleaned {changed} files")


if __name__ == "__main__":
    main()
