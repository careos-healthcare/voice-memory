import '../pro_value/pro_value_copy.dart';
import 'pro_interest_models.dart';

/// Copy for local Pro interest and pricing signal capture.
abstract final class ProInterestCopy {
  ProInterestCopy._();

  static const screenTitle = 'Pro interest';
  static const sectionTitle = 'Would this be useful to you?';
  static const sectionBody =
      'Purchases are not available yet. You can still mark what would make Pro '
      'worth paying for.';
  static const interestOnlyNote =
      'This is interest only. No payment is taken. The free archive flow '
      'remains usable.';
  static const purchasesUnavailableNote = ProValueCopy.purchaseUnavailableNote;

  static const valueSectionTitle = 'What would make Pro worth it?';
  static const pricingSectionTitle = 'Pricing signal';
  static const noteLabel = 'What would make Pro worth it?';
  static const noteHint = 'Optional — stays on this device only';

  static const saveButton = 'Save Pro interest';
  static const copySummaryButton = 'Copy Pro interest summary';
  static const summaryCopied = 'Pro interest summary copied';
  static const thanksMessage =
      'Thanks — your Pro interest stays on this device only.';

  static const openProInterestButton = 'Open Pro interest';
  static const markProInterestButton = 'Mark Pro interest';
  static const supportTitle = 'Pro interest';
  static const supportSubtitle = 'Mark what would make Pro useful later.';
  static const archiveCardTitle = 'Would Pro be useful later?';
  static const archiveCardBody =
      'Purchases are not available yet. You can mark what would make deeper '
      'long-term evidence history worth paying for.';
  static const previewSectionTitle = sectionTitle;
  static const previewSectionBody =
      'You can mark what would make Pro worth paying for before billing is ready.';

  static const valueLongerArchiveHistory = 'Longer archive history';
  static const valueDeeperBeliefTimeline = 'Deeper belief change timeline';
  static const valueMoreWatchThemes = 'More watch themes';
  static const valueRicherReviews = 'Richer weekly and monthly reviews';
  static const valueAdvancedExport = 'Advanced export report packs';
  static const valueDeeperContextViews =
      'Deeper context and evidence map views';

  static const pricingFreeFirst = 'I would try this free first';
  static const pricingLowMonthly = 'I would consider a low monthly price';
  static const pricingYearly = 'I would prefer yearly';
  static const pricingNotEnoughValue = 'Not enough value yet';

  static const pricingSignalNone = 'not captured';
  static const pricingSignalFreeFirst = 'free first';
  static const pricingSignalLowMonthly = 'low monthly';
  static const pricingSignalYearly = 'yearly';
  static const pricingSignalNotEnoughValue = 'not enough value yet';

  static const interpretationNotCaptured = 'Pro interest not captured yet.';
  static const interpretationRevenueSignal = 'Revenue signal present.';
  static const interpretationValueNeedsProof =
      'Value needs more proof before pricing.';
  static const interpretationProValueUnclear = 'Pro value unclear.';

  static const betaOutcomesCapturedLabel = 'Pro interest captured';
  static const betaOutcomesValueCountLabel = 'Selected Pro value count';
  static const betaOutcomesPricingLabel = 'Pricing signal';
  static const betaOutcomesNotePresentLabel = 'Pro interest note present';

  static String labelForValue(ProInterestValueId id) => switch (id) {
    ProInterestValueId.longerArchiveHistory => valueLongerArchiveHistory,
    ProInterestValueId.deeperBeliefTimeline => valueDeeperBeliefTimeline,
    ProInterestValueId.moreWatchThemes => valueMoreWatchThemes,
    ProInterestValueId.richerReviews => valueRicherReviews,
    ProInterestValueId.advancedExport => valueAdvancedExport,
    ProInterestValueId.deeperContextViews => valueDeeperContextViews,
  };

  static String labelForPricing(ProInterestPricingIntentId? id) => switch (id) {
    ProInterestPricingIntentId.freeFirst => pricingSignalFreeFirst,
    ProInterestPricingIntentId.lowMonthly => pricingSignalLowMonthly,
    ProInterestPricingIntentId.yearly => pricingSignalYearly,
    ProInterestPricingIntentId.notEnoughValue => pricingSignalNotEnoughValue,
    null => pricingSignalNone,
  };

  static String pricingOptionLabel(ProInterestPricingIntentId id) =>
      switch (id) {
        ProInterestPricingIntentId.freeFirst => pricingFreeFirst,
        ProInterestPricingIntentId.lowMonthly => pricingLowMonthly,
        ProInterestPricingIntentId.yearly => pricingYearly,
        ProInterestPricingIntentId.notEnoughValue => pricingNotEnoughValue,
      };

  static const allValueIds = ProInterestValueId.values;
  static const allPricingIds = ProInterestPricingIntentId.values;

  static String buildSafeSummary(ProInterestState state) {
    final values = state.selectedValueIds.map(labelForValue).join(', ');
    final valuesPart = values.isEmpty ? 'none selected' : values;
    final pricing = labelForPricing(state.pricingIntentId);
    return 'ArchiveMe Pro interest: values selected — $valuesPart. '
        'Pricing signal: $pricing.';
  }

  static List<String> allVisibleCopy() => [
    screenTitle,
    sectionTitle,
    sectionBody,
    interestOnlyNote,
    purchasesUnavailableNote,
    valueSectionTitle,
    pricingSectionTitle,
    noteLabel,
    noteHint,
    saveButton,
    copySummaryButton,
    summaryCopied,
    thanksMessage,
    openProInterestButton,
    markProInterestButton,
    supportTitle,
    supportSubtitle,
    archiveCardTitle,
    archiveCardBody,
    previewSectionTitle,
    previewSectionBody,
    valueLongerArchiveHistory,
    valueDeeperBeliefTimeline,
    valueMoreWatchThemes,
    valueRicherReviews,
    valueAdvancedExport,
    valueDeeperContextViews,
    pricingFreeFirst,
    pricingLowMonthly,
    pricingYearly,
    pricingNotEnoughValue,
    pricingSignalNone,
    pricingSignalFreeFirst,
    pricingSignalLowMonthly,
    pricingSignalYearly,
    pricingSignalNotEnoughValue,
    interpretationNotCaptured,
    interpretationRevenueSignal,
    interpretationValueNeedsProof,
    interpretationProValueUnclear,
    betaOutcomesCapturedLabel,
    betaOutcomesValueCountLabel,
    betaOutcomesPricingLabel,
    betaOutcomesNotePresentLabel,
  ];
}
