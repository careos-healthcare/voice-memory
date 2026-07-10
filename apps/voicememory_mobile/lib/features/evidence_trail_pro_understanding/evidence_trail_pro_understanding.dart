import 'evidence_trail_pro_understanding_copy.dart';

/// Beta-only evidence trail + Pro understanding decision matrix — interpretation only.
abstract final class EvidenceTrailProUnderstanding {
  EvidenceTrailProUnderstanding._();

  static const minimumTesterCount = 20;
  static const usefulProofAt30 = 7;
  static const usefulProofAt20 = 5;
  static const understoodLongerTrailAt30 = 6;
  static const understoodLongerTrailAt20 = 4;
  static const understoodProKeepsChangesAt30 = 6;
  static const understoodProKeepsChangesAt20 = 4;
  static const thoughtProWasMoreAiHighAt30 = 6;
  static const thoughtProWasMoreAiHighAt20 = 4;
  static const wantedRankingHighAt30 = 6;
  static const wantedRankingHighAt20 = 4;
  static const paywallCtaTapAt30 = 1;
  static const paywallCtaTapAt20 = 1;
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

  static int understoodLongerTrailTargetFor(int totalTesters) {
    if (totalTesters == 20) return understoodLongerTrailAt20;
    if (totalTesters == 30) return understoodLongerTrailAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: understoodLongerTrailAt30,
      denominator: scaleDenominator,
    );
  }

  static int understoodProKeepsChangesTargetFor(int totalTesters) {
    if (totalTesters == 20) return understoodProKeepsChangesAt20;
    if (totalTesters == 30) return understoodProKeepsChangesAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: understoodProKeepsChangesAt30,
      denominator: scaleDenominator,
    );
  }

  static int thoughtProWasMoreAiHighTargetFor(int totalTesters) {
    if (totalTesters == 20) return thoughtProWasMoreAiHighAt20;
    if (totalTesters == 30) return thoughtProWasMoreAiHighAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: thoughtProWasMoreAiHighAt30,
      denominator: scaleDenominator,
    );
  }

  static int wantedRankingHighTargetFor(int totalTesters) {
    if (totalTesters == 20) return wantedRankingHighAt20;
    if (totalTesters == 30) return wantedRankingHighAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: wantedRankingHighAt30,
      denominator: scaleDenominator,
    );
  }

  static int paywallCtaTapTargetFor(int totalTesters) {
    if (totalTesters == 20) return paywallCtaTapAt20;
    if (totalTesters == 30) return paywallCtaTapAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: paywallCtaTapAt30,
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

  static EvidenceTrailProUnderstandingDecision resolve(
    EvidenceTrailProUnderstandingSummary summary,
  ) {
    if (summary.totalTesters < minimumTesterCount) {
      return EvidenceTrailProUnderstandingDecision.insufficientData;
    }
    if (!_usefulProofPasses(summary)) {
      return EvidenceTrailProUnderstandingDecision.repairProofFirst;
    }
    if (_thoughtProWasMoreAiHigh(summary)) {
      return EvidenceTrailProUnderstandingDecision.removeMoreAiConfusion;
    }
    if (!_longerTrailUnderstood(summary)) {
      return EvidenceTrailProUnderstandingDecision.explainLongerTrail;
    }
    if (_wantedRankingHigh(summary)) {
      return EvidenceTrailProUnderstandingDecision.holdRanking;
    }
    if (_coreUnderstandingPasses(summary) && _payWeak(summary)) {
      return EvidenceTrailProUnderstandingDecision.readyForPricingValidation;
    }
    if (_coreUnderstandingPasses(summary) && _payPasses(summary)) {
      return EvidenceTrailProUnderstandingDecision.productionCandidate;
    }
    return EvidenceTrailProUnderstandingDecision.explainLongerTrail;
  }

  static bool _usefulProofPasses(EvidenceTrailProUnderstandingSummary summary) =>
      summary.usefulProofCount >= usefulProofTargetFor(summary.totalTesters);

  static bool _longerTrailUnderstood(
    EvidenceTrailProUnderstandingSummary summary,
  ) =>
      summary.understoodLongerTrailCount >=
      understoodLongerTrailTargetFor(summary.totalTesters);

  static bool _proChangesUnderstood(EvidenceTrailProUnderstandingSummary summary) =>
      summary.understoodProKeepsChangesCount >=
      understoodProKeepsChangesTargetFor(summary.totalTesters);

  static bool _thoughtProWasMoreAiHigh(
    EvidenceTrailProUnderstandingSummary summary,
  ) =>
      summary.thoughtProWasMoreAiCount >=
      thoughtProWasMoreAiHighTargetFor(summary.totalTesters);

  static bool _wantedRankingHigh(EvidenceTrailProUnderstandingSummary summary) =>
      summary.wantedRankingCount >=
      wantedRankingHighTargetFor(summary.totalTesters);

  static bool _coreUnderstandingPasses(
    EvidenceTrailProUnderstandingSummary summary,
  ) =>
      _usefulProofPasses(summary) &&
      _longerTrailUnderstood(summary) &&
      _proChangesUnderstood(summary);

  static bool _payWeak(EvidenceTrailProUnderstandingSummary summary) =>
      summary.paywallCtaTapCount <
          paywallCtaTapTargetFor(summary.totalTesters) ||
      summary.wouldPayYesMaybeCount < wouldPayTargetFor(summary.totalTesters);

  static bool _payPasses(EvidenceTrailProUnderstandingSummary summary) =>
      summary.paywallCtaTapCount >=
          paywallCtaTapTargetFor(summary.totalTesters) &&
      summary.wouldPayYesMaybeCount >= wouldPayTargetFor(summary.totalTesters);

  static EvidenceTrailProUnderstandingReport report(
    EvidenceTrailProUnderstandingSummary summary,
    EvidenceTrailProUnderstandingDecision decision,
  ) =>
      EvidenceTrailProUnderstandingReport(
        title: EvidenceTrailProUnderstandingCopy.title,
        body: EvidenceTrailProUnderstandingCopy.body,
        supportingLine: EvidenceTrailProUnderstandingCopy.supportingLine,
        decision: decision,
        guardrail: EvidenceTrailProUnderstandingCopy.guardrail,
      );

  static int _scaledTarget({
    required int totalTesters,
    required int numerator,
    required int denominator,
  }) =>
      ((numerator * totalTesters) / denominator).ceil();
}

enum EvidenceTrailProUnderstandingDecision {
  insufficientData,
  repairProofFirst,
  explainLongerTrail,
  removeMoreAiConfusion,
  holdRanking,
  readyForPricingValidation,
  productionCandidate,
}

class EvidenceTrailProUnderstandingSummary {
  const EvidenceTrailProUnderstandingSummary({
    required this.totalTesters,
    required this.usefulProofCount,
    required this.understoodFirstProofCount,
    required this.understoodLongerTrailCount,
    required this.understoodProKeepsChangesCount,
    required this.thoughtProWasMoreAiCount,
    required this.wantedRankingCount,
    required this.paywallCtaTapCount,
    required this.wouldPayYesMaybeCount,
  });

  final int totalTesters;
  final int usefulProofCount;
  final int understoodFirstProofCount;
  final int understoodLongerTrailCount;
  final int understoodProKeepsChangesCount;
  final int thoughtProWasMoreAiCount;
  final int wantedRankingCount;
  final int paywallCtaTapCount;
  final int wouldPayYesMaybeCount;
}

class EvidenceTrailProUnderstandingReport {
  const EvidenceTrailProUnderstandingReport({
    required this.title,
    required this.body,
    required this.supportingLine,
    required this.decision,
    required this.guardrail,
  });

  final String title;
  final String body;
  final String supportingLine;
  final EvidenceTrailProUnderstandingDecision decision;
  final String guardrail;
}
