/// Copy for the saved-moments archive history sheet.
abstract final class ArchiveHistoryCopy {
  ArchiveHistoryCopy._();

  static const sheetTitle = 'Saved moments';
  static const sheetSubtitle =
      'Your archive is built from what you record. Private by default.';

  static const emptyTitle = 'No saved moments yet';
  static const emptyBody = 'Record one real moment to start your archive.';

  static const chipUsedAsEvidence = 'Used as evidence';
  static const chipSavedOnly = 'Saved only';
  static const chipTranscriptPending = 'Transcript pending';
  static const chipNeedsYourWords = 'Needs your words';
  static const chipIgnoredForPatterns = 'Ignored for patterns';

  static const pendingPreview =
      'Voice moment saved. Transcript needs your words.';

  static const noteUsedAsEvidence = 'Helped ArchiveMe spot a repeat.';
  static const noteNeedsYourWords =
      'Add what you said so ArchiveMe can use it.';
  static const noteIgnoredForPatterns = 'Saved, but not used as evidence.';

  static const addWordsCta = 'Add words';

  static const List<String> all = [
    sheetTitle,
    sheetSubtitle,
    emptyTitle,
    emptyBody,
    chipUsedAsEvidence,
    chipSavedOnly,
    chipTranscriptPending,
    chipNeedsYourWords,
    chipIgnoredForPatterns,
    pendingPreview,
    noteUsedAsEvidence,
    noteNeedsYourWords,
    noteIgnoredForPatterns,
    addWordsCta,
  ];
}
