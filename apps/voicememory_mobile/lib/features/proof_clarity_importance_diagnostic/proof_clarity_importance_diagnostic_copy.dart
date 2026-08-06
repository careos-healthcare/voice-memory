import 'proof_clarity_importance_diagnostic.dart';

/// Beta-only proof clarity + importance diagnostic copy — interpretation only.
abstract final class ProofClarityImportanceDiagnosticCopy {
  ProofClarityImportanceDiagnosticCopy._();

  static const guardrail =
      'Do not build ranked lists or tighten anchors until the diagnostic '
      'separates clarity demand from importance demand.';

  static const facilitatorQuestionExplanationClear =
      'Was this proof explanation clear enough to judge?';

  static const facilitatorQuestionWantsRanking =
      'Did you want ArchiveMe to rank or prioritize multiple past ideas?';

  static ProofClarityImportanceReport report(
    ProofClarityImportanceSummary summary,
    ProofClarityImportanceDecision decision,
  ) => ProofClarityImportanceReport(
    title: titleFor(decision),
    body: bodyFor(decision),
    nextAction: nextActionFor(decision),
    guardrail: guardrail,
  );

  static String titleFor(ProofClarityImportanceDecision decision) =>
      switch (decision) {
        ProofClarityImportanceDecision.insufficientData =>
          'Not enough clarity vs importance data yet',
        ProofClarityImportanceDecision.repairProofExplanation =>
          'Proof explanation still needs repair',
        ProofClarityImportanceDecision.bothProblemsRepairExplanationFirst =>
          'Clarity and ranking both flagged — fix explanation first',
        ProofClarityImportanceDecision.investigateRankingImportance =>
          'Ranking demand is the stronger signal',
        ProofClarityImportanceDecision.proofExplanationStable =>
          'Proof explanation is stable',
      };

  static String bodyFor(ProofClarityImportanceDecision decision) =>
      switch (decision) {
        ProofClarityImportanceDecision.insufficientData =>
          'Build 69 does not yet have enough testers to tell whether users '
              'want clearer proof explanation or ranking across ideas.',
        ProofClarityImportanceDecision.repairProofExplanation =>
          'Too many testers still find proof vague or cannot judge the '
              'explanation clearly enough.',
        ProofClarityImportanceDecision.bothProblemsRepairExplanationFirst =>
          'Testers report vague proof and want ranking, but explanation must '
              'be clearer before any importance ranking work.',
        ProofClarityImportanceDecision.investigateRankingImportance =>
          'Explanation is clear enough, but testers still want ranking or '
              'importance across multiple ideas. Diagnose only — do not build '
              'ranked lists yet.',
        ProofClarityImportanceDecision.proofExplanationStable =>
          'Useful proof, low vague/not relevant, clear explanation, and low '
              'ranking demand are all holding.',
      };

  static String nextActionFor(ProofClarityImportanceDecision decision) =>
      switch (decision) {
        ProofClarityImportanceDecision.insufficientData =>
          'Keep testing Build 69 until at least 20 testers complete proof '
              'detail and facilitator questions.',
        ProofClarityImportanceDecision.repairProofExplanation =>
          'Repair proof explanation copy only. Do not tighten anchors or add '
              'more proof.',
        ProofClarityImportanceDecision.bothProblemsRepairExplanationFirst =>
          'Repair proof explanation before investigating ranking or '
              'importance features.',
        ProofClarityImportanceDecision.investigateRankingImportance =>
          'Run follow-up interviews on ranking demand. Do not build ranked '
              'lists or change anchors yet.',
        ProofClarityImportanceDecision.proofExplanationStable =>
          'Return to evidence-trail clarity and value signals. Do not add '
              'ranking yet.',
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield guardrail;
    yield facilitatorQuestionExplanationClear;
    yield facilitatorQuestionWantsRanking;
    for (final decision in ProofClarityImportanceDecision.values) {
      yield titleFor(decision);
      yield bodyFor(decision);
      yield nextActionFor(decision);
    }
  }
}

class ProofClarityImportanceReport {
  const ProofClarityImportanceReport({
    required this.title,
    required this.body,
    required this.nextAction,
    required this.guardrail,
  });

  final String title;
  final String body;
  final String nextAction;
  final String guardrail;
}
