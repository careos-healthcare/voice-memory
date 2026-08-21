#!/usr/bin/env bash
# Analyzer gate for the focused-beta production graph — zero errors and warnings.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

collect_paths() {
  local paths=()
  paths+=(
    lib/router/app_router.dart
    lib/router/v1_route_registry.dart
    lib/router/production_route_link_gate.dart
    lib/router/production_billing_import_gate.dart
    lib/router/production_route_cta_registry.dart
    lib/core/config/v1_capability_registry.dart
    lib/core/config/v1_production_allowlist.dart
    lib/core/config/v1_billing_capability.dart
    lib/core/config/v1_feature_flags.dart
    lib/core/config/v1_launch_product_contract.dart
    lib/services/app_services.dart
    lib/config/release_config.dart
    lib/config/app_config.dart
    lib/product/consumer_ui_copy.dart
    lib/product/customer_language.dart
  )
  while IFS= read -r screen; do
    [[ -z "$screen" ]] && continue
    local snake
    snake=$(echo "$screen" | sed -E 's/([A-Z])/_\1/g' | sed 's/^_//' | tr '[:upper:]' '[:lower:]')
    if [[ "$snake" == *_screen ]]; then
      paths+=("lib/screens/${snake}.dart")
    else
      paths+=("lib/screens/${snake}_screen.dart")
    fi
  done < <(grep -oE "'[A-Z][A-Za-z0-9]+Screen'" lib/core/config/v1_production_allowlist.dart | tr -d "'")

  for scan in lib/widgets/account lib/widgets/security; do
    if [[ -d "$scan" ]]; then
      while IFS= read -r file; do
        paths+=("$file")
      done < <(find "$scan" -name '*.dart' -type f | sort)
    fi
  done

  printf '%s\n' "${paths[@]}" | sort -u
}

existing=()
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  if [[ -f "$path" ]]; then
    existing+=("$path")
  else
    echo "warn: skipping missing production graph file: $path" >&2
  fi
done < <(collect_paths)

if ((${#existing[@]} == 0)); then
  echo "error: no production graph dart files found" >&2
  exit 1
fi

OUTPUT="$(mktemp)"
trap 'rm -f "$OUTPUT"' EXIT

echo "analyze_production_graph: ${#existing[@]} file(s)"
flutter analyze "${existing[@]}" >"$OUTPUT" 2>&1 || true

errors=$(grep -c " error •" "$OUTPUT" 2>/dev/null || true)
warnings=$(grep -c " warning •" "$OUTPUT" 2>/dev/null || true)
errors=${errors:-0}
warnings=${warnings:-0}

echo "Analyzer (production graph): errors=$errors warnings=$warnings"

if (( errors > 0 )); then
  echo >&2
  echo "error: production graph analyzer reported $errors error(s):" >&2
  grep " error •" "$OUTPUT" >&2 || true
  exit 1
fi

if (( warnings > 0 )); then
  echo >&2
  echo "error: production graph analyzer reported $warnings warning(s):" >&2
  grep " warning •" "$OUTPUT" >&2 || true
  exit 1
fi

echo "OK — production graph analyzer clean"
