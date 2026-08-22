import 'package:archiveme_mobile/features/value_prop_ranking_diagnostic/value_prop_ranking_diagnostic_copy.dart';

/// Beta-only value proposition + ranking-need diagnostic — interpretation only.
abstract final class ValuePropRankingDiagnostic {
  ValuePropRankingDiagnostic._();

  static const minimumTesterCount = 20;
  static const usefulProofAt30 = 7;
  static const usefulProofAt20 = 5;
  static const understoodLongerTrailAt30 = 6;
  static const understoodLongerTrailAt20 = 4;
  static const understoodNotMoreAiAt30 = 6;
  static const understoodNotMoreAiAt20 = 4;
  static const payYesMaybeAt30 = 3;
  static const payYesMaybeAt20 = 2;
  static const worthPayingAt30 = 3;
  static const worthPayingAt20 = 2;
  static const needStrongerProofHighAt30 = 6;
  static const needStrongerProofHighAt20 = 4;
  static const needSeeOverTimeHighAt30 = 6;
  static const needSeeOverTimeHighAt20 = 4;
  static const needRankingBeforePayingHighAt30 = 6;
  static const needRankingBeforePayingHighAt20 = 4;
  static const priceTooHighHighAt30 = 6;
  static const priceTooHighHighAt20 = 4;
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

  static int understoodNotMoreAiTargetFor(int totalTesters) {
    if (totalTesters == 20) return understoodNotMoreAiAt20;
    if (totalTesters == 30) return understoodNotMoreAiAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: understoodNotMoreAiAt30,
      denominator: scaleDenominator,
    );
  }

  static int payYesMaybeTargetFor(int totalTesters) {
    if (totalTesters == 20) return payYesMaybeAt20;
    if (totalTesters == 30) return payYesMaybeAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: payYesMaybeAt30,
      denominator: scaleDenominator,
    );
  }

  static int worthPayingTargetFor(int totalTesters) {
    if (totalTesters == 20) return worthPayingAt20;
    if (totalTesters == 30) return worthPayingAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: worthPayingAt30,
      denominator: scaleDenominator,
    );
  }

  static int needStrongerProofHighTargetFor(int totalTesters) {
    if (totalTesters == 20) return needStrongerProofHighAt20;
    if (totalTesters == 30) return needStrongerProofHighAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: needStrongerProofHighAt30,
      denominator: scaleDenominator,
    );
  }

  static int needSeeOverTimeHighTargetFor(int totalTesters) {
    if (totalTesters == 20) return needSeeOverTimeHighAt20;
    if (totalTesters == 30) return needSeeOverTimeHighAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: needSeeOverTimeHighAt30,
      denominator: scaleDenominator,
    );
  }

  static int needRankingBeforePayingHighTargetFor(int totalTesters) {
    if (totalTesters == 20) return needRankingBeforePayingHighAt20;
    if (totalTesters == 30) return needRankingBeforePayingHighAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: needRankingBeforePayingHighAt30,
      denominator: scaleDenominator,
    );
  }

  static int priceTooHighHighTargetFor(int totalTesters) {
    if (totalTesters == 20) return priceTooHighHighAt20;
    if (totalTesters == 30) return priceTooHighHighAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: priceTooHighHighAt30,
      denominator: scaleDenominator,
    );
  }

  static ValuePropRankingDiagnosticDecision resolve(
    ValuePropRankingDiagnosticSummary summary,
  ) {
    if (summary.totalTesters < minimumTesterCount) {
      return ValuePropRankingDiagnosticDecision.insufficientData;
    }
    if (!_usefulProofPasses(summary)) {
      return ValuePropRankingDiagnosticDecision.repairProofFirst;
    }
    if (!_proUnderstandingPasses(summary)) {
      return ValuePropRankingDiagnosticDecision.repairProUnderstanding;
    }
    if (_needSeeOverTimeHigh(summary) && _payIntentExists(summary)) {
      return ValuePropRankingDiagnosticDecision.validateLongerTrailValue;
    }
    if (_needStrongerProofHigh(summary) && !_payYesMaybePasses(summary)) {
      return ValuePropRankingDiagnosticDecision.sharpenValueProposition;
    }
    if (_priceTooHighHigh(summary)) {
      return ValuePropRankingDiagnosticDecision.validatePriceCopy;
    }
    if (_needRankingBeforePayingHigh(summary) && !_payYesMaybePasses(summary)) {
      return ValuePropRankingDiagnosticDecision.investigateRankingNeedOnly;
    }
    if (_payYesMaybePasses(summary) && _worthPayingPasses(summary)) {
      return ValuePropRankingDiagnosticDecision.productionCandidate;
    }
    return ValuePropRankingDiagnosticDecision.sharpenValueProposition;
  }

  static bool _usefulProofPasses(ValuePropRankingDiagnosticSummary summary) =>
      summary.usefulProofCount >= usefulProofTargetFor(summary.totalTesters);

  static bool _longerTrailUnderstood(
    ValuePropRankingDiagnosticSummary summary,
  ) =>
      summary.understoodLongerTrailCount >=
      understoodLongerTrailTargetFor(summary.totalTesters);

  static bool _notMoreAiUnderstood(ValuePropRankingDiagnosticSummary summary) =>
      summary.understoodNotMoreAiCount >=
      understoodNotMoreAiTargetFor(summary.totalTesters);

  static bool _proUnderstandingPasses(
    ValuePropRankingDiagnosticSummary summary,
  ) => _longerTrailUnderstood(summary) && _notMoreAiUnderstood(summary);

  static int _payYesMaybeCount(ValuePropRankingDiagnosticSummary summary) =>
      summary.payYesCount + summary.payMaybeCount;

  static bool _payIntentExists(ValuePropRankingDiagnosticSummary summary) =>
      _payYesMaybeCount(summary) > 0;

  static bool _payYesMaybePasses(ValuePropRankingDiagnosticSummary summary) =>
      _payYesMaybeCount(summary) >= payYesMaybeTargetFor(summary.totalTesters);

  static bool _worthPayingPasses(ValuePropRankingDiagnosticSummary summary) =>
      summary.worthPayingCount >= worthPayingTargetFor(summary.totalTesters);

  static bool _needStrongerProofHigh(
    ValuePropRankingDiagnosticSummary summary,
  ) =>
      summary.needStrongerProofCount >=
      needStrongerProofHighTargetFor(summary.totalTesters);

  static bool _needSeeOverTimeHigh(ValuePropRankingDiagnosticSummary summary) =>
      summary.needSeeOverTimeCount >=
      needSeeOverTimeHighTargetFor(summary.totalTesters);

  static bool _needRankingBeforePayingHigh(
    ValuePropRankingDiagnosticSummary summary,
  ) =>
      summary.needRankingBeforePayingCount >=
      needRankingBeforePayingHighTargetFor(summary.totalTesters);

  static bool _priceTooHighHigh(ValuePropRankingDiagnosticSummary summary) =>
      summary.priceTooHighCount >=
      priceTooHighHighTargetFor(summary.totalTesters);

  static ValuePropRankingDiagnosticReport report(
    ValuePropRankingDiagnosticSummary summary,
    ValuePropRankingDiagnosticDecision decision,
  ) => ValuePropRankingDiagnosticReport(
    title: ValuePropRankingDiagnosticCopy.title,
    body: ValuePropRankingDiagnosticCopy.body,
    valueLine: ValuePropRankingDiagnosticCopy.valueLine,
    decision: decision,
    guardrail: ValuePropRankingDiagnosticCopy.guardrail,
  );

  static int _scaledTarget({
    required int totalTesters,
    required int numerator,
    required int denominator,
  }) => ((numerator * totalTesters) / denominator).ceil();
}

enum ValuePropRankingDiagnosticDecision {
  insufficientData,
  repairProofFirst,
  repairProUnderstanding,
  validateLongerTrailValue,
  sharpenValueProposition,
  validatePriceCopy,
  investigateRankingNeedOnly,
  productionCandidate,
}

class ValuePropRankingDiagnosticSummary {
  const ValuePropRankingDiagnosticSummary({
    required this.totalTesters,
    required this.usefulProofCount,
    required this.understoodLongerTrailCount,
    required this.understoodNotMoreAiCount,
    required this.payYesCount,
    required this.payMaybeCount,
    required this.payNoCount,
    required this.needStrongerProofCount,
    required this.needSeeOverTimeCount,
    required this.needRankingBeforePayingCount,
    required this.priceTooHighCount,
    required this.worthPayingCount,
  });

  final int totalTesters;
  final int usefulProofCount;
  final int understoodLongerTrailCount;
  final int understoodNotMoreAiCount;
  final int payYesCount;
  final int payMaybeCount;
  final int payNoCount;
  final int needStrongerProofCount;
  final int needSeeOverTimeCount;
  final int needRankingBeforePayingCount;
  final int priceTooHighCount;
  final int worthPayingCount;
}

class ValuePropRankingDiagnosticReport {
  const ValuePropRankingDiagnosticReport({
    required this.title,
    required this.body,
    required this.valueLine,
    required this.decision,
    required this.guardrail,
  });

  final String title;
  final String body;
  final String valueLine;
  final ValuePropRankingDiagnosticDecision decision;
  final String guardrail;
}