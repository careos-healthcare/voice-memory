/// Copy for the first confirmed-repeat payoff after the third related save.
abstract final class FirstProofMomentCopy {
  FirstProofMomentCopy._();

  static const title = 'ArchiveMe found your first repeat';

  static const bodyFallback =
      'ArchiveMe found a repeat across three moments. That is enough to start tracking whether this gets stronger, softer, or changes.';

  static const evidenceLabel = 'Evidence from your words';

  static const whyLine =
      'This is the first moment your archive becomes useful.';

  static const footer =
      'Keep recording when it shows up again — ArchiveMe will track what changes.';

  static String bodyWithPhrase(String phrase) =>
      'You mentioned “$phrase” across three moments. That is enough for ArchiveMe to start tracking whether this gets stronger, softer, or changes.';
}
