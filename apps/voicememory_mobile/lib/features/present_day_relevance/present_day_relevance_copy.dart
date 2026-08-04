import 'present_day_relevance_model.dart';

/// Copy for present-day relevance — trust layer only, no new interpretation.
abstract final class PresentDayRelevanceCopy {
  PresentDayRelevanceCopy._();

  static const title = 'Why this may matter now';

  static const primaryBody =
      'This is not important just because it happened before. It may matter if '
      'it still affects what you notice, avoid, repeat, choose, or come back to now.';

  static const currentStateBody =
      'This looks current because it has shown up again in recent saved moments.';

  static const fadingStateBody =
      'ArchiveMe gives this less weight when it has not appeared recently.';

  static const softenedStateBody =
      'This may still matter, but it seems to be changing.';

  static const unclearStateBody =
      'ArchiveMe will keep this lightly in view until there is stronger current evidence.';

  static const footer = 'Your past is context, not a verdict.';

  static const differentiationLine =
      'ChatGPT can help with what you ask today. ArchiveMe shows whether today '
      'is connected to what has kept returning.';

  static String stateBodyFor(PresentDayRelevanceState state) => switch (state) {
    PresentDayRelevanceState.current => currentStateBody,
    PresentDayRelevanceState.fading => fadingStateBody,
    PresentDayRelevanceState.softened => softenedStateBody,
    PresentDayRelevanceState.unclear => unclearStateBody,
  };

  static const List<String> all = [
    title,
    primaryBody,
    currentStateBody,
    fadingStateBody,
    softenedStateBody,
    unclearStateBody,
    footer,
    differentiationLine,
  ];
}
