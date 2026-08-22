/// Local inputs for the capacity yes loop card — metadata only.
class CapacityLoopInput {
  const CapacityLoopInput({
    required this.realSavedMomentCount,
    required this.capacityEvidenceCount,
    required this.capacityLoopActive,
    required this.capacityCohortActive,
    required this.sampleMode,
    this.topRecurringTheme,
    this.costSignalCount = 0,
    this.triggerSignalCount = 0,
    this.costCheckinRecordedCount = 0,
    this.hasPendingCostCheckin = false,
    this.outcomeRecordedCount = 0,
    this.hasPendingOutcome = false,
    this.hasPatternChangeOutcomes = false,
    this.hasPendingPullReason = false,
    this.pullReasonSummary = '',
  });

  final int realSavedMomentCount;
  final int capacityEvidenceCount;
  final bool capacityLoopActive;
  final bool capacityCohortActive;
  final bool sampleMode;
  final String? topRecurringTheme;
  final int costSignalCount;
  final int triggerSignalCount;
  final int costCheckinRecordedCount;
  final bool hasPendingCostCheckin;
  final int outcomeRecordedCount;
  final bool hasPendingOutcome;
  final bool hasPatternChangeOutcomes;
  final bool hasPendingPullReason;
  final String pullReasonSummary;

  bool get capacityWedgeActive => capacityLoopActive || capacityCohortActive;
}

/// Card / screen result for the capacity yes loop — no private journal text.
class CapacityLoopResult {
  const CapacityLoopResult({
    required this.hasCard,
    required this.isEmpty,
    required this.showOnArchiveHome,
    required this.title,
    required this.subtitle,
    required this.evidenceCountLabel,
    required this.whatRepeated,
    required this.costLater,
    required this.watchNext,
    required this.primaryCtaLabel,
    required this.secondaryCtaLabel,
    required this.primaryRoute,
    required this.secondaryRoute,
    required this.shareCopy,
    required this.triggerLabel,
    required this.saidYesLabel,
    required this.costLaterLabel,
    required this.repeatedLabel,
    required this.watchNextLabel,
    this.costEvidenceLabel = '',
    this.outcomeEvidenceLabel = '',
    this.pullReasonSummary = '',
  });

  static const empty = CapacityLoopResult(
    hasCard: false,
    isEmpty: true,
    showOnArchiveHome: false,
    title: '',
    subtitle: '',
    evidenceCountLabel: '',
    whatRepeated: '',
    costLater: '',
    watchNext: '',
    primaryCtaLabel: '',
    secondaryCtaLabel: '',
    primaryRoute: '',
    secondaryRoute: '',
    shareCopy: '',
    triggerLabel: '',
    saidYesLabel: '',
    costLaterLabel: '',
    repeatedLabel: '',
    watchNextLabel: '',
  );

  final bool hasCard;
  final bool isEmpty;
  final bool showOnArchiveHome;
  final String title;
  final String subtitle;
  final String evidenceCountLabel;
  final String whatRepeated;
  final String costLater;
  final String watchNext;
  final String primaryCtaLabel;
  final String secondaryCtaLabel;
  final String primaryRoute;
  final String secondaryRoute;
  final String shareCopy;
  final String triggerLabel;
  final String saidYesLabel;
  final String costLaterLabel;
  final String repeatedLabel;
  final String watchNextLabel;
  final String costEvidenceLabel;
  final String outcomeEvidenceLabel;
  final String pullReasonSummary;
}