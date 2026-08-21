#!/usr/bin/env bash
# Reports feature consolidation metrics:
#   1) baseline lib/features module count
#   2) quarantined routes that still map to present feature dirs
#   3) orphan feature dirs (no imports from outside lib/features/<name>/)
#
# Usage: bash tool/audit_feature_consolidation_candidates.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python3 << 'PY'
from __future__ import annotations

import re
import subprocess
from pathlib import Path

ROOT = Path('.')
FEATURES = ROOT / 'lib' / 'features'
REGISTRY = ROOT / 'lib' / 'router' / 'v1_route_registry.dart'

text = REGISTRY.read_text()
exact = re.findall(r"'(/[^']+)'", text.split('quarantinedExactPaths')[1].split('];')[0])
param = re.findall(r"'(/[^']+)'", text.split('parameterizedQuarantinePaths')[1].split('];')[0])
quarantined = exact + param

feature_dirs = sorted(p.name for p in FEATURES.iterdir() if p.is_dir())


def route_candidates(path: str) -> set[str]:
    parts = [p for p in path.strip('/').split('/') if p and not p.startswith(':')]
    out = set()
    for part in parts:
        out.add(part.replace('-', '_'))
    if len(parts) >= 2:
        out.add('_'.join(parts).replace('-', '_'))
    return out


mapped: dict[str, set[str]] = {}
for route in quarantined:
    for cand in route_candidates(route):
        if cand in feature_dirs:
            mapped.setdefault(cand, set()).add(route)

orphans: list[str] = []
for name in feature_dirs:
    hits = subprocess.run(
        [
            'grep',
            '-rl',
            f'features/{name}/',
            'lib',
            '--include=*.dart',
        ],
        capture_output=True,
        text=True,
        check=False,
    ).stdout.splitlines()
    external = [h for h in hits if not h.startswith(f'lib/features/{name}/')]
    if not external:
        orphans.append(name)

quarantined_present = sorted(mapped)
candidates = sorted(set(quarantined_present) & set(orphans))

print('=== 1. BASELINE ===')
print(f'feature_dir_count={len(feature_dirs)}')
print('(track this; should only go down over consolidation cycles)')
print()

print('=== 2. QUARANTINED ROUTE -> PRESENT FEATURE DIR ===')
for name in quarantined_present:
    tag = 'ORPHAN' if name in orphans else 'referenced-in-lib-outside-module'
    routes = ', '.join(sorted(mapped[name]))
    print(f'{name}\t{tag}\t{routes}')
print()

print('=== 3. ORPHAN FEATURE DIRS (lib/ only) ===')
for name in sorted(orphans):
    print(name)
print()

print('=== 4. ATTIC CANDIDATES (quarantined + orphan + present) ===')
if candidates:
    for name in candidates:
        print(name)
else:
    print('(none)')
PY
