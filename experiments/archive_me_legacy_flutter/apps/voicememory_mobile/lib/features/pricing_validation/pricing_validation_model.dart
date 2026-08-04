import '../../services/analytics/analytics_catalog.dart';

enum PricingValidationPriceOption {
  price299,
  price499,
  price799,
  wouldNotPayMonthly,
}

extension PricingValidationPriceOptionValueState
    on PricingValidationPriceOption {
  CatalogPricingValueState get valueState => switch (this) {
    PricingValidationPriceOption.price299 =>
      CatalogPricingValueState.monthlyStorePlan,
    PricingValidationPriceOption.price499 =>
      CatalogPricingValueState.annualStorePlan,
    PricingValidationPriceOption.price799 =>
      CatalogPricingValueState.needsMoreValue,
    PricingValidationPriceOption.wouldNotPayMonthly =>
      CatalogPricingValueState.wouldNotSubscribe,
  };

  String get valueStateToken =>
      AnalyticsCatalog.pricingValueStateToken(valueState);
}

enum PricingValidationReasonOption {
  moreProofOverTime,
  betterCorrections,
  clearerTimeline,
  lowerPrice,
}

extension PricingValidationReasonOptionCatalog
    on PricingValidationReasonOption {
  CatalogPricingReason get catalogReason => switch (this) {
    PricingValidationReasonOption.moreProofOverTime =>
      CatalogPricingReason.moreProofOverTime,
    PricingValidationReasonOption.betterCorrections =>
      CatalogPricingReason.betterCorrections,
    PricingValidationReasonOption.clearerTimeline =>
      CatalogPricingReason.clearerTimeline,
    PricingValidationReasonOption.lowerPrice => CatalogPricingReason.lowerPrice,
  };

  String get reasonToken => AnalyticsCatalog.pricingReasonToken(catalogReason);
}

class PricingValidationResult {
  const PricingValidationResult({
    required this.shouldShow,
    required this.title,
    required this.body,
    required this.pricePrompt,
    required this.reasonPrompt,
    required this.primaryCta,
    required this.secondaryCta,
    required this.source,
    required this.entryCount,
    required this.hasUsefulProof,
    required this.activeRepairMode,
  });

  static const hidden = PricingValidationResult(
    shouldShow: false,
    title: '',
    body: '',
    pricePrompt: '',
    reasonPrompt: '',
    primaryCta: '',
    secondaryCta: '',
    source: '',
    entryCount: 0,
    hasUsefulProof: false,
    activeRepairMode: '',
  );

  final bool shouldShow;
  final String title;
  final String body;
  final String pricePrompt;
  final String reasonPrompt;
  final String primaryCta;
  final String secondaryCta;
  final String source;
  final int entryCount;
  final bool hasUsefulProof;
  final String activeRepairMode;
}
