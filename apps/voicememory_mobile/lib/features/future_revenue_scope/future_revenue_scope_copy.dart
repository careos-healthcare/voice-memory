/// Future revenue scope copy — block live V1 claims for deferred paid directions.
abstract final class FutureRevenueScopeCopy {
  FutureRevenueScopeCopy._();

  static const headline = 'Future revenue scope lock';

  static const body =
      'Reports, exports, referrals, safe sharing, cross-device continuity, Android '
      'expansion, B2B, annual plan, premium tiers, private reports, and loop packs '
      'stay future-only until TestFlight proof.';

  static const v1GrowthLoopLine =
      'Safe sharing is not a V1 growth loop. Keep sharing explicit, future-gated, '
      'and product-insight only.';

  static const guardrail =
      'Do not surface future revenue directions as live V1 claims. Hide or gate '
      'them until proof and beta validation complete. Revenue focus: sharper packaging, '
      'live billing, wedge acquisition, cleaner first proof journey — not more product surface.';

  static const futureDirections = <String>[
    'reports',
    'exports',
    'referrals',
    'safe sharing',
    'cross-device continuity',
    'android expansion',
    'b2b',
    'annual plan',
    'premium tiers',
    'private reports',
    'loop packs',
    'contradiction detection',
    'archive memory expansion',
    'ranking / importance surfaces',
    'importance surfaces',
  ];

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield v1GrowthLoopLine;
    yield guardrail;
    yield* futureDirections;
  }
}
