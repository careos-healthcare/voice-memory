# Release fragility audit v1

Identify **operational risks that can break release even when tests pass**. Audit only — no product changes. CI can report fragility without mutating release configuration.

## Decisions

| Decision | Meaning |
| --- | --- |
| `lowRisk` | Repo signals and recorded manual evidence look stable |
| `manualCheckNeeded` | Manual release evidence still pending |
| `releaseBlocked` | Earliest operational risk must be fixed before submission |

## Risk categories (17)

1. Signing
2. Bundle id
3. Display name
4. iOS deployment target
5. RevenueCat key
6. App Store products
7. Entitlement id
8. Restore path
9. Support URL
10. Privacy URL
11. Terms URL
12. Widget extension
13. Production API
14. Secrets
15. Screenshots
16. TestFlight upload
17. Stale product copy

## Decision order

1. Any risk at `releaseBlocked` → overall `releaseBlocked`
2. Else any risk at `manualCheckNeeded` → overall `manualCheckNeeded`
3. Else → `lowRisk`

## Key rules

- **Audit only** — no product UI or purchase logic changes
- **CI can report** — scripts surface fragility without editing release config
- **Repo + manual bridge** — static repo detectors plus optional human evidence flags
- **Earliest blocker wins** — first `releaseBlocked` risk is surfaced in results

## Repo signal bridge

`ReleaseFragilityAudit.fromRepoSignals()` reads mobile config, iOS project files, billing identifiers, widget extension sources, secrets rotation scan, and pro copy guards. It bridges:

- `SecretsRotationLaunchGate` for secrets risk
- `WidgetReleaseRiskGate` for widget extension risk
- `PhysicalDeviceSmokeProof` detectors for display name, restore path, and terms routes
- `ProductLanguageConsistencyGuard` for stale product copy

Manual flags (`signingVerified`, `screenshotsReady`, `testFlightUploaded`, secrets rotation confirmations) default to pending unless explicitly passed.

## CI bundle

`tool/run_release_fragility_audit.sh` runs:

- `test/release_fragility_audit_test.dart`

## Code modules

- Engine: `lib/features/release_fragility/release_fragility_audit.dart`
- Copy: `lib/features/release_fragility/release_fragility_copy.dart`
- Tests: `test/release_fragility_audit_test.dart`

## Run tests

```bash
cd apps/voicememory_mobile
flutter test test/release_fragility_audit_test.dart
```

Or use the CI wrapper:

```bash
cd apps/voicememory_mobile
./tool/run_release_fragility_audit.sh
```
