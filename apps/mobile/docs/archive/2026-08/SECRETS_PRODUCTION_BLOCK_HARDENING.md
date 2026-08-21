# Secrets Production Block Hardening v1

Make secrets rotation an **unavoidable production submission blocker** while keeping internal TestFlight safe when rotation is still pending.

## Goal

Harden the existing `SecretsRotationLaunchGate` so production submission cannot slip through with pending or failed rotation.

## Decisions

| Decision | Meaning |
| --- | --- |
| `productionBlocked` | Repo safety failed or rotation explicitly failed |
| `testFlightSafeOnly` | Repo safety passes; manual rotation still pending |
| `productionReady` | Rotation confirmed and repo safety passes |

## Production block requirements (8)

1. Stripe secret key rotated
2. Stripe webhook secret rotated
3. Old webhook disabled
4. Production env updated
5. No secret values committed
6. No secret values printed in logs
7. RevenueCat key not exposed in docs/logs
8. Production env verified

Plus meta requirement: launch blocked until rotation confirmed.

## Key rules

- **Internal TestFlight can be safe** while rotation pending (repo safety passes)
- **Production submission must block** until all rotation + repo safety requirements pass
- **Never print actual secrets**
- **Never commit actual secrets**
- Hardening only — no product feature changes

## Bridges

| Bridge | Behavior |
| --- | --- |
| `SecretsProductionBlockHardening.build()` | Wraps `SecretsRotationLaunchGate.build()` with hardened requirements |
| `commercialReadinessBridge()` | Merges launch gate into `CommercialReadinessGate` and exposes `productionSubmissionBlocked` |
| `blocksCommercialProduction()` | Returns `true` when commercial path must stay off production |

Commercial readiness mapping:

| Hardened state | Commercial status |
| --- | --- |
| Rotation pending + repo safe | `productionBlockedBySecrets` |
| Rotation failed / repo unsafe | `productionBlockedBySecrets` |
| Rotation confirmed | Can reach `commerciallyReady` |

## Code modules

- Engine: `lib/features/secrets_rotation_gate/secrets_production_block_hardening.dart`
- Base gate: `lib/features/secrets_rotation_gate/secrets_rotation_launch_gate.dart`
- Tests: `test/secrets_production_block_hardening_test.dart`

## Run tests

```bash
cd apps/mobile
flutter test test/secrets_production_block_hardening_test.dart
```
