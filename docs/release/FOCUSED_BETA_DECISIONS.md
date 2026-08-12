# Focused beta — scope, exclusions, and failure ledger

**Date:** 2026-08-12  
**Repository:** `voice-memory` (mobile app path: `apps/mobile/`; docs often say `apps/voicememory_mobile/` — same tree, renamed path)  
**Branch at baseline:** `main` @ `3ac9a1f4`  
**Sources:** `AGENTS.md`, `apps/mobile/LAUNCH_VALIDATION.md`, `apps/mobile/docs/V1_PRODUCT_CONTRACT.md`, `apps/mobile/lib/core/config/v1_launch_product_contract.dart`, `apps/mobile/lib/core/config/v1_production_allowlist.dart`, `apps/mobile/lib/core/config/v1_capability_registry.dart`, `apps/mobile/lib/router/app_router.dart`, `apps/mobile/lib/router/route_catalog.dart`, `apps/mobile/lib/features/release_evidence/release_evidence_pack.dart`, `apps/mobile/APP_STORE_SUBMISSION_PACK.md`

---

## Focused beta scope (production graph)

### Primary tabs / destinations

| Surface | Route(s) | Source |
|--------|----------|--------|
| **Record** | `/record`, `/quick-capture` | `RouteCatalog.recordHome`, `V1LaunchProductContract` capabilities `voice_capture`, `text_capture` |
| **Archive** | `/archive-belief`, `/entry/:id`, `/belief-evidence`, `/export` | `V1ProductionAllowlist.productionRouterScreens`, launch capabilities `original_transcripts`, `archive_search`, `exact_evidence`, `export_deletion` |
| **Changes** (nested under Archive UX, own tab in shell) | `/belief-changes`, `/belief-detail` | `V1LaunchProductContract` capability `cautious_patterns`; `PrimaryDestination.changes` in `lib/router/primary_destination.dart` |
| **Account** | `/account`, `/security`, `/delete-account`, `/settings`, `/privacy`, `/terms` | Launch capabilities `private_storage`, `export_deletion`; allowlisted screens include `AccountScreen`, `SecuritySettingsScreen`, `DeleteAccountScreen` |

**Navigation shell:** Record → Archive → Changes → Account when `V1FeatureFlags.enableV1Only == true` (`lib/core/config/v1_feature_flags.dart`).

### In scope — customer capabilities

Aligned with `V1LaunchProductContract.launchCapabilities` and `V1ProductionAllowlist.launchCapabilities`:

1. **Local voice capture** — microphone allowed (`V1CapabilityRegistry.microphone = true`).
2. **Local text capture** — quick text route `/quick-capture`.
3. **Encrypted local archive** — journal store, essential startup phase `essential_local_archive` (`v1_production_allowlist.dart`).
4. **Correction and suppression** — entry detail + belief evidence routes; free forever per `docs/V1_PRODUCT_CONTRACT.md`.
5. **Evidence-backed possible patterns** — cautious language on Changes tab; not certainty/diagnosis (trust phrases in contract).
6. **Export and deletion** — `/export`, `/delete-account`; never paywalled per product contract.
7. **App lock** — `V1CapabilityRegistry.biometricLock = true`; `SecuritySettingsScreen` allowlisted.

### Progressive disclosure

- **Changes** content stays nested under the Archive journey and hidden until eligibility thresholds are met (pattern/compare gates in archive engines — not expanded in this ledger).
- **Remote processing** (transcription, analysis API) is optional and must remain gated before the first network request (consent / API guard expectations; see unresolved decisions).

### Explicitly excluded from the beta production graph

When `V1FeatureFlags.enableV1Only` is true (`lib/core/config/v1_feature_flags.dart`), these resolve off or redirect via `V1QuarantineRedirects`:

| Category | Examples / enforcement | Source |
|----------|----------------------|--------|
| Widgets | Home-screen widgets | `enableWidgets => false` when V1-only |
| Notifications | Push/local notification surfaces | `V1CapabilityRegistry.notifications = false` |
| Consumer web app | Not in mobile production router | Monorepo `apps/web/` separate from mobile graph validator |
| Paywall / purchases (live) | Billing code present; **RevenueCat paused** per `APP_STORE_SUBMISSION_PACK.md` | `storeBilling = true` in registry but submission pack says purchases unavailable |
| Labs / dashboards | `TestingArchiveMeScreen`, insight/revenue dashboards | Blocked in `validate_v1_production_graph.sh`, `blockedProductionScreens` |
| Blind spots / theories / thought map | Thought map, analyst | `enableThoughtMap`, `enableAnalyst` false under V1-only |
| Sample / reviewer routes | `/sample-archive` allowlisted for review only | `SampleArchiveContextScreen` in allowlist — demo data, no journal writes (`APP_STORE_SUBMISSION_PACK.md`) |
| Experimental dashboards | Weekly review, beta feedback cards | `quarantinedProductionWidgets`, blocked screens |

**Quarantined widgets (must not render on launch surfaces):** `WeeklyGrowthPreviewCard`, `BetaFeedbackSheet`, `RememberThisButton`, `WeeklyArchiveReviewCard`, `DailyArchiveMemoryCard`, etc. — `V1LaunchProductContract.quarantinedProductionWidgets`.

---

## Focused release test suite (reference)

Command documented in `apps/mobile/LAUNCH_VALIDATION.md` (16 files). Baseline run recorded in `docs/release/BASELINE_2026-08-12.md`.

---

## Failing focused tests — classification ledger

**Batch result:** 269 passed, **15 failed** (2026-08-12 run).  
**Rule:** Privacy/durability failures are **not** labeled stale without evidence.

| # | Test | Failure summary | Classification | Owner | Intended resolution |
|---|------|-----------------|----------------|-------|---------------------|
| 1 | `consumer_visible_branding_test.dart` — `consumer_ui_copy.dart` has no VoiceMemory branding | Forbidden `ChatGPT` in `ConsumerUiCopy.paywallDifferentiation` | **Unresolved product decision** — test bans ChatGPT; product copy intentionally references ChatGPT for differentiation | Product / copy | Decide: allow controlled ChatGPT comparison on paywall vs remove from consumer copy and update test allowlist |
| 2 | `consumer_visible_branding_test.dart` — `privacy_copy_policy.dart` has no VoiceMemory branding | Forbidden strings: `voice memory`, `Voice Memory`, `VoiceMemory` in `privacy_copy_policy.dart` | **Trust / reliability defect** — legacy branding in privacy-facing policy file | Mobile / trust | Replace consumer-visible legacy strings with ArchiveMe; retain bundle IDs only in non-user-facing migration docs |
| 3 | `first_run_payoff_walkthrough_test.dart` — first save card stays calm | Expected text containing `compare what repeats:` — **0 widgets found** | **Stale expectation** (copy moved to return-loop) *or* **real regression** if first-save card lost comparison cue | Mobile UX | Product confirms intended first-save copy; then update test or restore UI text |
| 4 | `mobile_production_readiness_test.dart` — share-safe proof | `PathNotFoundException` on temp prefs after test completed (async persist from `ArchiveInsightFeedbackStore`) | **Trust / reliability defect** — async side effect / test isolation | Mobile / storage | Fix store lifecycle or test teardown; add regression test for prefs path stability |
| 5 | `first_run_payoff_walkthrough_test.dart` — 1-entry workspace | Expected CTA `Record if it happens again`, got `null` | **Stale expectation** or **real regression** — `ConsumerUiCopy.patternsFirstEntrySavedCta` is now `Record another moment` (`consumer_ui_copy.dart`) | Mobile UX | Align test with `ConsumerUiCopy` or restore CTA wiring on Patterns empty state |
| 6 | `first_run_payoff_walkthrough_test.dart` — 2-entry workspace | Expected `ArchiveMe has two moments to compare.`, got empty | **Stale expectation** — two-entry copy likely refactored (`FirstThreeSessionCopy.session2*`) | Mobile UX | Update test strings from `VisibleArchiveProofCopy` / session copy constants |
| 7 | `first_run_payoff_walkthrough_test.dart` — ArchiveMe not VoiceMemory | Expected helper to contain `ArchiveMe`; actual return-loop reassurance string | **Stale expectation** — helper text no longer includes brand name | Mobile QA | Point test at canonical copy constants, not hardcoded brand substring |
| 8 | `app_store_rc_polish_test.dart` — RevenueCat unconfigured copy | Expected body to contain `ArchiveMe`; actual `Plans are not available right now.` | **Stale expectation** — matches `ConsumerUiCopy.paywallSetupUnavailableBody` | Mobile / billing UX | Update test to assert current unavailable copy + separate headline branding check |
| 9 | `next_evidence_plan_test.dart` — archive belief wires plan card | `archive_belief_screen.dart` source lacks expected wiring | **Non-production experiment** or **stale wiring test** — card not on Archive home in current graph | Mobile / archive | Confirm whether Next Evidence Plan ships in focused beta; if not, move test to quarantine suite; if yes, restore wiring |
| 10 | `archive_watchlist_test.dart` — wires watchlist card | No `ArchiveWatchlist*` in `archive_belief_screen.dart` | **Non-production experiment** / **stale wiring test** | Mobile / archive | Same as #9 — product decision on watchlist in beta |
| 11 | `archive_depth_test.dart` — includes depth card widget | No `ArchiveDepthCard` in `archive_belief_screen.dart` | **Non-production experiment** / **stale wiring test** | Mobile / archive | Confirm depth card eligibility for beta Archive home |
| 12 | `archive_milestones_test.dart` — wires milestones card | No milestones widget in archive belief screen | **Non-production experiment** / **stale wiring test** | Mobile / archive | Confirm milestones surface for beta |
| 13 | `launch_hardening_test.dart` — 0-entry sample archive copy | Expected sample-archive helper string, got `null` | **Stale expectation** — UI copy removed or moved | Mobile UX | Locate current sample-archive copy in lib; update test or restore helper |
| 14 | `launch_hardening_test.dart` — 1-entry next action | Expected second-moment explanation string, got `null` | **Stale expectation** or **real regression** on early archive empty state | Mobile UX | Product decision on 1-entry Archive home next-action copy |
| 15 | `revenuecat_release_config_test.dart` — billing not configured | Expected `Purchases are not available right now`, actual `Plans are not available right now.` | **Stale expectation** — copy centralized to `ConsumerUiCopy.paywallSetupUnavailableBody` | Mobile / billing | Update test to match `ConsumerUiCopy` (not a privacy weakening) |

### Validator failures outside the Flutter suite

| Check | Result | Classification | Owner | Intended resolution |
|-------|--------|------------------|-------|---------------------|
| `tool/validate_v1_production_graph.sh` | **FAIL** — `OfflineSyncVerificationScreen` in `app_router.dart` but missing from `V1ProductionAllowlist.productionRouterScreens` | **Real regression** — production graph drift | Mobile / release | Add to allowlist if beta ships offline-sync verification, or quarantine route under V1-only redirects |
| `npm run validate:api-guard` | **FAIL** — static checks pass; `validate:grade-a-blockers-tests` cannot find `lib/reliability/api-guard-tests.ts` | **Trust / reliability infrastructure gap** — test harness path broken after repo layout change | Platform / API | Restore or relocate api-guard tests under `packages/shared` or `apps/api`; do **not** mark as pass |

---

## Unresolved product decisions (no guessed answers)

1. **ChatGPT in consumer paywall differentiation** — intentional positioning (`ConsumerUiCopy.paywallDifferentiation`) vs `consumer_visible_branding_test.dart` blanket ban.
2. **Archive home auxiliary cards** (depth, milestones, watchlist, next evidence plan) — ship in focused beta or remain quarantined experiments?
3. **First-save / 1-entry / 2-entry Patterns copy** — current constants in `consumer_ui_copy.dart` / `VisibleArchiveProofCopy` vs walkthrough test expectations (see rows 3, 5, 6, 7, 13, 14).
4. **Offline sync verification route** — is `/offline-sync-verification` in beta scope? Router exposes `OfflineSyncVerificationScreen` (`app_router.dart:164`).
5. **Live billing copy vs billing paused** — submission pack says RevenueCat paused; registry has `storeBilling = true`. When billing returns, confirm unavailable vs active copy (`Plans are not available right now.`).
6. **Remote processing consent gate** — document exact first-network-request gate in mobile (API attestation exists in `validate-api-guard.mjs` static checks; runtime mobile consent flow not verified in this baseline).
7. **Changes tab naming in external comms** — playbook says Record/Archive/Account; product contract includes Changes tab as first-class destination.

---

## Review checkpoint (privacy / durability)

- Row **#4** (`mobile_production_readiness_test` async prefs failure) is classified **trust/reliability**, not stale.
- Row **#2** (VoiceMemory in privacy policy copy) is **trust/reliability**, not stale.
- **`validate:api-guard`** failure is an **infrastructure gap**, not waived.
- **`validate:privacy-logs`** and **`validate:security-aplus`** **passed** at baseline — do not weaken to green the suite.

---

## Related commands (next playbook steps)

```bash
cd apps/mobile
flutter test test/ios_testflight_submission_readiness_test.dart ...  # see LAUNCH_VALIDATION.md
bash tool/validate_v1_production_graph.sh
cd ../.. && npm run validate:privacy-logs && npm run validate:security-aplus && npm run validate:api-guard
```
