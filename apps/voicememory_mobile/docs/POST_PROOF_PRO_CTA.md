# Post-proof Pro CTA hardening v1

Ensure the **Pro CTA appears after value, not before**. Classification and gating only — no pricing or RevenueCat changes.

## Decisions

| Decision | Meaning |
| --- | --- |
| `proCtaBlocked` | Pro CTA hidden until proof value or explicit Pro open (default) |
| `proCtaHardened` | Post-proof timing and canonical copy rules pass |

## Canonical copy

- **CTA:** "Keep the longer trail"
- **Body:** "Free showed the first useful proof. Pro keeps tracking what happens next."

## Rules (8)

1. Hide before first useful proof unless explicit Pro open
2. Show after proof value moment
3. Canonical CTA and body
4. No more AI language
5. No life-dashboard framing
6. No storage framing
7. No urgency or scarcity language
8. No pricing or RevenueCat changes

## Visibility

**Hide** Pro CTA before first useful proof unless the user explicitly opens Pro.

**Show** after:

- First useful proof
- Accepted proof
- Clear longer-trail moment

## Always blocked copy

- More AI framing
- Life-dashboard framing
- Storage framing
- Urgency/scarcity language

## Bridge factories

`PostProofProCtaHardening.composeInput()` bridges:

- `PaidIntentBetaProofResult` — `firstUsefulProofSeen` and `proofAcceptedOrCorrected`

`shouldShowProCta()` and `evaluateCopyPassesRules()` enforce timing and copy guardrails.

## CI bundle

`tool/run_post_proof_pro_cta_hardening.sh` runs:

- `test/post_proof_pro_cta_hardening_test.dart`

## Code modules

- Engine: `lib/features/post_proof_pro_cta/post_proof_pro_cta_hardening.dart`
- Copy: `lib/features/post_proof_pro_cta/post_proof_pro_cta_copy.dart`
- Tests: `test/post_proof_pro_cta_hardening_test.dart`

## Run tests

```bash
cd apps/voicememory_mobile
flutter test test/post_proof_pro_cta_hardening_test.dart
```

Or use the CI wrapper:

```bash
cd apps/voicememory_mobile
./tool/run_post_proof_pro_cta_hardening.sh
```
