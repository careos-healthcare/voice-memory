# Payment proof beta instrument v1

Make beta payment evidence **concrete** and **separate from interest**. Instrumentation and classification only — uses the existing Pro/paywall path.

## Decisions

| Decision | Meaning |
| --- | --- |
| `interestOnly` | Maybe or liking the idea — not payment proof |
| `proofNotReached` | First useful proof not reached — blocks paid interpretation |
| `proofReachedNoProTap` | Proof landed but paywall not opened |
| `proCuriosity` | Tapped Pro but has not started purchase |
| `purchaseIntent` | Started purchase but sandbox proof incomplete |
| `purchaseProof` | Completed sandbox purchase |
| `restoreProof` | Completed restore — strengthens payment proof |
| `paidIntentPromising` | Would-pay yes after proof value |
| `paidIntentWeak` | Would-pay no after proof value |

## Decision order

Strongest payment evidence wins:

1. Restore complete → `restoreProof`
2. Sandbox purchase complete → `purchaseProof`
3. Purchase start → `purchaseIntent`
4. Pro tap (after proof) → `proCuriosity`
5. Proof reached without Pro tap → `proofReachedNoProTap` or would-pay classification
6. Maybe before proof → `interestOnly`
7. No useful proof → `proofNotReached`

## Tracked signals (15)

1. First save
2. Second save
3. First useful proof seen
4. Proof accepted
5. Proof corrected
6. Pro promise seen
7. Pro tapped
8. Purchase started
9. Purchase completed
10. Restore started
11. Restore completed
12. Entitlement active
13. Tester would pay yes
14. Tester would pay maybe
15. Tester would pay no

## Key rules

- **Maybe is not payment proof**
- **Pro tap is curiosity** — not payment proof
- **Purchase start is intent** — not proof until complete
- **Sandbox purchase is proof**
- **Restore success strengthens proof**
- **Proof not reached blocks paid interpretation**
- **No pricing experiments**
- **No new Pro benefits**
- **Use existing Pro/paywall path**

## Paid intent bridge

`PaymentProofBetaInstrument.fromPaidIntentBetaProof()` maps existing paid-intent beta attribution into this instrument. `maybe` responses stay `interestOnly`.

## Code module

`lib/features/payment_proof_beta/payment_proof_beta_instrument.dart`

## Guardrail

Do not count interest as revenue evidence. Do not add pricing experiments, Pro benefits, or new product surfaces.

## Related docs

- [payment_proof_not_interest_gate.md](payment_proof_not_interest_gate.md) — earlier interest vs proof gate
- [paid_intent_beta_proof.md](paid_intent_beta_proof.md) — paid intent funnel measurement
