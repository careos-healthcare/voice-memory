/// Stable product copy for proof selection — selection, not ranking.
abstract final class ProofSelectionPrincipleCopy {
  ProofSelectionPrincipleCopy._();

  static const headline = 'Why this proof appears first';

  static const body =
      'ArchiveMe shows the clearest specific repeat it can compare safely right '
      'now. It is not saying this is the most important thing. You can confirm '
      'it or correct it.';

  static const guardrail =
      'Do not rank patterns until users consistently understand and trust one '
      'proof moment.';

  static const decisionLabel = 'Selection, not ranking';

  static const whyThisOneLine =
      'Why this one: ArchiveMe is showing the clearest specific repeat it can '
      'compare safely right now.';

  static const notRankingOrMostImportantLine =
      'It is not ranking every past mention yet, and it is not saying this is '
      'the most important thing.';

  static const correctionLine =
      'If this feels wrong, mark it Too vague or Not relevant.';

  static const bannedPhrases = [
    'ranked list',
    'importance score',
    'importance scoring',
    'most important pattern',
    'the key issue',
    'you should',
    'you need to',
    'therapy',
    'diagnosis',
    'coach',
    'coaching',
    'advice',
  ];

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield guardrail;
    yield decisionLabel;
    yield whyThisOneLine;
    yield notRankingOrMostImportantLine;
    yield correctionLine;
  }
}