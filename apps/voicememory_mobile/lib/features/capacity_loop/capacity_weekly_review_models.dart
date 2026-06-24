/// Gate input for capacity weekly review — metadata only.
class CapacityWeeklyReviewGateInput {
  const CapacityWeeklyReviewGateInput({
    required this.sampleMode,
    required this.realSavedMomentCount,
    required this.capacityEvidenceCount,
    required this.capacityWedgeActive,
    required this.capacityMomentCount,
    required this.outcomeOrCostRecordCount,
  });

  final bool sampleMode;
  final int realSavedMomentCount;
  final int capacityEvidenceCount;
  final bool capacityWedgeActive;
  final int capacityMomentCount;
  final int outcomeOrCostRecordCount;
}

/// Engine input for capacity weekly review.
class CapacityWeeklyReviewInput {
  const CapacityWeeklyReviewInput({
    required this.sampleMode,
    required this.realSavedMomentCount,
    required this.capacityWedgeActive,
    required this.capacityMomentCount,
    required this.capacityEvidenceCount,
    required this.outcomeRecordedCount,
    required this.laterCostRecordedCount,
    required this.hasPatternChangeOutcomes,
    required this.allAnsweredOutcomesAreYes,
    required this.hasAnsweredOutcomes,
    required this.pendingDecisionOutcome,
    required this.pendingCostCheckin,
    required this.beforeYesPauseOnHome,
  });

  final bool sampleMode;
  final int realSavedMomentCount;
  final bool capacityWedgeActive;
  final int capacityMomentCount;
  final int capacityEvidenceCount;
  final int outcomeRecordedCount;
  final int laterCostRecordedCount;
  final bool hasPatternChangeOutcomes;
  final bool allAnsweredOutcomesAreYes;
  final bool hasAnsweredOutcomes;
  final bool pendingDecisionOutcome;
  final bool pendingCostCheckin;
  final bool beforeYesPauseOnHome;
}

/// Card / screen result — no private journal text.
class CapacityWeeklyReviewResult {
  const CapacityWeeklyReviewResult({
    required this.hasReview,
    required this.showOnArchiveHome,
    required this.showOnCapacityLoop,
    required this.title,
    required this.subtitle,
    required this.evidenceCountLabel,
    required this.outcomeLine,
    required this.laterCostLine,
    required this.whatRepeated,
    required this.whatChanged,
    required this.laterCostSection,
    required this.watchNext,
    required this.primaryCtaLabel,
    required this.secondaryCtaLabel,
    required this.primaryRoute,
    required this.secondaryRoute,
    required this.cardSummary,
  });

  static const hidden = CapacityWeeklyReviewResult(
    hasReview: false,
    showOnArchiveHome: false,
    showOnCapacityLoop: false,
    title: '',
    subtitle: '',
    evidenceCountLabel: '',
    outcomeLine: '',
    laterCostLine: '',
    whatRepeated: '',
    whatChanged: '',
    laterCostSection: '',
    watchNext: '',
    primaryCtaLabel: '',
    secondaryCtaLabel: '',
    primaryRoute: '',
    secondaryRoute: '',
    cardSummary: '',
  );

  final bool hasReview;
  final bool showOnArchiveHome;
  final bool showOnCapacityLoop;
  final String title;
  final String subtitle;
  final String evidenceCountLabel;
  final String outcomeLine;
  final String laterCostLine;
  final String whatRepeated;
  final String whatChanged;
  final String laterCostSection;
  final String watchNext;
  final String primaryCtaLabel;
  final String secondaryCtaLabel;
  final String primaryRoute;
  final String secondaryRoute;
  final String cardSummary;
}
