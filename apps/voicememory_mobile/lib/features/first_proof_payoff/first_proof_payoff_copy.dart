/// Copy for the first proof emotional payoff — grounded, non-diagnostic.
abstract final class FirstProofPayoffCopy {
  FirstProofPayoffCopy._();

  static const headline = 'ArchiveMe noticed this came back';

  static const yourWordsLabel = 'Your words:';

  static const patternLine = 'That is the pattern.';

  static const truthLine =
      'This is not a diagnosis or advice. It is a repeat ArchiveMe found in your own words.';

  static const fallbackHeadline =
      'ArchiveMe noticed the same thread across your saved moments.';

  static const fallbackBody = 'Record one more real moment when it returns.';

  static const watchThisNextCta = 'Watch this next';

  static const viewPatternDetailsCta = 'View pattern details';

  /// Weak milestone copy that must not lead the payoff card.
  static const bannedMainLeads = [
    'First proof unlocked',
    'ArchiveMe found a repeat in your words',
    'This showed up across three related moments',
    'This came back.',
    'ArchiveMe found this repeat across three real moments',
    'Across three moments, your archive noticed:',
    'That may be worth watching.',
  ];

  static String formatBulletSnippet(String snippet) {
    final trimmed = snippet.trim();
    if (trimmed.isEmpty) return '';
    return '- "$trimmed"';
  }

  static List<String> allVisibleStrings() => [
        headline,
        yourWordsLabel,
        patternLine,
        truthLine,
        fallbackHeadline,
        fallbackBody,
        watchThisNextCta,
        viewPatternDetailsCta,
      ];
}
