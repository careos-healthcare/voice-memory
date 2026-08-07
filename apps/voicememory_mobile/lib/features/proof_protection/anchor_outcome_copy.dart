import 'anchor_outcome_matrix.dart';

/// Beta-only anchor outcome copy — interpretation only, no product changes.
abstract final class AnchorOutcomeCopy {
  AnchorOutcomeCopy._();

  static const guardrail =
      'No Pro, pricing, or timeline changes until useful proof holds and '
      'vague/not relevant stays low.';

  static AnchorOutcomeReport report(
    AnchorOutcomeSummary summary,
    AnchorOutcomeDecision decision,
  ) => AnchorOutcomeReport(
    title: titleFor(decision),
    body: bodyFor(decision),
    nextAction: nextActionFor(decision),
    guardrail: guardrail,
  );

  static String titleFor(AnchorOutcomeDecision decision) => switch (decision) {
    AnchorOutcomeDecision.insufficientData => 'Not enough anchor data yet',
    AnchorOutcomeDecision.anchorsStillTooLoose => 'Anchors are still too loose',
    AnchorOutcomeDecision.anchorsTooStrict => 'Anchors may be too strict',
    AnchorOutcomeDecision.proofStableReturnToEvidenceTrail => 'Proof is stable',
    AnchorOutcomeDecision.productionCandidate => 'Proof and value signals pass',
  };

  static String bodyFor(AnchorOutcomeDecision decision) => switch (decision) {
    AnchorOutcomeDecision.insufficientData =>
      'Build 64 does not yet have enough testers to choose the next anchor move.',
    AnchorOutcomeDecision.anchorsStillTooLoose =>
      'Too many testers still mark proof as too vague or not relevant after '
          'tightening anchors.',
    AnchorOutcomeDecision.anchorsTooStrict =>
      'Useful proof is below the Build 64 target after tightening anchors.',
    AnchorOutcomeDecision.proofStableReturnToEvidenceTrail =>
      'Anchor quality is holding, but evidence-trail and value signals still '
          'need work.',
    AnchorOutcomeDecision.productionCandidate =>
      'Useful proof, anchor quality, specific proof recall, Pro understanding, '
          'and would-pay intent are all holding.',
  };

  static String nextActionFor(AnchorOutcomeDecision decision) =>
      switch (decision) {
        AnchorOutcomeDecision.insufficientData =>
          'Keep testing Build 64 until at least 20 testers complete the flow.',
        AnchorOutcomeDecision.anchorsStillTooLoose =>
          'Tighten anchors again. Reduce vague or unsupported proof.',
        AnchorOutcomeDecision.anchorsTooStrict =>
          'Repair proof usefulness without loosening vague anchors.',
        AnchorOutcomeDecision.proofStableReturnToEvidenceTrail =>
          'Return to evidence-trail clarity and Pro understanding test.',
        AnchorOutcomeDecision.productionCandidate =>
          'Stop product development and finish App Store readiness.',
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield guardrail;
    for (final decision in AnchorOutcomeDecision.values) {
      yield titleFor(decision);
      yield bodyFor(decision);
      yield nextActionFor(decision);
    }
  }
}

class AnchorOutcomeReport {
  const AnchorOutcomeReport({
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
