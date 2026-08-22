#!/usr/bin/env python3
"""Pre-flight: prove the delete set is safe to remove."""
import os, json, re
ROOT = os.path.abspath(os.path.dirname(__file__))
RET = os.path.realpath(os.path.join(ROOT, "retired_sprawl"))
s = json.load(open(os.path.join(ROOT, ".reach_state.json")))
edges = s["edges"]; kinds = s["kinds"]
delete = [l.strip() for l in open(os.path.join(ROOT, ".reach_delete.txt")) if l.strip()]
del_rp = {os.path.realpath(os.path.join(ROOT, d)) for d in delete}
ok = True

def rel(p): return os.path.relpath(p, ROOT)

# 1. nothing outside the delete set points into it (import/export/part)
print("== 1. incoming edges from survivors ==")
bad = []
for src, dsts in edges.items():
    if src in del_rp:
        continue
    for d in dsts:
        if d in del_rp:
            k = [kk for kk, vv in kinds.get(src, {}).items() if d in vv]
            bad.append((rel(src), rel(d), k))
if bad:
    ok = False
    for a, b, k in bad: print(f"   VIOLATION {a} --{k}--> {b}")
else:
    print("   clean: no survivor imports/exports/parts any file being deleted")

# 2. no symlinks in the delete set; every path is a regular file inside retired
print("\n== 2. symlink / location safety ==")
prob = []
for d in delete:
    p = os.path.join(ROOT, d)
    if os.path.islink(p): prob.append(f"IS A SYMLINK: {d}")
    if not os.path.isfile(p): prob.append(f"NOT A REGULAR FILE: {d}")
    if not os.path.realpath(p).startswith(RET + os.sep):
        prob.append(f"OUTSIDE retired_sprawl: {d}")
    # no path component may be a symlink except lib/features/* (we use real paths)
    if not d.startswith("retired_sprawl/"): prob.append(f"NOT a retired_sprawl/ path: {d}")
if prob:
    ok = False
    for p in prob: print("   " + p)
else:
    print(f"   clean: all {len(delete)} are regular files under retired_sprawl/, none are symlinks")

# 3. part / generated companions
print("\n== 3. part directives & generated companions ==")
issues = []
for d in delete:
    p = os.path.join(ROOT, d)
    txt = open(p, errors="replace").read()
    if re.search(r"^\s*part\s+of\b", txt, re.M):
        issues.append(f"{d}: contains 'part of'")
    for m in re.finditer(r"^\s*part\s+'([^']+)'", txt, re.M):
        t = os.path.realpath(os.path.join(os.path.dirname(p), m.group(1)))
        if t not in del_rp:
            issues.append(f"{d}: declares part '{m.group(1)}' NOT in delete set")
    for suf in (".g.dart", ".freezed.dart", ".gr.dart", ".mocks.dart"):
        if os.path.exists(p[:-5] + suf) and os.path.realpath(p[:-5]+suf) not in del_rp:
            issues.append(f"{d}: companion {suf} survives")
if issues:
    ok = False
    for i in issues: print("   " + i)
else:
    print("   clean: no part-of files, no orphaned parts, no surviving companions")

# 4. directories that would become empty (must NOT remove symlinked module roots)
print("\n== 4. modules fully emptied ==")
from collections import defaultdict
bymod = defaultdict(int)
for d in delete:
    bymod[d.split("/")[2]] += 1
total = defaultdict(int)
for dp, dn, fn in os.walk(os.path.join(ROOT, "retired_sprawl", "lib_features")):
    for f in fn:
        if f.endswith(".dart"):
            m = os.path.relpath(os.path.join(dp, f),
                                os.path.join(ROOT, "retired_sprawl/lib_features")).split("/")[0]
            total[m] += 1
emptied = [m for m in bymod if bymod[m] == total[m]]
print(f"   modules losing every .dart file: {len(emptied)} -> {emptied}")
print("   (module directories themselves are KEPT so the 373 symlinks stay valid)")

print("\n== RESULT:", "SAFE TO PROCEED" if ok else "STOP — violations above", "==")
print(f"delete set size: {len(delete)}")
