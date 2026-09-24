/// Feature noise reduction copy — keep the first proof journey clear.
abstract final class FeatureNoiseReductionCopy {
  FeatureNoiseReductionCopy._();

  static const headline = 'Keep the first journey clear';

  static const body =
      'ArchiveMe should show only what helps the user save a repeat, understand the '
      'first proof, correct it, and see the longer trail.';

  static const coreJourneyLine =
      'Core journey: record, first proof, why it appeared, confirm or correct, longer '
      'trail, Pro.';

  static const hideEarlyLine =
      'Hide reports, action items, archive health, context detail, quick actions, and '
      'review surfaces until they clearly support the proof trail.';

  static const notDeletedLine =
      'Hidden does not mean removed. Later-stage features can return when the user has '
      'enough evidence.';

  static const lowEffortLine =
      'The product should feel like a quiet proof trail, not a workspace to manage.';

  static const proLine = 'Pro should stay focused on keeping the longer trail.';

  static const guardrail =
      'Do not let secondary surfaces compete with the first proof journey.';

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield coreJourneyLine;
    yield hideEarlyLine;
    yield notDeletedLine;
    yield lowEffortLine;
    yield proLine;
    yield guardrail;
  }
}
