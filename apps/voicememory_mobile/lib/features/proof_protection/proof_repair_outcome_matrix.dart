/// Beta-only proof repair outcome decision matrix — Build 63 interpretation only.
abstract final class ProofRepairOutcomeMatrix {
  ProofRepairOutcomeMatrix._();

  static const minimumTesterCount = 20;
  static const usefulProofAt30 = 7;
  static const usefulProofAt20 = 5;
  static const tooVagueHighAt30 = 6;
  static const tooVagueHighAt20 = 4;
  static const evidenceTrailClearNumerator = 4;
  static const understandsProNumerator = 4;
  static const paywallCtaTapNumerator = 1;
  static const wouldPayNumerator = 3;
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

  static int evidenceTrailClearTargetFor(int totalTesters) =>
      _scaledTarget(
        totalTesters: totalTesters,
        numerator: evidenceTrailClearNumerator,
        denominator: scaleDenominator,
      );

  static int understandsProTargetFor(int totalTesters) =>
      _scaledTarget(
        totalTesters: totalTesters,
        numerator: understandsProNumerator,
        denominator: scaleDenominator,
      );

  static int paywallCtaTapTargetFor(int totalTesters) =>
      _scaledTarget(
        totalTesters: totalTesters,
        numerator: paywallCtaTapNumerator,
        denominator: scaleDenominator,
      );

  static int wouldPayTargetFor(int totalTesters) =>
      _scaledTarget(
        totalTesters: totalTesters,
        numerator: wouldPayNumerator,
        denominator: scaleDenominator,
      );

  static ProofRepairOutcomeDecision resolve(ProofRepairOutcomeSummary summary) {
    if (summary.totalTesters < minimumTesterCount) {
      return ProofRepairOutcomeDecision.insufficientData;
    }
    if (summary.usefulProofCount < usefulProofTargetFor(summary.totalTesters)) {
      return ProofRepairOutcomeDecision.repairProofAgain;
    }
    if (_tooVagueOrNotRelevantHigh(summary)) {
      return ProofRepairOutcomeDecision.tightenAnchorsAgain;
    }
    if (_allProductionTargetsPass(summary)) {
      return ProofRepairOutcomeDecision.productionCandidate;
    }
    if (_proofStable(summary)) {
      return ProofRepairOutcomeDecision.proofStableReturnToEvidenceTrail;
    }
    return ProofRepairOutcomeDecision.repairProofAgain;
  }

  static bool _tooVagueOrNotRelevantHigh(ProofRepairOutcomeSummary summary) =>
      summary.tooVagueOrNotRelevantCount >=
      tooVagueHighTargetFor(summary.totalTesters);

  static bool _proofStable(ProofRepairOutcomeSummary summary) {
    final total = summary.totalTesters;
    return summary.usefulProofCount >= usefulProofTargetFor(total) &&
        !_tooVagueOrNotRelevantHigh(summary);
  }

  static bool _allProductionTargetsPass(ProofRepairOutcomeSummary summary) {
    final total = summary.totalTesters;
    return _proofStable(summary) &&
        summary.evidenceTrailClearCount >= evidenceTrailClearTargetFor(total) &&
        summary.understandsProCount >= understandsProTargetFor(total) &&
        summary.paywallCtaTapCount >= paywallCtaTapTargetFor(total) &&
        summary.wouldPayYesMaybeCount >= wouldPayTargetFor(total);
  }

  static int _scaledTarget({
    required int totalTesters,
    required int numerator,
    required int denominator,
  }) =>
      ((numerator * totalTesters) / denominator).ceil();
}

enum ProofRepairOutcomeDecision {
  insufficientData,
  repairProofAgain,
  tightenAnchorsAgain,
  proofStableReturnToEvidenceTrail,
  productionCandidate,
}

class ProofRepairOutcomeSummary {
  const ProofRepairOutcomeSummary({
    required this.totalTesters,
    required this.firstSessionSaveCount,
    required this.usefulProofCount,
    required this.tooVagueOrNotRelevantCount,
    required this.sawProCount,
    required this.understandsProCount,
    required this.evidenceTrailClearCount,
    required this.paywallCtaTapCount,
    required this.wouldPayYesMaybeCount,
  });

  final int totalTesters;
  final int firstSessionSaveCount;
  final int usefulProofCount;
  final int tooVagueOrNotRelevantCount;
  final int sawProCount;
  final int understandsProCount;
  final int evidenceTrailClearCount;
  final int paywallCtaTapCount;
  final int wouldPayYesMaybeCount;
}
