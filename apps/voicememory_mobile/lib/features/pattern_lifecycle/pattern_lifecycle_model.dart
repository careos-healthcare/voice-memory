/// Where a pattern sits in its evidence story — no scores or percentages.
enum PatternLifecycleState {
  forming,
  repeated,
  watching,
  changing,
  softening,
  quiet;

  String get analyticsValue => switch (this) {
        PatternLifecycleState.forming => 'forming',
        PatternLifecycleState.repeated => 'repeated',
        PatternLifecycleState.watching => 'watching',
        PatternLifecycleState.changing => 'changing',
        PatternLifecycleState.softening => 'softening',
        PatternLifecycleState.quiet => 'quiet',
      };
}

/// Grounded lifecycle label from existing evidence engines only.
class PatternLifecycle {
  const PatternLifecycle({
    required this.state,
    required this.label,
    required this.body,
  });

  final PatternLifecycleState state;
  final String label;
  final String body;

  String get lifecycleRowLabel => 'Lifecycle: $label';

  bool get shouldShow => true;
}
