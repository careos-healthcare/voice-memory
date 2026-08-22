import 'package:archiveme_mobile/features/v1_interface/v1_core_product_sentence.dart';

/// Blocked V1 expansion surfaces — docs/tests only until proof and paid intent pass.
abstract final class V1ExpansionGateCopy {
  V1ExpansionGateCopy._();

  static const headline = 'V1 expansion gates';

  static const expansionBlockedLine =
      'Expansion is blocked until V1 proof passes.';

  static const sharperV1MoveLine =
      'The best next move is not more product expansion. It is a sharper V1:';

  static const String coreV1Sentence = V1CoreProductSentence.line;

  static const manifestoRef =
      'The revenue increase now comes from sharper packaging, live billing, wedge '
      'acquisition, and a cleaner first proof journey — not more product surface.';

  static const expansionGatesDocPath = 'docs/V1_EXPANSION_GATES.md';

  static const blockedExpansionIdeas = <String>[
    'three-day proof challenge',
    'one-tap return check-ins expansion beyond existing light check-ins',
    'private monthly report',
    'ask your archive',
    'search as memory retrieval',
    'export as premium ownership feature if not fully tested',
    'cross-device continuity',
    'additional wedge landing pages',
    'founder pro beta',
    'private report pro trigger',
    'loop packs',
    'b2b-lite workplace pressure archive',
    'affiliate/partner niches',
    'annual plan',
  ];

  /// Back-compat alias for tests referencing the older name.
  static const List<String> blockedLiveSurfaces = blockedExpansionIdeas;

  static const requiredBeforeExpansion = <String>[
    'first useful proof on real archives',
    'live billing verified',
    'willingness-to-pay signals for longer trail',
    'beta proof thresholds met',
  ];

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield expansionBlockedLine;
    yield sharperV1MoveLine;
    yield coreV1Sentence;
    yield manifestoRef;
    yield* blockedExpansionIdeas;
    yield* requiredBeforeExpansion;
  }
}