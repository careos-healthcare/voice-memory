import '../../domain/services/cognitive_trajectory_evaluator.dart';

/// Representation of a single day's analytical telemetry payload.
class TelemetryDataPoint {
  const TelemetryDataPoint({
    required this.date,
    required this.direction,
    required this.lexicalDelta,
    required this.driftDelta,
    this.wasGrounded = false,
  });

  final DateTime date;
  final CognitiveDirection direction;
  final double lexicalDelta;
  final double driftDelta;

  /// Whether sensory down-regulation was active when this observation was captured.
  final bool wasGrounded;

  /// Computes the normalized recovery index score for coordinate plotting.
  double get recoveryIndex => lexicalDelta - driftDelta;
}
