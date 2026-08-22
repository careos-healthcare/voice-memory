/// Daily archive exercise kinds — local prompts only.
enum DailyArchiveExerciseKind {
  firstMoment,
  comparisonMaterial,
  watchTheme,
  betaFeedback,
  patternRepeated,
  feltDifferent,
  checkConcern,
  saveUseful,
}

/// Local inputs for the daily archive exercise — metadata only.
class DailyArchiveExerciseInput {
  const DailyArchiveExerciseInput({
    required this.realSavedMomentCount,
    required this.hasWatchTheme,
    required this.betaFeedbackCaptured,
    this.sampleMode = false,
    this.dayIndex = 0,
  });

  final int realSavedMomentCount;
  final bool hasWatchTheme;
  final bool betaFeedbackCaptured;
  final bool sampleMode;
  final int dayIndex;
}

/// Deterministic daily exercise output — no private entry content.
class DailyArchiveExerciseResult {
  const DailyArchiveExerciseResult({
    required this.kind,
    required this.title,
    required this.prompt,
    required this.hint,
    required this.primaryCtaLabel,
    required this.primaryRoute,
    required this.showOnArchiveHome,
    required this.showOnRecord,
  });

  final DailyArchiveExerciseKind kind;
  final String title;
  final String prompt;
  final String hint;
  final String primaryCtaLabel;
  final String primaryRoute;
  final bool showOnArchiveHome;
  final bool showOnRecord;
}