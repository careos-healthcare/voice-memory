import 'beta_results_summary.dart';

/// Beta results reader copy — one combined recommendation, no product changes.
abstract final class BetaResultsReaderCopy {
  BetaResultsReaderCopy._();

  static const guardrail =
      'No new features until proof, clarity, and pricing signals are stable.';

  static BetaResultsReaderReport report(
    BetaResultsSummary summary,
    BetaResultsDecision decision,
  ) => BetaResultsReaderReport(
    title: titleFor(decision),
    body: bodyFor(decision),
    nextAction: nextActionFor(decision),
    guardrail: guardrail,
  );

  static String titleFor(BetaResultsDecision decision) => switch (decision) {
    BetaResultsDecision.insufficientData => 'Not enough beta signal yet',
    BetaResultsDecision.protectProof => 'Protect proof first',
    BetaResultsDecision.improveFirstSession => 'First session still weak',
    BetaResultsDecision.improveTimelineExplanation =>
      'Timeline is still unclear',
    BetaResultsDecision.proTooHidden => 'Pro is still too hidden',
    BetaResultsDecision.improveProExplanation => 'Pro value still unclear',
    BetaResultsDecision.pricingValidation =>
      'Value is understood, price is not',
    BetaResultsDecision.evidenceTrailFocus => 'Evidence trail is the product',
    BetaResultsDecision.productionCandidate => 'Beta loop is working',
  };

  static String bodyFor(BetaResultsDecision decision) => switch (decision) {
    BetaResultsDecision.insufficientData =>
      'There are not enough testers yet to read the combined beta results.',
    BetaResultsDecision.protectProof =>
      'Useful proof or negative feedback is still too weak for Pro or pricing work.',
    BetaResultsDecision.improveFirstSession =>
      'Proof is holding, but first-session saves are still below target.',
    BetaResultsDecision.improveTimelineExplanation =>
      'Testers are not saying the longer evidence trail is clear enough yet.',
    BetaResultsDecision.proTooHidden =>
      'Strong proof exists, but too few testers are seeing the Pro evidence trail.',
    BetaResultsDecision.improveProExplanation =>
      'Saw Pro is improving, but Understands Pro is still below target.',
    BetaResultsDecision.pricingValidation =>
      'Timeline clarity is good enough, but would-pay intent is still weak.',
    BetaResultsDecision.evidenceTrailFocus =>
      'Pricing feedback says the longer evidence trail is the core value to keep building.',
    BetaResultsDecision.productionCandidate =>
      'Proof, first session, timeline clarity, Pro visibility, and would-pay are all holding.',
  };

  static String nextActionFor(BetaResultsDecision decision) =>
      switch (decision) {
        BetaResultsDecision.insufficientData =>
          'Keep testing until at least 20 testers complete the flow.',
        BetaResultsDecision.protectProof =>
          'Stop Pro testing. Return to proof protection.',
        BetaResultsDecision.improveFirstSession =>
          'Keep proof stable and improve the first recording prompt.',
        BetaResultsDecision.improveTimelineExplanation =>
          'Improve evidence trail/timeline wording. Do not change price.',
        BetaResultsDecision.proTooHidden =>
          'Move the Pro moment closer to strong proof. Do not change price.',
        BetaResultsDecision.improveProExplanation =>
          'Clarify that Pro keeps the longer evidence trail.',
        BetaResultsDecision.pricingValidation =>
          'Run pricing validation. Do not add product features.',
        BetaResultsDecision.evidenceTrailFocus =>
          'Keep product focused on the evidence trail.',
        BetaResultsDecision.productionCandidate =>
          'Freeze product scope and prepare the production candidate.',
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield guardrail;
    for (final decision in BetaResultsDecision.values) {
      yield titleFor(decision);
      yield bodyFor(decision);
      yield nextActionFor(decision);
    }
  }
}

class BetaResultsReaderReport {
  const BetaResultsReaderReport({
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
