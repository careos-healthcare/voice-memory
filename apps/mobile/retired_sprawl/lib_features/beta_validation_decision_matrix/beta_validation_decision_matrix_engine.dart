import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/beta_validation_decision_matrix/beta_validation_decision_matrix_copy.dart';
import 'package:archiveme_mobile/features/beta_validation_decision_matrix/beta_validation_decision_matrix_model.dart';
import 'package:archiveme_mobile/features/revenue_readiness/revenue_readiness_dashboard_v2_model.dart';

/// Beta-only validation decision matrix — chooses one next action after 20–30 testers.
abstract final class BetaValidationDecisionMatrixEngine {
  BetaValidationDecisionMatrixEngine._();

  static const minimumTesterCount = 20;
  static const cohort20Size = 20;
  static const cohort30Size = 30;

  static const cohort20Thresholds = BetaValidationThresholds(
    cohortSize: cohort20Size,
    firstSessionSaveTarget: 5,
    usefulProofTarget: 5,
    sawProTarget: 3,
    understandsProTarget: 3,
    paywallCtaTapTarget: 2,
    wouldPayTarget: 3,
  );

  static const cohort30Thresholds = BetaValidationThresholds(
    cohortSize: cohort30Size,
    firstSessionSaveTarget: 8,
    usefulProofTarget: 8,
    sawProTarget: 5,
    understandsProTarget: 5,
    paywallCtaTapTarget: 3,
    wouldPayTarget: 5,
  );

  static bool shouldShow({required bool betaMissionEnabled}) =>
      betaMissionEnabled && ArchiveBetaMissionGate.isEnabled;

  static BetaValidationThresholds thresholdsFor(int testerCount) {
    if (testerCount >= cohort30Size) return cohort30Thresholds;
    return cohort20Thresholds;
  }

  static BetaValidationDecisionMatrixResult buildFromInput(
    BetaValidationDecisionMatrixInput input,
  ) {
    final thresholds = thresholdsFor(input.testerCount);
    final outcome = resolveOutcome(input);
    return BetaValidationDecisionMatrixResult(
      outcome: outcome,
      title: BetaValidationDecisionMatrixCopy.titleFor(outcome),
      body: BetaValidationDecisionMatrixCopy.bodyFor(outcome),
      cta: BetaValidationDecisionMatrixCopy.ctaFor(outcome),
      reason: reasonFor(outcome: outcome, input: input, thresholds: thresholds),
      input: input,
      thresholds: thresholds,
    );
  }

  static BetaValidationDecisionMatrixInput inputFromRevenue(
    RevenueReadinessDashboardV2Input input,
  ) => BetaValidationDecisionMatrixInput(
    testerCount: input.testerCount,
    firstSessionSaveCount: input.firstSessionSaveCount,
    usefulProofCount: input.usefulCount,
    sawProCount: input.sawProCount,
    understandsProYesMaybeCount: input.understandsProYesMaybe,
    paywallCtaTapCount: input.paywallCtaTapped,
    wouldPayYesMaybeCount: input.wouldPayYesMaybeCount,
  );

  static BetaValidationDecisionMatrixResult fromRevenueInput(
    RevenueReadinessDashboardV2Input input,
  ) => buildFromInput(inputFromRevenue(input));

  static BetaValidationDecisionOutcome resolveOutcome(
    BetaValidationDecisionMatrixInput input,
  ) {
    if (input.testerCount < minimumTesterCount) {
      return BetaValidationDecisionOutcome.insufficientData;
    }
    final thresholds = thresholdsFor(input.testerCount);
    if (input.usefulProofCount < thresholds.usefulProofTarget) {
      return BetaValidationDecisionOutcome.protectProof;
    }
    if (input.firstSessionSaveCount < thresholds.firstSessionSaveTarget) {
      return BetaValidationDecisionOutcome.fixOpeningScreenOnly;
    }
    if (input.sawProCount < thresholds.sawProTarget) {
      return BetaValidationDecisionOutcome.fixProPlacement;
    }
    if (input.understandsProYesMaybeCount < thresholds.understandsProTarget) {
      return BetaValidationDecisionOutcome.fixProExplanation;
    }
    if (input.paywallCtaTapCount == 0) {
      return BetaValidationDecisionOutcome.fixPaywallValue;
    }
    return BetaValidationDecisionOutcome.widenBetaAndValidatePricing;
  }

  static String reasonFor({
    required BetaValidationDecisionOutcome outcome,
    required BetaValidationDecisionMatrixInput input,
    required BetaValidationThresholds thresholds,
  }) => switch (outcome) {
    BetaValidationDecisionOutcome.insufficientData =>
      'Only ${input.testerCount} of $minimumTesterCount testers counted. '
          'Wait for a 20–30 tester round before choosing the next fix.',
    BetaValidationDecisionOutcome.protectProof =>
      'Useful proof (${input.usefulProofCount}/${thresholds.usefulProofTarget}) '
          'is below the ${thresholds.cohortSize}-tester target. '
          'Proof protection outranks Pro and paywall work.',
    BetaValidationDecisionOutcome.fixOpeningScreenOnly =>
      'Useful proof passed (${input.usefulProofCount}/${thresholds.usefulProofTarget}), '
          'but first-session saves (${input.firstSessionSaveCount}/'
          '${thresholds.firstSessionSaveTarget}) are still below target. '
          'Opening screen only — do not touch proof or Pro yet.',
    BetaValidationDecisionOutcome.fixProPlacement =>
      'Proof (${input.usefulProofCount}/${thresholds.usefulProofTarget}) and '
          'first-session saves (${input.firstSessionSaveCount}/'
          '${thresholds.firstSessionSaveTarget}) passed, but Saw Pro '
          '(${input.sawProCount}/${thresholds.sawProTarget}) is still below target.',
    BetaValidationDecisionOutcome.fixProExplanation =>
      'Saw Pro passed (${input.sawProCount}/${thresholds.sawProTarget}), but '
          'Understands Pro yes/maybe (${input.understandsProYesMaybeCount}/'
          '${thresholds.understandsProTarget}) is still below target.',
    BetaValidationDecisionOutcome.fixPaywallValue =>
      'Earlier gates passed, but paywall CTA taps are still 0/${thresholds.paywallCtaTapTarget}. '
          'Clarify paid value before changing pricing.',
    BetaValidationDecisionOutcome.widenBetaAndValidatePricing =>
      'All core gates passed for the ${thresholds.cohortSize}-tester round: '
          'first-session saves (${input.firstSessionSaveCount}/'
          '${thresholds.firstSessionSaveTarget}), useful proof '
          '(${input.usefulProofCount}/${thresholds.usefulProofTarget}), '
          'Saw Pro (${input.sawProCount}/${thresholds.sawProTarget}), '
          'Understands Pro (${input.understandsProYesMaybeCount}/'
          '${thresholds.understandsProTarget}), and paywall CTA taps '
          '(${input.paywallCtaTapCount}/${thresholds.paywallCtaTapTarget}).',
  };
}