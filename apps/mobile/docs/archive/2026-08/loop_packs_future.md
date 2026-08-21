# Loop packs future gate v1

> Canonical doc: `docs/architecture/loop_packs_future.md` · Code: `lib/features/loop_packs_future/`


Define **loop packs as future acquisition angles** without adding them to V1 UI. Classification and documentation only — no product changes.

## Decisions

| Decision | Meaning |
| --- | --- |
| `packsFrozen` | TestFlight or paid-intent beta proof incomplete |
| `packsDocumentedOnly` | Beta proof complete; packs stay in acquisition docs only |

## Loop packs (6)

1. Saying yes with no capacity
2. Trying to prove enough
3. Relationship replay
4. Avoiding direct conversations
5. Repeating the same habit
6. Feeling behind when stopping

## Prerequisites (2)

1. TestFlight uploaded
2. Paid-intent beta complete

## Pack status rules

| Status | When |
| --- | --- |
| `blockedBeforeBetaProof` | TestFlight or paid-intent beta pending/failed |
| `futureAcquisitionDocumented` | Beta proof complete — acquisition docs only, not V1 UI |

## Key rules

- **Do not add new onboarding UI**
- **Do not add paywall benefits**
- **Future acquisition positioning only** until TestFlight + paid-intent beta pass
- **Avoid clinical framing or treatment-style language**
- **V1 surfacing always blocked** — gate never enables live product surfaces

## Audience wedge alignment

Each pack maps to a persisted `AudienceWedge` id for acquisition planning:

| Pack | Wedge id |
| --- | --- |
| Saying yes with no capacity | `sayingYesNoCapacity` |
| Trying to prove enough | `proveEnough` |
| Relationship replay | `relationshipReplay` |
| Avoiding direct conversations | `avoidingDirectConversations` |
| Repeating the same habit | `repeatingHabit` |
| Feeling behind when stopping | `feelingBehindWhenStop` |

## Bridge factories

`LoopPacksFutureGate.composeInput()` bridges:

- `SingleLaunchChecklistInput` — TestFlight and paid-intent beta fields
- `PaidIntentBetaProofResult` — paid-intent beta complete when `paidIntentSignalPromising`

## CI bundle

`tool/run_loop_packs_future_gate.sh` runs:

- `test/loop_packs_future_gate_test.dart`

## Code modules

- Engine: `lib/features/loop_packs_future/loop_packs_future_gate.dart`
- Copy: `lib/features/loop_packs_future/loop_packs_future_copy.dart`
- Tests: `test/loop_packs_future_gate_test.dart`

## Run tests

```bash
cd apps/mobile
flutter test test/loop_packs_future_gate_test.dart
```

Or use the CI wrapper:

```bash
cd apps/mobile
./tool/run_loop_packs_future_gate.sh
```
