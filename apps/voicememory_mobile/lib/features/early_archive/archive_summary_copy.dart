/// Copy for the unified Archive Summary card.
abstract final class ArchiveSummaryCopy {
  ArchiveSummaryCopy._();

  static const title = 'Your archive so far';

  static const keepsRepeatingLabel = 'Keeps repeating';
  static const keepsRepeatingFallback =
      'ArchiveMe is still watching for a clear repeat.';

  static const loopFormingLabel = 'Loop forming';
  static const changingLabel = 'Changing';
  static const changingFallback =
      'Record the next time it happens to see whether it changes.';
  static const whatHelpsLabel = 'What helps';
  static const whatHelpsFallback =
      'ArchiveMe has not found a repeated helpful action yet.';
  static const whatHelpsPrefix = 'ArchiveMe noticed this helped before:';

  static const recordNextLabel = 'Record next';
  static const recordNextCta = 'Record the next piece';

  static const recordNextTriggerUnknown =
      'Record what happened before it appeared.';
  static const recordNextThoughtUnknown =
      'Record what your mind said in the moment.';
  static const recordNextActionUnknown = 'Record what you did next.';
  static const recordNextResultUnknown =
      'Record whether it helped, cost you, or changed.';
  static const recordNextChangeUnknown = 'Record the next time it happens.';
  static const recordNextPositiveMissing = 'Record what helped today.';

  static const recordNextChangeGuided =
      'What happened when this came up again?';
}
