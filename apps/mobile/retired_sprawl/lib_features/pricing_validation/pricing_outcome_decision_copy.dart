import 'package:archiveme_mobile/features/pricing_validation/pricing_outcome_decision_matrix.dart';

/// Beta-only pricing outcome copy — interprets validation feedback, no purchase changes.
abstract final class PricingOutcomeDecisionCopy {
  PricingOutcomeDecisionCopy._();

  static const guardrail =
      'Do not change RevenueCat, product IDs, purchase flow, restore flow, '
      'or entitlements from this decision matrix.';

  static PricingOutcomeDecisionReport report(
    PricingValidationSummary summary,
    PricingOutcomeDecision decision,
  ) => PricingOutcomeDecisionReport(
    title: titleFor(decision),
    body: bodyFor(decision),
    nextAction: nextActionFor(decision),
    guardrail: guardrail,
  );

  static String titleFor(PricingOutcomeDecision decision) => switch (decision) {
    PricingOutcomeDecision.insufficientData => 'Do not change pricing yet',
    PricingOutcomeDecision.subscriptionRisk => 'Subscription risk',
    PricingOutcomeDecision.evidenceTrailFocus => 'Evidence trail is the value',
    PricingOutcomeDecision.timelineClarity => 'Clarify the timeline',
    PricingOutcomeDecision.lowerPriceTest => 'Test lower entry pricing',
    PricingOutcomeDecision.pricingSignalStrong =>
      'Pricing signal is strong enough',
  };

  static String bodyFor(PricingOutcomeDecision decision) => switch (decision) {
    PricingOutcomeDecision.insufficientData =>
      'There is not enough clean pricing data. Keep Build 60 running before '
          'changing price or product.',
    PricingOutcomeDecision.subscriptionRisk =>
      'If most people say they would not pay monthly, the issue may be the '
          'subscription model or the urgency of Pro value. Do not lower price blindly.',
    PricingOutcomeDecision.evidenceTrailFocus =>
      'If more proof over time wins, keep the product focused on the longer '
          'evidence trail. Do not add generic journaling features.',
    PricingOutcomeDecision.timelineClarity =>
      'If clearer timeline wins, improve how the longer evidence trail is '
          'shown before changing price.',
    PricingOutcomeDecision.lowerPriceTest =>
      'If lower price or £2.99 wins, run a clean lower-price test next. '
          'Do not mix it with new product changes.',
    PricingOutcomeDecision.pricingSignalStrong =>
      'If £4.99/£7.99 interest and would-pay intent are strong, keep premium '
          'positioning and widen the beta.',
  };

  static String nextActionFor(PricingOutcomeDecision decision) =>
      switch (decision) {
        PricingOutcomeDecision.insufficientData => 'Keep testing Build 60.',
        PricingOutcomeDecision.subscriptionRisk =>
          'Test subscription objection before changing price.',
        PricingOutcomeDecision.evidenceTrailFocus =>
          'Keep Pro centered on the longer evidence trail.',
        PricingOutcomeDecision.timelineClarity =>
          'Improve timeline clarity next.',
        PricingOutcomeDecision.lowerPriceTest => 'Run a lower-price test next.',
        PricingOutcomeDecision.pricingSignalStrong =>
          'Widen beta and keep pricing position.',
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield guardrail;
    for (final decision in PricingOutcomeDecision.values) {
      yield titleFor(decision);
      yield bodyFor(decision);
      yield nextActionFor(decision);
    }
  }
}

class PricingOutcomeDecisionReport {
  const PricingOutcomeDecisionReport({
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