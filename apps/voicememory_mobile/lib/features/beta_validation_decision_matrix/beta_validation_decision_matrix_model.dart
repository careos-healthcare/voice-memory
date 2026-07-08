import 'beta_validation_decision_matrix_copy.dart';

enum BetaValidationDecisionOutcome {
  insufficientData,
  protectProof,
  fixOpeningScreenOnly,
  fixProPlacement,
  fixProExplanation,
  fixPaywallValue,
  widenBetaAndValidatePricing,
}

class BetaValidationThresholds {
  const BetaValidationThresholds({
    required this.cohortSize,
    required this.firstSessionSaveTarget,
    required this.usefulProofTarget,
    required this.sawProTarget,
    required this.understandsProTarget,
    required this.paywallCtaTapTarget,
    required this.wouldPayTarget,
  });

  final int cohortSize;
  final int firstSessionSaveTarget;
  final int usefulProofTarget;
  final int sawProTarget;
  final int understandsProTarget;
  final int paywallCtaTapTarget;
  final int wouldPayTarget;
}

class BetaValidationDecisionMatrixInput {
  const BetaValidationDecisionMatrixInput({
    required this.testerCount,
    required this.firstSessionSaveCount,
    required this.usefulProofCount,
    required this.sawProCount,
    required this.understandsProYesMaybeCount,
    required this.paywallCtaTapCount,
    this.wouldPayYesMaybeCount,
  });

  final int testerCount;
  final int firstSessionSaveCount;
  final int usefulProofCount;
  final int sawProCount;
  final int understandsProYesMaybeCount;
  final int paywallCtaTapCount;
  final int? wouldPayYesMaybeCount;
}

class BetaValidationDecisionMatrixResult {
  const BetaValidationDecisionMatrixResult({
    required this.outcome,
    required this.title,
    required this.body,
    required this.cta,
    required this.reason,
    required this.input,
    required this.thresholds,
  });

  final BetaValidationDecisionOutcome outcome;
  final String title;
  final String body;
  final String cta;
  final String reason;
  final BetaValidationDecisionMatrixInput input;
  final BetaValidationThresholds thresholds;

  String get outcomeLabel => BetaValidationDecisionMatrixCopy.titleFor(outcome);

  String get cohortLabel =>
      '${BetaValidationDecisionMatrixCopy.testerCountLabel}: '
      '${input.testerCount}/${thresholds.cohortSize}';

  List<String> get metricLines => [
        BetaValidationDecisionMatrixCopy.metricLine(
          label: BetaValidationDecisionMatrixCopy.firstSessionSaveLabel,
          actual: input.firstSessionSaveCount,
          target: thresholds.firstSessionSaveTarget,
        ),
        BetaValidationDecisionMatrixCopy.metricLine(
          label: BetaValidationDecisionMatrixCopy.usefulProofLabel,
          actual: input.usefulProofCount,
          target: thresholds.usefulProofTarget,
        ),
        BetaValidationDecisionMatrixCopy.metricLine(
          label: BetaValidationDecisionMatrixCopy.sawProLabel,
          actual: input.sawProCount,
          target: thresholds.sawProTarget,
        ),
        BetaValidationDecisionMatrixCopy.metricLine(
          label: BetaValidationDecisionMatrixCopy.understandsProLabel,
          actual: input.understandsProYesMaybeCount,
          target: thresholds.understandsProTarget,
        ),
        BetaValidationDecisionMatrixCopy.metricLine(
          label: BetaValidationDecisionMatrixCopy.paywallCtaTapLabel,
          actual: input.paywallCtaTapCount,
          target: thresholds.paywallCtaTapTarget,
        ),
        BetaValidationDecisionMatrixCopy.wouldPayMetricLine(
          actual: input.wouldPayYesMaybeCount,
          target: thresholds.wouldPayTarget,
        ),
      ];
}
