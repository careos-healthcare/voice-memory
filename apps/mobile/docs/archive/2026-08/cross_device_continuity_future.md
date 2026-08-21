# Cross device continuity future gate v1

> Canonical doc: `docs/architecture/cross_device_continuity_future.md` · Code: `lib/features/cross_device_continuity_future/`


Prevent **cloud and sync promises until technically proven**, while documenting future cross-device continuity expansion. Classification only — no product changes.

## Decisions

| Decision | Meaning |
| --- | --- |
| `continuityFrozen` | Continuity deferred until technical proof complete (default) |
| `futureContinuityDocumented` | All proof prerequisites pass; future continuity may be documented |

## Rules (5)

1. Future only
2. No cloud backup promise
3. No access everywhere promise
4. No never lose your archive promise
5. Technical proof required before launch — account identity, restore, backup, privacy, and migration proof

## Always blocked in V1 copy

- **Cloud backup promise** — until sync is proven
- **Access everywhere promise** — until sync is proven
- **Never lose your archive promise** — until sync is proven

## Technical proof prerequisites (5)

All required before `futureContinuityDocumented`:

1. `accountIdentityProof` — account identity works
2. `restoreProof` — restore flow proven
3. `backupProof` — backup flow proven
4. `privacyProof` — privacy controls proven
5. `migrationProof` — migration proof path proven

## Alignment

- `SyncExpectationSafetyGuard` blocks the same unproven sync promises in live copy
- `CrossDeviceContinuityFutureGate` documents when continuity may be planned, not promised

## Bridge factories

`CrossDeviceContinuityFutureGate.composeInput()` bridges:

- `SingleLaunchChecklistInput` — `productionApiWorks`, `restoreWorks`, `supportPrivacyTermsWork`

`evaluateCopyPassesRules()` rejects cloud backup, access everywhere, and never-lose-archive promise copy.

## CI bundle

`tool/run_cross_device_continuity_future_gate.sh` runs:

- `test/cross_device_continuity_future_gate_test.dart`

## Code modules

- Engine: `lib/features/cross_device_continuity_future/cross_device_continuity_future_gate.dart`
- Copy: `lib/features/cross_device_continuity_future/cross_device_continuity_future_copy.dart`
- Tests: `test/cross_device_continuity_future_gate_test.dart`

## Run tests

```bash
cd apps/mobile
flutter test test/cross_device_continuity_future_gate_test.dart
```

Or use the CI wrapper:

```bash
cd apps/mobile
./tool/run_cross_device_continuity_future_gate.sh
```
