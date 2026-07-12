# B2B workplace pressure future gate v1

Define **future B2B-lite expansion around work pressure** without changing V1. Landing-page positioning and documentation only — no product changes.

## Decisions

| Decision | Meaning |
| --- | --- |
| `b2bFrozen` | B2B-lite positioning deferred until TestFlight and paid-intent beta pass (default) |
| `futureLandingPositioningDocumented` | Beta proof complete; future landing-page positioning may be documented |

## Audience segments (6)

1. `founders` — Founders
2. `managers` — Managers
3. `carers` — Carers
4. `highResponsibilityWorkers` — High-responsibility workers
5. `peopleWhoOvercommit` — People who overcommit
6. `peopleWhoSayYesWithNoCapacity` — People who say yes with no capacity

## Rules (5)

1. No employer dashboard
2. No employee surveillance
3. No medical or treatment-style claims
4. No live B2B UI
5. Future landing-page positioning only

## Always blocked

- **Employer dashboard** — no team surveillance surfaces
- **Employee surveillance** — no monitoring copy
- **Medical or treatment-style claims** — no clinical framing
- **Live B2B UI** — even after documentation unlock

## Beta proof unlock

Both required:

1. `testFlightUploaded`
2. `paidIntentBetaComplete`

## Bridge factories

`B2bWorkplacePressureFutureGate.composeInput()` bridges:

- `SingleLaunchChecklistInput` — `testFlightUploaded`, `paidIntentBetaComplete`
- `PaidIntentBetaProofResult` — `paidIntentSignalPromising`

`evaluateCopyPassesRules()` rejects employer dashboard, employee surveillance, and medical or treatment-style claim copy.

## CI bundle

`tool/run_b2b_workplace_pressure_future_gate.sh` runs:

- `test/b2b_workplace_pressure_future_gate_test.dart`

## Code modules

- Engine: `lib/features/b2b_workplace_pressure_future/b2b_workplace_pressure_future_gate.dart`
- Copy: `lib/features/b2b_workplace_pressure_future/b2b_workplace_pressure_future_copy.dart`
- Tests: `test/b2b_workplace_pressure_future_gate_test.dart`

## Run tests

```bash
cd apps/voicememory_mobile
flutter test test/b2b_workplace_pressure_future_gate_test.dart
```

Or use the CI wrapper:

```bash
cd apps/voicememory_mobile
./tool/run_b2b_workplace_pressure_future_gate.sh
```
