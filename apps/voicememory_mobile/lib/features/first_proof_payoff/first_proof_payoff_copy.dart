/// Copy for the first proof emotional payoff — grounded, non-diagnostic.
abstract final class FirstProofPayoffCopy {
  FirstProofPayoffCopy._();

  static const headline = 'This came back.';

  static const subheadWithSnippets =
      'Across three moments, your archive noticed:';

  static const subheadFallback =
      'ArchiveMe found this repeat across three real moments.';

  static const evidenceLabel = 'Evidence from your words';

  static const meaningLine = 'That may be worth watching.';

  static const returnHook =
      'Next time it shows up, ArchiveMe can compare what changed.';

  static const watchThisNextCta = 'Watch this next';

  static const viewPatternDetailsCta = 'View pattern details';

  static const firstSnippetLabel = 'You said:';
  static const laterSnippetLabel = 'Then later:';
  static const thirdSnippetLabel = 'And again:';

  static String groundedPhraseLine(String phrase) => phrase.trim();

  static String formatQuotedSnippet(String snippet) {
    final trimmed = snippet.trim();
    if (trimmed.isEmpty) return '';
    return '‘$trimmed’';
  }

  static List<String> allVisibleStrings() => [
        headline,
        subheadWithSnippets,
        subheadFallback,
        evidenceLabel,
        meaningLine,
        returnHook,
        watchThisNextCta,
        viewPatternDetailsCta,
        firstSnippetLabel,
        laterSnippetLabel,
        thirdSnippetLabel,
      ];
}
