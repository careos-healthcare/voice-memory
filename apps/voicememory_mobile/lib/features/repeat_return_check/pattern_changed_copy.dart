/// Copy for pattern-changed celebration — grounded repeat return checks only.
abstract final class PatternChangedCopy {
  PatternChangedCopy._();

  static const softerTitle = 'What changed: softer';

  static const softerBody =
      'ArchiveMe noticed this showed up with less urgency than before. Pro keeps the timeline so '
      'ArchiveMe can compare returns over time.';

  static const changedTitle = 'What changed this time';

  static const changedBody =
      'ArchiveMe noticed this did not show up the same way as before. '
      'Pro keeps tracking what changed over time.';

  static const strongerTitle = 'What changed: stronger';

  static const strongerBody =
      'ArchiveMe noticed this showed up with more intensity than before. Pro keeps the evidence '
      'history as the trail grows.';

  static const recordIfReturnsCta = 'Record when it returns';

  static const dismiss = 'Dismiss';
}
