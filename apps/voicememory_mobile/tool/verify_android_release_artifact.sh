#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
BUNDLETOOL_VERSION="1.18.3"
BUNDLETOOL_SHA256="a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29"
BUNDLETOOL_URL="https://github.com/google/bundletool/releases/download/${BUNDLETOOL_VERSION}/bundletool-all-${BUNDLETOOL_VERSION}.jar"
CACHE_DIR="${BUNDLETOOL_CACHE_DIR:-${HOME}/.cache/archiveme/bundletool}"
BUNDLETOOL_JAR="${CACHE_DIR}/bundletool-all-${BUNDLETOOL_VERSION}.jar"

usage() {
  echo "Usage: $0 PATH_TO_AAB" >&2
}

if [[ $# -ne 1 ]]; then
  usage
  exit 2
fi

AAB="$1"
if [[ ! -f "$AAB" ]]; then
  echo "error: AAB not found: $AAB" >&2
  exit 1
fi

for command in curl java jarsigner keytool python3; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "error: required command is unavailable: $command" >&2
    exit 1
  fi
done

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

mkdir -p "$CACHE_DIR"
if [[ ! -f "$BUNDLETOOL_JAR" ]] ||
    [[ "$(sha256_file "$BUNDLETOOL_JAR")" != "$BUNDLETOOL_SHA256" ]]; then
  temporary_jar="${BUNDLETOOL_JAR}.tmp.$$"
  trap 'rm -f "${temporary_jar:-}" "${manifest_file:-}" "${certificate_file:-}"' EXIT
  curl --fail --location --proto '=https' --tlsv1.2 \
    --output "$temporary_jar" "$BUNDLETOOL_URL"
  actual_checksum="$(sha256_file "$temporary_jar")"
  if [[ "$actual_checksum" != "$BUNDLETOOL_SHA256" ]]; then
    echo "error: bundletool checksum mismatch" >&2
    echo "expected: $BUNDLETOOL_SHA256" >&2
    echo "actual:   $actual_checksum" >&2
    exit 1
  fi
  mv "$temporary_jar" "$BUNDLETOOL_JAR"
fi

java -jar "$BUNDLETOOL_JAR" validate --bundle="$AAB"

manifest_file="$(mktemp)"
certificate_file="$(mktemp)"
trap 'rm -f "$manifest_file" "$certificate_file"' EXIT
java -jar "$BUNDLETOOL_JAR" dump manifest --bundle="$AAB" >"$manifest_file"

version_line="$(
  python3 - "$ROOT/pubspec.yaml" <<'PY'
import re
import sys

contents = open(sys.argv[1], encoding="utf-8").read()
match = re.search(r"^version:\s*([^\s+]+)\+(\d+)\s*$", contents, re.MULTILINE)
if not match:
    raise SystemExit("error: pubspec.yaml must contain version NAME+CODE")
print(f"{match.group(1)}\t{match.group(2)}")
PY
)"
IFS=$'\t' read -r pubspec_version_name pubspec_version_code <<<"$version_line"

EXPECTED_APPLICATION_ID="${EXPECTED_APPLICATION_ID:-com.voicememory.mobile}"
EXPECTED_VERSION_NAME="${EXPECTED_VERSION_NAME:-$pubspec_version_name}"
EXPECTED_VERSION_CODE="${EXPECTED_VERSION_CODE:-$pubspec_version_code}"
EXPECTED_MIN_SDK="${EXPECTED_MIN_SDK:-26}"

python3 - \
  "$manifest_file" \
  "$EXPECTED_APPLICATION_ID" \
  "$EXPECTED_VERSION_NAME" \
  "$EXPECTED_VERSION_CODE" \
  "$EXPECTED_MIN_SDK" <<'PY'
import re
import sys
import xml.etree.ElementTree as ET

manifest_path, expected_id, expected_name, expected_code, expected_min = sys.argv[1:]
android = "{http://schemas.android.com/apk/res/android}"
root = ET.parse(manifest_path).getroot()
errors = []

def require(condition, message):
    if not condition:
        errors.append(message)

require(root.attrib.get("package") == expected_id,
        f"application ID is {root.attrib.get('package')!r}, expected {expected_id!r}")
require(root.attrib.get(android + "versionName") == expected_name,
        f"versionName is {root.attrib.get(android + 'versionName')!r}, expected {expected_name!r}")
require(root.attrib.get(android + "versionCode") == expected_code,
        f"versionCode is {root.attrib.get(android + 'versionCode')!r}, expected {expected_code!r}")

uses_sdk = root.find("uses-sdk")
require(uses_sdk is not None, "uses-sdk is missing")
if uses_sdk is not None:
    min_sdk = uses_sdk.attrib.get(android + "minSdkVersion")
    target_sdk = uses_sdk.attrib.get(android + "targetSdkVersion")
    require(min_sdk == expected_min,
            f"minSdkVersion is {min_sdk!r}, expected {expected_min!r}")
    try:
        require(int(target_sdk or "0") >= 36,
                f"targetSdkVersion is {target_sdk!r}, expected >= 36")
    except ValueError:
        errors.append(f"targetSdkVersion is not numeric: {target_sdk!r}")

application = root.find("application")
require(application is not None, "application element is missing")
if application is not None:
    require(application.attrib.get(android + "debuggable", "false") == "false",
            "release application is debuggable")
    require(application.attrib.get(android + "allowBackup") == "false",
            "android:allowBackup must be false")
    full_backup = application.attrib.get(android + "fullBackupContent")
    extraction_rules = application.attrib.get(android + "dataExtractionRules")
    require(full_backup == "false", "android:fullBackupContent must be false")
    require(bool(extraction_rules), "android:dataExtractionRules must be present")

permissions = {
    node.attrib.get(android + "name")
    for node in root
    if node.tag in ("uses-permission", "uses-permission-sdk-23")
}
permissions.discard(None)
required = {
    "android.permission.INTERNET",
    "android.permission.RECORD_AUDIO",
    "android.permission.USE_BIOMETRIC",
    "com.android.vending.BILLING",
}
forbidden = permissions - required
require(not forbidden, "forbidden permissions: " + ", ".join(sorted(forbidden)))
require(required <= permissions,
        "missing required permissions: " + ", ".join(sorted(required - permissions)))

component_pattern = re.compile(
    r"(^|[.$])(debug|test|benchmark)([.$]|$)|testlab|leakcanary",
    re.IGNORECASE,
)
bad_components = []
for node in root.iter():
    if node.tag not in ("activity", "activity-alias", "service", "receiver", "provider"):
        continue
    name = node.attrib.get(android + "name", "")
    if component_pattern.search(name):
        bad_components.append(name)
require(not bad_components,
        "debug/test components present: " + ", ".join(sorted(set(bad_components))))

if errors:
    for error in errors:
        print(f"error: {error}", file=sys.stderr)
    raise SystemExit(1)

print(f"applicationId={expected_id}")
print(f"versionName={expected_name}")
print(f"versionCode={expected_code}")
print(f"minSdkVersion={expected_min}")
print(f"targetSdkVersion={uses_sdk.attrib[android + 'targetSdkVersion']}")
print("debuggable=false")
print("allowBackup=false")
print("permissions=" + ",".join(sorted(permissions)))
PY

jarsigner -verify -strict "$AAB" >/dev/null
keytool -printcert -jarfile "$AAB" >"$certificate_file"
if grep -Eqi 'CN=Android Debug|O=Android, C=US' "$certificate_file"; then
  echo "error: release AAB is signed with an Android debug certificate" >&2
  exit 1
fi

if [[ -n "${EXPECTED_SIGNING_CERT_SHA256:-}" ]]; then
  actual_fingerprint="$(
    awk -F': ' '/SHA256:/{gsub(":", "", $2); print toupper($2); exit}' \
      "$certificate_file"
  )"
  expected_fingerprint="$(
    printf '%s' "$EXPECTED_SIGNING_CERT_SHA256" | tr -d ':' | tr '[:lower:]' '[:upper:]'
  )"
  if [[ "$actual_fingerprint" != "$expected_fingerprint" ]]; then
    echo "error: signing certificate SHA-256 fingerprint does not match" >&2
    exit 1
  fi
fi

echo "Android release artifact verification passed."
