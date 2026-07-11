/// V1 surface scope audit copy — core visible, secondary hidden, no deletion.
abstract final class V1SurfaceScopeAuditCopy {
  V1SurfaceScopeAuditCopy._();

  static const headline = 'V1 surface scope audit';

  static const body =
      'Reduce first-release risk by keeping core surfaces visible and moving '
      'secondary surfaces out of the default journey. No product deletion.';

  static const coreLine =
      'Core V1: record, save, post-save reinforcement, prompt assist, first proof, '
      'why proof appeared, confirm/correct, Pro longer proof trail, restore purchases, '
      'privacy/support.';

  static const secondaryLine =
      'Secondary hidden: reports, dashboards, action items, archive packs, archive '
      'analyst, search, calendar, widgets, monthly reviews, share cards, action plans, '
      'context maps.';

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
