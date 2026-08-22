import 'package:archiveme_mobile/features/beta_decision_rules/beta_decision_rule_copy.dart';

enum BetaDecisionRuleOutcome {
  fixOpeningScreenOnly,
  fixProPlacement,
  fixProExplanation,
  protectProof,
  continueMoreTesters,
  insufficientData,
}

class BetaDecisionRuleInput {
  const BetaDecisionRuleInput({
    required this.testerCount,
    required this.firstSessionSaveCount,
    required this.sawProCount,
    required this.understandsProYesMaybeCount,
    required this.usefulProofCount,
  });

  final int testerCount;
  final int firstSessionSaveCount;
  final int sawProCount;
  final int understandsProYesMaybeCount;
  final int usefulProofCount;
}

class BetaDecisionRuleResult {
  const BetaDecisionRuleResult({
    required this.outcome,
    required this.title,
    required this.body,
    required this.cta,
    required this.reason,
    required this.input,
  });

  final BetaDecisionRuleOutcome outcome;
  final String title;
  final String body;
  final String cta;
  final String reason;
  final BetaDecisionRuleInput input;

  String get outcomeLabel => BetaDecisionRuleCopy.titleFor(outcome);

  List<String> get inputLines => [
    '${BetaDecisionRuleCopy.testerCountLabel}: ${input.testerCount}/10',
    '${BetaDecisionRuleCopy.firstSessionSaveLabel}: '
        '${input.firstSessionSaveCount}/10',
    '${BetaDecisionRuleCopy.sawProLabel}: ${input.sawProCount}/10',
    '${BetaDecisionRuleCopy.understandsProLabel}: '
        '${input.understandsProYesMaybeCount}/10',
    '${BetaDecisionRuleCopy.usefulProofLabel}: '
        '${input.usefulProofCount}/10',
  ];
}