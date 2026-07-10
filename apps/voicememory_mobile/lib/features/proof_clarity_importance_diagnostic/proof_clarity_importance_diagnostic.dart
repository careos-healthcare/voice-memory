/// Beta-only proof clarity + importance diagnostic — interpretation only.
abstract final class ProofClarityImportanceDiagnostic {
  ProofClarityImportanceDiagnostic._();

  static const minimumTesterCount = 20;
  static const usefulProofAt30 = 7;
  static const usefulProofAt20 = 5;
  static const tooVagueHighAt30 = 6;
  static const tooVagueHighAt20 = 4;
  static const proofExplanationClearAt30 = 6;
  static const proofExplanationClearAt20 = 4;
  static const wantsRankingImportanceAt30 = 6;
  static const wantsRankingImportanceAt20 = 4;
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

  static int proofExplanationClearTargetFor(int totalTesters) {
    if (totalTesters == 20) return proofExplanationClearAt20;
    if (totalTesters == 30) return proofExplanationClearAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: proofExplanationClearAt30,
      denominator: scaleDenominator,
    );
  }

  static int wantsRankingImportanceTargetFor(int totalTesters) {
    if (totalTesters == 20) return wantsRankingImportanceAt20;
    if (totalTesters == 30) return wantsRankingImportanceAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: wantsRankingImportanceAt30,
      denominator: scaleDenominator,
    );
  }

  static ProofClarityImportanceDecision resolve(
    ProofClarityImportanceSummary summary,
  ) {
    if (summary.totalTesters < minimumTesterCount) {
      return ProofClarityImportanceDecision.insufficientData;
    }
    if (_bothProblems(summary)) {
      return ProofClarityImportanceDecision.bothProblemsRepairExplanationFirst;
    }
    if (_tooVagueOrNotRelevantHigh(summary) ||
        _proofExplanationTooLow(summary)) {
      return ProofClarityImportanceDecision.repairProofExplanation;
    }
    if (_wantsRankingImportanceHigh(summary)) {
      return ProofClarityImportanceDecision.investigateRankingImportance;
    }
    if (_proofExplanationStable(summary)) {
      return ProofClarityImportanceDecision.proofExplanationStable;
    }
    return ProofClarityImportanceDecision.repairProofExplanation;
  }

  static bool _tooVagueOrNotRelevantHigh(ProofClarityImportanceSummary summary) =>
      summary.tooVagueOrNotRelevantCount >=
      tooVagueHighTargetFor(summary.totalTesters);

  static bool _proofExplanationTooLow(ProofClarityImportanceSummary summary) =>
      summary.proofExplanationClearCount <
      proofExplanationClearTargetFor(summary.totalTesters);

  static bool _wantsRankingImportanceHigh(ProofClarityImportanceSummary summary) =>
      summary.wantsRankingImportanceCount >=
      wantsRankingImportanceTargetFor(summary.totalTesters);

  static bool _bothProblems(ProofClarityImportanceSummary summary) =>
      _tooVagueOrNotRelevantHigh(summary) &&
      _wantsRankingImportanceHigh(summary);

  static bool _proofExplanationStable(ProofClarityImportanceSummary summary) {
    final total = summary.totalTesters;
    return summary.usefulProofCount >= usefulProofTargetFor(total) &&
        !_tooVagueOrNotRelevantHigh(summary) &&
        summary.proofExplanationClearCount >=
            proofExplanationClearTargetFor(total) &&
        !_wantsRankingImportanceHigh(summary);
  }

  static int _scaledTarget({
    required int totalTesters,
    required int numerator,
    required int denominator,
  }) =>
      ((numerator * totalTesters) / denominator).ceil();
}

enum ProofClarityImportanceDecision {
  insufficientData,
  repairProofExplanation,
  bothProblemsRepairExplanationFirst,
  investigateRankingImportance,
  proofExplanationStable,
}

class ProofClarityImportanceSummary {
  const ProofClarityImportanceSummary({
    required this.totalTesters,
    required this.usefulProofCount,
    required this.tooVagueOrNotRelevantCount,
    required this.proofExplanationClearCount,
    required this.wantsRankingImportanceCount,
  });

  final int totalTesters;
  final int usefulProofCount;
  final int tooVagueOrNotRelevantCount;
  final int proofExplanationClearCount;
  final int wantsRankingImportanceCount;
}
