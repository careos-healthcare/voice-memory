#!/bin/bash
# Core validation for ArchiveMe mobile.
#
# Runs the analyzer on lib/ and the full test/ suite, then release gates.
#
# Usage:
#   ./tool/validate_core.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

echo "==> silent catch audit"
dart run tool/audit_silent_catches.dart

echo ""
echo "==> flutter analyze lib/ (errors/warnings gate + info baseline)"
bash tool/validate_analyzer_baseline.sh

echo ""
echo "==> flutter test (full suite)"
flutter test

echo ""
echo "==> Pro access enforcement audit CI bundle"
bash tool/run_pro_access_enforcement_audit.sh

echo ""
echo "==> Widget release risk gate"
bash tool/run_widget_release_risk_gate.sh

echo ""
echo "==> Product language consistency guard"
bash tool/run_product_language_consistency_guard.sh

echo ""
echo "==> First proof field readiness"
bash tool/run_first_proof_field_readiness.sh

echo ""
echo "==> Physical device smoke proof"
bash tool/run_physical_device_release_smoke.sh

echo ""
echo "==> Secrets rotation launch gate"
bash tool/run_secrets_rotation_launch_gate.sh

echo ""
echo "==> Commercial proof executor"
bash tool/run_commercial_proof_executor.sh

echo ""
echo "==> RevenueCat live proof runner"
bash tool/run_revenuecat_live_proof_checklist.sh

echo ""
echo "==> Stray test artifact guard"
bash tool/validate_no_stray_test_artifacts.sh

echo ""
echo "==> Research package import guard"
bash tool/validate_no_research_imports.sh

echo ""
echo "==> V1 production graph + permission audit"
bash tool/validate_v1_production_graph.sh

echo ""
echo "==> Repository cleanliness (git + stray artifacts)"
bash tool/validate_repository_cleanliness.sh

echo ""
echo "Core validation passed."
