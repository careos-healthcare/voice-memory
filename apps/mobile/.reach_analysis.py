#!/usr/bin/env python3
"""Reachability analysis for the retired_sprawl burn-down.

Builds a transitive closure over import/export/part edges, resolving symlinks
and deduplicating by realpath. Over-approximates reachability everywhere it is
ambiguous, so the "unreachable" set is a lower bound.

This is the generator for `.reach_state.json`. Consumers are `.reach_safety.py`,
`.reach_block.py`, and `.reach_preflight.py`. Re-run this script from
`apps/mobile` whenever a significant retired_sprawl change lands — module
moves, RecordScreen-scale cleanups — rather than leaving the cache stale.
Paths written to `.reach_state.json` are relative to this directory so the
cache is not machine-specific.
"""
import os, re, sys, json
from collections import defaultdict, deque

ROOT = os.path.abspath(os.path.dirname(__file__))
ROOT_REAL = os.path.realpath(ROOT)
PKG = "archiveme_mobile"
LIB = os.path.join(ROOT, "lib")
RETIRED = os.path.join(ROOT, "retired_sprawl")


def rel_real(path):
    """Symlink-collapsed path relative to apps/mobile."""
    return os.path.relpath(os.path.realpath(path), ROOT_REAL)


def rel_logical(path):
    """Checkout-relative path that keeps lib/features symlink identity."""
    abs_path = os.path.abspath(path)
    rel = os.path.relpath(abs_path, ROOT)
    if not rel.startswith(".."):
        return rel
    return os.path.relpath(os.path.realpath(abs_path), ROOT_REAL)

def rp(p):
    return os.path.realpath(p)

RETIRED_RP = rp(RETIRED)

# ---------------------------------------------------------------- file universe
def walk(base, follow=True):
    out = []
    for dirpath, dirnames, filenames in os.walk(base, followlinks=follow):
        dirnames[:] = [d for d in dirnames if d not in (".dart_tool", "build", ".git")]
        for f in filenames:
            if f.endswith(".dart"):
                out.append(os.path.join(dirpath, f))
    return out

SCAN_DIRS = ["lib", "test", "integration_test", "retired_sprawl", "tool", "scripts",
             "experiments", "attic", "hook", "native", "config", "apps"]
logical_paths = defaultdict(set)   # realpath -> {logical paths}
for d in SCAN_DIRS:
    base = os.path.join(ROOT, d)
    if not os.path.isdir(base):
        continue
    for p in walk(base):
        logical_paths[rp(p)].add(os.path.abspath(p))

ALL = set(logical_paths)

# ------------------------------------------------------------------ directives
DIRECTIVE = re.compile(
    r"""^\s*(import|export|part\s+of|part)\s+(?:'([^']+)'|"([^"]+)")""",
    re.MULTILINE)

def read(p):
    try:
        with open(p, "r", encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return ""

def resolve(uri, from_logical):
    """Return candidate realpaths this URI could denote."""
    cands = []
    if uri.startswith("dart:"):
        return cands
    if uri.startswith("package:"):
        rest = uri[len("package:"):]
        pkg, _, tail = rest.partition("/")
        if pkg != PKG:
            return cands
        cands.append(os.path.join(LIB, tail))
    elif uri.startswith(("http:", "https:")):
        return cands
    else:
        # Relative: resolve against every logical location of the importer.
        cands.append(os.path.normpath(os.path.join(os.path.dirname(from_logical), uri)))
    out = []
    for c in cands:
        if os.path.exists(c):
            r = rp(c)
            if r in ALL:
                out.append(r)
    return out

edges = defaultdict(set)      # realpath -> set(realpath)
part_of_edges = defaultdict(set)
kinds = defaultdict(lambda: defaultdict(set))  # src -> kind -> dsts

for r in ALL:
    text = read(r)
    if not text:
        continue
    for m in DIRECTIVE.finditer(text):
        kind = m.group(1)
        uri = m.group(2) or m.group(3)
        if not uri:
            continue
        kind = "part of" if kind.startswith("part of") else kind
        targets = set()
        # Resolve from every logical alias of this file (symlink + real path).
        for lp in logical_paths[r]:
            for t in resolve(uri, lp):
                targets.add(t)
        for t in targets:
            if t == r:
                continue
            kinds[r][kind].add(t)
            if kind == "part of":
                # A part is alive iff its library is; link both ways so a live
                # part never orphans its library and vice versa.
                part_of_edges[t].add(r)
                edges[r].add(t)
            else:
                edges[r].add(t)

# `part 'x.dart'` already produces library -> part in `edges`.
for lib_owner, parts in part_of_edges.items():
    edges[lib_owner] |= parts

# ----------------------------------------------------------------------- roots
def closure(roots):
    seen, q = set(), deque()
    for r in roots:
        if r in ALL and r not in seen:
            seen.add(r); q.append(r)
    while q:
        cur = q.popleft()
        for nxt in edges.get(cur, ()):
            if nxt not in seen:
                seen.add(nxt); q.append(nxt)
    return seen

main_dart = rp(os.path.join(LIB, "main.dart"))
test_roots = [rp(p) for p in walk(os.path.join(ROOT, "test"))]
itest_roots = [rp(p) for p in walk(os.path.join(ROOT, "integration_test"))]
lib_roots = [rp(p) for p in walk(LIB)]
# live lib = lib files whose realpath is NOT inside retired_sprawl
live_lib_roots = [r for r in lib_roots if not r.startswith(RETIRED_RP + os.sep)]

C_main = closure([main_dart])
C_test = closure(test_roots)
C_itest = closure(itest_roots)
C_livelib = closure(live_lib_roots)

retired_files = {r for r in ALL if r.startswith(RETIRED_RP + os.sep)}

def mod_of(r):
    rel = os.path.relpath(r, os.path.join(RETIRED_RP, "lib_features"))
    return rel.split(os.sep)[0]

spec_reach = C_main | C_test                       # exactly what the brief asked for
cons_reach = C_main | C_test | C_itest | C_livelib  # conservative superset

spec_unreach = sorted(retired_files - spec_reach)
cons_unreach = sorted(retired_files - cons_reach)

report = {
    "total_retired_files": len(retired_files),
    "total_retired_modules": len({mod_of(r) for r in retired_files}),
    "main_closure_retired": len(retired_files & C_main),
    "test_closure_retired": len(retired_files & C_test),
    "itest_closure_retired": len(retired_files & C_itest),
    "livelib_closure_retired": len(retired_files & C_livelib),
    "spec_unreachable": len(spec_unreach),
    "conservative_unreachable": len(cons_unreach),
    "modules_livelib": len({mod_of(r) for r in retired_files & C_livelib}),
    "modules_main": len({mod_of(r) for r in retired_files & C_main}),
    "test_only_files": len((retired_files & C_test) - C_livelib),
    "test_only_modules": len({mod_of(r) for r in retired_files if r in C_test and r not in C_livelib}
                             - {mod_of(r) for r in retired_files & C_livelib}),
}
print(json.dumps(report, indent=2))

with open(os.path.join(ROOT, ".reach_spec_unreach.txt"), "w") as fh:
    fh.write("\n".join(rel_real(p) for p in spec_unreach) + "\n")
with open(os.path.join(ROOT, ".reach_cons_unreach.txt"), "w") as fh:
    fh.write("\n".join(rel_real(p) for p in cons_unreach) + "\n")

# Save graph state for later phases. Store paths relative to apps/mobile —
# absolute realpaths made the cache unusable on any other machine.
state = {
    "edges": {rel_real(k): sorted(rel_real(v) for v in vs) for k, vs in edges.items()},
    "kinds": {
        rel_real(k): {kk: sorted(rel_real(v) for v in vv) for kk, vv in kinds_for.items()}
        for k, kinds_for in kinds.items()
    },
    "C_main": sorted(rel_real(p) for p in C_main),
    "C_test": sorted(rel_real(p) for p in C_test),
    "C_livelib": sorted(rel_real(p) for p in C_livelib),
    "C_itest": sorted(rel_real(p) for p in C_itest),
    "retired": sorted(rel_real(p) for p in retired_files),
    "logical": {
        rel_real(k): sorted(rel_logical(v) for v in vs) for k, vs in logical_paths.items()
    },
}


def _assert_relative(obj):
    if isinstance(obj, str):
        if os.path.isabs(obj):
            raise SystemExit(f"refusing to write absolute path: {obj}")
    elif isinstance(obj, dict):
        for key, val in obj.items():
            _assert_relative(key)
            _assert_relative(val)
    elif isinstance(obj, list):
        for item in obj:
            _assert_relative(item)


_assert_relative(state)
with open(os.path.join(ROOT, ".reach_state.json"), "w") as fh:
    json.dump(state, fh)
print("\nwrote .reach_spec_unreach.txt / .reach_cons_unreach.txt / .reach_state.json")
