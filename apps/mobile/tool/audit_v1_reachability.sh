#!/usr/bin/env bash
# Capability-flag × gated-CTA × V1 route-allowlist reachability audit.
#
# Why Dart for the engine: existing bash audits already grep `name = false`
# literals, Screen class names, and quoted push('/path') strings. They cannot
# follow `static bool get x => Foo.isEnabled` into bool.fromEnvironment, or
# resolve RouteCatalog.explorePatterns to /explore on the quarantine list.
# Those two hops are the actual failure mode (pattern exploration). The
# wrapper keeps the same fail()/required-file/exit-code contract as
# audit_v1_permissions.sh and audit_v1_service_locator.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
  echo "error: $1" >&2
  exit 1
}

for required in \
  "$ROOT/lib/core/config/v1_capability_registry.dart" \
  "$ROOT/lib/router/v1_route_registry.dart" \
  "$ROOT/lib/router/route_catalog.dart" \
  "$ROOT/lib/router/v1_quarantine_redirects.dart" \
  "$ROOT/tool/audit_v1_reachability.dart"; do
  [[ -f "$required" ]] || fail "missing required source ${required#$ROOT/}"
done

echo "==> reachability audit (flags × gated CTAs × route lists)"
dart run "$ROOT/tool/audit_v1_reachability.dart"
