import 'release_candidate_comprehension_copy.dart';

/// Beta-only release-candidate comprehension decision matrix — interpretation only.
abstract final class ReleaseCandidateComprehension {
  ReleaseCandidateComprehension._();

  static const minimumTesterCount = 20;
  static const understoodNotVoiceChatAt30 = 7;
  static const understoodNotVoiceChatAt20 = 5;
  static const understoodFirstProofAt30 = 7;
  static const understoodFirstProofAt20 = 5;
  static const understoodWhyAppearedAt30 = 7;
  static const understoodWhyAppearedAt20 = 5;
  static const understoodConfirmCorrectAt30 = 7;
  static const understoodConfirmCorrectAt20 = 5;
  static const understoodProKeepsTrailAt30 = 6;
  static const understoodProKeepsTrailAt20 = 4;
  static const understoodReturnsChangesAt30 = 6;
  static const understoodReturnsChangesAt20 = 4;
  static const thoughtItWasVoiceChatHighAt30 = 5;
  static const thoughtItWasVoiceChatHighAt20 = 3;
  static const thoughtItWasMoreAiHighAt30 = 5;
  static const thoughtItWasMoreAiHighAt20 = 3;
  static const wouldPayYesMaybeAt30 = 3;
  static const wouldPayYesMaybeAt20 = 2;
  static const scaleDenominator = 30;

  static int understoodNotVoiceChatTargetFor(int totalTesters) {
    if (totalTesters == 20) return understoodNotVoiceChatAt20;
    if (totalTesters == 30) return understoodNotVoiceChatAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: understoodNotVoiceChatAt30,
      denominator: scaleDenominator,
    );
  }

  static int understoodFirstProofTargetFor(int totalTesters) {
    if (totalTesters == 20) return understoodFirstProofAt20;
    if (totalTesters == 30) return understoodFirstProofAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: understoodFirstProofAt30,
      denominator: scaleDenominator,
    );
  }

  static int understoodWhyAppearedTargetFor(int totalTesters) {
    if (totalTesters == 20) return understoodWhyAppearedAt20;
    if (totalTesters == 30) return understoodWhyAppearedAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: understoodWhyAppearedAt30,
      denominator: scaleDenominator,
    );
  }

  static int understoodConfirmCorrectTargetFor(int totalTesters) {
    if (totalTesters == 20) return understoodConfirmCorrectAt20;
    if (totalTesters == 30) return understoodConfirmCorrectAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: understoodConfirmCorrectAt30,
      denominator: scaleDenominator,
    );
  }

  static int understoodProKeepsTrailTargetFor(int totalTesters) {
    if (totalTesters == 20) return understoodProKeepsTrailAt20;
    if (totalTesters == 30) return understoodProKeepsTrailAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: understoodProKeepsTrailAt30,
      denominator: scaleDenominator,
    );
  }

  static int understoodReturnsChangesTargetFor(int totalTesters) {
    if (totalTesters == 20) return understoodReturnsChangesAt20;
    if (totalTesters == 30) return understoodReturnsChangesAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: understoodReturnsChangesAt30,
      denominator: scaleDenominator,
    );
  }

  static int thoughtItWasVoiceChatHighTargetFor(int totalTesters) {
    if (totalTesters == 20) return thoughtItWasVoiceChatHighAt20;
    if (totalTesters == 30) return thoughtItWasVoiceChatHighAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: thoughtItWasVoiceChatHighAt30,
      denominator: scaleDenominator,
    );
  }

  static int thoughtItWasMoreAiHighTargetFor(int totalTesters) {
    if (totalTesters == 20) return thoughtItWasMoreAiHighAt20;
    if (totalTesters == 30) return thoughtItWasMoreAiHighAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: thoughtItWasMoreAiHighAt30,
      denominator: scaleDenominator,
    );
  }

  static int wouldPayYesMaybeTargetFor(int totalTesters) {
    if (totalTesters == 20) return wouldPayYesMaybeAt20;
    if (totalTesters == 30) return wouldPayYesMaybeAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: wouldPayYesMaybeAt30,
      denominator: scaleDenominator,
    );
  }

  static ReleaseCandidateComprehensionDecision resolve(
    ReleaseCandidateComprehensionSummary summary,
  ) {
    if (summary.totalTesters < minimumTesterCount) {
      return ReleaseCandidateComprehensionDecision.insufficientData;
    }
    if (_thoughtItWasVoiceChatHigh(summary) ||
        !_notVoiceChatUnderstood(summary)) {
      return ReleaseCandidateComprehensionDecision.repairPositioning;
    }
    if (!_firstProofUnderstood(summary)) {
      return ReleaseCandidateComprehensionDecision.repairFirstProof;
    }
    if (!_whyAppearedUnderstood(summary)) {
      return ReleaseCandidateComprehensionDecision.repairWhyAppeared;
    }
    if (!_confirmCorrectUnderstood(summary)) {
      return ReleaseCandidateComprehensionDecision.repairConfirmCorrect;
    }
    if (!_proTrailUnderstood(summary)) {
      return ReleaseCandidateComprehensionDecision.repairProTrail;
    }
    if (!_returnsChangesUnderstood(summary)) {
      return ReleaseCandidateComprehensionDecision.repairChangeTrail;
    }
    if (_allComprehensionPasses(summary) && !_wouldPayYesMaybePasses(summary)) {
      return ReleaseCandidateComprehensionDecision.pricingValidation;
    }
    if (_allComprehensionPasses(summary) && _wouldPayYesMaybePasses(summary)) {
      return ReleaseCandidateComprehensionDecision.releaseCandidate;
    }
    return ReleaseCandidateComprehensionDecision.repairPositioning;
  }

  static bool _notVoiceChatUnderstood(
    ReleaseCandidateComprehensionSummary summary,
  ) =>
      summary.understoodNotVoiceChatCount >=
      understoodNotVoiceChatTargetFor(summary.totalTesters);

  static bool _firstProofUnderstood(ReleaseCandidateComprehensionSummary summary) =>
      summary.understoodFirstProofCount >=
      understoodFirstProofTargetFor(summary.totalTesters);

  static bool _whyAppearedUnderstood(ReleaseCandidateComprehensionSummary summary) =>
      summary.understoodWhyAppearedCount >=
      understoodWhyAppearedTargetFor(summary.totalTesters);

  static bool _confirmCorrectUnderstood(
    ReleaseCandidateComprehensionSummary summary,
  ) =>
      summary.understoodConfirmCorrectCount >=
      understoodConfirmCorrectTargetFor(summary.totalTesters);

  static bool _proTrailUnderstood(ReleaseCandidateComprehensionSummary summary) =>
      summary.understoodProKeepsTrailCount >=
      understoodProKeepsTrailTargetFor(summary.totalTesters);

  static bool _returnsChangesUnderstood(
    ReleaseCandidateComprehensionSummary summary,
  ) =>
      summary.understoodReturnsChangesFadesCorrectionsCount >=
      understoodReturnsChangesTargetFor(summary.totalTesters);

  static bool _thoughtItWasVoiceChatHigh(
    ReleaseCandidateComprehensionSummary summary,
  ) =>
      summary.thoughtItWasVoiceChatCount >=
      thoughtItWasVoiceChatHighTargetFor(summary.totalTesters);

  static int _wouldPayYesMaybeCount(ReleaseCandidateComprehensionSummary summary) =>
      summary.wouldPayYesCount + summary.wouldPayMaybeCount;

  static bool _wouldPayYesMaybePasses(
    ReleaseCandidateComprehensionSummary summary,
  ) =>
      _wouldPayYesMaybeCount(summary) >=
      wouldPayYesMaybeTargetFor(summary.totalTesters);

  static bool _allComprehensionPasses(
    ReleaseCandidateComprehensionSummary summary,
  ) =>
      _notVoiceChatUnderstood(summary) &&
      _firstProofUnderstood(summary) &&
      _whyAppearedUnderstood(summary) &&
      _confirmCorrectUnderstood(summary) &&
      _proTrailUnderstood(summary) &&
      _returnsChangesUnderstood(summary);

  static ReleaseCandidateComprehensionReport report(
    ReleaseCandidateComprehensionSummary summary,
    ReleaseCandidateComprehensionDecision decision,
  ) =>
      ReleaseCandidateComprehensionReport(
        headline: ReleaseCandidateComprehensionCopy.headline,
        body: ReleaseCandidateComprehensionCopy.body,
        decision: decision,
        guardrail: ReleaseCandidateComprehensionCopy.guardrail,
      );

  static bool copyPassesPositioningGuard(String text) {
    final lower = text.toLowerCase();
    for (final phrase in ReleaseCandidateComprehensionCopy.bannedPhrases) {
      if (lower.contains(phrase)) return false;
    }
    return true;
  }

  static int _scaledTarget({
    required int totalTesters,
    required int numerator,
    required int denominator,
  }) =>
      ((numerator * totalTesters) / denominator).ceil();
}

enum ReleaseCandidateComprehensionDecision {
  insufficientData,
  repairPositioning,
  repairFirstProof,
  repairWhyAppeared,
  repairConfirmCorrect,
  repairProTrail,
  repairChangeTrail,
  pricingValidation,
  releaseCandidate,
}

class ReleaseCandidateComprehensionSummary {
  const ReleaseCandidateComprehensionSummary({
    required this.totalTesters,
    required this.understoodNotVoiceChatCount,
    required this.understoodFirstProofCount,
    required this.understoodWhyAppearedCount,
    required this.understoodConfirmCorrectCount,
    required this.understoodProKeepsTrailCount,
    required this.understoodReturnsChangesFadesCorrectionsCount,
    required this.thoughtItWasVoiceChatCount,
    required this.thoughtItWasMoreAiCount,
    required this.wouldPayYesCount,
    required this.wouldPayMaybeCount,
    required this.wouldPayNoCount,
  });

  final int totalTesters;
  final int understoodNotVoiceChatCount;
  final int understoodFirstProofCount;
  final int understoodWhyAppearedCount;
  final int understoodConfirmCorrectCount;
  final int understoodProKeepsTrailCount;
  final int understoodReturnsChangesFadesCorrectionsCount;
  final int thoughtItWasVoiceChatCount;
  final int thoughtItWasMoreAiCount;
  final int wouldPayYesCount;
  final int wouldPayMaybeCount;
  final int wouldPayNoCount;
}

class ReleaseCandidateComprehensionReport {
  const ReleaseCandidateComprehensionReport({
    required this.headline,
    required this.body,
    required this.decision,
    required this.guardrail,
  });

  final String headline;
  final String body;
  final ReleaseCandidateComprehensionDecision decision;
  final String guardrail;
}
