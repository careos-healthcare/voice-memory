# Three day proof challenge gate v1

> Canonical doc: `docs/architecture/three_day_proof_challenge.md` · Code: `lib/features/three_day_proof_challenge/`


Prepare a **future 3-day proof challenge** without changing V1. Classification and documentation only — no product changes.

## Canonical promise

> Save 3 real moments in 3 days. See the first useful proof.

## Decisions

| Decision | Meaning |
| --- | --- |
| `futureAcquisitionOnly` | Keep challenge in acquisition docs; V1 unchanged (default) |
| `v1SurfacingAllowed` | Paid-intent beta shows users need this; V1 surfacing may be considered |

## Rules (4)

1. Future acquisition only
2. No streaks
3. No daily pressure
4. No required check-in

## V1 surfacing gate

V1 UI stays blocked unless **both** are true:

1. Paid-intent beta complete (`paidIntentSignalPromising`)
2. Users need the challenge (e.g. `notEnoughMoments` or `proofNotReached`)

Even when `v1SurfacingAllowed`, the gate still forbids streaks, daily pressure, and required check-ins.

## Key rules

- **Future acquisition only** by default
- **No streaks**
- **No daily pressure**
- **No required check-in**
- **No live V1 UI** unless paid-intent beta shows users need this
- **Audit only** — CI can report without mutating product configuration

## Bridge factories

`ThreeDayProofChallengeGate.composeInput()` bridges:

- `SingleLaunchChecklistInput` — paid-intent beta complete
- `PaidIntentBetaProofResult` — paid-intent promising; `proofNotReached` need signal
- `FirstProofSuccessBetaResult` — `notEnoughMoments` need signal

## CI bundle

`tool/run_three_day_proof_challenge_gate.sh` runs:

- `test/three_day_proof_challenge_gate_test.dart`

## Code modules

- Engine: `lib/features/three_day_proof_challenge/three_day_proof_challenge_gate.dart`
- Copy: `lib/features/three_day_proof_challenge/three_day_proof_challenge_copy.dart`
- Tests: `test/three_day_proof_challenge_gate_test.dart`

## Run tests

```bash
cd apps/mobile
flutter test test/three_day_proof_challenge_gate_test.dart
```

Or use the CI wrapper:

```bash
cd apps/mobile
./tool/run_three_day_proof_challenge_gate.sh
```
