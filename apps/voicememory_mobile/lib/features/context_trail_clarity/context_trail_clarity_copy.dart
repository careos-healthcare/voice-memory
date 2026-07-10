/// Context trail clarity copy — optional context enrichment, not manual organisation.
abstract final class ContextTrailClarityCopy {
  ContextTrailClarityCopy._();

  static const headline = 'Where the repeat shows up';

  static const body =
      'Context helps ArchiveMe show where a repeat appears — work, home, family, '
      'money, health, decisions, relationships, or somewhere else. You do not need '
      'to tag everything.';

  static const optionalLine =
      'Context is optional. The proof trail still works from saved moments.';

  static const evidenceLine =
      'Context helps explain where the evidence came from.';

  static const notMaintenanceLine =
      'No manual map maintenance. No tagging homework.';

  static const trailLine =
      'Use context only when it makes the repeat clearer.';

  static const proLaterLine =
      'Over time, Pro can keep a longer context trail — where the same repeat '
      'returns, changes, fades, or gets corrected.';

  static const guardrail =
      'Context must support the proof trail. It must not become a required tagging '
      'system, dashboard, ranking tool, or mind-map maintenance task.';

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield optionalLine;
    yield evidenceLine;
    yield notMaintenanceLine;
    yield trailLine;
    yield proLaterLine;
  }
}
