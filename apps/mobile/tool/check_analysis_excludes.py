#!/usr/bin/env python3
"""Fail when the generated analyzer exclude block drifts from the symlinks on disk.

The analyzer reaches retired code *through* the `lib/features/<name>` symlinks and
reports it under those paths, so `retired_sprawl/**` alone excludes nothing. Every
symlink therefore needs its own `lib/features/<name>/**` entry. When the two sets
disagree, retired files get analyzed and the issue count moves for reasons that
have nothing to do with the code anyone just wrote.

Run via: python3 tool/run_gate.py validates analysis_excludes
"""

import os
import re
import sys

BEGIN = "# BEGIN generated: lib/features symlink excludes (restore_lib_features_symlinks.sh)"
END = "# END generated"
GENERATED_ITEM = re.compile(r"^\s*-\s*lib/features/([^/\s]+)/\*\*\s*$")
RETIRED_ITEM = re.compile(r"^\s*-\s*retired_sprawl/\*\*\s*$")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OPTIONS_PATH = os.path.join(ROOT, "analysis_options.yaml")
FEATURES_DIR = os.path.join(ROOT, "lib", "features")
REMEDIATION = "./tool/restore_lib_features_symlinks.sh"

problems = []


def fail(message):
    problems.append(message)


def symlinked_features():
    """Feature dirs that are symlinks into retired_sprawl, plus integrity problems."""
    names, dangling = set(), []
    if not os.path.isdir(FEATURES_DIR):
        fail(f"missing {FEATURES_DIR}")
        return names, dangling
    for entry in sorted(os.listdir(FEATURES_DIR)):
        path = os.path.join(FEATURES_DIR, entry)
        if not os.path.islink(path):
            continue
        target = os.readlink(path)
        if "retired_sprawl/lib_features/" not in target.replace(os.sep, "/"):
            fail(f"lib/features/{entry} is a symlink to an unexpected target: {target}")
            continue
        if not os.path.exists(path):
            dangling.append(entry)
        names.add(entry)
    return names, dangling


def excluded_features():
    """Feature names listed inside the generated block, plus block-shape problems."""
    if not os.path.isfile(OPTIONS_PATH):
        fail("analysis_options.yaml is missing; the analyzer would run with no excludes")
        return []

    with open(OPTIONS_PATH, encoding="utf-8") as handle:
        lines = handle.read().splitlines()

    begins = [i for i, line in enumerate(lines) if line.strip() == BEGIN]
    ends = [i for i, line in enumerate(lines) if line.strip() == END]

    if len(begins) != 1 or len(ends) != 1:
        fail(
            f"expected exactly one generated block, found {len(begins)} BEGIN and "
            f"{len(ends)} END markers (a duplicated block means the generator appended "
            f"instead of replacing)"
        )
        return []
    if ends[0] < begins[0]:
        fail("generated block markers are out of order")
        return []

    if not any(RETIRED_ITEM.match(line) for line in lines):
        fail("the `- retired_sprawl/**` exclude is missing")

    names = []
    for line in lines[begins[0] + 1:ends[0]]:
        if not line.strip():
            continue
        match = GENERATED_ITEM.match(line)
        if not match:
            fail(f"unexpected line inside the generated block: {line.strip()!r}")
            continue
        names.append(match.group(1))

    # Entries outside the block would be invisible to the generator's rewrite.
    outside = [
        GENERATED_ITEM.match(line).group(1)
        for i, line in enumerate(lines)
        if GENERATED_ITEM.match(line) and not begins[0] < i < ends[0]
    ]
    for name in outside:
        fail(
            f"lib/features/{name}/** is excluded outside the generated block; "
            f"move it inside so the generator keeps it in sync"
        )

    return names


def main():
    symlinks, dangling = symlinked_features()
    listed = excluded_features()

    for name in dangling:
        fail(f"lib/features/{name} is a dangling symlink (its retired_sprawl target is gone)")

    duplicates = sorted({name for name in listed if listed.count(name) > 1})
    if duplicates:
        fail(f"duplicate exclude entries: {', '.join(duplicates)}")

    excluded = set(listed)
    if listed != sorted(listed):
        fail("generated block is not sorted; re-run the generator for a stable diff")

    leaked = sorted(symlinks - excluded)
    if leaked:
        fail(
            f"{len(leaked)} symlinked feature(s) are NOT excluded, so retired code is "
            f"being analyzed: {', '.join(leaked[:10])}"
            + (" ..." if len(leaked) > 10 else "")
        )

    stale = sorted(excluded - symlinks)
    if stale:
        fail(
            f"{len(stale)} exclude entry(ies) have no matching symlink, so live code may "
            f"be silently unanalyzed: {', '.join(stale[:10])}"
            + (" ..." if len(stale) > 10 else "")
        )

    if problems:
        print("analyzer exclude drift detected:\n")
        for problem in problems:
            print(f"  - {problem}")
        print(f"\nsymlinks on disk: {len(symlinks)}   entries in block: {len(set(listed))}")
        print(f"regenerate with: {REMEDIATION}")
        return 1

    print(
        f"analyzer excludes are in sync: {len(symlinks)} lib/features symlinks, "
        f"{len(excluded)} exclude entries, retired_sprawl/** present."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
