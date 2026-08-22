"""Normalizes `flutter analyze` output into comparable issue signatures.

Emits `severity | message | file | rule` with line/column numbers stripped, so
two runs can be compared as sorted multisets while other agents are editing the
same tree. Scratch helper for the caregiver-revocation change.
"""

import re
import sys

LINE = re.compile(r"^\s*(info|warning|error) • (.*) • (\S+) • (\S+)\s*$")
POSITION = re.compile(r"(:\d+){1,2}$")

rows = []
with open(sys.argv[1], encoding="utf-8", errors="replace") as handle:
    for raw in handle:
        match = LINE.match(raw.rstrip("\n"))
        if not match:
            continue
        severity, message, location, rule = match.groups()
        path = POSITION.sub("", location)
        rows.append(f"{severity} | {message} | {path} | {rule}")

sys.stdout.write("\n".join(sorted(rows)) + "\n")
