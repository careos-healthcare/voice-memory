/// Copy for the compact weekly archive review card.
abstract final class WeeklyArchiveWeekReviewCopy {
  WeeklyArchiveWeekReviewCopy._();

  static const title = 'This week in your archive';

  static const promise =
      'Free shows what repeated this week. Pro keeps weekly reviews to compare '
      'stronger, softer, and what changed over time.';

  static const repeatedLabel = 'What repeated this week';
  static const repeatedFallback = 'No clear repeat yet.';

  static const changedLabel = 'What changed this week';
  static const changedLouder = 'Stronger this week.';
  static const changedSame = 'About the same this week.';
  static const changedSofter = 'Softer this week.';
  static const changedFallback = 'Not enough return checks yet.';

  static const helpedLabel = 'Appeared to help';
  static const helpedPrefix = 'ArchiveMe noticed this in your words before:';
  static const helpedFallback = 'No repeated helpful evidence in your words yet.';

  static const nextToWatchLabel = 'What ArchiveMe is watching next';
  static const nextToWatchFallback = 'Record the next real moment.';

  static const recordCta = "Record next week's evidence";

  static const recordGuidedPrompt = 'What happened in this moment?';
}
