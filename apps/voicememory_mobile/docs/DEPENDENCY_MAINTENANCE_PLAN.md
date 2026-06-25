# ArchiveMe — Dependency Maintenance Plan

Dependency upgrades are **deferred during TestFlight beta** unless a security fix or build blocker requires them. This plan tracks debt and sets rules for a future upgrade branch.

## Policy

- **Do not upgrade before TestFlight** unless required to fix a crash, store rejection, or critical security advisory.
- **Schedule a dedicated upgrade branch** after beta feedback (target: 2–4 weeks post–first cohort).
- **Never combine** dependency upgrades with positioning, onboarding, or beta-readiness copy branches.
- Each upgrade branch must run: full focused test suite, iOS release `--no-codesign`, Android debug APK, and physical-device smoke on 2 devices.

## Current outdated packages (major / notable)

From `flutter pub outdated` (snapshot — re-run before any upgrade branch):

| Package | Current constraint | Risk if stale | Upgrade priority |
|---------|-------------------|---------------|------------------|
| `go_router` | 14.x | Medium — routing API drift | After beta |
| `purchases_flutter` (RevenueCat) | 8.x | Low while payments disabled | Before paid launch only |
| `firebase_*` | 3.x / 11.x | Medium — analytics/messaging | After beta, test push + analytics |
| `record` | 6.x | Medium — microphone capture | After beta, test record flow |
| `flutter_local_notifications` | 21.x | Low unless push changes | After beta |
| `flutter_secure_storage` | 9.x | Low — encryption key store works | After beta, test journal migration |
| `share_plus` / `package_info_plus` | older majors | Low | Batch with other UI deps |

## Risk levels

- **High:** packages on the recording, encryption, or navigation critical path (`record`, `flutter_secure_storage`, `go_router`).
- **Medium:** Firebase, local notifications, permission_handler.
- **Low:** UI/share/info packages while core flows unchanged.

## Test requirements (future upgrade branch)

1. `flutter test` — full suite or at minimum:
   - privacy_at_rest_hardening_test.dart
   - privacy_copy_policy_test.dart
   - beta_readiness_simplification_pack_test.dart
   - capacity_three_moment_activation_test.dart
   - low_effort_yes_capture_test.dart
2. `flutter build ios --release --no-codesign`
3. `flutter build apk --debug`
4. Manual: fresh install → save moment → quick capture → archive home → delete/wipe

## Related docs

- [POST_BETA_RESPONSE_ROADMAP.md](../../docs/POST_BETA_RESPONSE_ROADMAP.md) — do not upgrade until post-beta branch selection
- [PAID_LAUNCH_DECISION_CHECKLIST.md](./PAID_LAUNCH_DECISION_CHECKLIST.md)
- [TESTFLIGHT_MANUAL_QA.md](./TESTFLIGHT_MANUAL_QA.md)
- [VALIDATION.md](../VALIDATION.md)
