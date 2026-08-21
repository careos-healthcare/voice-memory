# Safe sharing future gate v1

> Canonical doc: `docs/architecture/safe_sharing_future.md` · Code: `lib/features/safe_sharing_future/`


Allow **future growth sharing** only if private text cannot leak. Classification and documentation only — no product changes.

## Decisions

| Decision | Meaning |
| --- | --- |
| `sharingFrozen` | Growth sharing deferred until first useful proof and paid-intent beta pass (default) |
| `futureGrowthSharingDocumented` | Proof and beta complete; future growth sharing may be documented |

## Rules (6)

1. No raw private text by default
2. Explicit user share or export
3. Share product insight, not archive content
4. No sharing in first five minutes
5. No sharing before first useful proof
6. No live V1 sharing expansion — no new live V1 sharing UI

## Always blocked

- **Raw private text leak** — never share raw private text by default
- **Archive content sharing** — share product insight, not user archive content
- **Early sharing** — no sharing in first five minutes or before first useful proof
- **Live V1 sharing expansion** — no new live V1 sharing surfaces in V1
- **V1 growth loop** — sharing is not a normal V1 growth loop; keep it explicit and future-gated

## Future growth sharing unlock

Both required:

1. `firstUsefulProofSeen` — user has seen first useful proof
2. `paidIntentBetaComplete` — paid-intent promising signal

## Bridge factories

`SafeSharingFutureGate.composeInput()` bridges:

- `SingleLaunchChecklistInput` — `paidIntentBetaComplete`
- `PaidIntentBetaProofResult` — `paidIntentSignalPromising` and `firstUsefulProofSeen`

`evaluateCopyPassesRules()` rejects raw private text leak and archive content share copy.

## CI bundle

`tool/run_safe_sharing_future_gate.sh` runs:

- `test/safe_sharing_future_gate_test.dart`

## Code modules

- Engine: `lib/features/safe_sharing_future/safe_sharing_future_gate.dart`
- Copy: `lib/features/safe_sharing_future/safe_sharing_future_copy.dart`
- Tests: `test/safe_sharing_future_gate_test.dart`

## Run tests

```bash
cd apps/mobile
flutter test test/safe_sharing_future_gate_test.dart
```

Or use the CI wrapper:

```bash
cd apps/mobile
./tool/run_safe_sharing_future_gate.sh
```
