#!/usr/bin/env python3
"""Move sandbox tearDown from main() into groups that actually create the sandbox."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "test"


def main_body(text: str) -> str | None:
    match = re.search(
        r"void main\(\) \{([\s\S]*?)(?:^  group\(|^  test\(|^  testWidgets\()",
        text,
        re.MULTILINE,
    )
    return match.group(1) if match else None


def fix_file(path: Path) -> bool:
    text = path.read_text()
    original = text
    body = main_body(text)
    if body is None:
        return False
    if "tearDown(() => sandbox.dispose())" not in body:
        return False
    if "sandbox = TestStorageSandbox.create()" in body:
        return False

    new_body = body
    new_body = re.sub(r"\n  late TestStorageSandbox sandbox;\n", "\n", new_body)
    new_body = re.sub(r"\n  tearDown\(\(\) => sandbox\.dispose\(\)\);\n", "\n", new_body)
    text = text.replace(body, new_body, 1)

    # Ensure each setUp that creates sandbox has group-scoped late + tearDown.
    pattern = re.compile(
        r"^(\s*)setUp\(\(\) async \{\n"
        r"(?:\1  .*\n)*?"
        r"\1  sandbox = TestStorageSandbox\.create\(\);\n",
        re.MULTILINE,
    )
    offset = 0
    while True:
        match = pattern.search(text, offset)
        if not match:
            break
        indent = match.group(1)
        setup_start = match.start()

        before = text[:setup_start]
        group_starts = list(re.finditer(rf"^{re.escape(indent)}group\(", before, re.MULTILINE))
        if not group_starts:
            offset = match.end()
            continue
        group_start = group_starts[-1].start()
        group_header = re.search(
            rf"^{re.escape(indent)}group\([^\)]+\) \{{\n",
            text[group_start:setup_start],
            re.MULTILINE,
        )
        if not group_header:
            offset = match.end()
            continue

        insert_pos = group_start + group_header.end()
        group_prefix = text[group_start:setup_start + 200]
        decl = f"{indent}late TestStorageSandbox sandbox;\n\n"
        if f"{indent}late TestStorageSandbox sandbox;" not in group_prefix:
            text = text[:insert_pos] + decl + text[insert_pos:]
            setup_start += len(decl)
            match = pattern.search(text, setup_start - 1)
            if not match:
                break

        group_slice = text[group_start : match.end() + 400]
        tear_line = f"{indent}tearDown(() => sandbox.dispose());"
        if tear_line not in group_slice:
            setup_end = match.end()
            close = re.search(rf"^{re.escape(indent)}\}}\);\n", text[setup_end:], re.MULTILINE)
            if close:
                pos = setup_end + close.end()
                text = text[:pos] + f"\n{indent}tearDown(() => sandbox.dispose());\n" + text[pos:]

        offset = match.end() + 100

    if text == original:
        return False
    path.write_text(text)
    return True


def main() -> None:
    fixed: list[str] = []
    for path in sorted(ROOT.rglob("*.dart")):
        if fix_file(path):
            fixed.append(str(path.relative_to(ROOT)))
    print(f"Fixed {len(fixed)} files")
    for name in fixed:
        print(f"  {name}")


if __name__ == "__main__":
    main()
