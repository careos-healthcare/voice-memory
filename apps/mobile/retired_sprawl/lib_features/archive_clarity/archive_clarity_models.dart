/// Archive clarity stage identifiers — non-clinical progress only.
enum ArchiveClarityStageId {
  starting,
  comparisonForming,
  patternEmerging,
  evidenceGrowing,
  reviewReady,
}

/// Local inputs for archive clarity progress — metadata only.
class ArchiveClarityInput {
  const ArchiveClarityInput({
    required this.realSavedMomentCount,
    required this.usableEvidenceCount,
    required this.hasWatchTheme,
    required this.betaFeedbackCaptured,
    this.firstWeekComplete = false,
    this.weeklyReviewAvailable = false,
    this.sampleMode = false,
  });

  final int realSavedMomentCount;
  final int usableEvidenceCount;
  final bool hasWatchTheme;
  final bool betaFeedbackCaptured;
  final bool firstWeekComplete;
  final bool weeklyReviewAvailable;
  final bool sampleMode;
}

/// Deterministic archive clarity output — no private entry content.
class ArchiveClarityResult {
  const ArchiveClarityResult({
    required this.stageId,
    required this.stageLabel,
    required this.headline,
    required this.body,
    required this.evidenceStrengthLabel,
    required this.evidenceStrengthValue,
    required this.completedUnits,
    required this.targetUnits,
    required this.nextStepText,
    required this.primaryCtaLabel,
    required this.primaryRoute,
    required this.isReviewReady,
    required this.isEmpty,
    required this.showOnArchiveHome,
  });

  final ArchiveClarityStageId stageId;
  final String stageLabel;
  final String headline;
  final String body;
  final String evidenceStrengthLabel;
  final String evidenceStrengthValue;
  final int completedUnits;
  final int targetUnits;
  final String nextStepText;
  final String primaryCtaLabel;
  final String primaryRoute;
  final bool isReviewReady;
  final bool isEmpty;
  final bool showOnArchiveHome;
}