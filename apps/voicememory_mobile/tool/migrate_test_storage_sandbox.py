#!/usr/bin/env python3
"""Migrate timestamp-based journal/prefs test paths to TestStorageSandbox."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "test"

PATTERN = re.compile(
    r"journalPath:\s*\n?\s*'test/tmp/[^']+\$\{DateTime\.now\(\)\.microsecondsSinceEpoch\}_journal\.json',\s*\n?\s*prefsPath:\s*\n?\s*'test/tmp/[^']+\$\{DateTime\.now\(\)\.microsecondsSinceEpoch\}_prefs\.json',",
    re.MULTILINE,
)

PATTERN_ROOT = re.compile(
    r"journalPath:\s*'\$\{DateTime\.now\(\)\.microsecondsSinceEpoch\}_journal\.json',\s*\n?\s*prefsPath:\s*'\$\{DateTime\.now\(\)\.microsecondsSinceEpoch\}_prefs\.json',",
    re.MULTILINE,
)

PATTERN_TEMP_DIR = re.compile(
    r"(\s*)tempDir = Directory\.systemTemp\.createTempSync\([^)]+\);\s*\n"
    r"\1await AppServices\.resetForTest\(\s*\n"
    r"\1\s*journalPath: '\$\{tempDir\.path\}/journal\.json',",
    re.MULTILINE,
)

REPLACEMENT = """journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,"""

REPLACEMENT_TEMP = """\\1sandbox = TestStorageSandbox.create();
\\1await AppServices.resetForTest(
\\1  journalPath: sandbox.journalPath,"""


def import_for(path: Path) -> str:
    rel = path.parent.relative_to(ROOT)
    depth = len(rel.parts)
    prefix = "../" * depth if depth else ""
    return f"import '{prefix}support/test_storage_sandbox.dart';"


def ensure_import(text: str, path: Path) -> str:
    imp = import_for(path)
    if imp in text:
        return text
    matches = list(re.finditer(r"^import .+;$", text, flags=re.MULTILINE))
    if not matches:
        return imp + "\n" + text
    pos = matches[-1].end()
    return text[:pos] + "\n" + imp + text[pos:]


def wire_sandbox_in_setup(text: str, setup_indent: str) -> str:
    """Add sandbox create/dispose only inside the setUp/tearDown block being migrated."""
    block_start = text.find(f"{setup_indent}setUp(")
    if block_start == -1:
        return text
    if f"{setup_indent}sandbox = TestStorageSandbox.create();" in text:
        return text
    text = text.replace(
        f"{setup_indent}setUp(() async {{",
        f"{setup_indent}setUp(() async {{\n{setup_indent}  sandbox = TestStorageSandbox.create();",
        1,
    )
    text = text.replace(
        f"{setup_indent}setUp(() {{",
        f"{setup_indent}setUp(() {{\n{setup_indent}  sandbox = TestStorageSandbox.create();",
        1,
    )
    # Declare sandbox at same indent as setUp if missing.
    decl = f"{setup_indent}late TestStorageSandbox sandbox;"
    if decl not in text and "late TestStorageSandbox sandbox;" not in text:
        text = text.replace(
            f"{setup_indent}setUp(",
            f"{decl}\n{setup_indent}setUp(",
            1,
        )
    dispose = f"{setup_indent}tearDown(() => sandbox.dispose());"
    if "sandbox.dispose()" not in text:
        # Insert after setUp block's closing if no tearDown in this scope.
        setup_end = text.find(f"{setup_indent}setUp(")
        if setup_end != -1:
            brace = text.find("{", setup_end)
            depth = 0
            i = brace
            while i < len(text):
                if text[i] == "{":
                    depth += 1
                elif text[i] == "}":
                    depth -= 1
                    if depth == 0:
                        text = text[: i + 1] + f"\n\n{dispose}" + text[i + 1 :]
                        break
                i += 1
    return text


def migrate_file(path: Path, text: str) -> str:
    original = text
    indent = "    "
    if PATTERN_TEMP_DIR.search(text):
        indent_match = PATTERN_TEMP_DIR.search(text)
        indent = indent_match.group(1) if indent_match else "    "
    new = PATTERN.sub(REPLACEMENT, text)
    new = PATTERN_ROOT.sub(REPLACEMENT, new)
    new = PATTERN_TEMP_DIR.sub(REPLACEMENT_TEMP, new)
    if new == original:
        return text
    new = ensure_import(new, path)
    new = wire_sandbox_in_setup(new, indent)
    return new


def main() -> None:
    updated = 0
    for path in sorted(ROOT.rglob("*.dart")):
        if path.name in {"test_storage_sandbox.dart", "test_storage_sandbox_test.dart"}:
            continue
        text = path.read_text()
        if "microsecondsSinceEpoch}_journal.json" not in text and PATTERN_TEMP_DIR.search(text) is None:
            continue
        new = migrate_file(path, text)
        if new == text:
            print(f"SKIP (pattern miss): {path.relative_to(ROOT)}")
            continue
        path.write_text(new)
        updated += 1
        print(f"OK {path.relative_to(ROOT)}")
    print(f"updated {updated} files")


if __name__ == "__main__":
    main()
