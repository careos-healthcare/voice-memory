# Android after iOS proof gate v1

Block **Android expansion** until iOS purchase, restore, and paid intent are proven. Classification and gating documentation only — no product changes.

## Decisions

| Decision | Meaning |
| --- | --- |
| `androidFrozen` | Android expansion deferred until iOS proof prerequisites pass (default) |
| `androidExpansionUnblocked` | iOS proof complete; Android expansion may proceed |

## Prerequisites (7)

1. iOS TestFlight uploaded
2. iOS RevenueCat products load
3. iOS sandbox purchase works
4. iOS restore works
5. iOS entitlement persists
6. Paid-intent beta promising
7. No production secrets blocker

## Rules (2)

1. Android work blocked until prerequisites pass
2. Android setup documented but not prioritised

## Always blocked before iOS proof

- **Android work** — no Android expansion until all prerequisites pass
- **Android prioritisation** — setup may be documented but not prioritised before iOS proof

## Android expansion unlock

All seven prerequisites required.

## Bridge factories

`AndroidAfterIosProofGate.composeInput()` bridges:

- `SingleLaunchChecklistInput` — TestFlight, RevenueCat, purchase, restore, entitlement, paid intent, secrets
- `PaidIntentBetaProofResult` — `paidIntentSignalPromising`
- `SecretsRotationLaunchGateResult` — not `blockedForProductionSubmission`

## CI bundle

`tool/run_android_after_ios_proof_gate.sh` runs:

- `test/android_after_ios_proof_gate_test.dart`

## Code modules

- Engine: `lib/features/android_after_ios_proof/android_after_ios_proof_gate.dart`
- Copy: `lib/features/android_after_ios_proof/android_after_ios_proof_copy.dart`
- Tests: `test/android_after_ios_proof_gate_test.dart`

## Run tests

```bash
cd apps/voicememory_mobile
flutter test test/android_after_ios_proof_gate_test.dart
```

Or use the CI wrapper:

```bash
cd apps/voicememory_mobile
./tool/run_android_after_ios_proof_gate.sh
```
