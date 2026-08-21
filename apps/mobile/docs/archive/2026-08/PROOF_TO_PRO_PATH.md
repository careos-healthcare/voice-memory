# Proof-to-Pro path

Safe combined path where proof emotional clarity comes first, then Pro packaging appears only after meaningful proof.

## Trigger

Users care about proof but need a clearer paid reason — typically when beta evidence points to `sharpenProPackaging` after `proofFeltMeaningful`.

## Core rule

**Proof first. Pro second.**

Never show Pro packaging before the proof moment. Never on empty first-run.

## Sequence

1. **Make proof meaningful** — what came back, what changed, why it might matter
2. **Then explain Pro** — quiet bridge below the proof card, not a stacked second card

## Desired UX after meaningful proof

**Main proof copy:**
- "This came back."
- What came back
- What changed
- Why this might matter

**Quiet Pro bridge (below proof card):**
- "This is the kind of trail Pro keeps building."
- "Free helps you see the first useful repeat. Pro keeps the longer trail."

## Free vs Pro value

| Free | Pro |
|------|-----|
| First useful repeat | Longer trail |
| First proof | Older evidence kept |

Free must remain useful. Pro does not appear before proof.

## Paired branches

`proofEmotionalClarity` and `proPackaging` can be paired **only after meaningful proof**:

- **proofEmotionalClarity only** — proof clarity surfaces; no Pro bridge yet
- **proPackaging** — proof clarity **and** quiet Pro bridge on the same proof card
- **proUtility** — separate branch; not part of this path unless explicitly active

## Manual testing override

```
--dart-define=ARCHIVEME_BETA_IMPROVEMENT_BRANCH=proofToPro
```

`proofToPro` is a resolver alias (not a new product branch) that enables both proof clarity and Pro packaging when evidence thresholds pass.

## Blocked

- Pro before proof
- Stacked proof + Pro cards on the same surface
- Ask Archive, loop packs, B2B
- Fake locked content / dark-pattern paywalls
- More AI, better answers, coaching, therapy/clinical claims
- RevenueCat, product ID, entitlement, or pricing changes

## Module map

- Engine: `lib/features/beta_improvement/proof_to_pro_path_engine.dart`
- Model: `lib/features/beta_improvement/proof_to_pro_path_model.dart`
- Proof clarity: `lib/features/beta_improvement/proof_emotional_clarity_engine.dart`
- Pro packaging: `lib/features/beta_improvement/pro_packaging_branch_engine.dart`
- Surfaces: `FirstProofPayoffCard`, `WhatChangedV2Card`, `ProBridgeVisibilityEngine`, paywall/account packaging

See also `docs/BETA_IMPROVEMENT_PACK.md` and `test/proof_to_pro_path_test.dart`.
