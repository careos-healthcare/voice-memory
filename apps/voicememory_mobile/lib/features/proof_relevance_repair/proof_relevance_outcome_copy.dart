import 'proof_relevance_outcome_matrix.dart';

/// Beta-only proof relevance outcome copy — interpretation only, no product changes.
abstract final class ProofRelevanceOutcomeCopy {
  ProofRelevanceOutcomeCopy._();

  static const guardrail =
      'No Pro, pricing, or timeline changes until users understand what '
      'ArchiveMe noticed and can judge whether it is right.';

  static ProofRelevanceOutcomeReport report(
    ProofRelevanceOutcomeSummary summary,
    ProofRelevanceOutcomeDecision decision,
  ) =>
      ProofRelevanceOutcomeReport(
        title: titleFor(decision),
        body: bodyFor(decision),
        nextAction: nextActionFor(decision),
        guardrail: guardrail,
      );

  static String titleFor(ProofRelevanceOutcomeDecision decision) =>
      switch (decision) {
        ProofRelevanceOutcomeDecision.insufficientData =>
          'Not enough proof relevance data yet',
        ProofRelevanceOutcomeDecision.proofStillTooVague =>
          'Proof still feels too vague',
        ProofRelevanceOutcomeDecision.proofNotUnderstood =>
          'Proof is not understood clearly enough',
        ProofRelevanceOutcomeDecision.proofStableReturnToEvidenceTrail =>
          'Proof relevance is stable',
        ProofRelevanceOutcomeDecision.productionCandidate =>
          'Proof and value signals pass',
      };

  static String bodyFor(ProofRelevanceOutcomeDecision decision) =>
      switch (decision) {
        ProofRelevanceOutcomeDecision.insufficientData =>
          'The proof relevance build does not yet have enough testers to choose '
          'the next move.',
        ProofRelevanceOutcomeDecision.proofStillTooVague =>
          'Too many testers still mark proof as too vague or not relevant after '
          'the relevance copy repair.',
        ProofRelevanceOutcomeDecision.proofNotUnderstood =>
          'Testers still cannot clearly tell what ArchiveMe noticed or whether '
          'the proof feels right.',
        ProofRelevanceOutcomeDecision.proofStableReturnToEvidenceTrail =>
          'Proof relevance is holding, but evidence-trail and value signals '
          'still need work.',
        ProofRelevanceOutcomeDecision.productionCandidate =>
          'Useful proof, relevance understanding, specific proof recall, and '
          'would-pay intent are all holding.',
      };

  static String nextActionFor(ProofRelevanceOutcomeDecision decision) =>
      switch (decision) {
        ProofRelevanceOutcomeDecision.insufficientData =>
          'Keep testing the proof relevance build until at least 20 testers '
          'complete the flow.',
        ProofRelevanceOutcomeDecision.proofStillTooVague =>
          'Repair proof explanation or evidence display. Do not tighten anchors '
          'blindly.',
        ProofRelevanceOutcomeDecision.proofNotUnderstood =>
          'Make the proof explanation clearer before returning to Pro or pricing.',
        ProofRelevanceOutcomeDecision.proofStableReturnToEvidenceTrail =>
          'Return to evidence-trail clarity and Pro understanding test.',
        ProofRelevanceOutcomeDecision.productionCandidate =>
          'Stop product development and finish App Store readiness.',
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield guardrail;
    for (final decision in ProofRelevanceOutcomeDecision.values) {
      yield titleFor(decision);
      yield bodyFor(decision);
      yield nextActionFor(decision);
    }
  }
}

class ProofRelevanceOutcomeReport {
  const ProofRelevanceOutcomeReport({
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
