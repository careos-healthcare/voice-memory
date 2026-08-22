/// No dashboard positioning guard copy — ArchiveMe is a proof trail, not a life dashboard.
abstract final class NoDashboardPositioningGuardCopy {
  NoDashboardPositioningGuardCopy._();

  static const headline = 'ArchiveMe is not a life dashboard';

  static const body =
      'ArchiveMe is a quietly preserved proof trail. Save one repeat, see the first '
      'useful proof, and let the longer proof trail show what returned, changed, faded, '
      'or was corrected.';

  static const preferredLanguageLine =
      'Use proof trail, one repeat, first useful proof, longer proof trail, '
      'returns/changes/fades/corrected, and one sentence is enough.';

  static const avoidLanguageLine =
      'Avoid dashboard, command center, life operating system, second brain, '
      'productivity system, personal analytics dashboard, full life report, and '
      'action plan manager positioning.';

  static const blockLine =
      'This copy frames ArchiveMe as something users must maintain. Rewrite with proof-trail language.';

  static const warnLine =
      'This copy may feel like maintenance-heavy product framing. Prefer proof-trail language instead.';

  static const guardrail =
      'Copy guard only. No UI changes unless a first-journey blocker exists.';

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield preferredLanguageLine;
    yield avoidLanguageLine;
    yield blockLine;
    yield warnLine;
    yield guardrail;
  }
}