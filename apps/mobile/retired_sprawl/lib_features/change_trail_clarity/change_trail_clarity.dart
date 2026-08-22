import 'package:archiveme_mobile/features/change_trail_clarity/change_trail_clarity_copy.dart';

/// Beta-only change trail clarity decision matrix — interpretation only.
abstract final class ChangeTrailClarity {
  ChangeTrailClarity._();

  static const minimumTesterCount = 20;
  static const understoodFirstProofAt30 = 7;
  static const understoodFirstProofAt20 = 5;
  static const understoodProKeepsTrailAt30 = 6;
  static const understoodProKeepsTrailAt20 = 4;
  static const understoodReturnsAt30 = 6;
  static const understoodReturnsAt20 = 4;
  static const understoodChangesAt30 = 6;
  static const understoodChangesAt20 = 4;
  static const understoodFadesAt30 = 6;
  static const understoodFadesAt20 = 4;
  static const understoodCorrectionsAt30 = 6;
  static const understoodCorrectionsAt20 = 4;
  static const thoughtMoreAiHighAt30 = 5;
  static const thoughtMoreAiHighAt20 = 3;
  static const wouldPayYesMaybeAt30 = 3;
  static const wouldPayYesMaybeAt20 = 2;
  static const scaleDenominator = 30;

  static int understoodFirstProofTargetFor(int totalTesters) {
    if (totalTesters == 20) return understoodFirstProofAt20;
    if (totalTesters == 30) return understoodFirstProofAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: understoodFirstProofAt30,
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

  static int understoodReturnsTargetFor(int totalTesters) {
    if (totalTesters == 20) return understoodReturnsAt20;
    if (totalTesters == 30) return understoodReturnsAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: understoodReturnsAt30,
      denominator: scaleDenominator,
    );
  }

  static int understoodChangesTargetFor(int totalTesters) {
    if (totalTesters == 20) return understoodChangesAt20;
    if (totalTesters == 30) return understoodChangesAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: understoodChangesAt30,
      denominator: scaleDenominator,
    );
  }

  static int understoodFadesTargetFor(int totalTesters) {
    if (totalTesters == 20) return understoodFadesAt20;
    if (totalTesters == 30) return understoodFadesAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: understoodFadesAt30,
      denominator: scaleDenominator,
    );
  }

  static int understoodCorrectionsTargetFor(int totalTesters) {
    if (totalTesters == 20) return understoodCorrectionsAt20;
    if (totalTesters == 30) return understoodCorrectionsAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: understoodCorrectionsAt30,
      denominator: scaleDenominator,
    );
  }

  static int thoughtMoreAiHighTargetFor(int totalTesters) {
    if (totalTesters == 20) return thoughtMoreAiHighAt20;
    if (totalTesters == 30) return thoughtMoreAiHighAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: thoughtMoreAiHighAt30,
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

  static ChangeTrailClarityDecision resolve(ChangeTrailClaritySummary summary) {
    if (summary.totalTesters < minimumTesterCount) {
      return ChangeTrailClarityDecision.insufficientData;
    }
    if (!_firstProofUnderstood(summary)) {
      return ChangeTrailClarityDecision.repairFirstProof;
    }
    if (!_proTrailUnderstood(summary)) {
      return ChangeTrailClarityDecision.repairProTrail;
    }
    if (_thoughtMoreAiHigh(summary)) {
      return ChangeTrailClarityDecision.removeMoreAiConfusion;
    }
    if (!_returnsUnderstood(summary)) {
      return ChangeTrailClarityDecision.explainReturns;
    }
    if (!_changesUnderstood(summary)) {
      return ChangeTrailClarityDecision.explainChanges;
    }
    if (!_fadesUnderstood(summary)) {
      return ChangeTrailClarityDecision.explainFades;
    }
    if (!_correctionsUnderstood(summary)) {
      return ChangeTrailClarityDecision.explainCorrections;
    }
    if (_allTrailComprehensionPasses(summary) &&
        !_wouldPayYesMaybePasses(summary)) {
      return ChangeTrailClarityDecision.pricingValidation;
    }
    if (_allTrailComprehensionPasses(summary) &&
        _wouldPayYesMaybePasses(summary)) {
      return ChangeTrailClarityDecision.releaseCandidate;
    }
    return ChangeTrailClarityDecision.explainChanges;
  }

  static bool _firstProofUnderstood(ChangeTrailClaritySummary summary) =>
      summary.understoodFirstProofCount >=
      understoodFirstProofTargetFor(summary.totalTesters);

  static bool _proTrailUnderstood(ChangeTrailClaritySummary summary) =>
      summary.understoodProKeepsTrailCount >=
      understoodProKeepsTrailTargetFor(summary.totalTesters);

  static bool _returnsUnderstood(ChangeTrailClaritySummary summary) =>
      summary.understoodReturnsCount >=
      understoodReturnsTargetFor(summary.totalTesters);

  static bool _changesUnderstood(ChangeTrailClaritySummary summary) =>
      summary.understoodChangesCount >=
      understoodChangesTargetFor(summary.totalTesters);

  static bool _fadesUnderstood(ChangeTrailClaritySummary summary) =>
      summary.understoodFadesCount >=
      understoodFadesTargetFor(summary.totalTesters);

  static bool _correctionsUnderstood(ChangeTrailClaritySummary summary) =>
      summary.understoodCorrectionsCount >=
      understoodCorrectionsTargetFor(summary.totalTesters);

  static bool _thoughtMoreAiHigh(ChangeTrailClaritySummary summary) =>
      summary.thoughtMoreAiCount >=
      thoughtMoreAiHighTargetFor(summary.totalTesters);

  static int _wouldPayYesMaybeCount(ChangeTrailClaritySummary summary) =>
      summary.wouldPayYesCount + summary.wouldPayMaybeCount;

  static bool _wouldPayYesMaybePasses(ChangeTrailClaritySummary summary) =>
      _wouldPayYesMaybeCount(summary) >=
      wouldPayYesMaybeTargetFor(summary.totalTesters);

  static bool _allTrailComprehensionPasses(ChangeTrailClaritySummary summary) =>
      _firstProofUnderstood(summary) &&
      _proTrailUnderstood(summary) &&
      _returnsUnderstood(summary) &&
      _changesUnderstood(summary) &&
      _fadesUnderstood(summary) &&
      _correctionsUnderstood(summary);

  static ChangeTrailClarityReport report(
    ChangeTrailClaritySummary summary,
    ChangeTrailClarityDecision decision,
  ) => ChangeTrailClarityReport(
    title: ChangeTrailClarityCopy.title,
    body: ChangeTrailClarityCopy.body,
    decision: decision,
    guardrail: ChangeTrailClarityCopy.guardrail,
  );

  static int _scaledTarget({
    required int totalTesters,
    required int numerator,
    required int denominator,
  }) => ((numerator * totalTesters) / denominator).ceil();
}

enum ChangeTrailClarityDecision {
  insufficientData,
  repairFirstProof,
  repairProTrail,
  explainReturns,
  explainChanges,
  explainFades,
  explainCorrections,
  removeMoreAiConfusion,
  pricingValidation,
  releaseCandidate,
}

class ChangeTrailClaritySummary {
  const ChangeTrailClaritySummary({
    required this.totalTesters,
    required this.understoodFirstProofCount,
    required this.understoodProKeepsTrailCount,
    required this.understoodReturnsCount,
    required this.understoodChangesCount,
    required this.understoodFadesCount,
    required this.understoodCorrectionsCount,
    required this.thoughtMoreAiCount,
    required this.wantedMoreProofCount,
    required this.wantedRankingCount,
    required this.wouldPayYesCount,
    required this.wouldPayMaybeCount,
    required this.wouldPayNoCount,
  });

  final int totalTesters;
  final int understoodFirstProofCount;
  final int understoodProKeepsTrailCount;
  final int understoodReturnsCount;
  final int understoodChangesCount;
  final int understoodFadesCount;
  final int understoodCorrectionsCount;
  final int thoughtMoreAiCount;
  final int wantedMoreProofCount;
  final int wantedRankingCount;
  final int wouldPayYesCount;
  final int wouldPayMaybeCount;
  final int wouldPayNoCount;
}

class ChangeTrailClarityReport {
  const ChangeTrailClarityReport({
    required this.title,
    required this.body,
    required this.decision,
    required this.guardrail,
  });

  final String title;
  final String body;
  final ChangeTrailClarityDecision decision;
  final String guardrail;
}