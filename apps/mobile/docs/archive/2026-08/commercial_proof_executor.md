# Commercial proof executor v1

> Canonical doc: `docs/architecture/commercial_proof_executor.md` · Code: `lib/features/commercial_proof_executor/`


Turn scattered readiness gates into **one executable release checklist**.

## Statuses

| Status | Meaning |
| --- | --- |
| `productReadyOnly` | Product promise, first journey, first proof, or Pro promise not ready |
| `storeBlocked` | RevenueCat products not proven |
| `purchaseBlocked` | Paywall price or sandbox purchase not proven |
| `restoreBlocked` | Restore purchases not proven |
| `entitlementBlocked` | Entitlement persistence not proven |
| `testFlightBlocked` | TestFlight upload not proven |
| `betaBlocked` | Paid-intent beta not complete |
| `productionBlockedBySecrets` | Commercial path clear but secrets not rotated |
| `commerciallyReady` | All checks pass |

## Canonical checklist (12)

1. Product promise clear
2. First journey stable
3. First proof useful
4. Pro promise clear
5. RevenueCat products load
6. Paywall price visible
7. Sandbox purchase works
8. Restore works
9. Entitlement persists
10. TestFlight uploaded
11. Paid-intent beta complete
12. Secrets rotation complete

## Decision order

Earliest blocker wins:

1. Product layer (checks 1–4) → `productReadyOnly`
2. RevenueCat products → `storeBlocked`
3. Paywall price + sandbox purchase → `purchaseBlocked`
4. Restore → `restoreBlocked`
5. Entitlement persistence → `entitlementBlocked`
6. TestFlight upload → `testFlightBlocked`
7. Paid-intent beta → `betaBlocked`
8. Secrets rotation → `productionBlockedBySecrets`
9. All pass → `commerciallyReady`

## Key rules

- **No product features**
- **No pricing changes**
- **No RevenueCat behavior changes** unless proof command exposes blocker
- **Secrets rotation blocks production, not internal TestFlight** when repo safety passes

## Commercial readiness bridge

`CommercialProofExecutor.fromCommercialReadinessGateInput()` maps the existing commercial readiness gate into this executor. TestFlight is split into its own blocker instead of lumping with store proof.

## CI bundle

`tool/run_commercial_proof_executor.sh` runs:

- `test/commercial_proof_executor_test.dart`

## Code modules

- Engine: `lib/features/commercial_proof_executor/commercial_proof_executor.dart`
- Copy: `lib/features/commercial_proof_executor/commercial_proof_executor_copy.dart`
- Tests: `test/commercial_proof_executor_test.dart`

## Run tests

```bash
cd apps/mobile
flutter test test/commercial_proof_executor_test.dart
```
