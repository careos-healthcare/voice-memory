# ArchiveMe focused-beta reviewer checklist

_Generated from `release/focused_beta_status.json`. Do not edit by hand._

Version **0.2.0+48** · commit `1eabdc74cd25`

> **Release is blocked.** Complete machine gates before reviewer sign-off.

## Pre-submission gates

[x] **Production graph analyzer (zero errors/warnings)** (`a_production_graph_analyzer`) — pass
  - Evidence: `release/evidence/gate_a_production_graph_analyzer.log`
  - Note: analyze_production_graph: 51 file(s)
Analyzer (production graph): errors=0 warnings=0
OK — production graph analyzer clean
[x] **No active CTA to disallowed route** (`a_route_cta_integrity`) — pass
  - Evidence: `release/evidence/gate_a_route_cta_integrity.log`
  - Note: validate_production_route_links: PASS
[x] **No prohibited customer copy in production graph** (`a_customer_language`) — pass
  - Evidence: `release/evidence/gate_a_customer_language.log`
  - Note: 00:00 +25: ../../apps/web/app/contact/page.tsx follows customer language policy
00:00 +26: ../../apps/web/app/privacy/page.tsx follows customer language policy
00:00 +27: All tests passed!
[x] **Log redaction / privacy log scan** (`log_redaction`) — pass
  - Evidence: `release/evidence/gate_log_redaction.log`
  - Note: > voice-memory@0.1.0 validate:privacy-logs
> node scripts/validate-privacy-logs.mjs
validate-privacy-logs ok
[x] **No personal-content persistence in plaintext preferences** (`sensitive_storage_scan`) — pass
  - Evidence: `release/evidence/gate_sensitive_storage_scan.log`
  - Note: 00:00 +0: beta-scoped stores do not write personal content fields to prefs
00:00 +1: encrypted personal content keys are allowlisted
00:00 +2: All tests passed!
[x] **No production import/init of disabled billing/widgets/notifications/experiments** (`a_disabled_capability_imports`) — pass
  - Evidence: `release/evidence/gate_a_disabled_capability_imports.log`
  - Note: OK — launch product audit passed
==> production route-link integrity
validate_production_route_links: PASS
[x] **Zero network after consent decline/revoke** (`remote_consent_no_network_evidence`) — pass
  - Evidence: `release/evidence/gate_remote_consent_no_network_evidence.log`
  - Note: 00:01 +11: /Users/chiragpatel/Projects/voice-memory/apps/mobile/test/remote_processing_consent_gate_test.dart: saveTextThought is gated: declined consent saves locally with zero network calls
00:01 +12: /Users/chiragpatel/Projects/voice-memory/apps/mobile/test/remote_processing_consent_gate_test.dart: remote failure after consent does not erase a locally saved entry
00:01 +13: All tests passed!
[ ] **Capture, archive, evidence, export/delete automated behavior** (`b_capture_archive_behavior`) — fail
  - Evidence: `release/evidence/gate_b_capture_archive_behavior.log`
  - Note: ARCHIVEME_LOG event=auth_signOut_failed severity=error category=auth success=false error_code=http_400 http_status=400
00:04 +93 -1: /Users/chiragpatel/Projects/voice-memory/apps/mobile/test/security/release_log_scan_test.dart: production graph scan skips test fixture paths
00:04 +94 -1: Some tests failed.
[x] **Export and delete account paths** (`export_delete`) — pass
  - Evidence: `release/evidence/gate_export_delete.log`
  - Note: 00:01 +28: /Users/chiragpatel/Projects/voice-memory/apps/mobile/test/delete_account_confirmation_test.dart: Delete account confirmation successful server deletion shows completion copy only after confirm
ARCHIVEME_LOG event=auth_signOut_failed severity=error category=auth success=false error_code=http_400 http_status=400
00:02 +29: All tests passed!
[ ] **Android release build** (`c_android_release_build`) — not_run
[ ] **iOS release build (no codesign)** (`c_ios_release_build`) — not_run
[ ] **Web lint / typecheck / test / build** (`c_web_release_build`) — not_run
[x] **Security validators against current routes** (`security_validators`) — pass
  - Evidence: `release/evidence/gate_security_validators.log`
  - Note: security_release_check: PASS (6 checks)
[x] **Artifact inspection (manifest, entitlements, SDK init, version, legal links)** (`d_artifact_inspection`) — pass
  - Evidence: `release/evidence/gate_d_artifact_inspection.log`
  - Note: inspect_release_artifact: PASS
[ ] **Manual resilience checklist (interrupt, offline, low storage, background kill)** (`e_manual_resilience_checklist`) — not_run
[ ] **VoiceOver / TalkBack critical journeys** (`voiceover_talkback_manual`) — not_run
  - Note: No recorded manual accessibility sign-off for build 48.
[ ] **TestFlight / Play internal install smoke** (`testflight_internal_smoke`) — fail
  - Evidence: `mobile/evidence/testflight_tested.json`
  - Note: validate:testflight-proof exit 1; testflight_tested.json success:false.
[ ] **iOS / Android build signing evidence** (`ios_android_build_signing`) — fail
  - Evidence: `mobile/evidence/ios_signing_tested.json`
  - Note: validate:ios-signing and validate:android-signing exit 1; evidence JSON success:false.
[ ] **Sync / offline / conflict resolution** (`sync_offline_conflict`) — fail
  - Evidence: `mobile/evidence/offline_sync_tested.json`
  - Note: Structural validator exit 0, but device evidence timestamp 2026-08-11 not re-run on build 48 / commit 1eabdc74.

## Reviewer demo path (when release allowed)

1. Fresh install → Record (`/record`) — typed moment without microphone.
2. Voice moment after mic permission.
3. Archive Home (`/archive-belief`).
4. Sample Archive (`/sample-archive`) — example data only.
5. Settings → Help & reviewer guide, Support, Privacy, Terms.
6. Confirm no subscription, restore, or upgrade prompts appear.
