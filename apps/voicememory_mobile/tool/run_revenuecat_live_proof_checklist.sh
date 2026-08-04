#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$APP_DIR/../.." && pwd)"
PROOF_DOC="$APP_DIR/docs/REVENUECAT_PHYSICAL_DEVICE_PROOF.md"
platform="${1:-ios}"
status=0

if [[ "$platform" != "ios" && "$platform" != "android" ]]; then
  echo "Usage: $0 [ios|android]" >&2
  exit 64
fi

cd "$APP_DIR"
version="$(ruby -ne 'puts $1 if $_ =~ /^version:\s*(\S+)/' pubspec.yaml)"
commit="$(git -C "$REPO_DIR" rev-parse HEAD)"
recorded_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
metadata_dir="$APP_DIR/build/revenuecat-proof"
mkdir -p "$metadata_dir"
cat >"$metadata_dir/${platform}-metadata.json" <<JSON
{
  "platform": "$platform",
  "appVersionBuild": "$version",
  "commitSha": "$commit",
  "recordedAt": "$recorded_at",
  "transactionResultsRecorded": false
}
JSON

echo "RevenueCat physical proof metadata recorded:"
echo "  platform: $platform"
echo "  app version/build: $version"
echo "  commit: $commit"
echo "  metadata: build/revenuecat-proof/${platform}-metadata.json"

if ! "$SCRIPT_DIR/validate_revenuecat_configuration.sh" \
    --platform "$platform" --paid; then
  status=1
fi

echo ""
echo "Manual sequence (must run on a physical store-sandbox device):"
echo "  1. Record free CustomerInfo entitlement state."
echo "  2. Validate current offering and exact monthly/yearly product IDs."
echo "  3. Purchase monthly and confirm archive_loop_pro."
echo "  4. Purchase yearly with a fresh sandbox account."
echo "  5. Cancel the store sheet and confirm no Pro grant."
echo "  6. Reinstall, restore without a new purchase, and refresh CustomerInfo."
echo "  7. Restore after sign-in and on a second device where supported."
echo "  8. Exercise expiry/refund/revocation using sandbox controls."
echo "  9. Test offline launch inside and outside the five-day cache window."
echo " 10. Add redacted evidence references and tester identity to the proof doc."

if ! python3 - "$PROOF_DOC" "$platform" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
platform = sys.argv[2]
text = path.read_text()
display_name = {"ios": "iOS", "android": "Android"}[platform]
heading = f"## {display_name} evidence"
start = text.find(heading)
if start < 0:
    raise SystemExit(f"Missing {heading}")
next_section = text.find("\n## ", start + len(heading))
section = text[start: next_section if next_section >= 0 else len(text)]

required_fields = (
    "App version/build",
    "Commit SHA",
    "Device model",
    "OS version",
    "Store sandbox/test account type",
    "Test date (ISO 8601)",
    "Tester",
)
missing = [
    field for field in required_fields
    if f"| {field} |" not in section
]
if missing:
    raise SystemExit("Missing evidence fields: " + ", ".join(missing))

scenarios = (
    "Monthly purchase",
    "Yearly purchase",
    "User cancellation",
    "Restore after reinstall",
    "Restore on second device",
    "Expiry/refund/revocation",
    "Offline launch",
)
blocked = []
for scenario in scenarios:
    rows = [line for line in section.splitlines() if line.startswith(f"| {scenario} |")]
    if not rows:
        blocked.append(f"{scenario}: missing")
        continue
    cells = [cell.strip() for cell in rows[0].strip("|").split("|")]
    if len(cells) < 6 or cells[-1] != "PASS":
        blocked.append(f"{scenario}: proof not PASS")
    elif any(value in {"", "NOT RUN", "—"} for value in cells[1:5]):
        blocked.append(f"{scenario}: evidence incomplete")

metadata_incomplete = any(
    f"| {field} | NOT RUN |" in section for field in required_fields
)
if metadata_incomplete:
    blocked.append("device/build metadata incomplete")
if blocked:
    raise SystemExit(
        "RevenueCat physical proof remains blocked:\n  - " + "\n  - ".join(blocked)
    )
PY
then
  status=1
fi

if ((status != 0)); then
  echo "RevenueCat launch proof is BLOCKED; no transaction success was inferred." >&2
  exit "$status"
fi

echo "RevenueCat physical-device evidence is complete for $platform."
