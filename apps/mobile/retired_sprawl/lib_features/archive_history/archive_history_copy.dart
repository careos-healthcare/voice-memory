/// Copy for the saved-moments archive history sheet.
abstract final class ArchiveHistoryCopy {
  ArchiveHistoryCopy._();

  static const sheetTitle = 'Saved moments';
  static const sheetSubtitle =
      'Your archive is built from what you record. Private by default.';

  static const emptyTitle = 'No saved moments yet';
  static const emptyBody =
      'Record a few real moments. ArchiveMe will look for what repeats across them.';

  static const chipUsedAsEvidence = 'Used as evidence';
  static const chipSavedOnly = 'Saved only';
  static const chipTranscriptPending = 'Transcript pending';
  static const chipNeedsYourWords = 'Needs your words';
  static const chipIgnoredForPatterns = 'Ignored for patterns';
  static const chipExcludedFromPattern = 'Excluded from pattern';

  static const pendingPreview =
      'Voice moment saved. Transcript needs your words.';

  static const noteUsedAsEvidence = 'Helped ArchiveMe spot a repeat.';
  static const noteNeedsYourWords =
      'Add what you said so ArchiveMe can use it.';
  static const noteIgnoredForPatterns = 'Saved, but not used as evidence.';
  static const noteExcludedFromPattern =
      'Saved, but not used as evidence for this pattern.';

  static const addWordsCta = 'Add words';

  static const filterAll = 'All';
  static const filterUsedAsEvidence = 'Used as evidence';
  static const filterSavedOnly = 'Saved only';
  static const filterNeedsYourWords = 'Needs your words';
  static const filterQuietDays = 'Quiet days';
  static const filterIgnoredForPatterns = 'Ignored for patterns';
  static const filterHelped = 'Helped';

  static const filteredEmptyTitle = 'Nothing here yet';
  static const filteredEmptyBody =
      'Moments will appear here when they match this filter.';

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
    chipExcludedFromPattern,
    pendingPreview,
    noteUsedAsEvidence,
    noteNeedsYourWords,
    noteIgnoredForPatterns,
    noteExcludedFromPattern,
    addWordsCta,
    filterAll,
    filterUsedAsEvidence,
    filterSavedOnly,
    filterNeedsYourWords,
    filterQuietDays,
    filterIgnoredForPatterns,
    filterHelped,
    filteredEmptyTitle,
    filteredEmptyBody,
  ];
}
