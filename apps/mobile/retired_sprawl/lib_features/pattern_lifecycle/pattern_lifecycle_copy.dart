import 'package:archiveme_mobile/features/pattern_lifecycle/pattern_lifecycle_model.dart';

/// User-facing copy for pattern lifecycle stages.
abstract final class PatternLifecycleCopy {
  PatternLifecycleCopy._();

  static const formingLabel = 'Forming';

  static const formingBody =
      'ArchiveMe is collecting evidence. One more related moment may turn this into a pattern.';

  static const repeatedLabel = 'Repeated';

  static const repeatedBody =
      'This has appeared across 3+ related saved moments.';

  static const watchingLabel = 'Watching';

  static const watchingBody =
      'ArchiveMe is watching whether this comes back, changes, or stays quiet.';

  static const changingLabel = 'Changing';

  static const changingBody =
      'This pattern has returned, and the latest evidence looks different.';

  static const softeningLabel = 'Softening';

  static const softeningBody =
      'This has repeated before, but the latest evidence looks softer.';

  static const quietLabel = 'Quiet';

  static const quietBody =
      'This has not shown up recently. That may matter too.';

  static String labelFor(PatternLifecycleState state) => switch (state) {
    PatternLifecycleState.forming => formingLabel,
    PatternLifecycleState.repeated => repeatedLabel,
    PatternLifecycleState.watching => watchingLabel,
    PatternLifecycleState.changing => changingLabel,
    PatternLifecycleState.softening => softeningLabel,
    PatternLifecycleState.quiet => quietLabel,
  };

  static String bodyFor(PatternLifecycleState state) => switch (state) {
    PatternLifecycleState.forming => formingBody,
    PatternLifecycleState.repeated => repeatedBody,
    PatternLifecycleState.watching => watchingBody,
    PatternLifecycleState.changing => changingBody,
    PatternLifecycleState.softening => softeningBody,
    PatternLifecycleState.quiet => quietBody,
  };

  static List<String> allVisibleStrings() => [
    formingLabel,
    formingBody,
    repeatedLabel,
    repeatedBody,
    watchingLabel,
    watchingBody,
    changingLabel,
    changingBody,
    softeningLabel,
    softeningBody,
    quietLabel,
    quietBody,
  ];
}