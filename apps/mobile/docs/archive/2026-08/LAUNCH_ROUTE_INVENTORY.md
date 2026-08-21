# Launch route inventory (Objective 1)

Authoritative enforcement lives in code, not this doc:

1. **`lib/core/config/v1_navigation_guard.dart`** — `V1NavigationGuard`. Default-deny
   allowlist. When `V1FeatureFlags.enableV1Only` is `true` (it is, at launch), any
   path not in `_exactAllowed`/`_prefixAllowed` is redirected to Record or Archive.
   This is the **primary launch-surface gate**.
2. **`lib/router/developer_route_guard.dart`** — `DeveloperRouteGuard`. Redirects
   legacy aliases (`/timeline`, `/search`, …) to Archive, and blocks
   `developerOnlyPaths` unless `DeveloperSettingsGate.isUnlocked` (debug build +
   explicit developer unlock — see that file).
3. **`lib/config/production_navigation.dart`** — `ProductionNavigation`. Hides/
   redirects QA-verification routes (`debugOnlyRoutes`) from release-build nav.

`app_router.dart` runs these in order: `V1NavigationGuard` → `DeveloperRouteGuard`
→ `ProductionNavigation`. A route only reaches a customer in a release build if
**none** of the three redirect it.

This table lists every path registered in `app_router.dart` (96 total, via
`rg -o "path: '[^']+'"`). "Disposition" is what actually happens today given the
current guard configuration (all three flags/gates in their default production
state), verified against `test/v1_navigation_guard_test.dart` and
`test/app_router_guards_test.dart`.

## Launch (customer-ready, in the V1 allowlist)

| Route | Classification | Notes |
|---|---|---|
| `/` | launch | root, redirects into shell |
| `/record` | launch | primary tab |
| `/archive-belief` | launch | primary tab (Archive Home) |
| `/belief-changes` | launch | primary tab (Changes) |
| `/account`, `/account/*` | launch | primary tab + sign-in/create/migration |
| `/entry/:id` | launch | entry detail/edit/delete, prefix-allowed |
| `/details` | launch | |
| `/settings` | launch | |
| `/subscription`, `/pricing`, `/restore-purchases` | launch | paywall/purchase/restore |
| `/delete-account` | launch | account deletion |
| `/privacy`, `/privacy-trust-centre`, `/security`, `/terms`, `/about` | launch | legal/privacy |
| `/support-feedback`, `/help-reviewer-guide` | launch | support |
| `/sample-archive`, `/sample-archive/context/*` | launch | pre-recording sample/demo |
| `/testing-archiveme` | launch | App Store reviewer test harness (kept allowed intentionally; gated separately by its own screen logic, not a QA tool) |
| `/belief-evidence`, `/belief-detail` | launch | proof detail surfaces |
| `/quick-capture`, `/quick-yes-capture`, `/live-voice` | launch | alternate capture entry points |
| `/onboarding`, `/onboarding-intent`, `/onboarding-loop` | launch | onboarding + processing consent |
| `/future-preview`, `/cold-start/seed` | launch | onboarding preview/seed |
| `/start`, `/start/capacity-yes`, `/start/prove-enough`, `/start/generic` | launch | onboarding entry variants |
| `/invite` | launch | invite/referral entry |

## Quarantined by `V1NavigationGuard.blockedFeatureRoutes` (explicit default-deny)

All redirect to Archive Home; production nav/deep-links cannot reach them while
`enableV1Only` is true.

| Route | Classification | Disposition |
|---|---|---|
| `/pattern-map`, `/pattern-profile`, `/pattern-recognition` | experiment (interpretation engine) | quarantined |
| `/action-items` | experiment | quarantined |
| `/archive-review`, `/weekly-archive-review`, `/prove-enough/monthly-review` | duplicate archive interpretation | quarantined |
| `/insight-quality` | telemetry/dashboard | quarantined |
| `/archive-timeline` | duplicate archive view | quarantined |
| `/ask-archive` | experiment | quarantined |
| `/archive-cleanup` | internal tool | quarantined |
| `/moments`, `/journal` | duplicate/legacy list view | quarantined (also legacy-redirected by `DeveloperRouteGuard`) |
| `/archive-journey`, `/archive-share`, `/archive-deep-dive` | duplicate/experiment | quarantined (also `developerOnlyPaths`) |
| `/weekly-story`, `/updates` | milestone/marketing experiment | quarantined (also `developerOnlyPaths`) |
| `/export`, `/archive-export` | experiment (superseded by in-app export under Account/Privacy) | quarantined |
| `/archive-packs`, `/archive-packs/:id`, `/collections`, `/collections/:id` | unused packs/collection experiment | quarantined |
| `/pinned-evidence` | experiment | quarantined |
| `/yesterdays-snapshot` | milestone experiment | quarantined |
| `/review-ritual` | experiment | quarantined |
| `/archive-calendar` | unused view | quarantined |

## Explicit obsolete/duplicate registrations found in `app_router.dart` (not in any allowlist → already default-quarantined, disposition confirmed by this pass)

| Route | Classification | Disposition |
|---|---|---|
| `/capacity-loop` | capacity-loop experiment | **fixed this pass** — was wrongly present in `V1NavigationGuard._exactAllowed`; removed. Now genuinely quarantined. |
| `/weekly-report` | milestone/revenue-lift experiment | **fixed this pass** — same wrongly-allowed bug; removed from `_exactAllowed`. |
| `/archive-analyst` | duplicated archive interpretation, also in `developerOnlyPaths` | **fixed this pass** — same bug; removed from `_exactAllowed`, so it's no longer double-gated in a confusing way. |
| `/archive-evidence-trail` | superseded by inline `ProofDetailSheet` (Objective 2) | **fixed this pass** — was in both `_exactAllowed` (V1) and `developerOnlyPaths` (dev-gated), a self-contradictory config implying "launch route" while actually being dev-gated. Removed from `_exactAllowed`; stays reachable only via developer unlock, consistent with it being a legacy full-page proof-trail view now superseded by the Archive's inline proof detail sheet. |
| `/developer-diagnostics`, `/first-pattern-quality`, `/trial-control`, `/revenuecat-verify`, `/restore-production-verify`, `/native-push-verify`, `/offline-sync-verify` | internal QA/verification | debug-build + developer-unlock gated (`DeveloperRouteGuard.developerOnlyPaths` ∩ `ProductionNavigation.debugOnlyRoutes`) |
| `/archive-debug`, `/archive-tool/:tool`, `/archive-explanation/:id`, `/discover-yourself/chapter/:id` | internal tools | developer-only (prefix/pattern rules in `DeveloperRouteGuard`) |
| `/blind-spots` | obsolete (screen deleted this pass — see below) | developer-only redirect target only; route still registered but its screen is gone, so `DeveloperRouteGuard` redirects it to Archive regardless of unlock state today (pre-existing; screen removal didn't change routing since it was already dev-gated) |
| `/archive-identity`, `/archive-life-chapters` | obsolete | developer-only |
| `/subscription-review-preview` | screenshot/founder-only surface | developer-only |
| `/timeline`, `/search`, `/discover`, `/discover-changes`, `/memory`, `/archive-detail` | obsolete/legacy names | `DeveloperRouteGuard.legacyRedirects` → Archive Home unconditionally (not developer-gated, just an unconditional alias redirect for old deep links) |
| `/beta-feedback`, `/beta-invite-pack`, `/beta-outcomes` | beta laboratory/tester dashboards | not in any allowlist → default-denied by `V1NavigationGuard`, falls back to Archive Home |
| `/capacity-beta-mission`, `/capacity-beta-signals`, `/capacity-boundary-response`, `/capacity-weekly-review` | capacity-loop family | default-denied, falls back to Archive Home |
| `/daily-archive-exercise`, `/first-week-path`, `/milestone-share-cards`, `/moment-detail`, `/pro-interest`, `/pro-preview`, `/prove-enough/evidence-trail`, `/signal-detail`, `/signal-evidence`, `/signal-journey`, `/signal-review`, `/then-vs-now`, `/todays-one-question` | assorted experiments/duplicated proof variants | default-denied, falls back to Archive Home |

**Net effect:** the only paths a release-build user can ever land on (via nav, deep
link, or push) are the ~45 "launch" rows above. Everything else — roughly 50
registered routes — is unreachable in production either because it's on the
explicit `blockedFeatureRoutes` deny-list, gated behind the debug+developer-unlock
check, or simply absent from the allowlist (default-deny catches routes even if
nobody remembers to blocklist them by name).

## Screens deleted this pass (proven unreachable from the launch nav graph, no persistence/migration role)

`archive_detail_screen.dart`, `blind_spots_screen.dart`,
`discover_chapter_detail_screen.dart`, `discover_screen.dart`,
`discover_yourself_screen.dart`, `home_screen.dart`, `identity_screen.dart`,
`life_chapters_screen.dart`, `memory_screen.dart`,
`mobile_subscription_screen.dart` (superseded paywall, `paywall_screen.dart` is
the live one), `search_screen.dart`, `timeline_screen.dart`, plus widgets
`archive_detail_drawer.dart` and `patterns/patterns_first_archive_view.dart`.

Each was confirmed to have zero imports from any file reachable from `main.dart`
and zero references from any store/model/migration class before deletion. The
~30 test-file references to the deleted `PatternsFirstArchiveView` were the
in-repo Archive test suites (`first_archive_state_test.dart`,
`view_archive_after_save_test.dart`, `patterns_empty_view_test.dart`,
`visible_archive_proof_ui_test.dart`); the first two were rewritten for the new
Archive spec (Objective 2) and the latter two had their now-orphaned test cases
for the deleted widget removed (see Objective 6 notes in the final report).

**Not deleted, intentionally quarantined instead (routes/imports untouched,
still gated):** everything in `blockedFeatureRoutes` and `developerOnlyPaths`
above — those screens are still on disk and still reachable via developer
unlock, which is the safer default per the brief ("when in doubt, quarantine
rather than delete").

**Explicitly preserved regardless of reachability analysis:** all files under
`lib/storage/legacy_storage_migration.dart`, `lib/storage/account_namespace.dart`,
`lib/features/account_migration/**`, `lib/features/proof_admission/**`,
`lib/services/sync_service.dart`, `lib/services/app_services.dart` — untouched.
