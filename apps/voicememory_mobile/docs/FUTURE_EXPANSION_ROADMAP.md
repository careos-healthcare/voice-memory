# Future expansion roadmap gate v1

Capture **expansion ideas without letting them enter V1 before release proof**. Audit and classification only — no product changes, no new live UI.

## Decisions

| Decision | Meaning |
| --- | --- |
| `expansionFrozen` | Release proof prerequisites incomplete or failed |
| `documentedOnly` | Release proof complete; keep ideas documented, not in V1 |
| `postV1PlanningAllowed` | Release proof complete; at least one idea unlocked for post-V1 planning |

## Expansion ideas (14)

1. Loop packs
2. Three-day proof challenge
3. Private reports after proof
4. Safe exports
5. Referrals after proof
6. Cross-device continuity
7. B2B work pressure
8. Return-tomorrow ritual
9. Contradiction change detection
10. Safe sharing
11. Android after iOS proof
12. Archive memory after V1
13. Premium longer-trail tiers
14. Partner-led niches

## Prerequisites (8)

1. TestFlight uploaded
2. Purchase works
3. Restore works
4. Entitlement persists
5. Paid-intent beta complete
6. First proof success rate acceptable
7. No release blockers
8. No secrets production blocker for production launch

## Idea status rules

| Status | When |
| --- | --- |
| `blockedBeforeReleaseProof` | Any prerequisite is pending or failed |
| `documentedNotSurfaced` | Release proof complete, but idea must stay doc-only in V1 |
| `readyForPostV1Planning` | Release proof complete and idea has no extra V1 surfacing block |

Always documented-not-surfaced in V1:

- Three-day proof challenge
- Cross-device continuity
- Premium longer-trail tiers (also blocked until paid-intent beta complete)

## Key rules

- **Expansion blocked before release proof**
- **Documented but not surfaced in V1**
- **No new live UI**
- **No pricing experiments before paid-intent beta**
- **Audit only** — CI can report without mutating product configuration

## Bridge factories

`FutureExpansionRoadmapGate.composeInput()` bridges optional upstream gates:

- `SingleLaunchChecklistInput` — TestFlight, purchase, restore, entitlement, paid-intent
- `ReleaseFragilityAuditResult` — release blocker rollup
- `FirstProofSuccessBetaResult` — first proof success acceptable when `proofWorking`
- `SecretsRotationLaunchGateResult` — production secrets blocker cleared
- `PaidIntentBetaProofResult` — paid-intent beta complete when `paidIntentSignalPromising`

## CI bundle

`tool/run_future_expansion_roadmap_gate.sh` runs:

- `test/future_expansion_roadmap_gate_test.dart`

## Code modules

- Engine: `lib/features/future_expansion_roadmap/future_expansion_roadmap_gate.dart`
- Copy: `lib/features/future_expansion_roadmap/future_expansion_roadmap_copy.dart`
- Tests: `test/future_expansion_roadmap_gate_test.dart`

## Run tests

```bash
cd apps/voicememory_mobile
flutter test test/future_expansion_roadmap_gate_test.dart
```

Or use the CI wrapper:

```bash
cd apps/voicememory_mobile
./tool/run_future_expansion_roadmap_gate.sh
```
