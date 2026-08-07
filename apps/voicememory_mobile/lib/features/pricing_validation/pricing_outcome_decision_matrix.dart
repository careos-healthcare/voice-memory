/// Beta-only pricing outcome decision matrix — recommends next action from Build 60 feedback.
abstract final class PricingOutcomeDecisionMatrix {
  PricingOutcomeDecisionMatrix._();

  static const minimumTesterCount = 20;
  static const usefulProofNumerator = 7;
  static const usefulProofDenominator = 30;
  static const wouldPayNumerator = 4;
  static const wouldPayDenominator = 30;

  static const tiePriority = [
    PricingOutcomeDecision.subscriptionRisk,
    PricingOutcomeDecision.timelineClarity,
    PricingOutcomeDecision.lowerPriceTest,
    PricingOutcomeDecision.evidenceTrailFocus,
    PricingOutcomeDecision.pricingSignalStrong,
    PricingOutcomeDecision.insufficientData,
  ];

  static int usefulProofTargetFor(int totalTesters) => _scaledTarget(
    totalTesters: totalTesters,
    numerator: usefulProofNumerator,
    denominator: usefulProofDenominator,
  );

  static int wouldPayTargetFor(int totalTesters) => _scaledTarget(
    totalTesters: totalTesters,
    numerator: wouldPayNumerator,
    denominator: wouldPayDenominator,
  );

  static PricingOutcomeDecision resolve(PricingValidationSummary summary) {
    if (summary.totalTesters < minimumTesterCount) {
      return PricingOutcomeDecision.insufficientData;
    }
    if (summary.usefulProofCount < usefulProofTargetFor(summary.totalTesters)) {
      return PricingOutcomeDecision.insufficientData;
    }

    final candidates = <PricingOutcomeDecision>{};

    if (_isLargest(summary.wouldNotPayMonthlyCount, [
      summary.price299Count,
      summary.price499Count,
      summary.price799Count,
      summary.wouldNotPayMonthlyCount,
    ])) {
      candidates.add(PricingOutcomeDecision.subscriptionRisk);
    }

    if (_isLargest(summary.moreProofOverTimeCount, _reasonCounts(summary))) {
      candidates.add(PricingOutcomeDecision.evidenceTrailFocus);
    }

    if (_isLargest(summary.clearerTimelineCount, _reasonCounts(summary))) {
      candidates.add(PricingOutcomeDecision.timelineClarity);
    }

    if (_isLargest(summary.lowerPriceCount, _reasonCounts(summary)) ||
        _isLargest(summary.price299Count, [
          summary.price299Count,
          summary.price499Count,
          summary.price799Count,
        ])) {
      candidates.add(PricingOutcomeDecision.lowerPriceTest);
    }

    final premiumPriceInterest = summary.price499Count + summary.price799Count;
    if (premiumPriceInterest > summary.price299Count &&
        premiumPriceInterest > summary.wouldNotPayMonthlyCount &&
        summary.wouldPayYesMaybeCount >=
            wouldPayTargetFor(summary.totalTesters)) {
      candidates.add(PricingOutcomeDecision.pricingSignalStrong);
    }

    if (candidates.isEmpty) {
      return PricingOutcomeDecision.insufficientData;
    }

    for (final decision in tiePriority) {
      if (candidates.contains(decision)) {
        return decision;
      }
    }

    return PricingOutcomeDecision.insufficientData;
  }

  static int _scaledTarget({
    required int totalTesters,
    required int numerator,
    required int denominator,
  }) => ((numerator * totalTesters) / denominator).ceil();

  static List<int> _reasonCounts(PricingValidationSummary summary) => [
    summary.moreProofOverTimeCount,
    summary.betterCorrectionsCount,
    summary.clearerTimelineCount,
    summary.lowerPriceCount,
  ];

  static bool _isLargest(int value, List<int> counts) {
    if (counts.every((count) => count == 0)) return false;
    final max = counts.reduce((a, b) => a > b ? a : b);
    return value == max && value > 0;
  }
}

enum PricingOutcomeDecision {
  insufficientData,
  subscriptionRisk,
  evidenceTrailFocus,
  timelineClarity,
  lowerPriceTest,
  pricingSignalStrong,
}

class PricingValidationSummary {
  const PricingValidationSummary({
    required this.totalTesters,
    required this.usefulProofCount,
    required this.sawProCount,
    required this.understandsProCount,
    required this.paywallCtaTapCount,
    required this.wouldPayYesMaybeCount,
    required this.price299Count,
    required this.price499Count,
    required this.price799Count,
    required this.wouldNotPayMonthlyCount,
    required this.moreProofOverTimeCount,
    required this.betterCorrectionsCount,
    required this.clearerTimelineCount,
    required this.lowerPriceCount,
  });

  final int totalTesters;
  final int usefulProofCount;
  final int sawProCount;
  final int understandsProCount;
  final int paywallCtaTapCount;
  final int wouldPayYesMaybeCount;
  final int price299Count;
  final int price499Count;
  final int price799Count;
  final int wouldNotPayMonthlyCount;
  final int moreProofOverTimeCount;
  final int betterCorrectionsCount;
  final int clearerTimelineCount;
  final int lowerPriceCount;
}
