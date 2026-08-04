#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$ROOT/docs/RELEASE_READINESS.md"

python3 - "$DOC" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
allowed = {"PASS", "FAIL", "BLOCKED", "NOT RUN"}
rows = []
for line in text.splitlines():
    if not line.startswith("| ") or line.startswith("| ---") or "Gate | Status" in line:
        continue
    cells = [cell.strip() for cell in line.strip("|").split("|")]
    if len(cells) != 3:
        continue
    gate, status, evidence = cells
    if status not in allowed:
        raise SystemExit(f"{gate}: invalid readiness status {status!r}")
    if status == "PASS" and (
        not evidence
        or evidence in {"NOT RUN", "—"}
        or "no evidence" in evidence.lower()
    ):
        raise SystemExit(f"{gate}: PASS requires concrete evidence")
    rows.append((gate, status, evidence))

if not rows:
    raise SystemExit("No readiness rows found")

blocking = [(gate, status) for gate, status, _ in rows if status != "PASS"]
print(f"Release readiness structure valid: {len(rows)} gates")
if blocking:
    print("Release remains blocked:")
    for gate, status in blocking:
        print(f"  {status}: {gate}")
    raise SystemExit(1)
print("All release gates have evidence-backed PASS status")
PY
