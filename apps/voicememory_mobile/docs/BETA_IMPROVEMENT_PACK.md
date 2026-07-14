# Beta improvement pack

Gated copy improvements for the six beta decision branches. **Only one branch is emphasized in live UI at a time.**

## Core rule

Build only the **first failing branch** from `docs/BETA_DECISION_SYSTEM.md`. Do not surface all six improvements together.

Expansion remains blocked unless beta evidence supports it (`docs/V1_EXPANSION_GATES.md`).

## Branches

### 1. Record/onboarding copy fix

**Trigger:** Users do not understand the app (`BetaNextBuildRecommendation.fixRecordOnboardingCopy`).

**Implemented:**
- `lib/features/beta_improvement/record_onboarding_copy_fix.dart`
- Clearer low-evidence Record copy via `BetaImprovementPackEngine`
- Not-a-diary clarifier + low-evidence helper line on first-use prompt

**Blocked:** Long onboarding flows, therapy/coaching framing.

### 2. Capture friction fix

**Trigger:** Users understand but do not record (`fixCaptureFriction`).

**Implemented:**
- `lib/features/beta_improvement/capture_friction_copy_fix.dart`
- Typed capture first when branch active (`CaptureEntryActions.preferTypedFirst`)
- Compact prompt chips on first-session capture repair card

**Blocked:** Forced voice, login walls, homework framing.

### 3. Return reminder / three-day plan

**Trigger:** Users record once but do not return (`addReturnReason`).

**Implemented:**
- `lib/features/beta_improvement/return_reason_copy_fix.dart`
- Post-save cue: "Come back if this shows up again."
- Optional three-day plan strip on post-save handoff (no streak)

**Blocked:** Push infrastructure changes, daily homework, full challenge product.

### 4. Proof emotional clarity

**Trigger:** Users reach proof but do not care (`improveProofEmotionalClarity`).

**Implemented:**
- `lib/features/beta_improvement/proof_emotional_clarity_copy_fix.dart`
- First proof headline/why-matters lines via `FirstProofPayoffEngine`

**Blocked:** Diagnosis, certainty, therapy claims.

### 5. Pro packaging

**Trigger:** Users care but will not pay (`sharpenProPackaging`).

**Implemented:**
- `lib/features/beta_improvement/pro_packaging_copy_fix.dart`
- Free vs Pro bridge copy on `ProBridgeVisibilityEngine`
- Longer trail promise — not more AI

**Blocked:** RevenueCat changes, fake purchase claims.

### 6. Pro utility expansion

**Trigger:** Users ask for history/export/report after caring (`expandProUtility`), only when expansion gate passes.

**Implemented:**
- `lib/features/beta_improvement/pro_utility_copy_fix.dart`
- Preview copy only (planned/preview labels)
- Shown on Testing ArchiveMe active-branch card

**Blocked:** Ask Archive, loop packs, B2B, new top-level nav, full export/report unless tested.

## Gating

- Resolver: `lib/features/beta_improvement/beta_improvement_recommendation_gate.dart`
- Orchestrator: `lib/features/beta_improvement/beta_improvement_pack_engine.dart`
- Sources: logged `BetaTesterOutcome` outcomes and/or `--dart-define=ARCHIVEME_BETA_IMPROVEMENT_BRANCH=<branch>`
- Evidence states limit where copy applies (entry count, meaningful proof, expansion allowed)

## Operator workflow

1. Log tester outcomes on `/testing-archiveme`
2. Read active branch on **Beta next-build decision** + **Active beta improvement branch** cards
3. Ship one branch; re-test with 5 people
4. Do not enable the next branch until the current failure clears

See also `docs/BETA_DECISION_SYSTEM.md` and `test/beta_improvement_pack_test.dart`.
