# Single Launch Checklist v1

> Canonical doc: `docs/architecture/single_launch_checklist.md` · Code: `lib/features/single_launch_checklist/`


One **source of truth** for ArchiveMe launch readiness. Aggregates existing proof modules without changing product UI or purchase logic.

## Statuses

| Status | Meaning |
| --- | --- |
| `notReady` | One or more TestFlight-required checklist items are missing, false, or pending |
| `readyForTestFlight` | Items 1–19 pass; secrets rotation not confirmed |
| `readyForSubmission` | All 20 checklist items pass |

## Canonical checklist (20)

1. Clean git
2. Version/build set
3. Physical iPhone smoke
4. Physical iPad smoke
5. Production API works
6. Voice save works
7. Typed save works
8. First proof works
9. Pro promise visible
10. RevenueCat products load
11. Paywall price visible
12. Sandbox purchase works
13. Entitlement unlocks
14. Restore works
15. Entitlement persists
16. Support/privacy/terms work
17. Screenshots ready
18. TestFlight uploaded
19. Paid-intent beta complete
20. Secrets rotated before production

## Key rules

- **Checklist aggregator only**
- **Do not change product UI**
- **Do not change purchase logic**
- Bridge existing readiness modules where possible

## Bridges

| Bridge | Source module |
| --- | --- |
| `fromReleaseEvidencePackInput()` | `ReleaseEvidencePackInput` — git, device smoke, API, save paths, store URLs, screenshots, TestFlight |
| `fromCommercialProofExecutorInput()` | `CommercialProofExecutorInput` + release evidence — Pro promise, RevenueCat, paywall, purchase, restore, entitlement, beta, secrets |
| `composeInput()` | Combines release evidence, commercial executor, `RevenueCatLiveProofInput`, `PaidIntentBetaProofResult`, `SecretsRotationLaunchGateResult` |

## Reduction notes

- Splits **entitlement unlock** and **entitlement persist** (merged in release evidence pack)
- Adds explicit **paywall price visible** (commercial executor only before this checklist)
- Adds **paid-intent beta complete** (store readiness / commercial executor)
- Keeps **iPhone** and **iPad** smoke as separate checklist rows

## Code modules

- Engine: `lib/features/single_launch_checklist/single_launch_checklist.dart`
- Copy: `lib/features/single_launch_checklist/single_launch_checklist_copy.dart`
- Tests: `test/single_launch_checklist_test.dart`

## Run tests

```bash
cd apps/mobile
flutter test test/single_launch_checklist_test.dart
```
