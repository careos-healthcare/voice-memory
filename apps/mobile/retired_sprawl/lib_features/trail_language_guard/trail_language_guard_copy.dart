/// Trail language guard copy — prefer trail language over maintenance-heavy terms.
abstract final class TrailLanguageGuardCopy {
  TrailLanguageGuardCopy._();

  static const headline = 'ArchiveMe builds a trail';

  static const body =
      'You do not maintain a mind map. You save small real moments, and ArchiveMe '
      'builds the proof trail over time.';

  static const preferredLanguageLine =
      'Use trail, proof trail, evidence trail, saved moments, and what came back.';

  static const avoidLanguageLine =
      'Avoid mind-map maintenance, dashboard to maintain, daily tracking, streaks, '
      'and storage language.';

  static const whyTrailLine =
      'Trail language makes the product feel low-effort: save the repeat now, see '
      'what happened later.';

  static const proLine =
      'Pro keeps the longer trail of what returned, changed, faded, or was corrected.';

  static const guardrail =
      'ArchiveMe must sound like a quietly preserved proof trail, not a map, dashboard, '
      'tracker, or storage system the user has to maintain.';

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield preferredLanguageLine;
    yield avoidLanguageLine;
    yield whyTrailLine;
    yield proLine;
  }
}