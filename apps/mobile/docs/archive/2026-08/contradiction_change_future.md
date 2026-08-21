# Contradiction change future gate v1

> Canonical doc: `docs/architecture/contradiction_change_future.md` · Code: `lib/features/contradiction_change_future/`


Document **future premium change detection** without adding V1 feature scope. Classification and documentation only — no product changes.

## Decisions

| Decision | Meaning |
| --- | --- |
| `changeFrozen` | Change detection deferred until strong proof trail and paid-intent beta pass (default) |
| `futureChangeDetectionDocumented` | Proof trail and beta proof complete; future change detection may be documented |

## Future value language

- "You used to say this."
- "Now your saved moments show something different."
- "This repeat may be changing."

## Rules (7)

1. Future value language documented
2. Strong proof trail required
3. Correction allowed
4. No clinical-label framing
5. No directive language
6. No forecast language
7. No new live V1 UI

## Always blocked

- **Clinical-label framing** — no diagnostic or treatment-style claims
- **Directive language** — no advice or recommendations
- **Forecast language** — no predictions or future certainty
- **Live V1 UI expansion** — no new contradiction-change surfaces in V1

## Future change detection unlock

Both required:

1. `strongProofTrailComplete` — useful proof seen and accepted or corrected
2. `paidIntentBetaComplete` — paid-intent promising signal

## Bridge factories

`ContradictionChangeFutureGate.composeInput()` bridges:

- `SingleLaunchChecklistInput` — `paidIntentBetaComplete`
- `PaidIntentBetaProofResult` — `paidIntentSignalPromising` and proof-trail signals

`evaluateCopyPassesRules()` rejects clinical-label, directive, and forecast copy.

## CI bundle

`tool/run_contradiction_change_future_gate.sh` runs:

- `test/contradiction_change_future_gate_test.dart`

## Code modules

- Engine: `lib/features/contradiction_change_future/contradiction_change_future_gate.dart`
- Copy: `lib/features/contradiction_change_future/contradiction_change_future_copy.dart`
- Tests: `test/contradiction_change_future_gate_test.dart`

## Run tests

```bash
cd apps/mobile
flutter test test/contradiction_change_future_gate_test.dart
```

Or use the CI wrapper:

```bash
cd apps/mobile
./tool/run_contradiction_change_future_gate.sh
```
