# Phase 1 release/dependency stabilization report

Recorded 2026-08-02 on branch `stabilize/archive-me-commercial-core` at
`fb5b33e6cbc220465e4a7fc22940a5d3962824ff`.

## Release status

**BLOCKED — not a clean release candidate.**

- The working tree is intentionally preserved and remains heavily dirty:
  7,828 paths (861 modified, 3,304 deleted, 3,663 untracked) at the final
  inventory. These counts include work owned by other agents.
- Store identity remains `BLOCKED_EXTERNAL`: 11 fields require verification in
  App Store Connect, Google Play Console, RevenueCat, Firebase, or the Apple
  Developer portal. Run `npm run check:identity` for the source-verifiable
  portion and follow `docs/current/STORE_IDENTITY_CHECKLIST.md`.
- The production npm audit has no critical or high findings after remediation,
  but retains five moderate transitive findings under
  `firebase-admin -> @google-cloud/storage` (`uuid`, `gaxios`,
  `teeny-request`, and `retry-request`). No forced or speculative major
  override was applied for these moderate-only findings.
- Broad web, backend, Android, and iOS release builds were intentionally not
  run in Phase 1.
- `npm run validate:backend-release` passes. Its production monetized-route
  policy now covers the retained `/api/transcribe` and `/api/analyze` routes
  only. Live audio and the removed synthesis/chat systems remain under
  `experiments/` or absent from V1; the validator no longer requires
  prohibited production routes to be recreated.

## Recorded toolchain

- Node `v25.2.1`; npm `11.6.2`; git `2.50.1`
- Flutter `3.44.6`; Dart `3.12.2`; DevTools `2.57.0`
- Xcode `26.1.1` (`17B100`)
- Ruby `3.1.0`
- Local Java runtime unavailable; CI pins Temurin 17
- Release CI pins Node `22.22.0`, npm `11.6.2`, Flutter `3.44.6`, Xcode
  `26.1.1`, Ruby `3.3`, and Fastlane `2.237.0`

## Dependency remediation

Baseline production audit: 14 findings (1 critical, 4 high, 9 moderate).

- Next family: `next` and `eslint-config-next` `16.2.6 -> 16.2.12`.
- Firebase family: `firebase-admin` `13.10.0 -> 14.2.0`.
- Image family: `sharp` pinned and tree-overridden to `0.35.3`.
- CSS family: `postcss` tree-overridden to `8.5.25`.
- WebSocket family: `websocket-driver` tree-overridden to `0.7.5`.
- Multipart family: `form-data` tree-overridden to `2.5.6`.

Final production audit: 5 moderate, 0 high, 0 critical. Next's own upgrade
documentation in `node_modules/next/dist/docs/01-app/01-getting-started/18-upgrading.md`
and the Next 16 guide were reviewed before changing the Next family.

## Exact generated release graph

- Status: PASS, 0 architecture violations
- Shipping entry point: `apps/voicememory_mobile/lib/main.dart`
- Reachable Dart files: 718
- Local import/export edges: 2,401
- Imported package dependencies: 29
- Primary routes: `/record`, `/archive-belief`, `/belief-changes`, `/account`
- Secondary routes: 15; flow routes: `/`, `/onboarding`
- Required mobile-facing APIs: `/api/health`, `/api/capture/attest`,
  `/api/transcribe`, `/api/analyze`, `/api/auth/send-code`,
  `/api/auth/verify`, `/api/auth/session`, `/api/auth/signout`,
  `/api/account/delete`, `/api/sync/manifest`, `/api/sync/pull`,
  `/api/sync/push`, `/api/billing/entitlements`,
  `/api/billing/revenuecat/link`, `/api/user/subscription-status`
- Declared backend routes classified by the release graph: 34 in 6 capability
  groups
- Android permissions: internet, record audio, biometric, Play billing
- iOS usage descriptions: Face ID and microphone; explicit Release
  entitlements: none
- Identity: ArchiveMe, `com.voicememory.mobile` on iOS and Android,
  `archiveme` URL scheme

The machine-readable graph is
`artifacts/v1-architecture/v1-reachability-report.json`; the concise generated
view is `V1_REACHABILITY_REPORT.md`.

## Reproducibility controls

- GitHub Actions are pinned to immutable 40-character commit SHAs.
- npm jobs use `npm ci`; Flutter jobs use
  `flutter pub get --enforce-lockfile`.
- `packageManager`, Node engine floor, patched direct dependencies, and
  security overrides are executable release-graph assertions.
- Store-upload workflows remain manual, production-environment protected, and
  do not expose signing credentials to pull requests.
