# Paid intent beta script v1

Measure real paid intent after first useful proof on TestFlight — without adding features, pricing experiments, or new Pro benefits.

## What to track

| # | Signal | Event / source |
|---|--------|----------------|
| 1 | First save completed | `first_60_first_save_completed` or entry count ≥ 1 |
| 2 | First useful proof seen | `first_proof_moment_seen` or `has_useful_proof` |
| 3 | Proof accepted or corrected | `beta_proof_feedback_answered` with `useful`, or correction saved |
| 4 | Pro promise seen | `value_moment_pro_bridge_seen` or `paywall_seen` |
| 5 | Pro tapped | `value_moment_pro_bridge_tapped` or `paywall_purchase_cta_tapped` |
| 6 | Purchase attempted | `purchase_started` |
| 7 | Purchase completed | `purchase_completed` |
| 8 | Restore attempted | `restore_started` |
| 9 | Tester would pay | Paid intent confirmation: yes / maybe / no |

## Decision outcomes

| Decision | Meaning |
|----------|---------|
| `insufficientData` | Not enough funnel signals yet |
| `proofNotReached` | Saved but no first useful proof |
| `proofNotUseful` | Proof shown but not accepted or corrected |
| `proNotSeen` | Proof landed but Pro promise not shown |
| `proNotTapped` | Pro shown but paywall not opened |
| `purchaseBlocked` | Purchase mechanics failed after Pro tap |
| `paidIntentWeak` | Tester would not pay or backed out |
| `paidIntentPromising` | Would pay yes/maybe or purchase completed |

## Tester script

1. Install TestFlight build with RevenueCat sandbox key.
2. Record one real moment and complete first save.
3. Return when ArchiveMe shows first useful proof.
4. Mark proof **useful** or correct it if needed.
5. Wait for existing Pro bridge or paywall — do not add new surfaces.
6. Read Pro promise: **Free shows the first useful proof. Pro keeps the longer proof trail.**
7. Tap Pro CTA and open paywall.
8. Attempt sandbox purchase (or restore if already subscribed).
9. Answer would-pay: **Yes / Maybe / No** in paid intent confirmation when shown.

## What not to do

- Do not add new product surfaces.
- Do not change pricing copy or run pricing experiments.
- Do not promise new Pro benefits.
- Do not expand proof volume or dashboards during beta proof.

## Code module

Decision model: `lib/features/paid_intent_beta_proof/paid_intent_beta_proof.dart`

Feed funnel signals with `PaidIntentBetaProof.fromAttribution()` or map would-pay from `PaidIntentBetaProof.fromWouldPayResponseId()`.

```bash
cd apps/voicememory_mobile
flutter test test/paid_intent_beta_proof_test.dart
```

## Related docs

- `docs/BETA_FEEDBACK_RESPONSE_PLAYBOOK.md`
- `docs/revenuecat_sandbox_proof.md`
- `docs/PAID_LAUNCH_DECISION_CHECKLIST.md`
