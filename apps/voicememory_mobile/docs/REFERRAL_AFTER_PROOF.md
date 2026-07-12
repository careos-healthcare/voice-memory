# Referral after proof gate v1

Allow **future referral and invite only after proof value**, never before. Classification and gating documentation only — no new product surfaces unless an existing route is already gated.

## Decisions

| Decision | Meaning |
| --- | --- |
| `referralBlocked` | Referral prompts frozen until proof value (default) |
| `referralAfterProofAllowed` | Useful proof accepted or Pro promise understood; gated referral may surface |

## Rules (6)

1. Referral prompt only after useful proof accepted or Pro promise understood
2. Never share private content
3. Invite shares product, not user archive
4. Not shown in first five minutes
5. Not part of paid promise
6. No live referral UI for V1 unless existing route is already gated

## Always blocked

- **Private content sharing** — invite copy stays product-only
- **Paid promise** — referral is never part of Pro promise
- **First five minutes** — no referral surfacing during first five minutes

## Proof value unlock

Either required:

1. `usefulProofAccepted` — first useful proof accepted
2. `proPromiseUnderstood` — Pro promise seen and user understood why

## Existing route policy

- `/invite` route exists in `app_router.dart`
- Live referral UI must stay gated through `ReferralInviteAfterValue.shouldShow`
- No new referral UI for V1

## Bridge factories

`ReferralAfterProofGate.composeInput()` bridges:

- `FirstProofSuccessBetaInput` — `proofAccepted`, `proPromiseSeen`, `userUnderstoodWhy`
- `PaidIntentBetaProofResult` — proof accepted and Pro promise signals

`evaluateCopyPassesRules()` rejects archive-sharing invite copy and paid-promise referral copy.

## CI bundle

`tool/run_referral_after_proof_gate.sh` runs:

- `test/referral_after_proof_gate_test.dart`

## Code modules

- Engine: `lib/features/referral_after_proof/referral_after_proof_gate.dart`
- Copy: `lib/features/referral_after_proof/referral_after_proof_copy.dart`
- Tests: `test/referral_after_proof_gate_test.dart`

## Run tests

```bash
cd apps/voicememory_mobile
flutter test test/referral_after_proof_gate_test.dart
```

Or use the CI wrapper:

```bash
cd apps/voicememory_mobile
./tool/run_referral_after_proof_gate.sh
```
