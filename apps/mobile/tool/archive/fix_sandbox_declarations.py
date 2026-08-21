#!/usr/bin/env python3
"""Add group-scoped late sandbox + tearDown where setUp creates a sandbox."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "test"
SETUP_CREATE = re.compile(
    r"^(\s*)setUp\(\(\) async \{\n"
    r"(?:\1  .*\n)*?"
    r"\1  sandbox = TestStorageSandbox\.create\(\);\n",
    re.MULTILINE,
)
GROUP_OPEN = re.compile(r"^(\s*)group\([^\)]+\) \{\n", re.MULTILINE)


def enclosing_group(text: str, setup_start: int) -> tuple[int, str] | None:
    setup_indent = len(re.match(r"^(\s*)", text[setup_start:]).group(1))
    before = text[:setup_start]
    candidates = [
        (m.start(), m.group(1))
        for m in GROUP_OPEN.finditer(before)
        if len(m.group(1)) < setup_indent
    ]
    if not candidates:
        return None
    return candidates[-1]


def group_has_sandbox_decl(text: str, group_start: int, setup_start: int) -> bool:
    return "late TestStorageSandbox sandbox;" in text[group_start:setup_start]


def find_setup_close(text: str, setup_start: int, indent: str) -> int | None:
    match = re.search(rf"^{re.escape(indent)}\}}\);\n", text[setup_start:], re.MULTILINE)
    if not match:
        return None
    return setup_start + match.end()


def fix_file(path: Path) -> bool:
    text = path.read_text()
    original = text
    offset = 0
    while True:
        match = SETUP_CREATE.search(text, offset)
        if not match:
            break
        setup_start = match.start()
        indent = match.group(1)
        group = enclosing_group(text, setup_start)
        if group is None:
            main = re.search(
                r"void main\(\) \{([\s\S]*?)(?:^  group\(|^  test\(|^  testWidgets\()",
                text,
                re.MULTILINE,
            )
            if main and "late TestStorageSandbox sandbox;" not in main.group(1):
                text = text.replace(
                    "void main() {",
                    "void main() {\n  late TestStorageSandbox sandbox;\n",
                    1,
                )
            close = find_setup_close(text, match.end(), indent)
            if close and f"{indent}tearDown(() => sandbox.dispose())" not in text[match.start(): close + 120]:
                text = text[:close] + f"\n{indent}tearDown(() => sandbox.dispose());\n" + text[close:]
            offset = (close or match.end()) + 50
            continue

        group_start, group_indent = group
        if not group_has_sandbox_decl(text, group_start, setup_start):
            header = re.search(
                rf"^{re.escape(group_indent)}group\([^\)]+\) \{{\n",
                text[group_start:setup_start],
                re.MULTILINE,
            )
            if header:
                insert_at = group_start + header.end()
                decl = f"{group_indent}late TestStorageSandbox sandbox;\n\n"
                text = text[:insert_at] + decl + text[insert_at:]
                setup_start += len(decl)
                match = SETUP_CREATE.search(text, setup_start - 1)
                if not match:
                    break

        close = find_setup_close(text, match.end(), indent)
        if close and f"{indent}tearDown(() => sandbox.dispose())" not in text[match.start(): close + 120]:
            text = text[:close] + f"\n{indent}tearDown(() => sandbox.dispose());\n" + text[close:]

        offset = match.end() + 100

    if text == original:
        return False
    path.write_text(text)
    return True


def main() -> None:
    fixed = []
    for path in sorted(ROOT.rglob("*.dart")):
        if path.name == "test_storage_sandbox_test.dart":
            continue
        if fix_file(path):
            fixed.append(str(path.relative_to(ROOT)))
    print(f"Fixed {len(fixed)} files")
    for name in fixed:
        print(f"  {name}")


if __name__ == "__main__":
    main()
