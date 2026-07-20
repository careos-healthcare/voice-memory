class WeeklyTelemetrySummary {
  final DateTime weekStartDate;
  final int totalObservations;
  final int groundedInterventionsCount;
  final double downRegulationSuccessRate;
  final double averageLexicalDelta;
  final double averageDriftDelta;

  const WeeklyTelemetrySummary({
    required this.weekStartDate,
    required this.totalObservations,
    required this.groundedInterventionsCount,
    required this.downRegulationSuccessRate,
    required this.averageLexicalDelta,
    required this.averageDriftDelta,
  });
}
