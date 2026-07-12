# Private reports future gate v1

Keep **private reports as a later upgrade**, not a launch headline. Classification and documentation only — no product changes.

## Decisions

| Decision | Meaning |
| --- | --- |
| `laterUpgradeOnly` | Reports deferred; not launch headline or primary Pro promise (default) |
| `futureProAddOnAllowed` | First proof seen and longer proof trail converts; future Pro add-on may be documented |

## Rules (7)

1. Only after first proof
2. No treatment-style framing
3. No clinical-label framing
4. No medical claims
5. No therapist-ready claims
6. Not primary Pro promise
7. Future Pro add-on only after longer proof trail converts

## Always blocked

- **Launch headline** — reports never lead launch positioning
- **Primary Pro promise** — proof trail stays primary (`longer proof trail`)

## Future Pro add-on unlock

Both required:

1. `firstProofSeen` — first useful proof observed
2. `longerProofTrailConverts` — proof-strong-enough-for-Pro or paid-intent promising signal

## Bridge factories

`PrivateReportsFutureGate.composeInput()` bridges:

- `FirstProofSuccessBetaResult` — `proofWorking`, `proofStrongEnoughForPro`
- `PaidIntentBetaProofResult` — proof reached, `paidIntentSignalPromising`

`evaluateCopyPassesRules()` rejects therapy, diagnosis, medical, therapist-ready, and report-primary Pro copy.

## CI bundle

`tool/run_private_reports_future_gate.sh` runs:

- `test/private_reports_future_gate_test.dart`

## Code modules

- Engine: `lib/features/private_reports_future/private_reports_future_gate.dart`
- Copy: `lib/features/private_reports_future/private_reports_future_copy.dart`
- Tests: `test/private_reports_future_gate_test.dart`

## Run tests

```bash
cd apps/voicememory_mobile
flutter test test/private_reports_future_gate_test.dart
```

Or use the CI wrapper:

```bash
cd apps/voicememory_mobile
./tool/run_private_reports_future_gate.sh
```
