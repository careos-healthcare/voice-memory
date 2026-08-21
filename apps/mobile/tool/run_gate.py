#!/usr/bin/env python3
"""Run CI gates, audits, validates, and self-tests from gates.yaml."""

import os
import subprocess
import sys

try:
    import yaml
except ImportError:
    yaml = None

MANIFEST_SECTIONS = (
    "gates",
    "audits",
    "validates",
    "self_tests",
)


def _fallback_load_manifest(manifest_path):
    """Minimal YAML loader when PyYAML is unavailable."""
    sections = {name: {} for name in MANIFEST_SECTIONS}
    current_section = None
    current_name = None

    with open(manifest_path, "r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.rstrip("\n")
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue

            if stripped.endswith(":") and not line.startswith(" "):
                top_level = stripped[:-1]
                if top_level in sections:
                    current_section = top_level
                    current_name = None
                continue

            if current_section and stripped.endswith(":") and line.startswith("  "):
                current_name = stripped[:-1]
                sections[current_section][current_name] = {}
                continue

            if current_section and current_name and "command:" in stripped:
                command = stripped.split("command:", 1)[1].strip().strip("\"'")
                sections[current_section][current_name]["command"] = command

    return sections


def load_manifest():
    manifest_path = os.path.join(os.path.dirname(__file__), "gates.yaml")
    if yaml:
        with open(manifest_path, "r", encoding="utf-8") as handle:
            data = yaml.safe_load(handle) or {}
        return {name: data.get(name, {}) for name in MANIFEST_SECTIONS}

    print("PyYAML not found, using lightweight built-in manifest loader...")
    return _fallback_load_manifest(manifest_path)


def resolve_entry(manifest, section, name):
    entries = manifest.get(section, {})
    if name not in entries:
        return None
    entry = entries[name]
    command = entry.get("command")
    if not command:
        return None
    return command


def usage(manifest):
    print("Usage: python3 tool/run_gate.py <section> <name>")
    print("       python3 tool/run_gate.py <gate_name>   # legacy: top-level gates only")
    print("")
    for section in MANIFEST_SECTIONS:
        names = sorted(manifest.get(section, {}).keys())
        if names:
            print(f"{section}: {', '.join(names)}")


def main():
    manifest = load_manifest()
    argv = sys.argv[1:]

    if not argv:
        usage(manifest)
        sys.exit(1)

    if len(argv) == 1:
        gate_name = argv[0]
        command = resolve_entry(manifest, "gates", gate_name)
        if not command:
            print(f"Error: gate '{gate_name}' not found in manifest.")
            usage(manifest)
            sys.exit(1)
        section_label = f"gates/{gate_name}"
    else:
        section, gate_name = argv[0], argv[1]
        if section not in MANIFEST_SECTIONS:
            print(f"Error: unknown section '{section}'.")
            usage(manifest)
            sys.exit(1)
        command = resolve_entry(manifest, section, gate_name)
        if not command:
            print(f"Error: '{gate_name}' not found under section '{section}'.")
            available = sorted(manifest.get(section, {}).keys())
            print(f"Available in {section}: {', '.join(available)}")
            sys.exit(1)
        section_label = f"{section}/{gate_name}"

    print(f"Running gate [{section_label}]: {command}")
    result = subprocess.run(command, shell=True)
    sys.exit(result.returncode)


if __name__ == "__main__":
    main()
