#!/usr/bin/env python3
"""Safety screen for the 169 unreachable candidates."""
import os, re, json, subprocess, sys
from collections import defaultdict

ROOT = os.path.abspath(os.path.dirname(__file__))
state = json.load(open(os.path.join(ROOT, ".reach_state.json")))
cands = [l.strip() for l in open(os.path.join(ROOT, ".reach_cons_unreach.txt")) if l.strip()]
cand_abs = {os.path.join(ROOT, c) for c in cands}
kinds = state["kinds"]
edges = state["edges"]
live = set(state["C_main"]) | set(state["C_test"]) | set(state["C_livelib"]) | set(state["C_itest"])

flags = defaultdict(list)

# ---- 1. part / part of -------------------------------------------------------
# incoming part edges: does any LIVE file declare `part 'candidate'`?
for src, kd in kinds.items():
    for kind, dsts in kd.items():
        if kind not in ("part", "part of"):
            continue
        for d in dsts:
            if d in cand_abs and src in live:
                flags[d].append(f"{kind} from LIVE {os.path.relpath(src, ROOT)}")
            if src in cand_abs and d in live:
                flags[src].append(f"declares '{kind}' -> LIVE {os.path.relpath(d, ROOT)}")
# candidate is itself a part file?
for c in cand_abs:
    txt = open(c, encoding="utf-8", errors="replace").read()
    if re.search(r"^\s*part\s+of\b", txt, re.M):
        flags[c].append("IS a part-of file")
    if re.search(r"^\s*part\s+'", txt, re.M):
        flags[c].append("declares part files")

# ---- 2. exports: is candidate exported by anything live? ---------------------
for src, kd in kinds.items():
    for d in kd.get("export", []):
        if d in cand_abs and src in live:
            flags[d].append(f"EXPORTED by LIVE {os.path.relpath(src, ROOT)}")

# ---- 3. generated / companion files -----------------------------------------
for c in cand_abs:
    base = c[:-5]
    for suf in (".g.dart", ".freezed.dart", ".gr.dart", ".mocks.dart"):
        if os.path.exists(base + suf):
            flags[c].append(f"has companion {suf}")
    if c.endswith((".g.dart", ".freezed.dart", ".gr.dart", ".mocks.dart")):
        flags[c].append("IS a generated companion")

# ---- 4. string references by basename anywhere in repo ----------------------
names = sorted({os.path.basename(c) for c in cand_abs})
REPO = os.path.abspath(os.path.join(ROOT, "..", ".."))
hits = defaultdict(set)
CH = 200
for i in range(0, len(names), CH):
    chunk = names[i:i+CH]
    pat = "|".join(re.escape(n) for n in chunk)
    try:
        out = subprocess.run(
            ["rg", "--follow", "--no-heading", "-o", "-n", "-e", pat,
             "-g", "!retired_sprawl/**", "-g", "!.reach_*", "-g", "!*.log",
             "--", ROOT],
            capture_output=True, text=True, timeout=300).stdout
    except Exception as e:
        print("rg failed", e); out = ""
    for line in out.splitlines():
        parts = line.split(":", 2)
        if len(parts) < 3:
            continue
        f, ln, tok = parts[0], parts[1], parts[2]
        hits[tok].add(f"{os.path.relpath(f, ROOT)}:{ln}")

for c in cand_abs:
    b = os.path.basename(c)
    if b in hits:
        for h in sorted(hits[b])[:6]:
            flags[c].append(f"NAME referenced outside retired tree: {h}")

# ---- 5. excluded / contested paths (concurrent agents) ----------------------
EXCLUDED_SUBSTR = [
    "retired_sprawl/lib_features/reflections/",
    "retired_sprawl/lib_features/consent_audit/",
    "retired_sprawl/lib_features/caregiver/",
    "retired_sprawl/lib_features/privacy/",
    "retired_sprawl/lib_features/coach/",
    "retired_sprawl/lib_features/live_audio/",
    "retired_sprawl/lib_features/voice_capture/transcription/",
]
EXCLUDED_NAMES = [
    "live_voice_session_copy.dart", "search_empty_state.dart",
    "on_device_processing_store.dart", "subscription_provider.dart",
    "flutter_test_config.dart", "export_selected_sheet.dart",
    "post_save_recorded_summary_card.dart", "privacy_copy_policy.dart",
    "voice_capture_handler.dart",
]
excluded = []
for c in sorted(cand_abs):
    rel = os.path.relpath(c, ROOT)
    why = None
    for s in EXCLUDED_SUBSTR:
        if s in rel:
            why = f"excluded path ({s})"
    if os.path.basename(c) in EXCLUDED_NAMES:
        why = f"excluded filename ({os.path.basename(c)})"
    if why:
        excluded.append((rel, why))
        flags[c].append("SKIP: " + why)

# ---- report ------------------------------------------------------------------
blocked, clean = [], []
for c in sorted(cand_abs):
    rel = os.path.relpath(c, ROOT)
    if flags.get(c):
        blocked.append((rel, flags[c]))
    else:
        clean.append(rel)

print(f"candidates: {len(cand_abs)}   flagged: {len(blocked)}   clean: {len(clean)}\n")
print("=== FLAGGED ===")
for rel, fl in blocked:
    print(f"\n{rel}")
    for f in fl:
        print(f"    - {f}")
with open(os.path.join(ROOT, ".reach_clean.txt"), "w") as fh:
    fh.write("\n".join(clean) + "\n")
with open(os.path.join(ROOT, ".reach_flagged.txt"), "w") as fh:
    for rel, fl in blocked:
        fh.write(rel + "\n")
        for f in fl:
            fh.write("    - " + f + "\n")
print(f"\n\nwrote .reach_clean.txt ({len(clean)}) and .reach_flagged.txt ({len(blocked)})")
