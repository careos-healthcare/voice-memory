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

**Goal:** Make proof emotionally understandable — what came back, what changed, and why it might matter.

**Implemented:**
- `lib/features/beta_improvement/proof_emotional_clarity_copy_fix.dart`
- `lib/features/beta_improvement/proof_emotional_clarity_engine.dart`
- `lib/features/beta_improvement/proof_emotional_clarity_model.dart`
- First proof structured card via `FirstProofPayoffCard` + `FirstProofPayoffEngine`
- What Changed v2 payoff headline when branch active
- Correction row reuses `EarlyArchiveInsightFeedbackStore`
- Manual preview: `--dart-define=ARCHIVEME_BETA_IMPROVEMENT_BRANCH=proofEmotionalClarity`

**Rules:**
- Proof must answer what came back, what changed, and why it might matter
- Never overclaim beyond evidence — watch-only uses softer copy only
- Strong headline ("This came back.") only when confidence guard allows

**Blocked:** Diagnosis, certainty, therapy claims, stacked proof cards.

### 5. Pro packaging

**Trigger:** Users care about proof but will not pay (`sharpenProPackaging`).

**Goal:** Make the paid value obvious — Pro keeps the longer trail.

**Implemented:**
- `lib/features/beta_improvement/pro_packaging_copy_fix.dart`
- `lib/features/beta_improvement/pro_packaging_branch_engine.dart`
- Free vs Pro bridge on `ProBridgeVisibilityEngine` and `FirstProofPayoffCard`
- Paywall/account packaging via `ProPackagingEngine` when branch active
- Manual preview: `--dart-define=ARCHIVEME_BETA_IMPROVEMENT_BRANCH=proPackaging`

**Rules:**
- Core paid reason: Pro keeps the longer trail — not more AI
- Do not claim unavailable utility or live reports
- Free must still feel useful (first useful repeat)
- Pro bridge only after meaningful proof (`hasMeaningfulProof`)

**Blocked:** RevenueCat changes, fake purchase claims, urgency/scarcity.

See also `docs/PRO_PACKAGING_V1.md`.

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
