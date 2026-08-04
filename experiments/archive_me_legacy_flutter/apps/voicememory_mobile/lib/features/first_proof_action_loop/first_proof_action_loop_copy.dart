/// Copy for the first proof action loop — next steps after truth answer.
abstract final class FirstProofActionLoopCopy {
  FirstProofActionLoopCopy._();

  static const yesTitle = 'Good. ArchiveMe will watch whether it changes.';
  static const sortOfTitle = 'Okay. Make the pattern fit your words.';
  static const noTitle = 'Okay. You stay in control.';

  static const watchThisNextCta = 'Watch this next';
  static const viewPatternDetailsCta = 'View pattern details';
  static const renamePatternCta = 'Rename pattern';
  static const keepRecordingCta = 'Keep recording';
  static const correctTranscriptCta = 'Correct transcript';
  static const removeFromPatternCta = 'Remove from this pattern';

  static List<String> allVisibleStrings() => [
    yesTitle,
    sortOfTitle,
    noTitle,
    watchThisNextCta,
    viewPatternDetailsCta,
    renamePatternCta,
    keepRecordingCta,
    correctTranscriptCta,
    removeFromPatternCta,
  ];
}
