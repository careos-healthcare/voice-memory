#!/usr/bin/env python3
"""Definitive blocking analysis for the 169 candidates."""
import os, re, json, subprocess
from collections import defaultdict

ROOT = os.path.abspath(os.path.dirname(__file__))
RET = os.path.realpath(os.path.join(ROOT, "retired_sprawl"))
cands = [l.strip() for l in open(os.path.join(ROOT, ".reach_cons_unreach.txt")) if l.strip()]
state = json.load(open(os.path.join(ROOT, ".reach_state.json")))

# logical lib/features path for a candidate, when its module is symlinked
def logical(rel):
    m = re.match(r"retired_sprawl/lib_features/([^/]+)/(.*)$", rel)
    if not m:
        return None
    mod, tail = m.groups()
    link = os.path.join(ROOT, "lib", "features", mod)
    if os.path.islink(link):
        return f"lib/features/{mod}/{tail}"
    return None

logmap = {c: logical(c) for c in cands}
block = defaultdict(list)

# ---- rule 1: privacy copy baseline (stale entry == fatal) -------------------
pbase = open(os.path.join(ROOT, "tool/privacy/privacy_copy_policy_baseline.txt")).read()
pbase_paths = {l.split(":")[0].strip() for l in pbase.splitlines()
               if l.strip() and not l.startswith("#")}
for c, lg in logmap.items():
    if lg and lg in pbase_paths:
        block[c].append("privacy_copy_policy_baseline entry -> stale = FATAL gate failure")

# ---- rule 2: PrivacyCopyPolicy.consumerPrivacySources (required sources) ----
pol = open(os.path.join(ROOT, "lib/security/privacy_copy_policy.dart")).read()
required = set(re.findall(r"'(lib/[^']+\.dart)'", pol))
for c, lg in logmap.items():
    if lg and lg in required:
        block[c].append("PrivacyCopyPolicy.consumerPrivacySources required source -> FATAL")

# ---- rule 3: concurrent-agent excluded paths -------------------------------
EXCL_DIR = ["reflections", "consent_audit", "caregiver", "privacy", "coach", "live_audio"]
for c in cands:
    m = re.match(r"retired_sprawl/lib_features/([^/]+)/", c)
    if m and m.group(1) in EXCL_DIR:
        block[c].append(f"concurrent-agent excluded module: {m.group(1)}")
    if "/voice_capture/transcription/" in c:
        block[c].append("concurrent-agent excluded: voice_capture/transcription/**")
    if os.path.basename(c) in (
        "live_voice_session_copy.dart", "search_empty_state.dart",
        "on_device_processing_store.dart", "subscription_provider.dart",
        "flutter_test_config.dart", "export_selected_sheet.dart",
        "post_save_recorded_summary_card.dart", "privacy_copy_policy.dart",
        "voice_capture_handler.dart"):
        block[c].append(f"concurrent-agent excluded filename: {os.path.basename(c)}")

# ---- rule 4: references that actually RESOLVE to the candidate --------------
# A name match is only a block if the surrounding path string resolves, through
# symlinks, to this exact candidate. `lib/features/insights/` and
# `lib/features/onboarding/` are real live directories that shadow same-named
# retired copies, so name matches there point at live files, not candidates.
cand_rp = {os.path.realpath(os.path.join(ROOT, c)): c for c in cands}
names = sorted({os.path.basename(c) for c in cands})
NAME_RE = "|".join(re.escape(n) for n in names)

def resolves_to_candidate(token, base_dir):
    """token is a path-ish string; return candidate rel path if it resolves to one."""
    t = token.strip()
    if t.startswith("package:archiveme_mobile/"):
        t = os.path.join(ROOT, "lib", t[len("package:archiveme_mobile/"):])
    elif t.startswith(("lib/", "test/", "tool/", "retired_sprawl/")):
        t = os.path.join(ROOT, t)
    elif t.startswith(("./", "../")) or "/" in t:
        t = os.path.join(base_dir, t)
    else:
        return None                     # bare filename, no path context
    if not os.path.exists(t):
        return None
    return cand_rp.get(os.path.realpath(t))

# find every string/URI token in the repo that ends in one of our basenames
PATHTOK = re.compile(r"""['"]([^'"\s]*(?:%s))['"]""" % NAME_RE)
scan_roots = ["lib", "test", "integration_test", "tool", "scripts", "docs",
              "hook", "config", "integration_test", "build.yaml",
              "pubspec.yaml", "analysis_options.yaml", ".github"]
seen_files = set()
for sr in scan_roots:
    p = os.path.join(ROOT, sr)
    if os.path.isdir(p):
        for dp, dn, fn in os.walk(p, followlinks=True):
            dn[:] = [d for d in dn if d not in (".dart_tool", "build")]
            for f in fn:
                seen_files.add(os.path.join(dp, f))
    elif os.path.isfile(p):
        seen_files.add(p)
# plus repo-root workflows
gh = os.path.join(os.path.dirname(os.path.dirname(ROOT)), ".github")
if os.path.isdir(gh):
    for dp, dn, fn in os.walk(gh):
        for f in fn:
            seen_files.add(os.path.join(dp, f))

for f in sorted(seen_files):
    if f.endswith((".log", ".png", ".jpg", ".lock")) or "/.reach_" in f:
        continue
    rf = os.path.realpath(f)
    inside = rf.startswith(RET + os.sep)
    try:
        txt = open(f, errors="replace").read()
    except OSError:
        continue
    if not any(n in txt for n in names):
        continue
    for i, line in enumerate(txt.splitlines(), 1):
        s = line.strip()
        for m in PATHTOK.finditer(line):
            hit = resolves_to_candidate(m.group(1), os.path.dirname(f))
            if not hit:
                continue
            relf = os.path.relpath(f, ROOT)
            if relf.endswith("_baseline.txt"):
                block[hit].append(f"[baseline-nonfatal] {relf}:{i}")
            elif inside:
                block[hit].append(f"[intra-retired ref] {relf}:{i}  {s[:90]}")
            elif s.startswith(("//", "*", "#")):
                block[hit].append(f"[comment ref] {relf}:{i}  {s[:90]}")
            else:
                block[hit].append(f"[LIVE PATH REF] {relf}:{i}  {s[:90]}")

# ---- report -----------------------------------------------------------------
fatal, soft, clean = [], [], []
for c in cands:
    bs = block.get(c, [])
    if not bs:
        clean.append(c)
    elif all(b.startswith(("[baseline-nonfatal]", "[doc]", "[comment ref]",
                           "[intra-retired ref]")) for b in bs):
        soft.append((c, bs))
    else:
        fatal.append((c, bs))

print(f"candidates {len(cands)}  |  blocked {len(fatal)}  |  soft-only {len(soft)}  |  clean {len(clean)}")
print("\n================ BLOCKED ================")
for c, bs in fatal:
    print(f"\n{c}")
    for b in sorted(set(bs)):
        print("   ", b)

with open(os.path.join(ROOT, ".reach_delete.txt"), "w") as fh:
    fh.write("\n".join(clean + [c for c, _ in soft]) + "\n")
with open(os.path.join(ROOT, ".reach_blocked.txt"), "w") as fh:
    for c, bs in fatal:
        fh.write(c + "\n")
        for b in sorted(set(bs)):
            fh.write("    " + b + "\n")
print(f"\n\nDELETE SET = {len(clean) + len(soft)}  (clean {len(clean)} + soft {len(soft)})")
print("wrote .reach_delete.txt / .reach_blocked.txt")
