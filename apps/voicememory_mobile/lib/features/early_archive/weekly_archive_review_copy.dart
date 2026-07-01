/// Copy for the compact weekly archive review card.
abstract final class WeeklyArchiveWeekReviewCopy {
  WeeklyArchiveWeekReviewCopy._();

  static const title = 'This week in your archive';

  static const promise =
      'Your archive is starting to show what repeated, what changed, and what helped.';

  static const repeatedLabel = 'Repeated';
  static const repeatedFallback = 'No clear repeat yet.';

  static const changedLabel = 'Changed';
  static const changedLouder = 'The repeat got louder.';
  static const changedSame = 'The repeat felt about the same.';
  static const changedSofter = 'The repeat softened.';
  static const changedFallback = 'Not enough return checks yet.';

  static const helpedLabel = 'Helped';
  static const helpedPrefix = 'ArchiveMe noticed this helped before:';
  static const helpedFallback = 'No repeated helpful action yet.';

  static const nextToWatchLabel = 'Next to watch';
  static const nextToWatchFallback = 'Record the next real moment.';

  static const recordCta = "Record next week's evidence";

  static const recordGuidedPrompt = 'What happened in this moment?';
}
