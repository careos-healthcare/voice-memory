import 'beta_validation_decision_matrix_model.dart';

/// Beta validation decision matrix copy — metadata-safe guidance only.
abstract final class BetaValidationDecisionMatrixCopy {
  BetaValidationDecisionMatrixCopy._();

  static const cardTitle = 'Beta validation decision matrix';
  static const cohortTitle = 'Validation cohort';
  static const metricsTitle = 'Core metrics';
  static const outcomeTitle = 'Selected outcome';
  static const reasonTitle = 'Why this won';
  static const onlyFixThisOneNext = 'Only fix this one next';
  static const localCountsNote =
      'Counts are local metadata only. No journal text is shown.';

  static const testerCountLabel = 'Testers';
  static const firstSessionSaveLabel = 'First-session saves';
  static const usefulProofLabel = 'Useful proof';
  static const sawProLabel = 'Saw Pro';
  static const understandsProLabel = 'Understands Pro (yes/maybe)';
  static const paywallCtaTapLabel = 'Paywall CTA tapped';
  static const wouldPayLabel = 'Would pay (yes/maybe)';

  static String titleFor(BetaValidationDecisionOutcome outcome) =>
      switch (outcome) {
        BetaValidationDecisionOutcome.insufficientData =>
          'Not enough validation data',
        BetaValidationDecisionOutcome.protectProof => 'Protect proof again',
        BetaValidationDecisionOutcome.fixOpeningScreenOnly =>
          'Fix opening screen only',
        BetaValidationDecisionOutcome.fixProPlacement => 'Fix Pro placement',
        BetaValidationDecisionOutcome.fixProExplanation =>
          'Fix Pro explanation',
        BetaValidationDecisionOutcome.fixPaywallValue => 'Fix paywall value',
        BetaValidationDecisionOutcome.widenBetaAndValidatePricing =>
          'Widen beta and validate pricing',
      };

  static String bodyFor(BetaValidationDecisionOutcome outcome) =>
      switch (outcome) {
        BetaValidationDecisionOutcome.insufficientData =>
          'Wait for at least 20 testers before deciding the next product fix.',
        BetaValidationDecisionOutcome.protectProof =>
          'Useful proof is below target. Do not touch Pro or paywall. '
              'Make proof feel more specific, careful, and real.',
        BetaValidationDecisionOutcome.fixOpeningScreenOnly =>
          'First-session saving is below target. Do not touch proof or Pro. '
              'Make the first save clearer and easier.',
        BetaValidationDecisionOutcome.fixProPlacement =>
          'Proof and first-session capture passed, but too few testers saw Pro. '
              'Move the Pro moment closer to useful proof.',
        BetaValidationDecisionOutcome.fixProExplanation =>
          'Testers are seeing Pro, but not enough understand it. '
              'Explain the longer timeline more clearly.',
        BetaValidationDecisionOutcome.fixPaywallValue =>
          'The core path is working, but no one tapped the paywall CTA. '
              'Make the paid value more concrete before changing pricing.',
        BetaValidationDecisionOutcome.widenBetaAndValidatePricing =>
          'The main beta signals passed. Do not build more features. '
              'Invite more testers and start pricing/purchase validation.',
      };

  static String ctaFor(BetaValidationDecisionOutcome outcome) =>
      switch (outcome) {
        BetaValidationDecisionOutcome.insufficientData => 'Keep testing',
        BetaValidationDecisionOutcome.protectProof => 'Review proof quality',
        BetaValidationDecisionOutcome.fixOpeningScreenOnly =>
          'Review opening screen',
        BetaValidationDecisionOutcome.fixProPlacement => 'Review Pro placement',
        BetaValidationDecisionOutcome.fixProExplanation =>
          'Review Pro explanation',
        BetaValidationDecisionOutcome.fixPaywallValue => 'Review paywall value',
        BetaValidationDecisionOutcome.widenBetaAndValidatePricing =>
          'Prepare wider beta',
      };

  static String metricLine({
    required String label,
    required int actual,
    required int target,
  }) =>
      '$label: $actual/$target';

  static String wouldPayMetricLine({
    required int? actual,
    required int target,
  }) =>
      actual == null
          ? '$wouldPayLabel: not yet'
          : metricLine(
              label: wouldPayLabel,
              actual: actual,
              target: target,
            );

  static Iterable<String> allVisibleStrings() sync* {
    yield cardTitle;
    yield cohortTitle;
    yield metricsTitle;
    yield outcomeTitle;
    yield reasonTitle;
    yield onlyFixThisOneNext;
    yield localCountsNote;
    yield testerCountLabel;
    yield firstSessionSaveLabel;
    yield usefulProofLabel;
    yield sawProLabel;
    yield understandsProLabel;
    yield paywallCtaTapLabel;
    yield wouldPayLabel;
    for (final outcome in BetaValidationDecisionOutcome.values) {
      yield titleFor(outcome);
      yield bodyFor(outcome);
      yield ctaFor(outcome);
    }
  }
}
