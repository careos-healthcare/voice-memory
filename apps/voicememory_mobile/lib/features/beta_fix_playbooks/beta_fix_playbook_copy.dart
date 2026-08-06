import '../beta_validation_decision_matrix/beta_validation_decision_matrix_model.dart';

/// Beta fix playbook copy — inactive guidance only, no behavior changes.
abstract final class BetaFixPlaybookCopy {
  BetaFixPlaybookCopy._();

  static const cardTitle = 'Beta fix playbook';
  static const diagnosisTitle = 'Current issue';
  static const fixPlanTitle = 'Fix plan';
  static const doNotDoTitle = 'Do not do';
  static const guidanceOnlyNote =
      'This is guidance only. It does not change product behavior.';

  static const protectProofTitle = 'Protect proof';
  static const protectProofDiagnosis =
      'Useful proof is below target. Do not touch Pro or paywall. '
      'Make weak proof more careful and strong proof more specific.';
  static const protectProofFix1 = 'Review weak/watch-only proof surfaces';
  static const protectProofFix2 =
      'Check whether proof is being shown too early';
  static const protectProofFix3 = 'Check whether proof copy sounds too certain';
  static const protectProofFix4 =
      'Ask testers what made the proof feel vague or wrong';
  static const protectProofFix5 = 'Prefer watch/wait state over forced proof';
  static const protectProofFix6 =
      'Keep Pro blocked after negative proof feedback';
  static const protectProofDont1 = 'Do not increase Pro pressure';
  static const protectProofDont2 = 'Do not change pricing';
  static const protectProofDont3 = 'Do not call weak evidence proof';
  static const protectProofDont4 = 'Do not fake stronger evidence';

  static const openingScreenTitle = 'Fix opening screen only';
  static const openingScreenDiagnosis =
      'First-session saving is below target. '
      'The first action is still not obvious or small enough.';
  static const openingScreenFix1 = 'Make first save the only obvious action';
  static const openingScreenFix2 = 'Reduce explanation above the first CTA';
  static const openingScreenFix3 = 'Keep typed capture first';
  static const openingScreenFix4 = 'Keep voice secondary';
  static const openingScreenFix5 = 'Keep examples concrete';
  static const openingScreenFix6 =
      'Remove anything that feels like homework, journaling, or setup';
  static const openingScreenDont1 = 'Do not change proof';
  static const openingScreenDont2 = 'Do not change Pro';
  static const openingScreenDont3 = 'Do not add onboarding steps';
  static const openingScreenDont4 =
      'Do not ask users to understand the whole product before saving';

  static const proPlacementTitle = 'Fix Pro placement';
  static const proPlacementDiagnosis =
      'Proof and first-session capture passed, but too few testers saw Pro. '
      'The paid moment is too hidden.';
  static const proPlacementFix1 = 'Move Pro closer to useful proof';
  static const proPlacementFix2 = 'Keep only one Pro card';
  static const proPlacementFix3 = 'Do not show Pro after weak/negative proof';
  static const proPlacementFix4 =
      'Prefer post-useful-proof placement over generic settings/paywall placement';
  static const proPlacementFix5 =
      'Keep the message: Free shows first proof, Pro keeps the longer proof trail';
  static const proPlacementDont1 = 'Do not show Pro before proof';
  static const proPlacementDont2 = 'Do not stack multiple Pro cards';
  static const proPlacementDont3 =
      'Do not show Pro after Too vague / Not relevant feedback';
  static const proPlacementDont4 = 'Do not change purchase mechanics';

  static const proExplanationTitle = 'Fix Pro explanation';
  static const proExplanationDiagnosis =
      'Testers are seeing Pro, but not enough understand it. '
      'The value of the longer proof trail is not clear enough.';
  static const proExplanationFix1 = 'Explain Free vs Pro in one sentence';
  static const proExplanationFix2 =
      'Show that Pro keeps what returns, changes, fades, and gets corrected';
  static const proExplanationFix3 = 'Say clearly that this is not more chat';
  static const proExplanationFix4 =
      'Keep control language: delete/correct entries';
  static const proExplanationFix5 =
      'Ask testers to explain Pro back in their own words';
  static const proExplanationDont1 = 'Do not add more features';
  static const proExplanationDont2 = 'Do not make vague AI claims';
  static const proExplanationDont3 = 'Do not make therapy/medical claims';
  static const proExplanationDont4 =
      'Do not change placement until explanation is tested';

  static const paywallValueTitle = 'Fix paywall value';
  static const paywallValueDiagnosis =
      'The core path passed, but nobody tapped the paywall CTA. '
      'The paid value is not concrete enough.';
  static const paywallValueFix1 = 'Make the CTA support line more concrete';
  static const paywallValueFix2 = 'Emphasize keeping the evidence trail';
  static const paywallValueFix3 =
      'Make the paywall connect directly to the proof just seen';
  static const paywallValueFix4 =
      'Keep pricing unchanged until value is clearer';
  static const paywallValueFix5 = 'Ask: would you pay to keep this timeline?';
  static const paywallValueDont1 = 'Do not discount immediately';
  static const paywallValueDont2 = 'Do not change RevenueCat';
  static const paywallValueDont3 = 'Do not change products or entitlements';
  static const paywallValueDont4 = 'Do not add fake locked content';

  static const widenBetaTitle = 'Widen beta';
  static const widenBetaDiagnosis = 'The validation gates passed.';
  static const widenBetaFix1 = 'Invite 20-30 more testers';
  static const widenBetaFix2 = 'Start pricing/purchase validation';
  static const widenBetaFix3 =
      'Keep watching useful proof and first-session save';
  static const widenBetaDont1 = 'Do not add new features before pricing signal';

  static String titleFor(
    BetaValidationDecisionOutcome outcome,
  ) => switch (outcome) {
    BetaValidationDecisionOutcome.protectProof => protectProofTitle,
    BetaValidationDecisionOutcome.fixOpeningScreenOnly => openingScreenTitle,
    BetaValidationDecisionOutcome.fixProPlacement => proPlacementTitle,
    BetaValidationDecisionOutcome.fixProExplanation => proExplanationTitle,
    BetaValidationDecisionOutcome.fixPaywallValue => paywallValueTitle,
    BetaValidationDecisionOutcome.widenBetaAndValidatePricing => widenBetaTitle,
    BetaValidationDecisionOutcome.insufficientData => '',
  };

  static String diagnosisFor(BetaValidationDecisionOutcome outcome) =>
      switch (outcome) {
        BetaValidationDecisionOutcome.protectProof => protectProofDiagnosis,
        BetaValidationDecisionOutcome.fixOpeningScreenOnly =>
          openingScreenDiagnosis,
        BetaValidationDecisionOutcome.fixProPlacement => proPlacementDiagnosis,
        BetaValidationDecisionOutcome.fixProExplanation =>
          proExplanationDiagnosis,
        BetaValidationDecisionOutcome.fixPaywallValue => paywallValueDiagnosis,
        BetaValidationDecisionOutcome.widenBetaAndValidatePricing =>
          widenBetaDiagnosis,
        BetaValidationDecisionOutcome.insufficientData => '',
      };

  static List<String> fixPlanFor(BetaValidationDecisionOutcome outcome) =>
      switch (outcome) {
        BetaValidationDecisionOutcome.protectProof => [
          protectProofFix1,
          protectProofFix2,
          protectProofFix3,
          protectProofFix4,
          protectProofFix5,
          protectProofFix6,
        ],
        BetaValidationDecisionOutcome.fixOpeningScreenOnly => [
          openingScreenFix1,
          openingScreenFix2,
          openingScreenFix3,
          openingScreenFix4,
          openingScreenFix5,
          openingScreenFix6,
        ],
        BetaValidationDecisionOutcome.fixProPlacement => [
          proPlacementFix1,
          proPlacementFix2,
          proPlacementFix3,
          proPlacementFix4,
          proPlacementFix5,
        ],
        BetaValidationDecisionOutcome.fixProExplanation => [
          proExplanationFix1,
          proExplanationFix2,
          proExplanationFix3,
          proExplanationFix4,
          proExplanationFix5,
        ],
        BetaValidationDecisionOutcome.fixPaywallValue => [
          paywallValueFix1,
          paywallValueFix2,
          paywallValueFix3,
          paywallValueFix4,
          paywallValueFix5,
        ],
        BetaValidationDecisionOutcome.widenBetaAndValidatePricing => [
          widenBetaFix1,
          widenBetaFix2,
          widenBetaFix3,
        ],
        BetaValidationDecisionOutcome.insufficientData => const [],
      };

  static List<String> doNotDoFor(BetaValidationDecisionOutcome outcome) =>
      switch (outcome) {
        BetaValidationDecisionOutcome.protectProof => [
          protectProofDont1,
          protectProofDont2,
          protectProofDont3,
          protectProofDont4,
        ],
        BetaValidationDecisionOutcome.fixOpeningScreenOnly => [
          openingScreenDont1,
          openingScreenDont2,
          openingScreenDont3,
          openingScreenDont4,
        ],
        BetaValidationDecisionOutcome.fixProPlacement => [
          proPlacementDont1,
          proPlacementDont2,
          proPlacementDont3,
          proPlacementDont4,
        ],
        BetaValidationDecisionOutcome.fixProExplanation => [
          proExplanationDont1,
          proExplanationDont2,
          proExplanationDont3,
          proExplanationDont4,
        ],
        BetaValidationDecisionOutcome.fixPaywallValue => [
          paywallValueDont1,
          paywallValueDont2,
          paywallValueDont3,
          paywallValueDont4,
        ],
        BetaValidationDecisionOutcome.widenBetaAndValidatePricing => [
          widenBetaDont1,
        ],
        BetaValidationDecisionOutcome.insufficientData => const [],
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield cardTitle;
    yield diagnosisTitle;
    yield fixPlanTitle;
    yield doNotDoTitle;
    yield guidanceOnlyNote;
    for (final outcome in BetaValidationDecisionOutcome.values) {
      if (outcome == BetaValidationDecisionOutcome.insufficientData) continue;
      yield titleFor(outcome);
      yield diagnosisFor(outcome);
      for (final step in fixPlanFor(outcome)) {
        yield step;
      }
      for (final step in doNotDoFor(outcome)) {
        yield step;
      }
    }
  }
}
