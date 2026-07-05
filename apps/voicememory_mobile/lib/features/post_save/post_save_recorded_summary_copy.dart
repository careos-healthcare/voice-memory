import '../low_evidence/low_evidence_copy.dart';

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
  static const String noPatternReassurance = LowEvidenceCopy.postSaveNoRepeat;
  static const String quietDaySaved = 'Saved as a quiet day.';
  static const String quietDayWatching =
      'ArchiveMe will keep watching when something stands out.';

  static const String lowSignalWhatThisAddedBody =
      'This was saved, but it does not add enough detail for ArchiveMe to connect it yet.';
  static const String lowSignalPrompt =
      'Add one real moment with a little more detail when you\'re ready.';
  static const String lowSignalAddDetailCta = 'Add more detail';
  static const String lowSignalBackToRecordCta = 'Back to Record';

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
    lowSignalWhatThisAddedBody,
    lowSignalPrompt,
    lowSignalAddDetailCta,
    lowSignalBackToRecordCta,
  ];
}
