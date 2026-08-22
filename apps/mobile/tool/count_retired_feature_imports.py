#!/usr/bin/env python3
"""Count package: imports that resolve to retired_sprawl symlink feature dirs."""

import os
import re
import sys
from pathlib import Path

FEATURE_IMPORT = re.compile(r"package:archiveme_mobile/features/([a-z0-9_]+)")


def v1_feature_dirs(features_dir: Path) -> set[str]:
    if not features_dir.is_dir():
        return set()
    return {
        name
        for name in os.listdir(features_dir)
        if (features_dir / name).is_dir() and not (features_dir / name).is_symlink()
    }


def scan_tree(root: Path, mobile: Path, v1: set[str]) -> tuple[set[str], dict[str, set[str]]]:
    retired: set[str] = set()
    by_file: dict[str, set[str]] = {}
    if not root.is_dir():
        return retired, by_file

    for path in root.rglob("*.dart"):
        if "retired_sprawl" in path.parts:
            continue
        hits = set()
        text = path.read_text(encoding="utf-8", errors="replace")
        for match in FEATURE_IMPORT.finditer(text):
            feature = match.group(1)
            if feature not in v1:
                hits.add(feature)
        if hits:
            retired |= hits
            by_file[str(path.relative_to(mobile))] = hits
    return retired, by_file


def main() -> int:
    mobile = Path(__file__).resolve().parent.parent
    features_dir = mobile / "lib/features"

    v1 = v1_feature_dirs(features_dir)
    symlink_count = sum(
        1
        for name in os.listdir(features_dir)
        if (features_dir / name).is_symlink()
    )

    lib_retired, lib_files = scan_tree(mobile / "lib", mobile, v1)
    test_retired, test_files = scan_tree(mobile / "test", mobile, v1)
    all_retired = lib_retired | test_retired

    print("Retired feature import audit")
    print(f" -> V1 feature dirs: {len(v1)}")
    print(f" -> Symlink feature dirs: {symlink_count}")
    print(f" -> Unique retired features imported: {len(all_retired)}")
    print(f" -> lib/ files with retired imports: {len(lib_files)}")
    print(f" -> test/ files with retired imports: {len(test_files)}")

    if all_retired:
        print("\nDeletion gate (retired_sprawl/) requires 0 unique retired features imported.")
        print("Top imported retired modules:")
        for name in sorted(all_retired)[:20]:
            print(f"   - {name}")
        if len(all_retired) > 20:
            print(f"   ... and {len(all_retired) - 20} more")
        return 1

    print("\n[SUCCESS] No retired feature imports detected — safe to delete retired_sprawl/.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
