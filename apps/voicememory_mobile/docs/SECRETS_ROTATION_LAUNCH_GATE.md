# Secrets rotation launch gate v1

Make exposed or old production secrets a **hard launch blocker**. TestFlight may proceed while rotation is pending; production submission stays blocked until rotation is confirmed.

## Statuses

| Status | Meaning |
| --- | --- |
| `safeForInternalTestFlight` | Repo safety passes; manual rotation steps still pending |
| `blockedForProductionSubmission` | Repo safety failed or rotation explicitly failed |
| `readyForProductionSubmission` | Rotation confirmed and repo safety passes |

## Required checks (9)

1. Stripe secret key rotated
2. Stripe webhook secret rotated
3. Production env updated
4. Old webhook disabled
5. RevenueCat API key separated from docs and logs
6. No secret values committed
7. No secret values printed in logs
8. Vercel and production env verified
9. Launch blocked until rotation confirmed

## Decision order

1. Repo safety (checks 5–7) must pass — otherwise `blockedForProductionSubmission`
2. Any rotation step explicitly failed → `blockedForProductionSubmission`
3. Rotation steps pending → `safeForInternalTestFlight`
4. All rotation confirmed → `readyForProductionSubmission`
5. Meta check 9 verifies the gate enforces the correct status

## Key rules

- **Do not print secrets**
- **Do not commit secret values**
- **No product feature changes** — classification and launch routing only
- **TestFlight allowed** when repo safety passes and rotation is pending
- **Production submission blocked** until rotation is confirmed

## Repo signal bridge

`SecretsRotationLaunchGate.fromRepoSignals()` reads static mobile lib/docs sources plus server deploy-check and `.env.example` templates. Automated checks verify:

- RevenueCat keys load via `String.fromEnvironment` (not hardcoded)
- Docs use placeholders (`appl_xxx`, `your_key_here`) — not live keys
- Billing logs do not print API key values
- Mobile lib/docs tree has no committed secret prefixes
- Production env template documents Stripe and app URL vars

Manual rotation confirmations remain `pending` until a human marks them complete.

## Commercial readiness bridge

`CommercialReadinessGate.buildFromSources()` accepts optional `secretsRotation` input. When present, it overrides the store `secretsRotated` flag and maps launch-gate status to commercial `secretsRotationDone`:

| Launch gate status | Commercial `secretsRotationDone` |
| --- | --- |
| `readyForProductionSubmission` | `true` → can reach `commerciallyReady` |
| `safeForInternalTestFlight` | `false` → `productionBlockedBySecrets` |
| `blockedForProductionSubmission` | `false` → `productionBlockedBySecrets` |

## CI bundle

`tool/run_secrets_rotation_launch_gate.sh` runs:

- `test/secrets_rotation_launch_gate_test.dart`

## Code modules

- Engine: `lib/features/secrets_rotation_gate/secrets_rotation_launch_gate.dart`
- Copy: `lib/features/secrets_rotation_gate/secrets_rotation_launch_gate_copy.dart`
- Tests: `test/secrets_rotation_launch_gate_test.dart`

## Run tests

```bash
cd apps/voicememory_mobile
flutter test test/secrets_rotation_launch_gate_test.dart
```

## Manual rotation checklist (before production)

1. Rotate Stripe secret key in Stripe Dashboard
2. Rotate Stripe webhook signing secret; update `STRIPE_WEBHOOK_SECRET` in Vercel
3. Update all production env vars (Vercel → Production)
4. Disable or delete the old webhook endpoint in Stripe
5. Confirm RevenueCat keys are build-time dart-defines only — never in docs or logs
6. Re-run `validate:deploy-secrets` on production after env update
7. Mark all rotation inputs `true` in the gate before App Store submission
