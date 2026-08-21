# Payment proof not interest gate v1

Separate whether testers **like the idea** from whether they **reach payment proof**. Classification only.

## Decisions

| Decision | Meaning |
| --- | --- |
| `interestOnly` | Idea interesting or would-pay maybe — not payment proof |
| `comprehensionOnly` | Saw useful proof and understood value without paying |
| `proCuriosity` | Tapped Pro but has not started purchase |
| `purchaseIntent` | Started purchase but has not completed sandbox proof |
| `purchaseProof` | Completed sandbox purchase |
| `restoreProof` | Restored purchase in sandbox |
| `notEnoughPaymentEvidence` | No meaningful signals yet |

## Decision order

Strongest payment evidence wins:

1. Restore → `restoreProof`
2. Sandbox purchase complete → `purchaseProof`
3. Purchase start → `purchaseIntent`
4. Pro tap → `proCuriosity`
5. Proof comprehension (proof + promise/continued use/price ask) → `comprehensionOnly`
6. Idea interesting or maybe → `interestOnly`
7. Otherwise → `notEnoughPaymentEvidence`

## Tracked inputs (10)

1. Tester says idea interesting
2. Tester says would pay maybe
3. Tester sees first useful proof
4. Tester sees Pro promise
5. Tester taps Pro
6. Tester starts purchase
7. Tester completes sandbox purchase
8. Tester restores purchase
9. Tester asks for price or details
10. Tester continues using after proof

## Key rules

- **Do not count maybe as payment proof**
- **Count Pro tap as curiosity** — not payment proof
- **Count purchase start as intent** — not proof until complete
- **Count sandbox purchase/restore as proof**
- **No pricing experiments**
- **No new Pro benefits**

## Paid intent bridge

`PaymentProofNotInterestGate.fromPaidIntentBetaProof()` maps existing paid-intent beta attribution into this gate. `maybe` responses stay `interestOnly`.

## CI bundle

`tool/run_payment_proof_not_interest_gate.sh` runs:

- `test/payment_proof_not_interest_gate_test.dart`

## Code modules

- Engine: `lib/features/payment_proof_not_interest/payment_proof_not_interest_gate.dart`
- Copy: `lib/features/payment_proof_not_interest/payment_proof_not_interest_gate_copy.dart`
- Tests: `test/payment_proof_not_interest_gate_test.dart`

## Run tests

```bash
cd apps/mobile
flutter test test/payment_proof_not_interest_gate_test.dart
```
