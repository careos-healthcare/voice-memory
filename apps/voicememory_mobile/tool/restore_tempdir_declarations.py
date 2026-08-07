#!/usr/bin/env python3
"""Restore late Directory tempDir declarations where still referenced."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "test"


def fix_file(text: str) -> str:
    if "tempDir" not in text:
        return text
    if re.search(r"\blate Directory tempDir\b", text):
        return text

    # Main-level setUp uses tempDir.
    if re.search(r"\n  setUp\([^)]*\)[^{]*\{[^}]*tempDir", text, re.DOTALL):
        if "void main()" in text:
            text = text.replace("void main() {", "void main() {\n  late Directory tempDir;", 1)
            return text

    # Group-level setUp uses tempDir.
    for m in re.finditer(r"(group\([^{]+\{)", text):
        start = m.end()
        # find matching group body until next same-indent group or end
        depth = 1
        i = start
        while i < len(text) and depth:
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
            i += 1
        body = text[start : i - 1]
        if "tempDir" in body and "late Directory tempDir" not in body:
            insert_at = start
            text = text[:insert_at] + "\n    late Directory tempDir;" + text[insert_at:]
            return fix_file(text)  # recurse for multiple groups

    # Inline test/function scope — add at start of setUp in nested group
    if "tempDir" in text:
        text = re.sub(
            r"(\n    setUp\(\(\) async \{)",
            r"\1\n    late Directory tempDir;",
            text,
            count=1,
        )
    return text


def main() -> None:
    changed = 0
    for path in sorted(ROOT.rglob("*.dart")):
        original = path.read_text()
        if "tempDir" not in original:
            continue
        if re.search(r"\blate Directory tempDir\b", original):
            continue
        updated = fix_file(original)
        if updated != original:
            path.write_text(updated)
            changed += 1
            print(path.relative_to(ROOT))
    print(f"restored tempDir in {changed} files")


if __name__ == "__main__":
    main()
