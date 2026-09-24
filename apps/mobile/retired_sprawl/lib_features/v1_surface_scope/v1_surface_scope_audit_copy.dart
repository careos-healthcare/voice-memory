/// V1 surface scope audit copy — core visible, secondary hidden, no deletion.
abstract final class V1SurfaceScopeAuditCopy {
  V1SurfaceScopeAuditCopy._();

  static const headline = 'V1 surface scope audit';

  static const body =
      'Reduce first-release risk by keeping core surfaces visible and moving '
      'secondary surfaces out of the default journey. No product deletion.';

  static const coreLine =
      'Core V1: record one real moment, return later, first useful proof, confirm or '
      'correct, Pro longer proof trail, live billing verification, wedge acquisition into '
      'record-return-proof loop, restore purchases, privacy/support.';

  static const secondaryLine =
      'Secondary hidden: private reports, exports, referrals, safe sharing, dashboards, '
      'action items, archive packs, archive analyst, search, calendar, widgets, monthly '
      'reviews, share cards, action plans, context maps, Android, B2B, loop packs, '
      'premium tiers.';

  static const blockerLine =
      'Release blocker only: purchase, restore, entitlement, TestFlight, metadata, '
      'privacy, support, secrets.';

  static const guardrail =
      'No product deletion. No layout changes unless a release blocker is found.';

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield coreLine;
    yield secondaryLine;
    yield blockerLine;
  }
}
