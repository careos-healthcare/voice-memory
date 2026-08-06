#!/usr/bin/env bash
# Enforces V1 production dependency graph — routes, modules, imports, deep links.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ROUTER="$ROOT/lib/router/app_router.dart"
ALLOWLIST="$ROOT/lib/core/config/v1_production_allowlist.dart"
QUARANTINE="$ROOT/lib/router/v1_quarantine_redirects.dart"

fail() {
  echo "error: $1" >&2
  exit 1
}

echo "==> research package import guard"
bash "$ROOT/tool/validate_no_research_imports.sh"

echo "==> deferred screens must not be production route builders"
for screen in CapacityLoopScreen BetaFeedbackScreen JournalScreen PatternMapScreen DeveloperDiagnosticsScreen WeeklyArchiveReviewScreen TestingArchiveMeScreen; do
  if grep -q "$screen" "$ROUTER"; then
    fail "$screen still referenced in app_router.dart"
  fi
done

echo "==> production router screens must be allowlisted"
while IFS= read -r screen; do
  [[ -z "$screen" ]] && continue
  if grep -q "$screen" "$ROUTER" && ! grep -q "'$screen'" "$ALLOWLIST"; then
    fail "$screen used in router but missing from V1ProductionAllowlist.productionRouterScreens"
  fi
done < <(grep -oE '[A-Z][A-Za-z0-9]+Screen' "$ROUTER" | sort -u)

echo "==> blocked deep links resolve to V1 destinations"
if ! grep -q "resolveInstantCaptureDeepLink" "$ROUTER"; then
  fail "missing instant capture deep link resolver"
fi
CAPABILITY_REGISTRY="$ROOT/lib/core/config/v1_capability_registry.dart"
if grep -q "liveVoice = false" "$CAPABILITY_REGISTRY"; then
  if ! grep -q "liveVoice ? '/live-voice' : RouteCatalog.recordHome" "$ROUTER"; then
    fail "voice-session deep link must redirect to record when liveVoice is disabled"
  fi
fi

echo "==> quarantine redirects registered when V1-only"
grep -q "V1QuarantineRedirects.routes" "$ROUTER" || fail "quarantine redirects not wired"

FEATURE_REGISTRY="$ROOT/tool/v1_registered_feature_modules.txt"
echo "==> feature module registry (approval required for new lib/features/*)"
[[ -f "$FEATURE_REGISTRY" ]] || fail "missing tool/v1_registered_feature_modules.txt"
while IFS= read -r dir; do
  [[ -z "$dir" ]] && continue
  if ! grep -Fxq "$dir" "$FEATURE_REGISTRY"; then
    fail "new lib/features/$dir not registered — add to tool/v1_registered_feature_modules.txt"
  fi
done < <(find lib/features -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)

echo "==> research dashboards unreachable in release navigation"
if grep -rq "TestingArchiveMeScreen\|InsightQualityDashboard\|RevenueReadinessDashboard" lib/config/production_navigation.dart lib/router/ 2>/dev/null; then
  fail "research dashboard surface still referenced in production navigation"
fi

echo "==> permission audit"
bash "$ROOT/tool/audit_v1_permissions.sh"

echo "==> service locator audit (V1 critical paths)"
bash "$ROOT/tool/audit_v1_service_locator.sh"

echo "OK — V1 production graph checks passed"
