/// Copy for the first confirmed-repeat payoff after the third related save.
abstract final class FirstProofMomentCopy {
  FirstProofMomentCopy._();

  static const title = 'ArchiveMe found a repeat in your words';

  static const titlePossible = 'ArchiveMe found a possible repeat';

  static const bodyFallback =
      'ArchiveMe noticed a possible repeat across three moments. When it shows up in your words again, your archive can compare whether it holds.';

  static const bodyFallbackStrong =
      'ArchiveMe found repeated evidence across three moments. Your archive is watching whether this gets stronger, softer, or changes.';

  static const evidenceLabel = 'Evidence from your words';

  static const whyLine =
      'Three related moments — your first proof of a repeat in your own words.';

  static const footer =
      'ArchiveMe is watching whether this changes when it shows up again in your words.';

  static String bodyWithPhrase(String phrase) =>
      'This showed up again in your words: “$phrase”. ArchiveMe found this repeat across three moments.';
}
