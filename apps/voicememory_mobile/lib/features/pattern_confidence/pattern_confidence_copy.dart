import 'pattern_confidence_model.dart';

/// User-facing copy for pattern evidence-strength labels.
abstract final class PatternConfidenceCopy {
  PatternConfidenceCopy._();

  static const earlySignalLabel = 'Early signal';

  static const earlySignalBody =
      'Seen in 2 saved moments. ArchiveMe needs one more related moment before calling it a pattern.';

  static const repeatedPatternLabel = 'Repeated pattern';

  static const repeatedPatternBody = 'Seen across 3+ related saved moments.';

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
    ...allExplanationStrings(),
  ];

  static const explanationTitle = 'Why ArchiveMe is showing this';

  static const explanationIntro =
      'ArchiveMe uses saved evidence, not a single answer.';

  static const explanationFooter = 'No single moment proves the whole story.';

  static const explanationDifferentiation =
      'ChatGPT can answer from one conversation. ArchiveMe explains the evidence trail behind a pattern.';

  static const explanationEarlySignalLabel = 'Early signal';
  static const explanationEarlySignalBody =
      'Seen once or twice. Useful as a clue, not a conclusion.';

  static const explanationRepeatedLabel = 'Repeated';
  static const explanationRepeatedBody =
      'This has returned across saved moments.';

  static const explanationCurrentLabel = 'Current';
  static const explanationCurrentBody =
      'This has appeared recently, so ArchiveMe gives it more weight.';

  static const explanationFadingLabel = 'Fading';
  static const explanationFadingBody =
      'This has not appeared recently, so ArchiveMe gives it less weight.';

  static const explanationSoftenedLabel = 'Softened';
  static const explanationSoftenedBody =
      'This returned, but with less force or urgency.';

  static const explanationChangedLabel = 'Changed';
  static const explanationChangedBody =
      'This returned differently than before.';

  static const explanationNeedsFreshProofLabel = 'Needs fresh proof';
  static const explanationNeedsFreshProofBody =
      'This may still matter, but ArchiveMe needs a newer saved moment before treating it as current.';

  static String explanationLabelFor(PatternConfidenceExplanationState state) =>
      switch (state) {
        PatternConfidenceExplanationState.earlySignal =>
          explanationEarlySignalLabel,
        PatternConfidenceExplanationState.repeated => explanationRepeatedLabel,
        PatternConfidenceExplanationState.current => explanationCurrentLabel,
        PatternConfidenceExplanationState.fading => explanationFadingLabel,
        PatternConfidenceExplanationState.softened => explanationSoftenedLabel,
        PatternConfidenceExplanationState.changed => explanationChangedLabel,
        PatternConfidenceExplanationState.needsFreshProof =>
          explanationNeedsFreshProofLabel,
      };

  static String explanationBodyFor(PatternConfidenceExplanationState state) =>
      switch (state) {
        PatternConfidenceExplanationState.earlySignal =>
          explanationEarlySignalBody,
        PatternConfidenceExplanationState.repeated => explanationRepeatedBody,
        PatternConfidenceExplanationState.current => explanationCurrentBody,
        PatternConfidenceExplanationState.fading => explanationFadingBody,
        PatternConfidenceExplanationState.softened => explanationSoftenedBody,
        PatternConfidenceExplanationState.changed => explanationChangedBody,
        PatternConfidenceExplanationState.needsFreshProof =>
          explanationNeedsFreshProofBody,
      };

  static List<String> allExplanationStrings() => [
    explanationTitle,
    explanationIntro,
    explanationFooter,
    explanationDifferentiation,
    explanationEarlySignalLabel,
    explanationEarlySignalBody,
    explanationRepeatedLabel,
    explanationRepeatedBody,
    explanationCurrentLabel,
    explanationCurrentBody,
    explanationFadingLabel,
    explanationFadingBody,
    explanationSoftenedLabel,
    explanationSoftenedBody,
    explanationChangedLabel,
    explanationChangedBody,
    explanationNeedsFreshProofLabel,
    explanationNeedsFreshProofBody,
  ];
}
