/// Beta-only evidence trail outcome decision matrix — Build 61 interpretation only.
abstract final class EvidenceTrailOutcomeDecisionMatrix {
  EvidenceTrailOutcomeDecisionMatrix._();

  static const minimumTesterCount = 20;
  static const usefulProofAt30 = 7;
  static const usefulProofAt20 = 5;
  static const evidenceTrailClearNumerator = 4;
  static const sawProNumerator = 4;
  static const understandsProNumerator = 4;
  static const paywallCtaTapNumerator = 1;
  static const wouldPayNumerator = 3;
  static const scaleDenominator = 30;
  static const tooVagueHighRatioNumerator = 1;
  static const tooVagueHighRatioDenominator = 5;

  static int usefulProofTargetFor(int totalTesters) {
    if (totalTesters == 20) return usefulProofAt20;
    if (totalTesters == 30) return usefulProofAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: usefulProofAt30,
      denominator: scaleDenominator,
    );
  }

  static int evidenceTrailClearTargetFor(int totalTesters) => _scaledTarget(
    totalTesters: totalTesters,
    numerator: evidenceTrailClearNumerator,
    denominator: scaleDenominator,
  );

  static int sawProTargetFor(int totalTesters) => _scaledTarget(
    totalTesters: totalTesters,
    numerator: sawProNumerator,
    denominator: scaleDenominator,
  );

  static int understandsProTargetFor(int totalTesters) => _scaledTarget(
    totalTesters: totalTesters,
    numerator: understandsProNumerator,
    denominator: scaleDenominator,
  );

  static int paywallCtaTapTargetFor(int totalTesters) => _scaledTarget(
    totalTesters: totalTesters,
    numerator: paywallCtaTapNumerator,
    denominator: scaleDenominator,
  );

  static int wouldPayTargetFor(int totalTesters) => _scaledTarget(
    totalTesters: totalTesters,
    numerator: wouldPayNumerator,
    denominator: scaleDenominator,
  );

  static EvidenceTrailOutcomeDecision resolve(
    EvidenceTrailOutcomeSummary summary,
  ) {
    if (summary.totalTesters < minimumTesterCount) {
      return EvidenceTrailOutcomeDecision.insufficientData;
    }
    if (summary.usefulProofCount < usefulProofTargetFor(summary.totalTesters)) {
      return EvidenceTrailOutcomeDecision.protectProof;
    }
    if (_tooVagueOrNotRelevantHigh(summary)) {
      return EvidenceTrailOutcomeDecision.protectProof;
    }
    if (_allProductionTargetsPass(summary)) {
      return EvidenceTrailOutcomeDecision.productionCandidate;
    }
    if (summary.evidenceTrailClearCount <
        evidenceTrailClearTargetFor(summary.totalTesters)) {
      return EvidenceTrailOutcomeDecision.improveTimelineExplanation;
    }
    if (summary.sawProCount < sawProTargetFor(summary.totalTesters)) {
      return EvidenceTrailOutcomeDecision.proTooHidden;
    }
    if (summary.evidenceTrailClearCount >=
            evidenceTrailClearTargetFor(summary.totalTesters) &&
        summary.wouldPayYesMaybeCount <
            wouldPayTargetFor(summary.totalTesters)) {
      return EvidenceTrailOutcomeDecision.pricingValidation;
    }
    return EvidenceTrailOutcomeDecision.improveTimelineExplanation;
  }

  static bool _tooVagueOrNotRelevantHigh(EvidenceTrailOutcomeSummary summary) =>
      summary.tooVagueOrNotRelevantCount * tooVagueHighRatioDenominator >
      summary.totalTesters * tooVagueHighRatioNumerator;

  static bool _allProductionTargetsPass(EvidenceTrailOutcomeSummary summary) {
    final total = summary.totalTesters;
    return summary.usefulProofCount >= usefulProofTargetFor(total) &&
        !_tooVagueOrNotRelevantHigh(summary) &&
        summary.sawProCount >= sawProTargetFor(total) &&
        summary.understandsProCount >= understandsProTargetFor(total) &&
        summary.paywallCtaTapCount >= paywallCtaTapTargetFor(total) &&
        summary.wouldPayYesMaybeCount >= wouldPayTargetFor(total) &&
        summary.evidenceTrailClearCount >= evidenceTrailClearTargetFor(total);
  }

  static int _scaledTarget({
    required int totalTesters,
    required int numerator,
    required int denominator,
  }) => ((numerator * totalTesters) / denominator).ceil();
}

enum EvidenceTrailOutcomeDecision {
  insufficientData,
  protectProof,
  improveTimelineExplanation,
  proTooHidden,
  pricingValidation,
  productionCandidate,
}

class EvidenceTrailOutcomeSummary {
  const EvidenceTrailOutcomeSummary({
    required this.totalTesters,
    required this.usefulProofCount,
    required this.tooVagueOrNotRelevantCount,
    required this.sawProCount,
    required this.understandsProCount,
    required this.paywallCtaTapCount,
    required this.wouldPayYesMaybeCount,
    required this.evidenceTrailClearCount,
  });

  final int totalTesters;
  final int usefulProofCount;
  final int tooVagueOrNotRelevantCount;
  final int sawProCount;
  final int understandsProCount;
  final int paywallCtaTapCount;
  final int wouldPayYesMaybeCount;
  final int evidenceTrailClearCount;
}