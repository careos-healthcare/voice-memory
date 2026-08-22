#!/usr/bin/env python3
"""Fix discarded_futures / unawaited_futures using whole-line transforms."""

from __future__ import annotations

import json
import re
import subprocess
from collections import defaultdict
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
LIB = PROJECT / "lib"


def run_analyze() -> list[dict]:
    result = subprocess.run(
        ["dart", "analyze", "--format=json", "lib"],
        cwd=PROJECT,
        capture_output=True,
        text=True,
        check=False,
    )
    return [
        d
        for d in json.loads(result.stdout)["diagnostics"]
        if d["code"] in {"discarded_futures", "unawaited_futures"}
    ]


def is_part_file(text: str) -> bool:
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("part of"):
            return True
        if stripped and not stripped.startswith("//"):
            break
    return False


def ensure_dart_async_import(lines: list[str]) -> list[str]:
    joined = "".join(lines)
    if "unawaited(" not in joined:
        return lines
    if re.search(r"import\s+'dart:async'", joined):
        return lines
    insert_at = 0
    for i, line in enumerate(lines):
        if line.startswith("import ") or line.startswith("export "):
            insert_at = i + 1
    lines.insert(insert_at, "import 'dart:async';\n")
    return lines


def should_fix_line(line: str) -> bool:
    stripped = line.strip()
    if not stripped or stripped.startswith("//"):
        return False
    return stripped.endswith(";")


def fix_line(line: str, code: str) -> str:
    if not should_fix_line(line):
        return line

    stripped = line.lstrip()
    indent = line[: len(line) - len(stripped)]
    body = stripped.rstrip("\n")
    trailing_newline = "\n" if line.endswith("\n") else ""
    core = body.rstrip()[:-1].rstrip()

    if code == "unawaited_futures":
        if core.lstrip().startswith("await "):
            return line
        return f"{indent}await {core.lstrip()};{trailing_newline}"

    if core.lstrip().startswith("unawaited("):
        return line

    if "?." in core and re.search(r"\.(dispose|close)\(\)$", core):
        match = re.match(r"^(\w+)\?\.(\w+)\(\)$", core.strip())
        if match:
            var, method = match.groups()
            return (
                f"{indent}final _disposable = {var};\n"
                f"{indent}if (_disposable != null) "
                f"unawaited(_disposable.{method}());{trailing_newline}"
            )

    return f"{indent}unawaited({core});{trailing_newline}"


def main() -> None:
    diagnostics = run_analyze()
    by_file_line: dict[str, dict[int, str]] = defaultdict(dict)
    for diag in diagnostics:
        path = diag["location"]["file"]
        if not path.startswith(str(LIB)):
            continue
        line_no = diag["location"]["range"]["start"]["line"]
        by_file_line[path][line_no] = diag["code"]

    changed = 0
    for file_path, line_codes in by_file_line.items():
        path = Path(file_path)
        original = path.read_text(encoding="utf-8")
        if is_part_file(original):
            continue

        lines = original.splitlines(keepends=True)
        needs_async = False
        for line_no, code in sorted(line_codes.items(), reverse=True):
            idx = line_no - 1
            if idx < 0 or idx >= len(lines):
                continue
            new_line = fix_line(lines[idx], code)
            if new_line != lines[idx]:
                if code == "discarded_futures" and "unawaited(" in new_line:
                    needs_async = True
                if new_line.count("\n") > 1:
                    lines[idx : idx + 1] = new_line.splitlines(keepends=True)
                else:
                    lines[idx] = new_line

        if needs_async:
            lines = ensure_dart_async_import(lines)

        updated = "".join(lines)
        if updated != original:
            path.write_text(updated, encoding="utf-8")
            changed += 1
            print(f"fixed {path.relative_to(PROJECT)} ({len(line_codes)} lines)")

    remaining = run_analyze()
    print(f"Updated {changed} files; {len(remaining)} future lint issues remain.")


if __name__ == "__main__":
    main()
