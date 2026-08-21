# Commercial readiness gate v1

> Canonical doc: `docs/architecture/commercial_readiness_gate.md` · Code: `lib/features/commercial_readiness_gate/`


State clearly whether the product is **commercially ready**, not just product-ready. Classification and repair routing only.

## Statuses

| Status | Meaning |
| --- | --- |
| `productReadyOnly` | Product promise, first journey, first proof, or Pro promise not ready |
| `storeBlocked` | RevenueCat products or TestFlight upload not proven |
| `purchaseBlocked` | Paywall price or sandbox purchase not proven |
| `restoreBlocked` | Restore purchases not proven |
| `entitlementBlocked` | Entitlement persistence not proven |
| `betaBlocked` | Paid-intent beta not complete |
| `productionBlockedBySecrets` | Commercial path clear but secrets not rotated |
| `commerciallyReady` | All checks pass |

## Required checks (12)

1. Product promise clear
2. First journey stable
3. First proof useful enough
4. Pro promise clear
5. RevenueCat product loads
6. Paywall price visible
7. Sandbox purchase works
8. Restore works
9. Entitlement persists
10. TestFlight build uploaded
11. Paid-intent beta complete
12. Secrets rotation done before production

## Decision order

Earliest blocker wins:

1. Product layer (checks 1–4) → `productReadyOnly`
2. Store layer (RevenueCat products, TestFlight) → `storeBlocked`
3. Purchase layer (paywall price, sandbox purchase) → `purchaseBlocked`
4. Restore → `restoreBlocked`
5. Entitlement persistence → `entitlementBlocked`
6. Paid-intent beta → `betaBlocked`
7. Secrets rotation → `productionBlockedBySecrets`
8. All pass → `commerciallyReady`

## Key rules

- **No product features**
- **No paywall mechanics changes** unless purchase, restore, or entitlement is the blocker

## Repo signal bridge

`CommercialReadinessGate.fromRepoSignals()` reads static copy and paywall source files to verify product-promise guards without changing behavior.

`CommercialReadinessGate.fromStoreReadinessInput()` bridges the unified store readiness checklist into commercial classification.

`CommercialReadinessGate.buildFromSources()` composes store readiness, RevenueCat sandbox proof, paid-intent beta proof, and secrets rotation launch gate into one commercial classification.

`CommercialReadinessGate.secretsRotationDoneFromLaunchGate()` maps `SecretsRotationLaunchGate` to the commercial `secretsRotationDone` check: only `readyForProductionSubmission` counts as done; `safeForInternalTestFlight` and `blockedForProductionSubmission` keep production blocked.

## CI bundle

`tool/run_commercial_readiness_gate.sh` runs:

- `test/commercial_readiness_gate_test.dart`
- `test/paid_intent_beta_proof_test.dart`
- `test/secrets_rotation_launch_gate_test.dart`

## Code modules

- Engine: `lib/features/commercial_readiness_gate/commercial_readiness_gate.dart`
- Copy: `lib/features/commercial_readiness_gate/commercial_readiness_gate_copy.dart`
- Tests: `test/commercial_readiness_gate_test.dart`

## Run tests

```bash
cd apps/mobile
flutter test test/commercial_readiness_gate_test.dart
```
