/// Evidence-strength label — no scores or percentages.
enum PatternConfidenceState {
  earlySignal,
  repeatedPattern,
  changingPattern,
  softeningPattern,
  notEnoughYet;

  String get analyticsValue => switch (this) {
        PatternConfidenceState.earlySignal => 'early_signal',
        PatternConfidenceState.repeatedPattern => 'repeated_pattern',
        PatternConfidenceState.changingPattern => 'changing_pattern',
        PatternConfidenceState.softeningPattern => 'softening_pattern',
        PatternConfidenceState.notEnoughYet => 'not_enough_yet',
      };
}

/// Grounded pattern confidence label from existing evidence gates.
class PatternConfidence {
  const PatternConfidence({
    required this.state,
    required this.label,
    required this.body,
  });

  final PatternConfidenceState state;
  final String label;
  final String body;

  bool get shouldShow => true;
}
