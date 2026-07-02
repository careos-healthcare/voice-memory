/// Static labels for the archive belief proof surface.
abstract final class ArchiveBeliefSurfaceCopy {
  static const headline = 'Your archive currently believes…';

  static const headlineStarting =
      'Your archive is starting to track repeated evidence';

  static const evidenceLabel = 'Based on these moments…';

  static const whatChangedLabel = 'What changed recently';

  static const watchingLabel = 'Still watching…';

  static const confidenceLabel = 'Signal strength:';

  static const recordNextCta = 'Record this next';

  static const previewBadge = 'Preview — not a conclusion yet';

  static const beliefFallback =
      'Similar evidence may be forming across these moments.';

  static const whatChangedFallback =
      'Not enough return checks yet to compare what changed.';

  static const watchingFallback =
      'Still watching… what happens the next time this shows up.';

  static const watchingAllKnown =
      'Still watching… how this changes on the next return.';

  static String beliefWithPhrase(String phrase) =>
      '“$phrase” keeps appearing across these moments.';

  static String stillWatching(String focus) => 'Still watching… $focus.';
}
