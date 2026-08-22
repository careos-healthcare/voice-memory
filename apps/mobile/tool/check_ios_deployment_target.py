#!/usr/bin/env python3
"""Fail when an iOS plugin needs a newer iOS than the app's deployment target.

The app's floor lives in several places that have to agree, and a plugin that
needs more than that floor breaks the build in a way that names the plugin but
not the cause. The Podfile `post_install` hook makes this worse: it force-writes
`IPHONEOS_DEPLOYMENT_TARGET` onto every pod, overwriting each podspec's own
requirement, so an under-target CocoaPods plugin does not complain during
`pod install` — it fails later, during compilation, inside someone else's code.

Both plugin systems have to be read. Flutter routes a plugin through Swift
Package Manager when it ships a `Package.swift` and through CocoaPods when it
does not, and this project uses both at once. Checking only SPM misses
`objectbox_flutter_libs` and `health`, which are podspec-only; checking only
podspecs misses nothing today but would break the moment a plugin drops its
podspec. Reading one system silently under-reports.

Requires `.flutter-plugins-dependencies`, which `flutter pub get` writes.

Run via: python3 tool/run_gate.py validates ios_deployment_target
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, ".flutter-plugins-dependencies")
PUBSPEC = os.path.join(ROOT, "pubspec.yaml")
LOCKFILE = os.path.join(ROOT, "pubspec.lock")
PODFILE = os.path.join(ROOT, "ios", "Podfile")
PBXPROJ = os.path.join(ROOT, "ios", "Runner.xcodeproj", "project.pbxproj")
GENERATED_SPM = os.path.join(
    ROOT, "ios", "Flutter", "ephemeral", "Packages",
    "FlutterGeneratedPluginSwiftPackage", "Package.swift",
)

PBX_TARGET = re.compile(r"IPHONEOS_DEPLOYMENT_TARGET\s*=\s*([0-9.]+)\s*;")
PODFILE_PLATFORM = re.compile(r"^\s*platform\s+:ios\s*,\s*['\"]([0-9.]+)['\"]", re.MULTILINE)
PODFILE_OVERRIDE = re.compile(
    r"IPHONEOS_DEPLOYMENT_TARGET['\"]\]\s*=\s*['\"]([0-9.]+)['\"]"
)

# `.iOS("16.0")` and `.iOS(.v16)` / `.iOS(.v13_1)` are both legal SwiftPM.
SPM_STRING = re.compile(r"\.iOS\(\s*['\"]([0-9.]+)['\"]\s*\)")
SPM_ENUM = re.compile(r"\.iOS\(\s*\.v(\d+)(?:_(\d+))?\s*\)")
# Podspecs declare it either as `s.ios.deployment_target` or via `s.platform`.
POD_DEPLOYMENT_TARGET = re.compile(
    r"\.ios\.deployment_target\s*=\s*['\"]([0-9.]+)['\"]"
)
POD_PLATFORM = re.compile(r"\.platform\s*=\s*:ios\s*,\s*['\"]([0-9.]+)['\"]")


def version(text):
    """`"16"` and `"16.0"` both become `(16, 0)` so they compare equal."""
    parts = [int(part) for part in text.split(".") if part != ""]
    while len(parts) < 2:
        parts.append(0)
    return tuple(parts[:3])


def show(parsed):
    return ".".join(str(part) for part in parsed[:2])


def read(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read()
    except OSError:
        return ""


def app_floor():
    """Lowest deployment target the app declares, and every place it is declared."""
    sources = {}

    pbx = [version(m) for m in PBX_TARGET.findall(read(PBXPROJ))]
    if pbx:
        sources["project.pbxproj"] = min(pbx)

    podfile = read(PODFILE)
    platform = PODFILE_PLATFORM.findall(podfile)
    if platform:
        sources["Podfile platform"] = min(version(v) for v in platform)
    override = PODFILE_OVERRIDE.findall(podfile)
    if override:
        sources["Podfile post_install"] = min(version(v) for v in override)

    return (min(sources.values()) if sources else None), sources


def declared_packages():
    """Package names appearing under any dependency block in pubspec.yaml."""
    names, inside = set(), False
    for line in read(PUBSPEC).splitlines():
        if re.match(r"^(dependencies|dev_dependencies|dependency_overrides):", line):
            inside = True
            continue
        if line and not line[0].isspace() and not line.startswith("#"):
            inside = False
        match = re.match(r"^  ([A-Za-z0-9_]+):", line)
        if inside and match:
            names.add(match.group(1))
    return names


def locked_packages():
    """Package name -> its `dependency:` kind from pubspec.lock."""
    kinds, name = {}, None
    for line in read(LOCKFILE).splitlines():
        match = re.match(r"^  ([A-Za-z0-9_]+):\s*$", line)
        if match:
            name = match.group(1)
            continue
        kind = re.match(r"^    dependency:\s*\"?([a-z ]+)\"?\s*$", line)
        if kind and name:
            kinds[name] = kind.group(1)
    return kinds


def plugin_manifests(plugin_path, name):
    """The SPM and podspec manifests for a plugin, wherever the plugin keeps them.

    Plugins put their Apple sources under `ios/` or, when the same code serves
    macOS too, under `darwin/`.
    """
    spm, podspec = None, None
    for platform_dir in ("ios", "darwin"):
        base = os.path.join(plugin_path, platform_dir)
        candidate = os.path.join(base, name, "Package.swift")
        if spm is None and os.path.isfile(candidate):
            spm = candidate
        candidate = os.path.join(base, f"{name}.podspec")
        if podspec is None and os.path.isfile(candidate):
            podspec = candidate
    return spm, podspec


def spm_requirement(path):
    text = read(path)
    found = [version(v) for v in SPM_STRING.findall(text)]
    found += [version(f"{major}.{minor or 0}") for major, minor in SPM_ENUM.findall(text)]
    return max(found) if found else None


def podspec_requirement(path):
    text = read(path)
    found = [version(v) for v in POD_DEPLOYMENT_TARGET.findall(text)]
    found += [version(v) for v in POD_PLATFORM.findall(text)]
    return max(found) if found else None


def main(argv):
    # Answers "what breaks if we move the target to X" without editing the
    # Podfile to find out, and lets the gate itself be tested.
    assumed = None
    if "--assume-floor" in argv:
        assumed = version(argv[argv.index("--assume-floor") + 1])

    if not os.path.isfile(MANIFEST):
        print("`.flutter-plugins-dependencies` is missing, so no plugin can be checked.")
        print("run `flutter pub get` first.")
        return 1

    with open(MANIFEST, encoding="utf-8") as handle:
        manifest = json.load(handle)

    floor, floor_sources = app_floor()
    if floor is None:
        print("no IPHONEOS_DEPLOYMENT_TARGET found in project.pbxproj or ios/Podfile.")
        return 1
    declared_sources = dict(floor_sources)
    if assumed is not None:
        floor = assumed
        floor_sources = {"--assume-floor": assumed}

    spm_enabled = bool(manifest.get("swift_package_manager_enabled"))
    declared = declared_packages()
    locked = locked_packages()

    # The manifest is a build artefact. When it predates the pubspec it can name
    # plugins that are no longer dependencies, so its verdict is reported but
    # never silently trusted.
    stale_reasons = []
    manifest_mtime = os.path.getmtime(MANIFEST)
    for path, label in ((PUBSPEC, "pubspec.yaml"), (LOCKFILE, "pubspec.lock")):
        if os.path.isfile(path) and os.path.getmtime(path) > manifest_mtime:
            stale_reasons.append(f"{label} has been modified since the manifest was written")

    rows, unknown, orphaned = [], [], []

    for plugin in manifest.get("plugins", {}).get("ios", []):
        name = plugin["name"]
        path = plugin.get("path") or ""

        if not os.path.isdir(path):
            orphaned.append(name)
            continue

        spm_path, podspec_path = plugin_manifests(path, name)
        spm = spm_requirement(spm_path) if spm_path else None
        pod = podspec_requirement(podspec_path) if podspec_path else None

        # Flutter prefers SPM when the plugin ships a package and SPM is on.
        if spm is not None and spm_enabled:
            required, system = spm, "spm"
        elif pod is not None:
            required, system = pod, "cocoapods"
        elif spm is not None:
            required, system = spm, "spm"
        else:
            unknown.append(name)
            continue

        # A plugin whose package is `direct` in the lock but absent from
        # pubspec.yaml was removed from the pubspec without a re-resolve.
        kind = locked.get(name, "")
        removed = bool(kind) and kind.startswith("direct") and name not in declared

        rows.append((name, required, system, removed))
        if removed:
            stale_reasons.append(
                f"{name} is `{kind}` in pubspec.lock but is not declared in pubspec.yaml"
            )

    violations = sorted(
        (row for row in rows if row[1] > floor),
        key=lambda row: (row[1], row[0]),
        reverse=True,
    )
    live = [row for row in rows if not row[3]]

    print(
        f"app deployment target floor: iOS {show(floor)}  "
        + "  ".join(f"[{label} {show(value)}]" for label, value in sorted(floor_sources.items()))
    )
    generated = read(GENERATED_SPM)
    if generated:
        found = [version(v) for v in SPM_STRING.findall(generated)]
        found += [version(f"{a}.{b or 0}") for a, b in SPM_ENUM.findall(generated)]
        if found:
            marker = "ok" if min(found) >= floor else "STALE"
            print(
                f"generated SPM package declares iOS {show(min(found))} ({marker}) — "
                f"Xcode resolves this before any script phase can regenerate it"
            )
    print(
        f"checked {len(rows)} iOS plugin(s): "
        f"{sum(1 for row in rows if row[2] == 'spm')} via SPM, "
        f"{sum(1 for row in rows if row[2] == 'cocoapods')} via CocoaPods"
    )

    if stale_reasons:
        print("\nWARNING — `.flutter-plugins-dependencies` may be stale:")
        for reason in sorted(set(stale_reasons)):
            print(f"  - {reason}")
        print(
            "  the plugin list below is the one the manifest describes, which may not "
            "be the one the next `flutter pub get` produces."
        )

    if orphaned:
        print(
            f"\nWARNING — {len(orphaned)} plugin path(s) in the manifest no longer exist "
            f"on disk, so their requirement could not be read: {', '.join(sorted(orphaned))}"
        )
    if unknown:
        print(
            f"\nnote: {len(unknown)} plugin(s) declare no iOS requirement of their own "
            f"and inherit the app's: {', '.join(sorted(unknown))}"
        )

    if violations:
        print(
            f"\n{len(violations)} plugin(s) require a newer iOS than the app's "
            f"floor of {show(floor)}:\n"
        )
        for name, required, system, removed in violations:
            suffix = "  (stale? not declared in pubspec.yaml)" if removed else ""
            print(f"  - {name:<32} needs iOS {show(required):<6} via {system}{suffix}")
        needed = max(row[1] for row in violations)
        print(f"\nraise the deployment target to at least {show(needed)} in:")
        for label in sorted(declared_sources):
            print(f"  - {label}")
        print(f"  - {os.path.relpath(GENERATED_SPM, ROOT)} (regenerate, do not hand-edit)")

        live_violations = [row for row in violations if not row[3]]
        if len(live_violations) != len(violations):
            if live_violations:
                still = max(row[1] for row in live_violations)
                drivers = sorted(name for name, req, _, _ in live_violations if req == still)
                print(
                    f"\nsetting aside the possibly-stale plugin(s), iOS {show(still)} would "
                    f"still be required by: {', '.join(drivers)}"
                )
            else:
                print(
                    "\nevery violation comes from a possibly-stale plugin; re-run after "
                    "`flutter pub get` before lowering the target."
                )
        return 1

    highest = max((row[1] for row in live), default=None)
    if highest is not None:
        drivers = sorted(name for name, req, _, removed in rows if req == highest and not removed)
        print(
            f"\nall plugins fit under iOS {show(floor)}. The highest requirement is "
            f"{show(highest)} from: {', '.join(drivers)}"
        )
    else:
        print(f"\nall plugins fit under iOS {show(floor)}.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
