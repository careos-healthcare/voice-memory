# First Proof Success Beta Guard v1

Measure first proof success with real testers **without loosening proof thresholds**. Beta measurement and prompt/input guidance routing only.

## Decisions

| Decision | Meaning |
| --- | --- |
| `notEnoughMoments` | Tester has not saved 3 usable moments |
| `weakInputQuality` | Match quality or proof confidence is too weak |
| `noSafeAnchor` | Proof cannot proceed without a safe anchor |
| `proofNotShown` | Proof has not been shown on the existing first-proof path |
| `proofShownNeedsFeedback` | Proof shown but acceptance/repair feedback is incomplete |
| `proofTooVagueRisk` | Tester selected too vague — route to proof trust repair |
| `proofNotRelevantRisk` | Tester selected not relevant — route to proof trust repair |
| `proofWorking` | First proof accepted or corrected for this tester |
| `proofStrongEnoughForPro` | Proof accepted after Pro promise seen with strong confidence |

## Inputs (11)

1. `usableMomentCount`
2. `hasSafeAnchor`
3. `hasMatchQuality`
4. `proofConfidence`
5. `proofShown`
6. `proofAccepted`
7. `proofCorrected`
8. `tooVagueSelected`
9. `notRelevantSelected`
10. `userUnderstoodWhy`
11. `userSavedAnotherAfterProof`

Bridge input for Pro-path measurement: `proPromiseSeen` (from payment/paid-intent proof modules).

## Signals (11)

1. Enough usable moments saved
2. Safe anchor present
3. Match quality present
4. Proof confidence strong enough
5. Proof shown
6. Proof accepted
7. Proof corrected
8. Too vague selected
9. Not relevant selected
10. User understood why
11. User saved another moment after proof

## Key rules

- **Do not loosen `minProofEntryCount`** (stays 3)
- **Do not loosen anchor rules**
- **Do not expand proof volume**
- Route failures to **prompt/input guidance only**
- **No new proof UI** unless the existing first-proof path already supports it

## Decision order

Earliest blocker wins:

1. Not enough moments (< 3 usable moments)
2. Weak input quality (missing match quality or weak confidence)
3. No safe anchor
4. Proof not shown
5. Too vague selected
6. Not relevant selected
7. Proof shown without feedback
8. Proof accepted + Pro seen + strong confidence → `proofStrongEnoughForPro`
9. Proof accepted or corrected → `proofWorking`

## Repo signal bridge

`FirstProofSuccessBetaGuard.fromRepoSignals()` verifies protected threshold constants in:

- `archive_evidence_quality_gate.dart` (`minProofEntryCount = 3`)
- `beta_readiness_engine.dart` (guards against threshold drift)

## Code modules

- Engine: `lib/features/first_proof_success_beta/first_proof_success_beta_guard.dart`
- Copy: `lib/features/first_proof_success_beta/first_proof_success_beta_copy.dart`
- Tests: `test/first_proof_success_beta_guard_test.dart`

## Run tests

```bash
cd apps/voicememory_mobile
flutter test test/first_proof_success_beta_guard_test.dart
```
