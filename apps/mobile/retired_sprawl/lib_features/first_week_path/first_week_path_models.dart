/// First Week Path step identifiers — entry-count based, not calendar days.
enum FirstWeekPathStep { day1, day2, day3, day4, day5, day6, day7 }

/// Local inputs for the first-week return path — metadata only.
class FirstWeekPathInput {
  const FirstWeekPathInput({
    required this.realSavedMomentCount,
    required this.hasWatchTheme, required this.betaFeedbackCaptured, required this.hasWeeklyReviewAvailable, this.usableEvidenceCount,
    this.sampleMode = false,
  });

  final int realSavedMomentCount;
  final int? usableEvidenceCount;
  final bool hasWatchTheme;
  final bool betaFeedbackCaptured;
  final bool hasWeeklyReviewAvailable;
  final bool sampleMode;
}

/// Deterministic first-week path output — no private entry content.
class FirstWeekPathResult {
  const FirstWeekPathResult({
    required this.currentStep,
    required this.completedStepCount,
    required this.totalStepCount,
    required this.progressLabel,
    required this.rewardText,
    required this.nextStepText,
    required this.primaryCtaLabel,
    required this.primaryRoute,
    required this.isComplete,
    required this.cardTitle,
    required this.cardBody,
    required this.showOnArchiveHome,
  });

  final FirstWeekPathStep currentStep;
  final int completedStepCount;
  final int totalStepCount;
  final String progressLabel;
  final String rewardText;
  final String nextStepText;
  final String primaryCtaLabel;
  final String primaryRoute;
  final bool isComplete;
  final String cardTitle;
  final String cardBody;
  final bool showOnArchiveHome;
}