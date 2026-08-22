import 'package:archiveme_mobile/features/pricing_offer_validation/pricing_offer_validation_v2_copy.dart';

/// Beta-only pricing offer validation decision matrix — interpretation only.
abstract final class PricingOfferValidationV2 {
  PricingOfferValidationV2._();

  static const minimumTesterCount = 20;
  static const usefulProofAt30 = 7;
  static const usefulProofAt20 = 5;
  static const understoodLongerTrailAt30 = 6;
  static const understoodLongerTrailAt20 = 4;
  static const understoodNotMoreAiAt30 = 6;
  static const understoodNotMoreAiAt20 = 4;
  static const payYesMaybeAt30 = 3;
  static const payYesMaybeAt20 = 2;
  static const priceTooHighHighAt30 = 6;
  static const priceTooHighHighAt20 = 4;
  static const needStrongerProofHighAt30 = 6;
  static const needStrongerProofHighAt20 = 4;
  static const needRankingHighAt30 = 6;
  static const needRankingHighAt20 = 4;
  static const ctaTapAt30 = 1;
  static const ctaTapAt20 = 1;
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

  static int priceTooHighHighTargetFor(int totalTesters) {
    if (totalTesters == 20) return priceTooHighHighAt20;
    if (totalTesters == 30) return priceTooHighHighAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: priceTooHighHighAt30,
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

  static int needRankingHighTargetFor(int totalTesters) {
    if (totalTesters == 20) return needRankingHighAt20;
    if (totalTesters == 30) return needRankingHighAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: needRankingHighAt30,
      denominator: scaleDenominator,
    );
  }

  static int ctaTapTargetFor(int totalTesters) {
    if (totalTesters == 20) return ctaTapAt20;
    if (totalTesters == 30) return ctaTapAt30;
    return _scaledTarget(
      totalTesters: totalTesters,
      numerator: ctaTapAt30,
      denominator: scaleDenominator,
    );
  }

  static PricingOfferValidationDecision resolve(
    PricingOfferValidationSummary summary,
  ) {
    if (summary.totalTesters < minimumTesterCount) {
      return PricingOfferValidationDecision.insufficientData;
    }
    if (!_usefulProofPasses(summary)) {
      return PricingOfferValidationDecision.repairProofFirst;
    }
    if (!_proUnderstandingPasses(summary)) {
      return PricingOfferValidationDecision.repairProUnderstanding;
    }
    if (_needRankingHigh(summary) && _payYesMaybePasses(summary)) {
      return PricingOfferValidationDecision.holdRanking;
    }
    if (_payYesMaybePasses(summary) && !_priceTooHighHigh(summary)) {
      return PricingOfferValidationDecision.pricingAcceptedProductionCandidate;
    }
    if (_payYesMaybePasses(summary) && _priceTooHighHigh(summary)) {
      return PricingOfferValidationDecision.validatePriceCopy;
    }
    if (_needStrongerProofHigh(summary)) {
      return PricingOfferValidationDecision.sharpenValueProposition;
    }
    if (_needRankingHigh(summary) && !_payYesMaybePasses(summary)) {
      return PricingOfferValidationDecision
          .investigateRankingOnlyIfPaymentBlocked;
    }
    return PricingOfferValidationDecision.sharpenValueProposition;
  }

  static bool _usefulProofPasses(PricingOfferValidationSummary summary) =>
      summary.usefulProofCount >= usefulProofTargetFor(summary.totalTesters);

  static bool _longerTrailUnderstood(PricingOfferValidationSummary summary) =>
      summary.understoodLongerTrailCount >=
      understoodLongerTrailTargetFor(summary.totalTesters);

  static bool _notMoreAiUnderstood(PricingOfferValidationSummary summary) =>
      summary.understoodNotMoreAiCount >=
      understoodNotMoreAiTargetFor(summary.totalTesters);

  static bool _proUnderstandingPasses(PricingOfferValidationSummary summary) =>
      _longerTrailUnderstood(summary) && _notMoreAiUnderstood(summary);

  static int _payYesMaybeCount(PricingOfferValidationSummary summary) =>
      summary.payYesCount + summary.payMaybeCount;

  static bool _payYesMaybePasses(PricingOfferValidationSummary summary) =>
      _payYesMaybeCount(summary) >= payYesMaybeTargetFor(summary.totalTesters);

  static bool _priceTooHighHigh(PricingOfferValidationSummary summary) =>
      summary.priceTooHighCount >=
      priceTooHighHighTargetFor(summary.totalTesters);

  static bool _needStrongerProofHigh(PricingOfferValidationSummary summary) =>
      summary.needStrongerProofCount >=
      needStrongerProofHighTargetFor(summary.totalTesters);

  static bool _needRankingHigh(PricingOfferValidationSummary summary) =>
      summary.needRankingCount >=
      needRankingHighTargetFor(summary.totalTesters);

  static PricingOfferValidationReport report(
    PricingOfferValidationSummary summary,
    PricingOfferValidationDecision decision,
  ) => PricingOfferValidationReport(
    title: PricingOfferValidationV2Copy.title,
    body: PricingOfferValidationV2Copy.body,
    valueLine: PricingOfferValidationV2Copy.valueLine,
    decision: decision,
    guardrail: PricingOfferValidationV2Copy.guardrail,
  );

  static int _scaledTarget({
    required int totalTesters,
    required int numerator,
    required int denominator,
  }) => ((numerator * totalTesters) / denominator).ceil();
}

enum PricingOfferValidationDecision {
  insufficientData,
  repairProofFirst,
  repairProUnderstanding,
  pricingAcceptedProductionCandidate,
  validatePriceCopy,
  sharpenValueProposition,
  holdRanking,
  investigateRankingOnlyIfPaymentBlocked,
}

class PricingOfferValidationSummary {
  const PricingOfferValidationSummary({
    required this.totalTesters,
    required this.usefulProofCount,
    required this.understoodLongerTrailCount,
    required this.understoodNotMoreAiCount,
    required this.payYesCount,
    required this.payMaybeCount,
    required this.payNoCount,
    required this.priceTooHighCount,
    required this.needStrongerProofCount,
    required this.needRankingCount,
    required this.ctaTapCount,
  });

  final int totalTesters;
  final int usefulProofCount;
  final int understoodLongerTrailCount;
  final int understoodNotMoreAiCount;
  final int payYesCount;
  final int payMaybeCount;
  final int payNoCount;
  final int priceTooHighCount;
  final int needStrongerProofCount;
  final int needRankingCount;
  final int ctaTapCount;
}

class PricingOfferValidationReport {
  const PricingOfferValidationReport({
    required this.title,
    required this.body,
    required this.valueLine,
    required this.decision,
    required this.guardrail,
  });

  final String title;
  final String body;
  final String valueLine;
  final PricingOfferValidationDecision decision;
  final String guardrail;
}