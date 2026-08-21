#!/usr/bin/env python3
"""Fix duplicate/unassigned TestStorageSandbox declarations from migration."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "test"


def main_block(text: str) -> tuple[str, int, int]:
    m = re.search(r"void main\(\) \{", text)
    if not m:
        return text, 0, len(text)
    start = m.end()
    depth = 1
    i = start
    while i < len(text) and depth:
        if text[i : i + 1] == "{":
            depth += 1
        elif text[i : i + 1] == "}":
            depth -= 1
        i += 1
    return text, start, i - 1


def has_assignment(block: str) -> bool:
    return bool(re.search(r"\bsandbox\s*=\s*TestStorageSandbox\.create", block))


def uses_sandbox(block: str) -> bool:
    return bool(re.search(r"\bsandbox\.", block))


def remove_line(block: str, pattern: str) -> str:
    return re.sub(pattern, "", block)


def fix_file(text: str) -> str:
    original = text
    _, main_start, main_end = main_block(text)
    main_body = text[main_start:main_end]

    # Drop orphan main-level sandbox when never assigned at main scope.
    if "late TestStorageSandbox sandbox;" in main_body and not has_assignment(main_body):
        # Keep only if no nested group declares its own sandbox.
        nested_groups = re.findall(r"group\([^{]+\{(.*?)(?=\n  group\(|\n\}$)", main_body, re.DOTALL)
        group_has_sandbox = any(
            "late TestStorageSandbox sandbox;" in g or has_assignment(g) for g in nested_groups
        )
        if group_has_sandbox or not uses_sandbox(main_body.split("group(")[0]):
            main_body = remove_line(main_body, r"\n  late TestStorageSandbox sandbox;")
            main_body = remove_line(main_body, r"\n\n  tearDown\(\(\) => sandbox\.dispose\(\)\);")
            main_body = remove_line(main_body, r"\n  tearDown\(\(\) => sandbox\.dispose\(\)\);")

    # Ensure group scopes that use sandbox assign it.
    def fix_group(match: re.Match[str]) -> str:
        header, body = match.group(1), match.group(2)
        if not uses_sandbox(body):
            return match.group(0)
        if "late TestStorageSandbox sandbox;" not in body and "final sandbox = TestStorageSandbox.create()" not in body:
            body = "\n    late TestStorageSandbox sandbox;" + body
        if not has_assignment(body):
            if re.search(r"setUp\(\(\) async \{", body):
                body = re.sub(
                    r"(setUp\(\(\) async \{)",
                    r"\1\n      sandbox = TestStorageSandbox.create();",
                    body,
                    count=1,
                )
            elif re.search(r"setUp\(\(\) \{", body):
                body = re.sub(
                    r"(setUp\(\(\) \{)",
                    r"\1\n      sandbox = TestStorageSandbox.create();",
                    body,
                    count=1,
                )
        if "sandbox.dispose()" not in body:
            if re.search(r"tearDown\(\(\)", body):
                body = re.sub(
                    r"(tearDown\(\(\)(?: async)? \{)",
                    r"\1\n      sandbox.dispose();",
                    body,
                    count=1,
                )
            else:
                t = re.search(r"\n    test(?:Widgets)?\(", body)
                if t:
                    body = body[: t.start()] + "\n\n    tearDown(() => sandbox.dispose());" + body[t.start() :]
        return header + body

    main_body = re.sub(
        r"(group\([^{]+\{)(.*?)(?=\n  group\(|\n\}$)",
        fix_group,
        main_body,
        flags=re.DOTALL,
    )

    # Main-level sandbox used and assigned? ensure tearDown.
    if "late TestStorageSandbox sandbox;" in main_body and has_assignment(main_body):
        if "sandbox.dispose()" not in main_body.split("group(")[0]:
            setup = re.search(r"setUp\(\(\)", main_body)
            if setup:
                pos = main_body.find("\n", setup.start())
                main_body = (
                    main_body[:pos]
                    + "\n\n  tearDown(() => sandbox.dispose());"
                    + main_body[pos:]
                )

    # Inline tests using sandbox without local assignment.
    inline = re.compile(
        r"(\n(?:      )*)test(?:Widgets)?\([^)]+\) async \{"
        r"((?:(?!\n(?:      )*test(?:Widgets)?\().)*?sandbox\.(?:(?!\n(?:      )*\}).)*?\n(?:      )*\})",
        re.DOTALL,
    )

    def fix_inline(m: re.Match[str]) -> str:
        block = m.group(0)
        if has_assignment(block) or "final sandbox = TestStorageSandbox.create()" in block:
            return block
        indent = m.group(1) + "  "
        setup = (
            f"{indent}final sandbox = TestStorageSandbox.create();\n"
            f"{indent}addTearDown(() => sandbox.dispose());\n"
        )
        return setup + block.lstrip("\n")

    main_body = inline.sub(fix_inline, main_body)

    # tempDir leftovers -> sandbox.root.path
    main_body = main_body.replace("tempDir.path", "sandbox.root.path")
    main_body = re.sub(
        r"\n\s*if \(tempDir\.existsSync\(\)\)[^\n]*\n",
        "\n",
        main_body,
    )
    main_body = re.sub(
        r"\n\s*if \(await tempDir\.exists\(\)\)[\s\S]*?\n\s*\}\n",
        "\n",
        main_body,
    )

    text = text[:main_start] + main_body + text[main_end:]
    return text if text != original else original


def main() -> None:
    changed = 0
    for path in sorted(ROOT.rglob("*.dart")):
        if path.name == "test_storage_sandbox.dart":
            continue
        original = path.read_text()
        updated = fix_file(original)
        if updated != original:
            path.write_text(updated)
            changed += 1
            print(f"scoped {path.relative_to(ROOT)}")
    print(f"scoped {changed} files")


if __name__ == "__main__":
    main()
