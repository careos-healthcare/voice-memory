import 'package:archiveme_mobile/features/payment_blocker_matrix/payment_blocker_decision_copy.dart';

/// Beta-only payment blocker decision matrix — interpretation only.
abstract final class PaymentBlockerDecisionMatrix {
  PaymentBlockerDecisionMatrix._();

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
  static const needSeeOverTimeHighAt30 = 6;
  static const needSeeOverTimeHighAt20 = 4;
  static const needStrongerProofHighAt30 = 6;
  static const needStrongerProofHighAt20 = 4;
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

  static int needSeeOverTimeHighTargetFor(int totalTesters) {
    if (totalTesters == 20) return needSeeOverTimeHighAt20;
    if (totalTesters == 30) return needSeeOverTimeHighAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: needSeeOverTimeHighAt30,
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

  static PaymentBlockerDecision resolve(PaymentBlockerSummary summary) {
    if (summary.totalTesters < minimumTesterCount) {
      return PaymentBlockerDecision.insufficientData;
    }
    if (!_usefulProofPasses(summary)) {
      return PaymentBlockerDecision.repairProofFirst;
    }
    if (!_proUnderstandingPasses(summary)) {
      return PaymentBlockerDecision.repairProUnderstanding;
    }
    if (_priceTooHighHigh(summary)) {
      return PaymentBlockerDecision.validatePriceCopy;
    }
    if (_needSeeOverTimeHigh(summary)) {
      return PaymentBlockerDecision.validateLongerTrailValue;
    }
    if (_needStrongerProofHigh(summary)) {
      return PaymentBlockerDecision.sharpenProofValueProposition;
    }
    if (_needRankingBeforePayingHigh(summary)) {
      return PaymentBlockerDecision.investigatePrioritisationConceptOnly;
    }
    if (_payYesMaybePasses(summary) && _worthPayingPasses(summary)) {
      return PaymentBlockerDecision.productionCandidate;
    }
    return PaymentBlockerDecision.sharpenProofValueProposition;
  }

  static bool _usefulProofPasses(PaymentBlockerSummary summary) =>
      summary.usefulProofCount >= usefulProofTargetFor(summary.totalTesters);

  static bool _longerTrailUnderstood(PaymentBlockerSummary summary) =>
      summary.understoodLongerTrailCount >=
      understoodLongerTrailTargetFor(summary.totalTesters);

  static bool _notMoreAiUnderstood(PaymentBlockerSummary summary) =>
      summary.understoodNotMoreAiCount >=
      understoodNotMoreAiTargetFor(summary.totalTesters);

  static bool _proUnderstandingPasses(PaymentBlockerSummary summary) =>
      _longerTrailUnderstood(summary) && _notMoreAiUnderstood(summary);

  static int _payYesMaybeCount(PaymentBlockerSummary summary) =>
      summary.payYesCount + summary.payMaybeCount;

  static bool _payYesMaybePasses(PaymentBlockerSummary summary) =>
      _payYesMaybeCount(summary) >= payYesMaybeTargetFor(summary.totalTesters);

  static bool _worthPayingPasses(PaymentBlockerSummary summary) =>
      summary.worthPayingCount >= worthPayingTargetFor(summary.totalTesters);

  static bool _needSeeOverTimeHigh(PaymentBlockerSummary summary) =>
      summary.needSeeOverTimeCount >=
      needSeeOverTimeHighTargetFor(summary.totalTesters);

  static bool _needStrongerProofHigh(PaymentBlockerSummary summary) =>
      summary.needStrongerProofCount >=
      needStrongerProofHighTargetFor(summary.totalTesters);

  static bool _needRankingBeforePayingHigh(PaymentBlockerSummary summary) =>
      summary.needRankingBeforePayingCount >=
      needRankingBeforePayingHighTargetFor(summary.totalTesters);

  static bool _priceTooHighHigh(PaymentBlockerSummary summary) =>
      summary.priceTooHighCount >=
      priceTooHighHighTargetFor(summary.totalTesters);

  static PaymentBlockerReport report(
    PaymentBlockerSummary summary,
    PaymentBlockerDecision decision,
  ) => PaymentBlockerReport(
    decision: decision,
    label: labelFor(decision),
    guardrail: PaymentBlockerDecisionCopy.guardrail,
  );

  static String labelFor(PaymentBlockerDecision decision) => switch (decision) {
    PaymentBlockerDecision.insufficientData =>
      PaymentBlockerDecisionCopy.insufficientDataLabel,
    PaymentBlockerDecision.repairProofFirst =>
      PaymentBlockerDecisionCopy.repairProofFirstLabel,
    PaymentBlockerDecision.repairProUnderstanding =>
      PaymentBlockerDecisionCopy.repairProUnderstandingLabel,
    PaymentBlockerDecision.validateLongerTrailValue =>
      PaymentBlockerDecisionCopy.validateLongerTrailValue,
    PaymentBlockerDecision.sharpenProofValueProposition =>
      PaymentBlockerDecisionCopy.sharpenProofValueProposition,
    PaymentBlockerDecision.investigatePrioritisationConceptOnly =>
      PaymentBlockerDecisionCopy.investigatePrioritisationConceptOnly,
    PaymentBlockerDecision.validatePriceCopy =>
      PaymentBlockerDecisionCopy.validatePriceCopyLabel,
    PaymentBlockerDecision.productionCandidate =>
      PaymentBlockerDecisionCopy.productionCandidateLabel,
  };

  static int _scaledTarget({
    required int totalTesters,
    required int numerator,
    required int denominator,
  }) => ((numerator * totalTesters) / denominator).ceil();
}

enum PaymentBlockerDecision {
  insufficientData,
  repairProofFirst,
  repairProUnderstanding,
  validateLongerTrailValue,
  sharpenProofValueProposition,
  investigatePrioritisationConceptOnly,
  validatePriceCopy,
  productionCandidate,
}

class PaymentBlockerSummary {
  const PaymentBlockerSummary({
    required this.totalTesters,
    required this.usefulProofCount,
    required this.understoodLongerTrailCount,
    required this.understoodNotMoreAiCount,
    required this.payYesCount,
    required this.payMaybeCount,
    required this.payNoCount,
    required this.needSeeOverTimeCount,
    required this.needStrongerProofCount,
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
  final int needSeeOverTimeCount;
  final int needStrongerProofCount;
  final int needRankingBeforePayingCount;
  final int priceTooHighCount;
  final int worthPayingCount;
}

class PaymentBlockerReport {
  const PaymentBlockerReport({
    required this.decision,
    required this.label,
    required this.guardrail,
  });

  final PaymentBlockerDecision decision;
  final String label;
  final String guardrail;
}