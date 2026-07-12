# Premium tiers future gate v1

Prevent **higher-tier complexity** before simple Pro converts. Classification and documentation only — no product changes.

## Decisions

| Decision | Meaning |
| --- | --- |
| `tiersFrozen` | Premium tiers deferred until simple Pro purchase proof is complete (default) |
| `futureTiersDocumented` | Simple Pro purchase proof complete; future tiers may be documented |

## Future tier ideas (5)

1. `longerHistory` — Longer history
2. `reportsExport` — Reports/export
3. `crossDeviceSync` — Cross-device sync
4. `privateBackup` — Private backup
5. `advancedSearch` — Advanced search

## Rules (4)

1. No new products or prices now
2. No RevenueCat product changes
3. No tier UI
4. Higher tiers require simple Pro purchase proof first

## Always blocked before simple Pro proof

- **New products/prices** — keep one simple Pro offer
- **RevenueCat changes** — do not add offerings or entitlements yet
- **Tier UI** — no comparison or upgrade-tier surfaces
- **Higher-tier planning** — document only until purchase proof lands

## Future tiers unlock

`simpleProPurchaseProofComplete` — sandbox purchase completed / purchase proof signal

## Bridge factories

`PremiumTiersFutureGate.composeInput()` bridges:

- `SingleLaunchChecklistInput` — `sandboxPurchaseWorks`
- `PaidIntentBetaProofResult` — `purchaseCompleted` signal

`evaluateCopyPassesRules()` rejects new product/price, RevenueCat change, and tier UI copy.

## CI bundle

`tool/run_premium_tiers_future_gate.sh` runs:

- `test/premium_tiers_future_gate_test.dart`

## Code modules

- Engine: `lib/features/premium_tiers_future/premium_tiers_future_gate.dart`
- Copy: `lib/features/premium_tiers_future/premium_tiers_future_copy.dart`
- Tests: `test/premium_tiers_future_gate_test.dart`

## Run tests

```bash
cd apps/voicememory_mobile
flutter test test/premium_tiers_future_gate_test.dart
```

Or use the CI wrapper:

```bash
cd apps/voicememory_mobile
./tool/run_premium_tiers_future_gate.sh
```
