/// How the archive reads a shift in a belief over time.
enum BeliefChangeAlertType {
  confidenceIncrease,
  confidenceDecrease,
  newBeliefEmerging,
  disappearingBelief,
}

/// Evidence-backed identity shift surfaced on Discover.
class BeliefChangeAlert {
  const BeliefChangeAlert({
    required this.id,
    required this.type,
    required this.headline,
    required this.beliefStatement,
    required this.priorLabel,
    required this.priorPercent,
    required this.currentLabel,
    required this.currentPercent,
    required this.magnitude,
    required this.evidenceEntryIds,
    required this.confidence,
  });

  final String id;
  final BeliefChangeAlertType type;
  final String headline;
  final String beliefStatement;
  final String priorLabel;
  final int priorPercent;
  final String currentLabel;
  final int currentPercent;

  /// Absolute confidence delta — used to sort by strength of change.
  final int magnitude;
  final List<String> evidenceEntryIds;
  final int confidence;

  String get confidenceRangeLabel =>
      '$priorPercent% → $currentPercent%';
}
