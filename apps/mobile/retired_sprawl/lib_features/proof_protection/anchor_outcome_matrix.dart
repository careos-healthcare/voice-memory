/// Beta-only anchor outcome decision matrix — Build 64 interpretation only.
abstract final class AnchorOutcomeMatrix {
  AnchorOutcomeMatrix._();

  static const minimumTesterCount = 20;
  static const usefulProofAt30 = 7;
  static const usefulProofAt20 = 5;
  static const tooVagueHighAt30 = 6;
  static const tooVagueHighAt20 = 4;
  static const specificProofExampleRememberedNumerator = 5;
  static const specificProofExampleRememberedAt20 = 4;
  static const understandsProNumerator = 4;
  static const understandsProAt20 = 3;
  static const paywallCtaTapNumerator = 1;
  static const wouldPayNumerator = 3;
  static const wouldPayAt20 = 2;
  static const scaleDenominator = 30;

  static int usefulProofTargetFor(int totalTesters) {
    if (totalTesters == 20) return usefulProofAt20;
    if (totalTesters == 30) return usefulProofAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: usefulProofAt30,
      denominator: scaleDenominator,
    );
  }

  static int tooVagueHighTargetFor(int totalTesters) {
    if (totalTesters == 20) return tooVagueHighAt20;
    if (totalTesters == 30) return tooVagueHighAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: tooVagueHighAt30,
      denominator: scaleDenominator,
    );
  }

  static int specificProofExampleRememberedTargetFor(int totalTesters) {
    if (totalTesters == 20) return specificProofExampleRememberedAt20;
    if (totalTesters == 30) return specificProofExampleRememberedNumerator;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: specificProofExampleRememberedNumerator,
      denominator: scaleDenominator,
    );
  }

  static int understandsProTargetFor(int totalTesters) {
    if (totalTesters == 20) return understandsProAt20;
    if (totalTesters == 30) return understandsProNumerator;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: understandsProNumerator,
      denominator: scaleDenominator,
    );
  }

  static int paywallCtaTapTargetFor(int totalTesters) => _scaledTarget(
    totalTesters: totalTesters,
    numerator: paywallCtaTapNumerator,
    denominator: scaleDenominator,
  );

  static int wouldPayTargetFor(int totalTesters) {
    if (totalTesters == 20) return wouldPayAt20;
    if (totalTesters == 30) return wouldPayNumerator;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: wouldPayNumerator,
      denominator: scaleDenominator,
    );
  }

  static AnchorOutcomeDecision resolve(AnchorOutcomeSummary summary) {
    if (summary.totalTesters < minimumTesterCount) {
      return AnchorOutcomeDecision.insufficientData;
    }
    if (_tooVagueOrNotRelevantHigh(summary)) {
      return AnchorOutcomeDecision.anchorsStillTooLoose;
    }
    if (summary.usefulProofCount < usefulProofTargetFor(summary.totalTesters)) {
      return AnchorOutcomeDecision.anchorsTooStrict;
    }
    if (_allProductionTargetsPass(summary)) {
      return AnchorOutcomeDecision.productionCandidate;
    }
    if (_proofStable(summary)) {
      return AnchorOutcomeDecision.proofStableReturnToEvidenceTrail;
    }
    return AnchorOutcomeDecision.anchorsTooStrict;
  }

  static bool _tooVagueOrNotRelevantHigh(AnchorOutcomeSummary summary) =>
      summary.tooVagueOrNotRelevantCount >=
      tooVagueHighTargetFor(summary.totalTesters);

  static bool _proofStable(AnchorOutcomeSummary summary) {
    final total = summary.totalTesters;
    return summary.usefulProofCount >= usefulProofTargetFor(total) &&
        !_tooVagueOrNotRelevantHigh(summary);
  }

  static bool _allProductionTargetsPass(AnchorOutcomeSummary summary) {
    final total = summary.totalTesters;
    return _proofStable(summary) &&
        summary.specificProofExampleRememberedCount >=
            specificProofExampleRememberedTargetFor(total) &&
        summary.understandsProCount >= understandsProTargetFor(total) &&
        summary.paywallCtaTapCount >= paywallCtaTapTargetFor(total) &&
        summary.wouldPayYesMaybeCount >= wouldPayTargetFor(total);
  }

  static int _scaledTarget({
    required int totalTesters,
    required int numerator,
    required int denominator,
  }) => ((numerator * totalTesters) / denominator).ceil();
}

enum AnchorOutcomeDecision {
  insufficientData,
  anchorsStillTooLoose,
  anchorsTooStrict,
  proofStableReturnToEvidenceTrail,
  productionCandidate,
}

class AnchorOutcomeSummary {
  const AnchorOutcomeSummary({
    required this.totalTesters,
    required this.firstSessionSaveCount,
    required this.usefulProofCount,
    required this.tooVagueOrNotRelevantCount,
    required this.specificProofExampleRememberedCount,
    required this.sawProCount,
    required this.understandsProCount,
    required this.paywallCtaTapCount,
    required this.wouldPayYesMaybeCount,
  });

  final int totalTesters;
  final int firstSessionSaveCount;
  final int usefulProofCount;
  final int tooVagueOrNotRelevantCount;
  final int specificProofExampleRememberedCount;
  final int sawProCount;
  final int understandsProCount;
  final int paywallCtaTapCount;
  final int wouldPayYesMaybeCount;
}