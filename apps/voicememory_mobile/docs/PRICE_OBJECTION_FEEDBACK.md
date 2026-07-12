# Price objection feedback gate v1

Collect **why users do not buy after Pro tap** without adding pricing experiments. Classification and interpretation only — no product changes.

## Decisions

| Decision | Meaning |
| --- | --- |
| `objectionFeedbackFrozen` | Feedback hidden until Pro tap without purchase (default) |
| `objectionFeedbackDocumented` | Post-tap feedback ready; canonical reasons and rules pass |

## Objection reasons (7)

1. `needStrongerProof` — Need stronger proof
2. `tooExpensive` — Too expensive
3. `notClearWhatProKeeps` — Not clear what Pro keeps
4. `notReadyYet` — Not ready yet
5. `wantedSyncBackup` — Wanted sync/backup
6. `wantedReports` — Wanted reports
7. `other` — Other

## Rules (5)

1. Show only after Pro tap without purchase
2. Do not change price
3. Do not add discounts
4. Do not add new features
5. Feed paid-intent beta interpretation only

## Visibility

**Show** only after Pro tap without purchase.

**Hide** when:

- User has not tapped Pro
- Purchase completed
- User is already Pro

## Always blocked

- **Price changes** — no pricing experiments from objection data
- **Discounts** — no promo or sale responses
- **New features** — objection signals inform interpretation, not scope
- **Non-beta use** — feed paid-intent beta interpretation only

## Bridge factories

`PriceObjectionFeedbackGate.composeInput()` bridges:

- `PaidIntentBetaProofResult` — `proTapped` and `purchaseCompleted` signals

`shouldShowFeedback()` and `evaluateCopyPassesRules()` enforce timing and copy guardrails.

## CI bundle

`tool/run_price_objection_feedback_gate.sh` runs:

- `test/price_objection_feedback_gate_test.dart`

## Code modules

- Engine: `lib/features/price_objection_feedback/price_objection_feedback_gate.dart`
- Copy: `lib/features/price_objection_feedback/price_objection_feedback_copy.dart`
- Tests: `test/price_objection_feedback_gate_test.dart`

## Run tests

```bash
cd apps/voicememory_mobile
flutter test test/price_objection_feedback_gate_test.dart
```

Or use the CI wrapper:

```bash
cd apps/voicememory_mobile
./tool/run_price_objection_feedback_gate.sh
```
