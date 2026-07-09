enum PricingValidationPriceOption {
  price299,
  price499,
  price799,
  wouldNotPayMonthly,
}

extension PricingValidationPriceOptionAnalytics on PricingValidationPriceOption {
  String get analyticsValue => switch (this) {
        PricingValidationPriceOption.price299 => '2.99',
        PricingValidationPriceOption.price499 => '4.99',
        PricingValidationPriceOption.price799 => '7.99',
        PricingValidationPriceOption.wouldNotPayMonthly => 'would_not_pay_monthly',
      };
}

enum PricingValidationReasonOption {
  moreProofOverTime,
  betterCorrections,
  clearerTimeline,
  lowerPrice,
}

extension PricingValidationReasonOptionAnalytics
    on PricingValidationReasonOption {
  String get analyticsValue => switch (this) {
        PricingValidationReasonOption.moreProofOverTime => 'more_proof_over_time',
        PricingValidationReasonOption.betterCorrections => 'better_corrections',
        PricingValidationReasonOption.clearerTimeline => 'clearer_timeline',
        PricingValidationReasonOption.lowerPrice => 'lower_price',
      };
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
