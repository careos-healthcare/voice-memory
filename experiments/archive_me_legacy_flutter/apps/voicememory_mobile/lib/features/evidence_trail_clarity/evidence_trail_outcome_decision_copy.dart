import 'evidence_trail_outcome_decision_matrix.dart';

/// Beta-only evidence trail outcome copy — interpretation only, no product changes.
abstract final class EvidenceTrailOutcomeDecisionCopy {
  EvidenceTrailOutcomeDecisionCopy._();

  static const guardrail =
      'Do not change pricing, paywall mechanics, or Pro features until proof and '
      'evidence-trail clarity stay stable.';

  static EvidenceTrailOutcomeDecisionReport report(
    EvidenceTrailOutcomeSummary summary,
    EvidenceTrailOutcomeDecision decision,
  ) => EvidenceTrailOutcomeDecisionReport(
    title: titleFor(decision),
    body: bodyFor(decision),
    nextAction: nextActionFor(decision),
    guardrail: guardrail,
  );

  static String titleFor(EvidenceTrailOutcomeDecision decision) =>
      switch (decision) {
        EvidenceTrailOutcomeDecision.insufficientData =>
          'Not enough signal yet',
        EvidenceTrailOutcomeDecision.protectProof => 'Protect proof first',
        EvidenceTrailOutcomeDecision.improveTimelineExplanation =>
          'Timeline is still unclear',
        EvidenceTrailOutcomeDecision.proTooHidden => 'Pro is still too hidden',
        EvidenceTrailOutcomeDecision.pricingValidation =>
          'Value is understood, price is not',
        EvidenceTrailOutcomeDecision.productionCandidate =>
          'Evidence trail is working',
      };

  static String bodyFor(
    EvidenceTrailOutcomeDecision decision,
  ) => switch (decision) {
    EvidenceTrailOutcomeDecision.insufficientData =>
      'Build 61 does not yet have enough testers to choose the next move.',
    EvidenceTrailOutcomeDecision.protectProof =>
      'Useful proof or negative feedback is still too weak to test Pro or pricing.',
    EvidenceTrailOutcomeDecision.improveTimelineExplanation =>
      'Testers are not saying the longer evidence trail is clear enough yet.',
    EvidenceTrailOutcomeDecision.proTooHidden =>
      'Enough proof exists, but too few testers are seeing the Pro evidence trail.',
    EvidenceTrailOutcomeDecision.pricingValidation =>
      'The evidence trail reads clearly, but would-pay intent is still weak.',
    EvidenceTrailOutcomeDecision.productionCandidate =>
      'Proof, timeline clarity, Pro visibility, and would-pay intent are all holding.',
  };

  static String nextActionFor(
    EvidenceTrailOutcomeDecision decision,
  ) => switch (decision) {
    EvidenceTrailOutcomeDecision.insufficientData =>
      'Keep testing Build 61 until at least 20 testers complete the flow.',
    EvidenceTrailOutcomeDecision.protectProof =>
      'Stop Pro testing and return to proof protection.',
    EvidenceTrailOutcomeDecision.improveTimelineExplanation =>
      'Improve the evidence trail wording and timeline explanation. Do not change price.',
    EvidenceTrailOutcomeDecision.proTooHidden =>
      'Move the Pro/evidence trail moment closer to strong proof. Do not change pricing.',
    EvidenceTrailOutcomeDecision.pricingValidation =>
      'Return to pricing validation. Do not add new product features.',
    EvidenceTrailOutcomeDecision.productionCandidate =>
      'Keep the evidence trail clarity path and prepare the production version.',
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield guardrail;
    for (final decision in EvidenceTrailOutcomeDecision.values) {
      yield titleFor(decision);
      yield bodyFor(decision);
      yield nextActionFor(decision);
    }
  }
}

class EvidenceTrailOutcomeDecisionReport {
  const EvidenceTrailOutcomeDecisionReport({
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
