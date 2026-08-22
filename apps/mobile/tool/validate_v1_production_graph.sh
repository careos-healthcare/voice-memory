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

# The checks below grep $ROUTER and $ALLOWLIST without testing for them. A moved
# or renamed router made every "must not appear" loop pass by reading nothing.
for required in "$ROUTER" "$ALLOWLIST" "$QUARANTINE"; do
  [[ -f "$required" ]] || fail "missing required source ${required#$ROOT/} — cannot validate the production graph"
done

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
# `find` writing "No such file or directory" to stderr inside a process
# substitution does not fail the loop, so a moved lib/features made this walk
# report success after comparing nothing against the registry.
scanned_modules=0
while IFS= read -r dir; do
  [[ -z "$dir" ]] && continue
  [[ "$dir" =~ ^# ]] && continue
  scanned_modules=$((scanned_modules + 1))
  if ! grep -Fxq "$dir" "$FEATURE_REGISTRY"; then
    fail "new lib/features/$dir not registered — add to tool/v1_registered_feature_modules.txt"
  fi
done < <(find lib/features -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)
(( scanned_modules > 0 )) || fail "walked 0 modules under lib/features — scan root missing, so the registry compared against nothing"
echo "    compared $scanned_modules module director(ies) against the registry"

echo "==> research dashboards unreachable in release navigation"
if grep -rq "TestingArchiveMeScreen\|InsightQualityDashboard\|RevenueReadinessDashboard" lib/config/production_navigation.dart lib/router/ 2>/dev/null; then
  fail "research dashboard surface still referenced in production navigation"
fi

echo "==> permission audit"
bash "$ROOT/tool/audit_v1_permissions.sh"

echo "==> service locator audit (V1 critical paths)"
bash "$ROOT/tool/audit_v1_service_locator.sh"

echo "==> launch product audit"
bash "$ROOT/tool/audit_v1_launch_product.sh"

echo "==> production route-link integrity"
dart run tool/validate_production_route_links.dart

echo "==> billing frozen — consumer graph must not import billing"
dart run tool/validate_production_billing_absence.dart

echo "OK — V1 production graph checks passed"
