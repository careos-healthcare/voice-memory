#!/usr/bin/env bash
set -euo pipefail

# Export apps/mobile (or repo-root Flutter app) into three Desktop upload parts.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${ROOT}/apps/mobile/pubspec.yaml" ]]; then
  FLUTTER_ROOT="${ROOT}/apps/mobile"
elif [[ -f "${ROOT}/pubspec.yaml" ]]; then
  FLUTTER_ROOT="${ROOT}"
else
  echo "error: could not find pubspec.yaml under ${ROOT} or ${ROOT}/apps/mobile" >&2
  exit 1
fi

OUTPUT_DIR="${HOME}/Desktop/upload1"
TEMP_FILE="$(mktemp "${TMPDIR:-/tmp}/codebase_export.XXXXXX")"
PART_PREFIX="${OUTPUT_DIR}/codebase_part_"

mkdir -p "${OUTPUT_DIR}"

append_file() {
  local relative_path="$1"
  local absolute_path="$2"

  printf '\n%s\n' "================================================================================"
  printf 'FILE: %s\n' "${relative_path}"
  printf '%s\n\n' "================================================================================"
  cat "${absolute_path}"
}

{
  append_file "pubspec.yaml" "${FLUTTER_ROOT}/pubspec.yaml"

  while IFS= read -r dart_file; do
    relative_path="${dart_file#"${FLUTTER_ROOT}/"}"
    append_file "${relative_path}" "${dart_file}"
  done < <(
    find "${FLUTTER_ROOT}/lib" "${FLUTTER_ROOT}/test" -type f -name '*.dart' 2>/dev/null \
      | LC_ALL=C sort
  )
} > "${TEMP_FILE}"

total_lines="$(wc -l < "${TEMP_FILE}" | tr -d ' ')"
if [[ "${total_lines}" -eq 0 ]]; then
  rm -f "${TEMP_FILE}"
  echo "error: aggregated export is empty" >&2
  exit 1
fi

lines_per_part=$((total_lines / 3))
if [[ "${lines_per_part}" -lt 1 ]]; then
  lines_per_part=1
fi

rm -f "${OUTPUT_DIR}"/codebase_part_*

split -l "${lines_per_part}" "${TEMP_FILE}" "${PART_PREFIX}"
rm -f "${TEMP_FILE}"

# split -l may emit a 4th chunk when total_lines is not divisible by 3; fold into ac.
shopt -s nullglob
split_parts=("${OUTPUT_DIR}"/codebase_part_*)
if (( ${#split_parts[@]} > 3 )); then
  cat "${OUTPUT_DIR}/codebase_part_ac" "${OUTPUT_DIR}"/codebase_part_ad* > "${OUTPUT_DIR}/codebase_part_ac_merged"
  mv "${OUTPUT_DIR}/codebase_part_ac_merged" "${OUTPUT_DIR}/codebase_part_ac"
  rm -f "${OUTPUT_DIR}"/codebase_part_ad*
fi

if [[ ! -f "${OUTPUT_DIR}/codebase_part_aa" ]]; then
  : > "${OUTPUT_DIR}/codebase_part_aa"
fi
if [[ ! -f "${OUTPUT_DIR}/codebase_part_ab" ]]; then
  : > "${OUTPUT_DIR}/codebase_part_ab"
fi
if [[ ! -f "${OUTPUT_DIR}/codebase_part_ac" ]]; then
  : > "${OUTPUT_DIR}/codebase_part_ac"
fi

echo "Success: exported Flutter codebase to ${OUTPUT_DIR}"
echo "  Source: ${FLUTTER_ROOT}"
echo "  Total lines: ${total_lines}"
echo "  Split size: ${lines_per_part} lines per part (total_lines / 3)"
echo "  Files: codebase_part_aa, codebase_part_ab, codebase_part_ac"
