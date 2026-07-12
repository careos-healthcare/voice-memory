# Annual plan future gate v1

Document **annual plan as future revenue test only** after monthly purchase proof. Classification and documentation only — no product changes.

## Decisions

| Decision | Meaning |
| --- | --- |
| `annualPlanFrozen` | Annual plan deferred until monthly proof and paid-intent beta value land (default) |
| `annualPlanDocumented` | Prerequisites complete; annual plan may be documented as future revenue test |

## Canonical copy focus

**Year trail focus:** "Keep the longer proof trail for the year."

## Prerequisites (2)

1. `monthlySandboxPurchaseProofComplete` — Monthly sandbox purchase proof complete
2. `paidIntentBetaShowsValue` — Paid-intent beta shows value

## Rules (5)

1. No annual RevenueCat product now
2. No paywall changes now
3. Annual plan requires monthly sandbox purchase proof first
4. Annual plan requires paid-intent beta showing value
5. Copy focuses on longer proof trail for the year

## Always blocked before proof

- **Annual RevenueCat product** — do not add annual offering yet
- **Paywall changes** — keep current paywall unchanged
- **Annual plan launch** — document only until monthly proof and beta value land

## Future annual plan unlock

Both prerequisites:

- `monthlySandboxPurchaseProofComplete` — sandbox monthly purchase completed
- `paidIntentBetaShowsValue` — first useful proof accepted or paid-intent beta promising

## Bridge factories

`AnnualPlanFutureGate.composeInput()` bridges:

- `SingleLaunchChecklistInput` — `sandboxPurchaseWorks`
- `PaidIntentBetaProofResult` — `purchaseCompleted` and proof/value signals

`evaluateCopyPassesRules()` rejects annual RevenueCat product and paywall change copy.

## CI bundle

`tool/run_annual_plan_future_gate.sh` runs:

- `test/annual_plan_future_gate_test.dart`

## Code modules

- Engine: `lib/features/annual_plan_future/annual_plan_future_gate.dart`
- Copy: `lib/features/annual_plan_future/annual_plan_future_copy.dart`
- Tests: `test/annual_plan_future_gate_test.dart`

## Run tests

```bash
cd apps/voicememory_mobile
flutter test test/annual_plan_future_gate_test.dart
```

Or use the CI wrapper:

```bash
cd apps/voicememory_mobile
./tool/run_annual_plan_future_gate.sh
```
