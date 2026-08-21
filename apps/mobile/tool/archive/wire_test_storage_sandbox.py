#!/usr/bin/env python3
"""Ensure every sandbox.* usage has create/dispose wiring."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "test"


def import_for(path: Path) -> str:
    rel = path.parent.relative_to(ROOT)
    depth = len(rel.parts)
    prefix = "../" * depth if depth else ""
    return f"import '{prefix}support/test_storage_sandbox.dart';"


def uses_sandbox(text: str) -> bool:
    return bool(re.search(r"\bsandbox\.(journalPath|prefsPath|recoveryPath|outputPath|path|root)\b", text))


def has_create(text: str) -> bool:
    return "TestStorageSandbox.create" in text


def repair(text: str, path: Path) -> str:
    if not uses_sandbox(text):
        return text
    text = text if import_for(path) in text else ensure_import(text, path)

    if not re.search(r"\blate TestStorageSandbox sandbox\b", text) and "final sandbox = TestStorageSandbox.create()" not in text:
        text = text.replace("void main() {", "void main() {\n  late TestStorageSandbox sandbox;", 1)

    if not has_create(text):
        text = re.sub(
            r"(setUp\(\(\) async \{)",
            r"\1\n    sandbox = TestStorageSandbox.create();",
            text,
            count=1,
        )

    if "sandbox.dispose()" not in text:
        # Prefer dedicated dispose tearDown before async cleanup tearDowns.
        m = re.search(r"\n  tearDown\(\(\) async \{", text)
        if m:
            text = text[: m.start()] + "\n  tearDown(() => sandbox.dispose());" + text[m.start() :]
        elif re.search(r"\n  tearDown\(\(\) \{", text):
            text = re.sub(r"\n  tearDown\(\(\) \{", "\n  tearDown(() => sandbox.dispose());\n  tearDown(() {", text, count=1)
        else:
            m2 = re.search(r"\n  group\(|\n  testWidgets\(|\n  test\(", text)
            if m2:
                text = text[: m2.start()] + "\n\n  tearDown(() => sandbox.dispose());" + text[m2.start() :]

    return text


def ensure_import(text: str, path: Path) -> str:
    imp = import_for(path)
    matches = list(re.finditer(r"^import .+;$", text, flags=re.MULTILINE))
    if not matches:
        return imp + "\n" + text
    pos = matches[-1].end()
    return text[:pos] + "\n" + imp + text[pos:]


def main() -> None:
    changed = 0
    for path in sorted(ROOT.rglob("*.dart")):
        if path.name == "test_storage_sandbox.dart":
            continue
        original = path.read_text()
        updated = repair(original, path)
        if updated != original:
            path.write_text(updated)
            changed += 1
            print(f"wired {path.relative_to(ROOT)}")
    print(f"wired {changed} files")


if __name__ == "__main__":
    main()
