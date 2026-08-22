/// Copy for the positive reinforcement loop — grounded helpful actions only.
abstract final class PositiveReinforcementCopy {
  PositiveReinforcementCopy._();

  static const title = 'This appeared in your words again';

  static const body =
      'ArchiveMe noticed this showed up again in calmer moments from your own words.';

  static const recordAgainCta = 'Record when this helps again';

  static const guidedRecordPrompt = 'What showed up as helpful in your words?';

  static const completionTitle = 'Helpful evidence captured';

  static const completionBody =
      'ArchiveMe noticed this in your words and is watching whether it repeats.';
}