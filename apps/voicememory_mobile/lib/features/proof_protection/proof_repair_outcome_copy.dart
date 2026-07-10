import 'proof_repair_outcome_matrix.dart';

/// Beta-only proof repair outcome copy — interpretation only, no product changes.
abstract final class ProofRepairOutcomeCopy {
  ProofRepairOutcomeCopy._();

  static const guardrail =
      'No Pro, pricing, or timeline changes until useful proof passes and '
      'vague/not relevant stays low.';

  static ProofRepairOutcomeReport report(
    ProofRepairOutcomeSummary summary,
    ProofRepairOutcomeDecision decision,
  ) =>
      ProofRepairOutcomeReport(
        title: titleFor(decision),
        body: bodyFor(decision),
        nextAction: nextActionFor(decision),
        guardrail: guardrail,
      );

  static String titleFor(ProofRepairOutcomeDecision decision) =>
      switch (decision) {
        ProofRepairOutcomeDecision.insufficientData =>
          'Not enough proof data yet',
        ProofRepairOutcomeDecision.repairProofAgain =>
          'Proof is still the blocker',
        ProofRepairOutcomeDecision.tightenAnchorsAgain =>
          'Proof is still too loose',
        ProofRepairOutcomeDecision.proofStableReturnToEvidenceTrail =>
          'Proof is stable',
        ProofRepairOutcomeDecision.productionCandidate =>
          'Proof and value signals pass',
      };

  static String bodyFor(ProofRepairOutcomeDecision decision) =>
      switch (decision) {
        ProofRepairOutcomeDecision.insufficientData =>
          'Build 63 does not yet have enough testers to choose the next proof move.',
        ProofRepairOutcomeDecision.repairProofAgain =>
          'Useful proof is still below the Build 63 target.',
        ProofRepairOutcomeDecision.tightenAnchorsAgain =>
          'Too many testers still mark proof as too vague or not relevant.',
        ProofRepairOutcomeDecision.proofStableReturnToEvidenceTrail =>
          'Proof quality is holding, but evidence-trail and value signals still need work.',
        ProofRepairOutcomeDecision.productionCandidate =>
          'Useful proof, anchor quality, evidence trail, Pro understanding, and '
          'would-pay intent are all holding.',
      };

  static String nextActionFor(ProofRepairOutcomeDecision decision) =>
      switch (decision) {
        ProofRepairOutcomeDecision.insufficientData =>
          'Keep testing Build 63 until at least 20 testers complete the flow.',
        ProofRepairOutcomeDecision.repairProofAgain =>
          'Repair proof again. Do not work on Pro, pricing, or timeline.',
        ProofRepairOutcomeDecision.tightenAnchorsAgain =>
          'Tighten anchors again. Reduce vague or unsupported proof.',
        ProofRepairOutcomeDecision.proofStableReturnToEvidenceTrail =>
          'Return to evidence-trail clarity and Pro understanding test.',
        ProofRepairOutcomeDecision.productionCandidate =>
          'Stop product development and finish App Store readiness.',
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield guardrail;
    for (final decision in ProofRepairOutcomeDecision.values) {
      yield titleFor(decision);
      yield bodyFor(decision);
      yield nextActionFor(decision);
    }
  }
}

class ProofRepairOutcomeReport {
  const ProofRepairOutcomeReport({
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
