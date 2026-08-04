/// Beta-only proof relevance outcome decision matrix — interpretation only.
abstract final class ProofRelevanceOutcomeMatrix {
  ProofRelevanceOutcomeMatrix._();

  static const minimumTesterCount = 20;
  static const usefulProofAt30 = 7;
  static const usefulProofAt20 = 5;
  static const tooVagueHighAt30 = 6;
  static const tooVagueHighAt20 = 4;
  static const understoodWhatItNoticedAt30 = 6;
  static const understoodWhatItNoticedAt20 = 4;
  static const couldTellIfRightAt30 = 6;
  static const couldTellIfRightAt20 = 4;
  static const didNotFeelLikeVagueAiAt30 = 6;
  static const didNotFeelLikeVagueAiAt20 = 4;
  static const specificProofExampleRememberedAt30 = 5;
  static const specificProofExampleRememberedAt20 = 4;
  static const wouldPayAt30 = 3;
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

  static int understoodWhatItNoticedTargetFor(int totalTesters) {
    if (totalTesters == 20) return understoodWhatItNoticedAt20;
    if (totalTesters == 30) return understoodWhatItNoticedAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: understoodWhatItNoticedAt30,
      denominator: scaleDenominator,
    );
  }

  static int couldTellIfRightTargetFor(int totalTesters) {
    if (totalTesters == 20) return couldTellIfRightAt20;
    if (totalTesters == 30) return couldTellIfRightAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: couldTellIfRightAt30,
      denominator: scaleDenominator,
    );
  }

  static int didNotFeelLikeVagueAiTargetFor(int totalTesters) {
    if (totalTesters == 20) return didNotFeelLikeVagueAiAt20;
    if (totalTesters == 30) return didNotFeelLikeVagueAiAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: didNotFeelLikeVagueAiAt30,
      denominator: scaleDenominator,
    );
  }

  static int specificProofExampleRememberedTargetFor(int totalTesters) {
    if (totalTesters == 20) return specificProofExampleRememberedAt20;
    if (totalTesters == 30) return specificProofExampleRememberedAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: specificProofExampleRememberedAt30,
      denominator: scaleDenominator,
    );
  }

  static int wouldPayTargetFor(int totalTesters) {
    if (totalTesters == 20) return wouldPayAt20;
    if (totalTesters == 30) return wouldPayAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: wouldPayAt30,
      denominator: scaleDenominator,
    );
  }

  static ProofRelevanceOutcomeDecision resolve(
    ProofRelevanceOutcomeSummary summary,
  ) {
    if (summary.totalTesters < minimumTesterCount) {
      return ProofRelevanceOutcomeDecision.insufficientData;
    }
    if (_tooVagueOrNotRelevantHigh(summary)) {
      return ProofRelevanceOutcomeDecision.proofStillTooVague;
    }
    if (_understandingTooLow(summary)) {
      return ProofRelevanceOutcomeDecision.proofNotUnderstood;
    }
    if (_allProductionTargetsPass(summary)) {
      return ProofRelevanceOutcomeDecision.productionCandidate;
    }
    if (_proofStable(summary)) {
      return ProofRelevanceOutcomeDecision.proofStableReturnToEvidenceTrail;
    }
    return ProofRelevanceOutcomeDecision.proofNotUnderstood;
  }

  static bool _tooVagueOrNotRelevantHigh(
    ProofRelevanceOutcomeSummary summary,
  ) =>
      summary.tooVagueOrNotRelevantCount >=
      tooVagueHighTargetFor(summary.totalTesters);

  static bool _understandingTooLow(ProofRelevanceOutcomeSummary summary) {
    final total = summary.totalTesters;
    return summary.understoodWhatItNoticedCount <
            understoodWhatItNoticedTargetFor(total) ||
        summary.couldTellIfRightCount < couldTellIfRightTargetFor(total);
  }

  static bool _proofStable(ProofRelevanceOutcomeSummary summary) {
    final total = summary.totalTesters;
    return summary.usefulProofCount >= usefulProofTargetFor(total) &&
        !_tooVagueOrNotRelevantHigh(summary) &&
        summary.understoodWhatItNoticedCount >=
            understoodWhatItNoticedTargetFor(total) &&
        summary.couldTellIfRightCount >= couldTellIfRightTargetFor(total) &&
        summary.didNotFeelLikeVagueAiCount >=
            didNotFeelLikeVagueAiTargetFor(total);
  }

  static bool _allProductionTargetsPass(ProofRelevanceOutcomeSummary summary) {
    final total = summary.totalTesters;
    return _proofStable(summary) &&
        summary.specificProofExampleRememberedCount >=
            specificProofExampleRememberedTargetFor(total) &&
        summary.wouldPayYesMaybeCount >= wouldPayTargetFor(total);
  }

  static int _scaledTarget({
    required int totalTesters,
    required int numerator,
    required int denominator,
  }) => ((numerator * totalTesters) / denominator).ceil();
}

enum ProofRelevanceOutcomeDecision {
  insufficientData,
  proofStillTooVague,
  proofNotUnderstood,
  proofStableReturnToEvidenceTrail,
  productionCandidate,
}

class ProofRelevanceOutcomeSummary {
  const ProofRelevanceOutcomeSummary({
    required this.totalTesters,
    required this.usefulProofCount,
    required this.tooVagueOrNotRelevantCount,
    required this.understoodWhatItNoticedCount,
    required this.couldTellIfRightCount,
    required this.didNotFeelLikeVagueAiCount,
    required this.specificProofExampleRememberedCount,
    required this.wouldPayYesMaybeCount,
  });

  final int totalTesters;
  final int usefulProofCount;
  final int tooVagueOrNotRelevantCount;
  final int understoodWhatItNoticedCount;
  final int couldTellIfRightCount;
  final int didNotFeelLikeVagueAiCount;
  final int specificProofExampleRememberedCount;
  final int wouldPayYesMaybeCount;
}
