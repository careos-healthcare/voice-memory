/// Entry-count gates for the Record tab empty / early-archive experience.
abstract class RecordEmptyArchiveGates {
  RecordEmptyArchiveGates._();

  static bool hasNoEntries(int entryCount) => entryCount == 0;
  static bool hasOneEntry(int entryCount) => entryCount == 1;
  static bool hasComparisonSeed(int entryCount) => entryCount >= 2;
  static bool hasPatternEvidence(int entryCount) => entryCount >= 3;

  static bool showEmptyArchiveCard({
    required bool loaded,
    required int entryCount,
  }) =>
      loaded && hasNoEntries(entryCount);

  /// Subtle privacy reassurance under the empty archive card — count 0 only.
  static bool showFirstRunPrivacyReassurance({
    required bool loaded,
    required int entryCount,
    required bool isPostSave,
  }) =>
      loaded && hasNoEntries(entryCount) && !isPostSave;

  static bool showArchiveStartedCard({
    required bool loaded,
    required int entryCount,
  }) =>
      loaded && hasOneEntry(entryCount);

  /// Early receipt / first-signal card on Record — 1–2 entries, ready state only.
  static bool showEarlyFirstSignalCard({
    required bool loaded,
    required int entryCount,
    required bool isPostSave,
  }) =>
      loaded &&
      !isPostSave &&
      (hasOneEntry(entryCount) || entryCount == 2);

  /// "Ready to record" status — only after comparison seed exists.
  static bool showReadyToRecordStatus({
    required bool loaded,
    required int entryCount,
  }) =>
      loaded && hasComparisonSeed(entryCount);

  /// First-three journey on Record — replaced by early specific insight at 2–3.
  static bool showFirstThreeJourneyCard({
    required bool loaded,
    required int entryCount,
  }) =>
      false;

  /// Daily Mirror hero card on Record — empty through early continuity stages.
  static bool showDailyMirrorCard({
    required bool loaded,
    required int entryCount,
  }) =>
      loaded && entryCount <= 4;

  /// Early sharp compare insight card on Record at two or three entries.
  static bool showEarlyCompareInsightCard({
    required bool loaded,
    required int entryCount,
  }) =>
      loaded && entryCount >= 2 && entryCount <= 3;

  /// Guided archive-context prompts (one small recording, daily suggestions, …).
  static bool showArchiveContextPrompts({
    required bool loaded,
    required int entryCount,
  }) =>
      loaded && hasPatternEvidence(entryCount);

  /// Two-day plan / return cards — too much progress chrome on a blank archive.
  static bool showTwoDayActivationCard({
    required bool loaded,
    required int entryCount,
  }) =>
      loaded && hasComparisonSeed(entryCount);

  /// Signal journey, archive watching, and similar retention cards.
  static bool showRetentionJourneyCards({
    required bool loaded,
    required int entryCount,
  }) =>
      loaded && hasPatternEvidence(entryCount);

  /// Legacy empty-archive onboarding cards below the record button.
  static bool showLegacyEmptyOnboarding({
    required bool loaded,
    required int entryCount,
  }) =>
      false;

  /// Current objective / progress chrome — too early at 0–1 entries.
  static bool showCurrentObjectiveCard({
    required bool loaded,
    required int entryCount,
  }) =>
      loaded && hasComparisonSeed(entryCount);

  /// Bottom-stack retention cards (aha, day 2, continuity, direction starters).
  static bool showBottomRetentionCards({
    required bool loaded,
    required int entryCount,
  }) =>
      loaded && hasComparisonSeed(entryCount);

  /// Aha / proof share cards — need real archive depth.
  static bool showAhaMomentCards({
    required bool loaded,
    required int entryCount,
  }) =>
      loaded && hasPatternEvidence(entryCount);

  /// Journey, repeat, and retention cards in the main column.
  static bool allowArchiveProgressUi({
    required bool loaded,
    required int entryCount,
  }) =>
      loaded && hasComparisonSeed(entryCount);

  /// Zero-entry Record tab — one hero + one capture block, no competing cards.
  static bool showFirstUseSimplifiedRecord({
    required bool loaded,
    required int entryCount,
  }) =>
      loaded && hasNoEntries(entryCount);

  /// Daily map prompt on Record — zero through returning users.
  static bool showDailyArchiveExerciseOnRecord({
    required bool loaded,
    required int entryCount,
  }) =>
      loaded;

  /// Today's one question on Record — after the first save.
  static bool showTodaysQuestionOnRecord({
    required bool loaded,
    required int entryCount,
  }) =>
      loaded && !hasNoEntries(entryCount);

  /// Review/evidence next-step prompts belong on Patterns, not Record.
  static bool showNextMomentPromptOnRecord({
    required bool loaded,
    required int entryCount,
  }) =>
      false;
}
