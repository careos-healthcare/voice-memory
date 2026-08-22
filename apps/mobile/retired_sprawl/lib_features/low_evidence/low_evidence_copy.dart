/// Reassuring copy when ArchiveMe does not yet have enough evidence.
abstract final class LowEvidenceCopy {
  LowEvidenceCopy._();

  static const oneEntryTitle = 'Your archive has started';
  static const oneEntryBody =
      'One real moment is enough to begin. Come back when this shows up again.';

  static const twoUnrelatedTitle = 'Nothing clear yet — that is normal';
  static const twoUnrelatedBody =
      'Your archive is still collecting real moments. Keep recording what stands out, even if it feels small.';

  static const twoRelatedTitle =
      'One more related moment may unlock first proof';
  static const twoRelatedBody =
      'ArchiveMe is watching whether this thread comes back again.';

  static const genericTestTitle = 'Patterns are still forming';
  static const genericTestBody =
      'ArchiveMe needs clearer real moments before it can compare what repeats.';

  static const quietDayTitle = 'Quiet days count';
  static const quietDayBody =
      'ArchiveMe will keep watching when something stands out.';

  static const postSaveNoRepeat =
      'Saved. ArchiveMe does not need every entry to become a pattern.';

  static List<String> allVisibleStrings() => [
    oneEntryTitle,
    oneEntryBody,
    twoUnrelatedTitle,
    twoUnrelatedBody,
    twoRelatedTitle,
    twoRelatedBody,
    genericTestTitle,
    genericTestBody,
    quietDayTitle,
    quietDayBody,
    postSaveNoRepeat,
  ];
}