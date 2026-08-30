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
    this.contributingEntryIds = const [],
  });

  final PatternConfidenceState state;
  final String label;
  final String body;
  final List<String> contributingEntryIds;

  bool get shouldShow => true;
}

/// Human-readable evidence confidence label for the explanation card.
enum PatternConfidenceExplanationState {
  earlySignal,
  repeated,
  current,
  fading,
  softened,
  changed,
  needsFreshProof;

  String get analyticsValue => switch (this) {
    PatternConfidenceExplanationState.earlySignal => 'early_signal',
    PatternConfidenceExplanationState.repeated => 'repeated',
    PatternConfidenceExplanationState.current => 'current',
    PatternConfidenceExplanationState.fading => 'fading',
    PatternConfidenceExplanationState.softened => 'softened',
    PatternConfidenceExplanationState.changed => 'changed',
    PatternConfidenceExplanationState.needsFreshProof => 'needs_fresh_proof',
  };
}

/// Resolved pattern confidence explanation — labels only, no scores.
class PatternConfidenceExplanationResult {
  const PatternConfidenceExplanationResult({
    required this.shouldShow,
    required this.entryCount,
    required this.source,
    required this.hasConfirmedRepeat,
    required this.hasBeliefSurface,
    required this.confidenceState,
    required this.title,
    required this.intro,
    required this.label,
    required this.body,
    required this.footer,
    required this.differentiationLine,
    this.contributingEntryIds = const [],
  });

  final bool shouldShow;
  final int entryCount;
  final String source;
  final bool hasConfirmedRepeat;
  final bool hasBeliefSurface;
  final PatternConfidenceExplanationState confidenceState;
  final String title;
  final String intro;
  final String label;
  final String body;
  final String footer;
  final String differentiationLine;
  final List<String> contributingEntryIds;
}
