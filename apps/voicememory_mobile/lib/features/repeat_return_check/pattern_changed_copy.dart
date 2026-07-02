/// Copy for pattern-changed celebration — grounded repeat return checks only.
abstract final class PatternChangedCopy {
  PatternChangedCopy._();

  static const softerTitle = 'Softer this time';

  static const softerBody =
      'ArchiveMe noticed this return showed up with less urgency than earlier '
      'returns. Pro keeps the timeline so ArchiveMe can compare returns over time.';

  static const changedTitle = 'Different this time';

  static const changedBody =
      'ArchiveMe noticed this did not show up the same way as earlier returns. '
      'Pro keeps tracking what changed over time.';

  static const strongerTitle = 'Stronger this time';

  static const strongerBody =
      'ArchiveMe noticed this return showed up with more intensity than earlier '
      'returns. Pro keeps the evidence history as the trail grows.';

  static const recordIfReturnsCta = 'Record when it returns';

  static const dismiss = 'Dismiss';
}
