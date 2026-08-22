/// Copy for the first proof truth follow-up — non-diagnostic, no advice.
abstract final class FirstProofTruthCopy {
  FirstProofTruthCopy._();

  static const question = 'Does this feel true?';

  static const yesOption = 'Yes';
  static const sortOfOption = 'Sort of';
  static const noOption = 'No';

  static const afterYes = 'Good. ArchiveMe will watch whether it changes.';

  static const afterSortOf =
      'Okay. You can rename the pattern or keep recording so ArchiveMe gets clearer.';

  static const afterNo =
      'Okay. You can rename it, correct the transcript, or ignore this pattern.';

  static List<String> allVisibleStrings() => [
    question,
    yesOption,
    sortOfOption,
    noOption,
    afterYes,
    afterSortOf,
    afterNo,
  ];
}