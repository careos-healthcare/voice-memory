# Store readiness single source v1

One canonical store and release checklist that unifies scattered prep docs without duplicating purchase, paywall, or RevenueCat behavior.

## Canonical order (12 steps)

1. Signing configured
2. App Store metadata ready
3. Support, privacy, and terms ready
4. Screenshots ready
5. RevenueCat products verified
6. Purchase path reachable
7. Restore path verified
8. Entitlement persists after restart
9. Physical device smoke passed
10. TestFlight upload ready
11. Paid intent beta ready
12. Secrets rotated before production submission

Steps 1–10 form the **TestFlight-ready** block. Steps 11–12 gate production submission after beta proof.

## Decisions

| Decision | Meaning |
| --- | --- |
| `notReady` | Earliest failing step in the TestFlight block (1–10) |
| `paidIntentPending` | TestFlight block clear; run paid intent beta |
| `secretsPending` | Paid intent beta ready; rotate secrets before submission |
| `submissionReady` | All 12 canonical steps verified |

## Bridges (no duplicated business logic)

- **`StoreReadinessProof`** — `fromProofInput()` / `toProofInput()` delegate proof classification to `StoreReadinessProof.resolve()`
- **`StoreReadinessAudit`** — `fromStoreReadinessAudit()` / `toAudit()` map audit fields without reimplementing status rules
- **`ProductionCandidateChecklist`** — `fromProductionCandidateChecklist()` uses `StoreReadinessProof.fromProductionCandidateChecklist()`

`StoreReadinessSingleSourceResult` also exposes `proofResult`, `auditStatus`, and `productionStatus` for side-by-side comparison with existing modules.

## Code modules

- Engine: `lib/features/store_readiness_single_source/store_readiness_single_source.dart`
- Copy: `lib/features/store_readiness_single_source/store_readiness_single_source_copy.dart`
- Tests: `test/store_readiness_single_source_test.dart`

## Related checklists (still valid, now bridged)

- `docs/IOS_RELEASE_CHECKLIST.md`
- `docs/ANDROID_RELEASE_CHECKLIST.md`
- `docs/REVENUECAT_RELEASE_CHECKLIST.md`
- `docs/TESTFLIGHT_CHECKLIST.md`
- `docs/paid_intent_beta_script.md`

Use this module as the **ordered classifier**. Keep detailed runbooks in the docs above.

## Rules

- Bridge to existing `StoreReadinessAudit`, `StoreReadinessProof`, and `ProductionCandidateChecklist`.
- Do not duplicate business logic inside the single-source module.
- Do not change purchase, paywall, or RevenueCat behavior.
- Fix the earliest failing canonical step first.

## Run tests

```bash
cd apps/voicememory_mobile
flutter test test/store_readiness_single_source_test.dart
```

Included in `tool/validate_core.sh`.
