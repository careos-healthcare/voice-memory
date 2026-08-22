import 'package:archiveme_mobile/features/beta_results_reader/beta_results_summary.dart';

/// Interpretation-only beta results reader — combines validation, pricing, and evidence trail signals.
abstract final class BetaResultsReader {
  BetaResultsReader._();

  static const minimumTesterCount = 20;
  static const scaleDenominator = 30;
  static const firstSessionSaveAt20 = 5;
  static const firstSessionSaveAt30 = 8;
  static const usefulProofAt20 = 5;
  static const usefulProofAt30 = 7;
  static const evidenceTrailClearNumerator = 4;
  static const sawProNumerator = 4;
  static const understandsProNumerator = 4;
  static const paywallCtaTapNumerator = 1;
  static const wouldPayNumerator = 3;
  static const tooVagueHighRatioNumerator = 1;
  static const tooVagueHighRatioDenominator = 5;

  static int firstSessionSaveTargetFor(int totalTesters) {
    if (totalTesters == 20) return firstSessionSaveAt20;
    if (totalTesters == 30) return firstSessionSaveAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: firstSessionSaveAt30,
      denominator: scaleDenominator,
    );
  }

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

  static BetaResultsDecision resolve(BetaResultsSummary summary) {
    if (summary.totalTesters < minimumTesterCount) {
      return BetaResultsDecision.insufficientData;
    }
    if (summary.usefulProofCount < usefulProofTargetFor(summary.totalTesters)) {
      return BetaResultsDecision.protectProof;
    }
    if (_tooVagueOrNotRelevantHigh(summary)) {
      return BetaResultsDecision.protectProof;
    }
    if (summary.firstSessionSaveCount <
        firstSessionSaveTargetFor(summary.totalTesters)) {
      return BetaResultsDecision.improveFirstSession;
    }
    if (summary.evidenceTrailClearCount <
        evidenceTrailClearTargetFor(summary.totalTesters)) {
      return BetaResultsDecision.improveTimelineExplanation;
    }
    if (summary.sawProCount < sawProTargetFor(summary.totalTesters)) {
      return BetaResultsDecision.proTooHidden;
    }
    if (summary.understandsProCount <
        understandsProTargetFor(summary.totalTesters)) {
      return BetaResultsDecision.improveProExplanation;
    }
    if (summary.evidenceTrailClearCount >=
            evidenceTrailClearTargetFor(summary.totalTesters) &&
        summary.wouldPayYesMaybeCount <
            wouldPayTargetFor(summary.totalTesters)) {
      return BetaResultsDecision.pricingValidation;
    }
    if (_moreProofOverTimeStrongest(summary)) {
      return BetaResultsDecision.evidenceTrailFocus;
    }
    if (_allProductionTargetsPass(summary)) {
      return BetaResultsDecision.productionCandidate;
    }
    return BetaResultsDecision.improveTimelineExplanation;
  }

  static bool _tooVagueOrNotRelevantHigh(BetaResultsSummary summary) =>
      summary.tooVagueOrNotRelevantCount * tooVagueHighRatioDenominator >
      summary.totalTesters * tooVagueHighRatioNumerator;

  static bool _moreProofOverTimeStrongest(BetaResultsSummary summary) =>
      _isLargest(summary.moreProofOverTimeCount, [
        summary.moreProofOverTimeCount,
        summary.clearerTimelineCount,
        summary.lowerPriceCount,
      ]);

  static bool _allProductionTargetsPass(BetaResultsSummary summary) {
    final total = summary.totalTesters;
    return summary.usefulProofCount >= usefulProofTargetFor(total) &&
        !_tooVagueOrNotRelevantHigh(summary) &&
        summary.firstSessionSaveCount >= firstSessionSaveTargetFor(total) &&
        summary.sawProCount >= sawProTargetFor(total) &&
        summary.understandsProCount >= understandsProTargetFor(total) &&
        summary.paywallCtaTapCount >= paywallCtaTapTargetFor(total) &&
        summary.wouldPayYesMaybeCount >= wouldPayTargetFor(total) &&
        summary.evidenceTrailClearCount >= evidenceTrailClearTargetFor(total);
  }

  static bool _isLargest(int value, List<int> counts) {
    if (counts.every((count) => count == 0)) return false;
    final max = counts.reduce((a, b) => a > b ? a : b);
    return value == max && value > 0;
  }

  static int _scaledTarget({
    required int totalTesters,
    required int numerator,
    required int denominator,
  }) => ((numerator * totalTesters) / denominator).ceil();
}