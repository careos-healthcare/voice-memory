import 'package:archiveme_mobile/features/beta_decision_rules/beta_decision_rule_copy.dart';
import 'package:archiveme_mobile/features/beta_decision_rules/beta_decision_rule_model.dart';
import 'package:archiveme_mobile/features/revenue_readiness/revenue_readiness_dashboard_v2_model.dart';

/// Beta-only decision rule engine — chooses one next action from tester counts.
abstract final class BetaDecisionRuleEngine {
  BetaDecisionRuleEngine._();

  static const minimumTesterCount = 10;
  static const firstSessionSaveCritical = 1;
  static const firstSessionSaveImproved = 2;
  static const sawProStillHidden = 1;
  static const sawProImproved = 3;
  static const understandsProStillWeak = 1;
  static const usefulProofTooLow = 2;

  static bool shouldShow({required bool betaMissionEnabled}) =>
      betaMissionEnabled;

  static BetaDecisionRuleResult buildFromInput(BetaDecisionRuleInput input) {
    final outcome = resolveOutcome(input);
    return BetaDecisionRuleResult(
      outcome: outcome,
      title: BetaDecisionRuleCopy.titleFor(outcome),
      body: BetaDecisionRuleCopy.bodyFor(outcome),
      cta: BetaDecisionRuleCopy.ctaFor(outcome),
      reason: reasonFor(outcome: outcome, input: input),
      input: input,
    );
  }

  static BetaDecisionRuleInput inputFromRevenue(
    RevenueReadinessDashboardV2Input input,
  ) => BetaDecisionRuleInput(
    testerCount: input.testerCount,
    firstSessionSaveCount: input.firstSessionSaveCount,
    sawProCount: input.sawProCount,
    understandsProYesMaybeCount: input.understandsProYesMaybe,
    usefulProofCount: input.usefulCount,
  );

  static BetaDecisionRuleResult fromRevenueInput(
    RevenueReadinessDashboardV2Input input,
  ) => buildFromInput(inputFromRevenue(input));

  static BetaDecisionRuleOutcome resolveOutcome(BetaDecisionRuleInput input) {
    if (input.testerCount < minimumTesterCount) {
      return BetaDecisionRuleOutcome.insufficientData;
    }
    if (input.usefulProofCount < usefulProofTooLow) {
      return BetaDecisionRuleOutcome.protectProof;
    }
    if (input.firstSessionSaveCount <= firstSessionSaveCritical) {
      return BetaDecisionRuleOutcome.fixOpeningScreenOnly;
    }
    if (input.firstSessionSaveCount >= firstSessionSaveImproved &&
        input.sawProCount <= sawProStillHidden) {
      return BetaDecisionRuleOutcome.fixProPlacement;
    }
    if (input.sawProCount >= sawProImproved &&
        input.understandsProYesMaybeCount <= understandsProStillWeak) {
      return BetaDecisionRuleOutcome.fixProExplanation;
    }
    return BetaDecisionRuleOutcome.continueMoreTesters;
  }

  static String reasonFor({
    required BetaDecisionRuleOutcome outcome,
    required BetaDecisionRuleInput input,
  }) => switch (outcome) {
    BetaDecisionRuleOutcome.insufficientData =>
      'Only ${input.testerCount} of $minimumTesterCount testers counted. '
          'Wait for a full round before choosing a build target.',
    BetaDecisionRuleOutcome.protectProof =>
      'Useful proof (${input.usefulProofCount}/10) is below the safe floor '
          '($usefulProofTooLow/10). Proof protection outranks conversion work.',
    BetaDecisionRuleOutcome.fixOpeningScreenOnly =>
      'First-session saves (${input.firstSessionSaveCount}/10) are still at or '
          'below the critical threshold ($firstSessionSaveCritical/10). '
          'Opening screen only — do not touch proof or Pro yet.',
    BetaDecisionRuleOutcome.fixProPlacement =>
      'First-session saves improved (${input.firstSessionSaveCount}/10 ≥ '
          '$firstSessionSaveImproved/10), but Saw Pro (${input.sawProCount}/10) '
          'is still at or below $sawProStillHidden/10.',
    BetaDecisionRuleOutcome.fixProExplanation =>
      'Saw Pro improved (${input.sawProCount}/10 ≥ $sawProImproved/10), but '
          'Understands Pro yes/maybe (${input.understandsProYesMaybeCount}/10) '
          'is still at or below $understandsProStillWeak/10.',
    BetaDecisionRuleOutcome.continueMoreTesters =>
      'All gates passed: first-session saves (${input.firstSessionSaveCount}/10), '
          'Saw Pro (${input.sawProCount}/10), Understands Pro '
          '(${input.understandsProYesMaybeCount}/10), and useful proof '
          '(${input.usefulProofCount}/10) are healthy enough.',
  };
}