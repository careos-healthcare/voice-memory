import 'pattern_confidence_model.dart';

/// User-facing copy for pattern evidence-strength labels.
abstract final class PatternConfidenceCopy {
  PatternConfidenceCopy._();

  static const earlySignalLabel = 'Early signal';

  static const earlySignalBody =
      'Seen in 2 saved moments. ArchiveMe needs one more related moment before calling it a pattern.';

  static const repeatedPatternLabel = 'Repeated pattern';

  static const repeatedPatternBody =
      'Seen across 3+ related saved moments.';

  static const changingPatternLabel = 'Changing pattern';

  static const changingPatternBody =
      'Repeated before, with later evidence that something may be changing.';

  static const softeningPatternLabel = 'Softening pattern';

  static const softeningPatternBody =
      'Repeated before, but the latest evidence looks softer.';

  static const notEnoughYetLabel = 'Not enough yet';

  static const notEnoughYetBody =
      'ArchiveMe needs more real moments before showing a pattern.';

  static String labelFor(PatternConfidenceState state) => switch (state) {
        PatternConfidenceState.earlySignal => earlySignalLabel,
        PatternConfidenceState.repeatedPattern => repeatedPatternLabel,
        PatternConfidenceState.changingPattern => changingPatternLabel,
        PatternConfidenceState.softeningPattern => softeningPatternLabel,
        PatternConfidenceState.notEnoughYet => notEnoughYetLabel,
      };

  static String bodyFor(PatternConfidenceState state) => switch (state) {
        PatternConfidenceState.earlySignal => earlySignalBody,
        PatternConfidenceState.repeatedPattern => repeatedPatternBody,
        PatternConfidenceState.changingPattern => changingPatternBody,
        PatternConfidenceState.softeningPattern => softeningPatternBody,
        PatternConfidenceState.notEnoughYet => notEnoughYetBody,
      };

  static List<String> allVisibleStrings() => [
        earlySignalLabel,
        earlySignalBody,
        repeatedPatternLabel,
        repeatedPatternBody,
        changingPatternLabel,
        changingPatternBody,
        softeningPatternLabel,
        softeningPatternBody,
        notEnoughYetLabel,
        notEnoughYetBody,
      ];
}
