#!/usr/bin/env python3
"""Fail when an `ios/Runner` Swift file is not compiled by the Runner target.

Adding a `.swift` file to the directory does not add it to the build. Xcode only
compiles what the target's Sources build phase lists, so a file can sit on disk,
be imported by nothing, and vanish from the binary with no error anywhere — the
call site that needed it fails much later with `cannot find 'X' in scope`, or
worse, a channel handler is silently never registered and the Dart side just
times out. `HardwareMonitorChannelHandler.swift` was lost exactly this way.

The reverse direction matters too: a phase entry whose file is gone breaks the
build outright, and a stale entry is the usual leftover from a rename.

Run via: python3 tool/run_gate.py validates ios_sources_phase
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PBXPROJ = os.path.join(ROOT, "ios", "Runner.xcodeproj", "project.pbxproj")
SOURCES_DIR = os.path.join(ROOT, "ios", "Runner")
TARGET_NAME = "Runner"

# `<id> /* <comment> */ = {isa = PBXBuildFile; fileRef = <id> /* ... */; };`
BUILD_FILE = re.compile(
    r"^\s*([0-9A-Z]{8,32})\s*/\*.*?\*/\s*=\s*\{isa = PBXBuildFile;.*?fileRef = ([0-9A-Z]{8,32})",
    re.MULTILINE,
)
# `<id> /* <comment> */ = {isa = PBXFileReference; ... path = <path>; ... };`
FILE_REF = re.compile(
    r"^\s*([0-9A-Z]{8,32})\s*/\*.*?\*/\s*=\s*\{isa = PBXFileReference;([^}]*)\}",
    re.MULTILINE,
)
PATH_ATTR = re.compile(r"\bpath = (\"[^\"]*\"|[^;]+);")

problems = []


def fail(message):
    problems.append(message)


def section(text, name):
    """Body of a `/* Begin <name> section */ ... /* End <name> section */` block."""
    match = re.search(
        r"/\* Begin %s section \*/(.*?)/\* End %s section \*/" % (name, name),
        text,
        re.DOTALL,
    )
    return match.group(1) if match else ""


def sources_phase_id(text, target):
    """The PBXSourcesBuildPhase id referenced by the named native target.

    Both Runner and RunnerTests own a phase literally commented `Sources`, so
    the phase has to be reached through the target rather than by its comment.
    """
    body = section(text, "PBXNativeTarget")
    for block in re.finditer(r"\{(.*?)\n\t\t\};", body, re.DOTALL):
        chunk = block.group(1)
        name = re.search(r"\bname = (\"[^\"]*\"|[^;]+);", chunk)
        if not name or name.group(1).strip().strip('"') != target:
            continue
        phases = re.search(r"buildPhases = \((.*?)\);", chunk, re.DOTALL)
        if not phases:
            fail(f"target {target} has no buildPhases list")
            return None
        ids = re.findall(r"([0-9A-Z]{8,32})\s*/\* Sources \*/", phases.group(1))
        if len(ids) != 1:
            fail(f"target {target} has {len(ids)} Sources phases, expected exactly 1")
            return None
        return ids[0]
    fail(f"no PBXNativeTarget named {target} in project.pbxproj")
    return None


def compiled_paths(text, phase_id):
    """File paths the given Sources phase compiles, resolved through PBXBuildFile."""
    refs = {m.group(1): m.group(2) for m in BUILD_FILE.finditer(section(text, "PBXBuildFile"))}

    paths = {}
    for match in FILE_REF.finditer(section(text, "PBXFileReference")):
        attr = PATH_ATTR.search(match.group(2))
        if attr:
            paths[match.group(1)] = attr.group(1).strip().strip('"')

    body = section(text, "PBXSourcesBuildPhase")
    block = re.search(
        r"%s\s*/\*.*?files = \((.*?)\);" % re.escape(phase_id), body, re.DOTALL
    )
    if not block:
        fail(f"Sources phase {phase_id} not found in PBXSourcesBuildPhase")
        return {}

    # A list, not a set: the same file listed twice is itself a defect.
    compiled = []
    for build_file_id in re.findall(r"([0-9A-Z]{8,32})\s*/\*", block.group(1)):
        ref = refs.get(build_file_id)
        if ref is None:
            fail(f"build file {build_file_id} in Sources resolves to no PBXBuildFile entry")
            continue
        path = paths.get(ref)
        if path is None:
            fail(f"build file {build_file_id} points at missing file reference {ref}")
            continue
        compiled.append(os.path.basename(path))
    return compiled


def main():
    if not os.path.isfile(PBXPROJ):
        print(f"missing {PBXPROJ}")
        return 1
    if not os.path.isdir(SOURCES_DIR):
        print(f"missing {SOURCES_DIR}")
        return 1

    with open(PBXPROJ, encoding="utf-8") as handle:
        text = handle.read()

    phase_id = sources_phase_id(text, TARGET_NAME)
    compiled = compiled_paths(text, phase_id) if phase_id else []

    on_disk = {
        name
        for name in os.listdir(SOURCES_DIR)
        if name.endswith(".swift") and os.path.isfile(os.path.join(SOURCES_DIR, name))
    }
    compiled_swift = [name for name in compiled if name.endswith(".swift")]
    unique_swift = set(compiled_swift)

    uncompiled = sorted(on_disk - unique_swift)
    if uncompiled:
        fail(
            f"{len(uncompiled)} Swift file(s) in ios/{TARGET_NAME} are not in the "
            f"{TARGET_NAME} Sources phase, so nothing compiles them: "
            + ", ".join(uncompiled)
        )

    for name in sorted(unique_swift - on_disk):
        fail(f"{name} is compiled by the {TARGET_NAME} target but is not on disk")

    duplicates = sorted({name for name in compiled_swift if compiled_swift.count(name) > 1})
    if duplicates:
        fail(f"compiled more than once (duplicate-symbol risk): {', '.join(duplicates)}")

    if problems:
        print(f"ios/{TARGET_NAME} Sources phase is out of sync with the directory:\n")
        for problem in problems:
            print(f"  - {problem}")
        print(
            f"\non disk: {len(on_disk)} .swift   in Sources phase: {len(unique_swift)} .swift"
        )
        print(
            "fix by adding the file to the Runner target in Xcode "
            "(File inspector > Target Membership), which edits project.pbxproj"
        )
        return 1

    print(
        f"ios/{TARGET_NAME} Sources phase is in sync: all {len(on_disk)} Swift file(s) "
        f"on disk are compiled, no stale entries."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
