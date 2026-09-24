/// Copy for the first confirmed-repeat payoff after the third related save.
abstract final class FirstProofMomentCopy {
  FirstProofMomentCopy._();

  static const primaryLabel = 'First proof unlocked';

  static const title = 'Thoughtprint found a repeat in your words';

  static const titlePossible = 'Thoughtprint found a possible repeat';

  static const bodyStrong = 'This showed up across three related moments.';

  static const bodyFallback =
      'Thoughtprint noticed a possible repeat across three moments. When it shows up in your words again, your archive can compare whether it holds.';

  static const evidenceLabel = 'Evidence from your words';

  static const whyLine =
      'Three related moments — your first proof of a repeat in your own words.';

  static const nextLine =
      'Next: record when this comes back so Thoughtprint can compare what changed.';

  static List<String> get allVisibleStrings => [
    primaryLabel,
    title,
    titlePossible,
    bodyStrong,
    bodyFallback,
    evidenceLabel,
    whyLine,
    nextLine,
  ];
}