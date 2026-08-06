import 'beta_decision_rule_model.dart';

/// Beta-only decision rule copy — metadata-safe, no journal text.
abstract final class BetaDecisionRuleCopy {
  BetaDecisionRuleCopy._();

  static const cardTitle = 'Beta decision rule';
  static const inputsTitle = 'Counted inputs';
  static const reasonTitle = 'Why this won';
  static const localCountsNote =
      'Counts are local metadata only. No journal text is shown.';

  static const testerCountLabel = 'Testers';
  static const firstSessionSaveLabel = 'First-session saves';
  static const sawProLabel = 'Saw Pro';
  static const understandsProLabel = 'Understands Pro (yes/maybe)';
  static const usefulProofLabel = 'Useful proof';

  static String titleFor(BetaDecisionRuleOutcome outcome) => switch (outcome) {
    BetaDecisionRuleOutcome.insufficientData => 'Not enough tester data yet',
    BetaDecisionRuleOutcome.protectProof => 'Protect the proof',
    BetaDecisionRuleOutcome.fixOpeningScreenOnly =>
      'Fix the opening screen only',
    BetaDecisionRuleOutcome.fixProPlacement => 'Fix Pro placement',
    BetaDecisionRuleOutcome.fixProExplanation => 'Fix Pro explanation',
    BetaDecisionRuleOutcome.continueMoreTesters => 'Continue with more testers',
  };

  static String bodyFor(BetaDecisionRuleOutcome outcome) => switch (outcome) {
    BetaDecisionRuleOutcome.insufficientData =>
      'Wait for 10 testers before deciding what to build next.',
    BetaDecisionRuleOutcome.protectProof =>
      'Useful proof dropped below the safe floor. Soften anything that distracts from the proof moment before adding more conversion pressure.',
    BetaDecisionRuleOutcome.fixOpeningScreenOnly =>
      'First-session saving is still too low. Do not touch proof or Pro yet. Make the first action clearer and smaller.',
    BetaDecisionRuleOutcome.fixProPlacement =>
      'First-session saving improved, but Pro is still too hidden. Move the Pro moment closer to useful proof.',
    BetaDecisionRuleOutcome.fixProExplanation =>
      'People are seeing Pro, but not enough understand it. Explain the longer proof trail more clearly before changing placement again.',
    BetaDecisionRuleOutcome.continueMoreTesters =>
      'The main beta signals are healthy enough. Do not build more until the next tester group confirms the pattern.',
  };

  static String ctaFor(BetaDecisionRuleOutcome outcome) => switch (outcome) {
    BetaDecisionRuleOutcome.insufficientData => 'Keep collecting data',
    BetaDecisionRuleOutcome.protectProof => 'Review proof surfaces',
    BetaDecisionRuleOutcome.fixOpeningScreenOnly => 'Review first session',
    BetaDecisionRuleOutcome.fixProPlacement => 'Review Pro placement',
    BetaDecisionRuleOutcome.fixProExplanation => 'Review Pro explanation',
    BetaDecisionRuleOutcome.continueMoreTesters => 'Invite more testers',
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield cardTitle;
    yield inputsTitle;
    yield reasonTitle;
    yield localCountsNote;
    yield testerCountLabel;
    yield firstSessionSaveLabel;
    yield sawProLabel;
    yield understandsProLabel;
    yield usefulProofLabel;
    for (final outcome in BetaDecisionRuleOutcome.values) {
      yield titleFor(outcome);
      yield bodyFor(outcome);
      yield ctaFor(outcome);
    }
  }
}
