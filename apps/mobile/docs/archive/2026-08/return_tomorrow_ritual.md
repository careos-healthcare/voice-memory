# Return tomorrow ritual gate v1

> Canonical doc: `docs/architecture/return_tomorrow_ritual.md` · Code: `lib/features/return_tomorrow_ritual/`


Prepare a **future retention ritual** without making daily homework. Classification and documentation only — no product changes.

## Decisions

| Decision | Meaning |
| --- | --- |
| `ritualFrozen` | Ritual deferred until paid-intent beta proof is complete (default) |
| `futureRetentionDocumented` | Beta proof complete; future retention ritual may be documented |

## Allowed language

- "Watch this tomorrow"
- "Did this come back?"
- "Save another moment only if it really returned"

## Blocked language

- Streaks
- Daily homework
- Required check-in
- Pressure to record
- Habit tracker language

## Rules (4)

1. Allowed language documented
2. No blocked retention pressure
3. Future retention only
4. No new live V1 UI

## Always blocked

- **Daily homework framing** — ritual stays observational, not assigned work
- **Retention pressure** — no streaks, required check-ins, or habit-tracker language
- **Live V1 UI expansion** — no new ritual surfaces in V1

## Beta proof unlock

`paidIntentBetaComplete` — paid-intent promising signal

## Bridge factories

`ReturnTomorrowRitualGate.composeInput()` bridges:

- `SingleLaunchChecklistInput` — `paidIntentBetaComplete`
- `PaidIntentBetaProofResult` — `paidIntentSignalPromising`

`evaluateCopyPassesRules()` rejects streak, homework, check-in, recording-pressure, and habit-tracker copy.

## CI bundle

`tool/run_return_tomorrow_ritual_gate.sh` runs:

- `test/return_tomorrow_ritual_gate_test.dart`

## Code modules

- Engine: `lib/features/return_tomorrow_ritual/return_tomorrow_ritual_gate.dart`
- Copy: `lib/features/return_tomorrow_ritual/return_tomorrow_ritual_copy.dart`
- Tests: `test/return_tomorrow_ritual_gate_test.dart`

## Run tests

```bash
cd apps/mobile
flutter test test/return_tomorrow_ritual_gate_test.dart
```

Or use the CI wrapper:

```bash
cd apps/mobile
./tool/run_return_tomorrow_ritual_gate.sh
```
