/// Copy for the helpful-action appeared payoff — evidence, not advice.
abstract final class HelpfulActionAppearedCopy {
  HelpfulActionAppearedCopy._();

  static const title = 'A helpful action appeared';

  static const evidenceLabel = 'Evidence, not advice';

  static const footer =
      'This is not a suggestion — it is something that appeared in your words.';

  static const chipLabel = 'Appeared to help';

  static const bodyFallback =
      'ArchiveMe noticed a possible helpful action. Record again when the repeat '
      'comes back so it can check whether this holds.';

  static String bodyWithPhrase(String action) =>
      'You mentioned "$action". ArchiveMe is watching whether this shows up again '
      'when the repeat comes back.';
}
