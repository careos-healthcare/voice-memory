import 'pricing_validation_model.dart';

/// Pricing validation copy — beta intent collection only, no purchase changes.
abstract final class PricingValidationCopy {
  PricingValidationCopy._();

  static const title = 'Which option fits?';
  static const body =
      'ArchiveMe Pro keeps the longer evidence trail: what returns, what changes, '
      'what fades, and what you correct.';
  static const pricePrompt =
      'If this stays useful, which store-plan response fits best?';
  static const reasonPrompt = 'What would make Pro worth paying for?';
  static const primaryCta = 'See Pro timeline';
  static const secondaryCta = 'Keep using free';

  // Legacy enum names remain storage-compatible; visible choices describe
  // package/value state and never fabricate an amount.
  static const price299 = 'I would consider the monthly store plan';
  static const price499 = 'I would consider the annual store plan';
  static const price799 = 'I need to see more value first';
  static const wouldNotPayMonthly = 'I would not subscribe';

  static const reasonMoreProof = 'More proof over time';
  static const reasonBetterCorrections = 'Better corrections';
  static const reasonClearerTimeline = 'Clearer timeline';
  static const reasonLowerPrice = 'Lower price';

  static const priceOptions = [
    PricingValidationPriceOption.price299,
    PricingValidationPriceOption.price499,
    PricingValidationPriceOption.price799,
    PricingValidationPriceOption.wouldNotPayMonthly,
  ];

  static const reasonOptions = [
    PricingValidationReasonOption.moreProofOverTime,
    PricingValidationReasonOption.betterCorrections,
    PricingValidationReasonOption.clearerTimeline,
    PricingValidationReasonOption.lowerPrice,
  ];

  static String priceLabel(PricingValidationPriceOption option) =>
      switch (option) {
        PricingValidationPriceOption.price299 => price299,
        PricingValidationPriceOption.price499 => price499,
        PricingValidationPriceOption.price799 => price799,
        PricingValidationPriceOption.wouldNotPayMonthly => wouldNotPayMonthly,
      };

  static String reasonLabel(PricingValidationReasonOption option) =>
      switch (option) {
        PricingValidationReasonOption.moreProofOverTime => reasonMoreProof,
        PricingValidationReasonOption.betterCorrections =>
          reasonBetterCorrections,
        PricingValidationReasonOption.clearerTimeline => reasonClearerTimeline,
        PricingValidationReasonOption.lowerPrice => reasonLowerPrice,
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield title;
    yield body;
    yield pricePrompt;
    yield reasonPrompt;
    yield primaryCta;
    yield secondaryCta;
    yield price299;
    yield price499;
    yield price799;
    yield wouldNotPayMonthly;
    yield reasonMoreProof;
    yield reasonBetterCorrections;
    yield reasonClearerTimeline;
    yield reasonLowerPrice;
  }
}
