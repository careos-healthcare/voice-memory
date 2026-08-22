# ArchiveMe focused-beta release summary

_Generated from `release/focused_beta_status.json`. Do not edit by hand._

## Release identity

| Field | Value |
| --- | --- |
| Product | ArchiveMe |
| Version | 0.2.0+48 |
| Commit | `1eabdc74cd25` |
| Environment | local-dev |
| Created | 2026-08-13T08:37:19.511Z |
| Channel | testflight-internal |
| Manifest stale after | 7 days |

## Capability registry snapshot

| Capability | Enabled | Source |
| --- | --- | --- |
| sync | true | apps/mobile/lib/router/app_router.dart (OfflineSyncVerificationScreen route in production graph) |
| storeBilling | false (livePurchases=false) | apps/mobile/lib/core/config/v1_capability_registry.dart (storeBilling = false — billing frozen for focused beta; see docs/product/COMMERCIAL_REENTRY.md) |
| notifications | false | apps/mobile/lib/core/config/v1_capability_registry.dart (notifications = false) |
| nativeExtensions | false | apps/mobile/lib/core/config/v1_capability_registry.dart (nativeExtensions = false) |

## Gate results

| Gate | Required | Status | Evidence | Actor |
| --- | --- | --- | --- | --- |
| a_production_graph_analyzer | yes | pass | release/evidence/gate_a_production_graph_analyzer.log | bash apps/mobile/tool/analyze_production_graph.sh |
| a_route_cta_integrity | yes | pass | release/evidence/gate_a_route_cta_integrity.log | validate_production_route_links + validate_production_billing_absence |
| a_customer_language | yes | pass | release/evidence/gate_a_customer_language.log | flutter test customer_language_production_copy_test.dart |
| log_redaction | yes | pass | release/evidence/gate_log_redaction.log | npm run validate:privacy-logs |
| sensitive_storage_scan | yes | pass | release/evidence/gate_sensitive_storage_scan.log | flutter test storage/mobile_prefs_policy_test.dart + bash scripts/validate-mobile-clean-working-tree.sh |
| a_disabled_capability_imports | yes | pass | release/evidence/gate_a_disabled_capability_imports.log | bash apps/mobile/tool/validate_v1_production_graph.sh |
| remote_consent_no_network_evidence | yes | pass | release/evidence/gate_remote_consent_no_network_evidence.log | flutter test remote_processing_consent_gate_test.dart + capture_pipeline_consent_boundary_test.dart + security/remote_processing_consent_gate_test.dart |
| b_capture_archive_behavior | yes | fail | release/evidence/gate_b_capture_archive_behavior.log | apps/mobile/tool/focused_beta_behavior_tests.txt |
| export_delete | yes | pass | release/evidence/gate_export_delete.log | flutter test archive_export_pack_test.dart + delete_account_confirmation_test.dart |
| c_android_release_build | yes | not_run | — | flutter build apk --release |
| c_ios_release_build | yes | not_run | — | flutter build ios --release --no-codesign |
| c_web_release_build | yes | not_run | — | npm run lint/build/test -w @voice-memory/web |
| security_validators | yes | pass | release/evidence/gate_security_validators.log | npm run validate:privacy-logs && validate:security-aplus && validate:api-guard |
| d_artifact_inspection | yes | pass | release/evidence/gate_d_artifact_inspection.log | dart run tool/inspect_release_artifact.dart |
| e_manual_resilience_checklist | yes | not_run | — | release/MANUAL_EVIDENCE_CHECKLIST.md |
| voiceover_talkback_manual | yes | not_run | — | apps/mobile/docs/ACCESSIBILITY_MANUAL_CHECKLIST.md |
| testflight_internal_smoke | yes | fail | mobile/evidence/testflight_tested.json | npm run validate:testflight-proof |
| ios_android_build_signing | yes | fail | mobile/evidence/ios_signing_tested.json | npm run validate:ios-signing && validate:android-signing |
| sync_offline_conflict | yes | fail | mobile/evidence/offline_sync_tested.json | npm run validate:offline-sync-production |
| purchase_restore | conditional (skipped) | not_run | mobile/evidence/testflight_tested.json | validate:revenuecat-production + TestFlight purchase/restore smoke |
| notifications_push | conditional (skipped) | waived | apps/mobile/lib/core/config/v1_capability_registry.dart | V1CapabilityRegistry.notifications = false |
| native_extensions_widgets | conditional (skipped) | waived | apps/mobile/lib/core/config/v1_capability_registry.dart | V1CapabilityRegistry.nativeExtensions = false |

## Release verdict

**RELEASE BLOCKED** — resolve blockers before packaging.

| Gate | Status | Blocker |
| --- | --- | --- |
| b_capture_archive_behavior | fail | ARCHIVEME_LOG event=auth_signOut_failed severity=error category=auth success=false error_code=http_400 http_status=400
00:04 +93 -1: /Users/chiragpatel/Projects/voice-memory/apps/mobile/test/security/release_log_scan_test.dart: production graph scan skips test fixture paths
00:04 +94 -1: Some tests failed. |
| c_android_release_build | not_run | required gate has not_run status |
| c_ios_release_build | not_run | required gate has not_run status |
| c_web_release_build | not_run | required gate has not_run status |
| e_manual_resilience_checklist | not_run | required gate has not_run status |
| voiceover_talkback_manual | not_run | required gate has not_run status |
| testflight_internal_smoke | fail | validate:testflight-proof exit 1; testflight_tested.json success:false. |
| ios_android_build_signing | fail | validate:ios-signing and validate:android-signing exit 1; evidence JSON success:false. |
| sync_offline_conflict | fail | Structural validator exit 0, but device evidence timestamp 2026-08-11 not re-run on build 48 / commit 1eabdc74. |


Blocking gates: 9
