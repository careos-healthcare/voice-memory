# Archive memory after V1 gate

> Canonical doc: `docs/architecture/archive_memory_after_v1.md` · Code: `lib/features/archive_memory_after_v1/`


Keep **archive memory expansion** after V1 proof. Classification and documentation only — no product changes.

## Decisions

| Decision | Meaning |
| --- | --- |
| `archiveMemoryFrozen` | Archive memory deferred until paid-intent beta proof is complete (default) |
| `futureArchiveMemoryDocumented` | Beta proof complete; future archive memory may be documented |

## Rules (5)

1. Future enhancement only
2. Not part of first five minutes
3. Not primary Pro promise
4. Supports proof trail, not storage
5. No new live V1 UI

## Always blocked

- **First five minutes** — archive memory stays out of early onboarding
- **Primary Pro promise** — proof trail stays primary (`longer proof trail`)
- **Storage framing** — archive memory supports proof trail, not storage headline
- **Live V1 UI expansion** — no new archive memory surfaces in V1

## Future archive memory unlock

`paidIntentBetaComplete` — paid-intent promising signal

## Bridge factories

`ArchiveMemoryAfterV1Gate.composeInput()` bridges:

- `SingleLaunchChecklistInput` — `paidIntentBetaComplete`
- `PaidIntentBetaProofResult` — `paidIntentSignalPromising`

`evaluateCopyPassesRules()` rejects archive-memory-primary Pro copy and storage framing copy.

## CI bundle

`tool/run_archive_memory_after_v1_gate.sh` runs:

- `test/archive_memory_after_v1_gate_test.dart`

## Code modules

- Engine: `lib/features/archive_memory_after_v1/archive_memory_after_v1_gate.dart`
- Copy: `lib/features/archive_memory_after_v1/archive_memory_after_v1_copy.dart`
- Tests: `test/archive_memory_after_v1_gate_test.dart`

## Run tests

```bash
cd apps/mobile
flutter test test/archive_memory_after_v1_gate_test.dart
```

Or use the CI wrapper:

```bash
cd apps/mobile
./tool/run_archive_memory_after_v1_gate.sh
```
