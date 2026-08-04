#!/usr/bin/env python3
"""Fail-closed verifier for Genesis artifact manifests."""

from __future__ import annotations

import hashlib
import json
import pathlib
import sys
from typing import NoReturn


def fail(message: str) -> NoReturn:
    raise SystemExit(f"Genesis manifest verification failed: {message}")


def digest(path: pathlib.Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def main() -> None:
    if len(sys.argv) != 3:
        fail("usage: verify_genesis_manifest.py MANIFEST ARTIFACT_DIRECTORY")
    manifest_path = pathlib.Path(sys.argv[1]).resolve()
    artifact_root = pathlib.Path(sys.argv[2]).resolve()
    if not manifest_path.is_file() or not artifact_root.is_dir():
        fail("manifest or artifact directory is missing")
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        fail(f"manifest cannot be decoded: {error}")
    if (
        manifest.get("schemaVersion") != 1
        or manifest.get("hashAlgorithm") != "SHA-256"
        or not isinstance(manifest.get("artifacts"), list)
    ):
        fail("unsupported manifest schema")

    declared: set[str] = set()
    for record in manifest["artifacts"]:
        if not isinstance(record, dict):
            fail("artifact record is not an object")
        name = record.get("name")
        expected_hash = record.get("sha256")
        expected_size = record.get("bytes")
        if (
            not isinstance(name, str)
            or pathlib.PurePath(name).name != name
            or name in declared
        ):
            fail("artifact name is unsafe or duplicated")
        if (
            not isinstance(expected_hash, str)
            or len(expected_hash) != 64
            or any(character not in "0123456789abcdef" for character in expected_hash)
            or not isinstance(expected_size, int)
            or expected_size < 0
        ):
            fail(f"artifact metadata is invalid for {name}")
        artifact = artifact_root / name
        if not artifact.is_file():
            fail(f"artifact is missing: {name}")
        if artifact.stat().st_size != expected_size:
            fail(f"artifact size differs: {name}")
        if digest(artifact) != expected_hash:
            fail(f"artifact hash differs: {name}")
        declared.add(name)

    actual = {path.name for path in artifact_root.iterdir() if path.is_file()}
    if actual != declared:
        fail("artifact directory contains undeclared or missing files")
    print(f"Verified {len(declared)} Genesis artifact(s).")


if __name__ == "__main__":
    main()
