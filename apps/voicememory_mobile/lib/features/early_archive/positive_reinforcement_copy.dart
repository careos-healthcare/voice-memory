/// Copy for the positive reinforcement loop — grounded helpful actions only.
abstract final class PositiveReinforcementCopy {
  PositiveReinforcementCopy._();

  static const title = 'Try repeating what helped';

  static const body =
      'ArchiveMe noticed this showed up in better moments. Try watching for it again today.';

  static const recordAgainCta = 'Record when this helps again';

  static const guidedRecordPrompt = 'What helped in this moment?';

  static const completionTitle = 'That helped again.';

  static const completionBody =
      'ArchiveMe is adding this to your helpful patterns.';
}
