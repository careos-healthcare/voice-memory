#!/usr/bin/env python3
"""Repair broken TestStorageSandbox migration artifacts."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "test"
IMPORT_SUFFIX = "support/test_storage_sandbox.dart';"


def import_for(path: Path) -> str:
    rel = path.parent.relative_to(ROOT)
    depth = len(rel.parts)
    prefix = "../" * depth if depth else ""
    return f"import '{prefix}support/test_storage_sandbox.dart';"


def strip_misplaced_imports(text: str) -> str:
    lines = []
    for ln in text.splitlines():
        if "support/test_storage_sandbox.dart" in ln and ln.strip().startswith("import "):
            continue
        lines.append(ln)
    out = "\n".join(lines)
    return out + ("\n" if text.endswith("\n") else "")


def ensure_import(text: str, path: Path) -> str:
    imp = import_for(path)
    if imp in text:
        return text
    matches = list(re.finditer(r"^import .+;$", text, flags=re.MULTILINE))
    if matches:
        pos = matches[-1].end()
        return text[:pos] + "\n" + imp + text[pos:]
    return imp + "\n" + text


def uses_sandbox(text: str) -> bool:
    return bool(
        re.search(r"\bsandbox\.(journalPath|prefsPath|recoveryPath|outputPath|path|root|dispose|ensureDir|clock|ids)\b", text)
        or "TestStorageSandbox.create" in text
        or "late TestStorageSandbox sandbox" in text
    )


def replace_temp_paths(text: str) -> str:
    text = text.replace("'${tempDir.path}/prefs.json'", "sandbox.prefsPath")
    text = text.replace("'${tempDir.path}/journal.json'", "sandbox.journalPath")
    text = text.replace("${tempDir.path}/prefs.json", "sandbox.prefsPath")
    text = text.replace("${tempDir.path}/journal.json", "sandbox.journalPath")
    text = text.replace("tempDir.path", "sandbox.root.path")
    return text


def remove_tempdir_declarations(text: str) -> str:
    text = re.sub(r"\n  late Directory tempDir;\n", "\n", text)
    text = re.sub(r"\n    late Directory tempDir;\n", "\n", text)
    text = re.sub(r"\n      late Directory tempDir;\n", "\n", text)
    return text


def remove_tempdir_setup_lines(text: str) -> str:
    patterns = [
        r"\n\s*tempDir = await Directory\.systemTemp\.createTemp\([^)]*\);\s*",
        r"\n\s*tempDir = Directory\.systemTemp\.createTempSync\([^)]*\);\s*",
        r"\n\s*final tempDir = await Directory\.systemTemp\.createTemp\([^)]*\);\s*",
        r"\n\s*final tempDir = Directory\.systemTemp\.createTempSync\([^)]*\);\s*",
        r"\n\s*tempDir = Directory\(sandbox\.path\([^)]*\)\);\s*",
    ]
    for pat in patterns:
        text = re.sub(pat, "\n", text)
    return text


def remove_tempdir_teardown(text: str) -> str:
    patterns = [
        r"\n\s*if \(await tempDir\.exists\(\)\) \{\s*\n\s*await tempDir\.delete\(recursive: true\);\s*\n\s*\}\s*",
        r"\n\s*if \(tempDir\.existsSync\(\)\) tempDir\.deleteSync\(recursive: true\);\s*",
        r"\n\s*tempDir\.deleteSync\(recursive: true\);\s*",
        r"\n\s*addTearDown\(\(\) => tempDir\.deleteSync\(recursive: true\)\);\s*",
    ]
    for pat in patterns:
        text = re.sub(pat, "\n", text)
    return text


def ensure_main_sandbox(text: str) -> str:
    if not re.search(r"\bsandbox\.", text):
        return text
    if "late TestStorageSandbox sandbox;" not in text:
        text = text.replace("void main() {", "void main() {\n  late TestStorageSandbox sandbox;", 1)
    # Wire first setUp at main level if sandbox never assigned.
    if "sandbox = TestStorageSandbox.create" not in text:
        text = re.sub(
            r"(setUp\(\(\) async \{)",
            r"\1\n    sandbox = TestStorageSandbox.create();",
            text,
            count=1,
        )
    if "sandbox.dispose()" not in text:
        if re.search(r"\ntearDown\(\(\) \{", text):
            text = re.sub(r"tearDown\(\(\) \{", "tearDown(() {\n    sandbox.dispose();", text, count=1)
        elif re.search(r"\ntearDown\(\(\) async \{", text):
            text = re.sub(
                r"tearDown\(\(\) async \{",
                "tearDown(() async {\n    sandbox.dispose();",
                text,
                count=1,
            )
        else:
            m = re.search(r"\n  group\(|\n  testWidgets\(|\n  test\(", text)
            if m:
                pos = m.start()
                text = text[:pos] + "\n\n  tearDown(() => sandbox.dispose());" + text[pos:]
    return text


def ensure_group_sandboxes(text: str) -> str:
    """Add sandbox wiring inside groups that use sandbox but declare their own scope."""
    group_pattern = re.compile(
        r"(group\([^{]+\{)(.*?)(?=\n  group\(|\n\}\s*$)",
        re.DOTALL,
    )

    def fix_group(match: re.Match[str]) -> str:
        header, body = match.group(1), match.group(2)
        if not re.search(r"\bsandbox\.", body):
            return match.group(0)
        new_body = body
        if "late TestStorageSandbox sandbox;" not in body and "TestStorageSandbox sandbox" not in body:
            new_body = "\n    late TestStorageSandbox sandbox;" + new_body
        if "sandbox = TestStorageSandbox.create" not in body:
            if re.search(r"setUp\(\(\) async \{", body):
                new_body = re.sub(
                    r"(setUp\(\(\) async \{)",
                    r"\1\n      sandbox = TestStorageSandbox.create();",
                    new_body,
                    count=1,
                )
            elif re.search(r"setUp\(\(\) \{", body):
                new_body = re.sub(
                    r"(setUp\(\(\) \{)",
                    r"\1\n      sandbox = TestStorageSandbox.create();",
                    new_body,
                    count=1,
                )
        if "sandbox.dispose()" not in body:
            if re.search(r"tearDown\(\(\) async \{", body):
                new_body = re.sub(
                    r"tearDown\(\(\) async \{",
                    "tearDown(() async {\n      sandbox.dispose();",
                    body if new_body == body else new_body,
                    count=1,
                )
            elif re.search(r"tearDown\(\(\) \{", body):
                new_body = re.sub(
                    r"tearDown\(\(\) \{",
                    "tearDown(() {\n      sandbox.dispose();",
                    new_body,
                    count=1,
                )
            else:
                first_test = re.search(r"\n    test(?:Widgets)?\(", new_body)
                if first_test:
                    pos = first_test.start()
                    new_body = new_body[:pos] + "\n\n    tearDown(() => sandbox.dispose());" + new_body[pos:]
        return header + new_body

    return group_pattern.sub(fix_group, text)


def ensure_inline_test_sandboxes(text: str) -> str:
    """Tests that reference sandbox without group/main scope get a local sandbox."""
    pattern = re.compile(
        r"(?P<indent>\n(?:    )*)test(?:Widgets)?\([^)]+\) async \{"
        r"(?P<body>(?:(?!\n\1\}).)*?sandbox\.(?:(?!\n\1\}).)*?\n\1\})",
        re.DOTALL,
    )

    def fix_test(match: re.Match[str]) -> str:
        block = match.group(0)
        if "TestStorageSandbox.create" in block or "late TestStorageSandbox sandbox" in block:
            return block
        indent = match.group("indent") + "  "
        setup = (
            f"{indent}final sandbox = TestStorageSandbox.create();\n"
            f"{indent}addTearDown(() => sandbox.dispose());\n"
        )
        return block.replace(
            f"{match.group('indent')}test",
            f"{setup}{match.group('indent')}test",
            1,
        )

    prev = None
    while prev != text:
        prev = text
        text = pattern.sub(fix_test, text)
    return text


def repair_file(path: Path) -> bool:
    if path.name == "test_storage_sandbox.dart":
        return False
    text = path.read_text()
    original = text

    if not uses_sandbox(text) and "tempDir" not in text:
        return False

    text = strip_misplaced_imports(text)
    if uses_sandbox(text):
        text = ensure_import(text, path)
    text = replace_temp_paths(text)
    text = remove_tempdir_setup_lines(text)
    text = remove_tempdir_teardown(text)
    text = remove_tempdir_declarations(text)
    if uses_sandbox(text):
        text = ensure_main_sandbox(text)
        text = ensure_group_sandboxes(text)
        text = ensure_inline_test_sandboxes(text)

    if text != original:
        path.write_text(text)
        return True
    return False


def main() -> None:
    changed = 0
    for path in sorted(ROOT.rglob("*.dart")):
        if repair_file(path):
            changed += 1
            print(f"fixed {path.relative_to(ROOT)}")
    print(f"repaired {changed} files")


if __name__ == "__main__":
    main()
