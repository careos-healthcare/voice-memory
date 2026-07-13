/// Blocked V1 expansion surfaces — docs/tests only until proof and paid intent pass.
abstract final class V1ExpansionGateCopy {
  V1ExpansionGateCopy._();

  static const headline = 'V1 expansion gate';

  static const manifestoRef =
      'The revenue increase now comes from sharper packaging, live billing, wedge '
      'acquisition, and a cleaner first proof journey — not more product surface.';

  static const blockedLiveSurfaces = <String>[
    'three-day proof challenge',
    'private monthly report',
    'ask your archive',
    'memory-retrieval search upgrade',
    'loop packs',
    'b2b-lite',
    'affiliate/partner niches',
    'annual plan',
  ];

  static const requiredBeforeExpansion = <String>[
    'first useful proof on real archives',
    'live billing verified',
    'willingness-to-pay signals for longer trail',
    'beta proof thresholds met',
  ];

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield manifestoRef;
    yield* blockedLiveSurfaces;
    yield* requiredBeforeExpansion;
  }
}
