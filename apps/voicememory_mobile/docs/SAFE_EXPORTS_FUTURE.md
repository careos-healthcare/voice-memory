# Safe exports future gate v1

Prepare **exports as future paid expansion** without making them a launch promise. Classification and documentation only — no product changes.

## Decisions

| Decision | Meaning |
| --- | --- |
| `exportsFrozen` | Export types deferred until export tests and paid-intent beta pass (default) |
| `futurePaidExpansionDocumented` | Export tests and beta proof complete; future paid expansion may be documented |

## Future export types (5)

1. `proofTrailPdf` — Proof trail PDF
2. `markdownArchive` — Markdown archive
3. `localBackup` — Local backup
4. `whatChangedMonthlyReport` — What changed monthly report
5. `evidenceTrailExport` — Evidence trail export

## Rules (4)

1. Not primary Pro promise
2. No private raw text leak without explicit user export action
3. Tested before marketing
4. No new export UI for V1

## Always blocked

- **Launch promise** — exports never lead launch positioning
- **Primary Pro promise** — proof trail stays primary (`longer proof trail`)
- **V1 export UI** — no new export surfaces in V1

## Future paid expansion unlock

Both required:

1. `exportTestsPass` — export flows tested before marketing
2. `paidIntentBetaComplete` — paid-intent promising signal

## Bridge factories

`SafeExportsFutureGate.composeInput()` bridges:

- `SingleLaunchChecklistInput` — `paidIntentBetaComplete`
- `PaidIntentBetaProofResult` — `paidIntentSignalPromising`

`evaluateCopyPassesRules()` rejects export-primary Pro copy and private raw text leak copy.

## CI bundle

`tool/run_safe_exports_future_gate.sh` runs:

- `test/safe_exports_future_gate_test.dart`

## Code modules

- Engine: `lib/features/safe_exports_future/safe_exports_future_gate.dart`
- Copy: `lib/features/safe_exports_future/safe_exports_future_copy.dart`
- Tests: `test/safe_exports_future_gate_test.dart`

## Run tests

```bash
cd apps/voicememory_mobile
flutter test test/safe_exports_future_gate_test.dart
```

Or use the CI wrapper:

```bash
cd apps/voicememory_mobile
./tool/run_safe_exports_future_gate.sh
```
