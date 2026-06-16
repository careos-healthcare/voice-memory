/// User-facing copy for the post-save heard/read-back card.
abstract class PostSaveRecordedSummaryCopy {
  PostSaveRecordedSummaryCopy._();

  static const String listeningTitle = 'Listening back...';
  static const String listeningBody =
      'ArchiveMe is turning your recording into text.';

  static const String title = 'What ArchiveMe heard';
  static const String whatThisAddedTitle = 'What this added';
  static const String whatChangedTitle = 'What changed';
  static const String connectToRepeatLabel = 'This may connect to a repeat:';
  static const String tomorrowCheckThisLabel = 'Tomorrow, check this:';

  static const String emptyFallback =
      'Recording saved. ArchiveMe will use this moment when there is enough to compare.';
  static const String firstEntryFootnote =
      'Saved privately. Come back with one more moment and ArchiveMe can begin comparing.';
  static const String safeSavedPrivately = 'Saved privately.';
  static const String safeNoGuessing =
      'ArchiveMe will only show a pattern when your own words support it.';

  static const List<String> all = [
    listeningTitle,
    listeningBody,
    title,
    whatThisAddedTitle,
    whatChangedTitle,
    emptyFallback,
    firstEntryFootnote,
    safeSavedPrivately,
    safeNoGuessing,
  ];
}
