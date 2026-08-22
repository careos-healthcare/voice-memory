import 'package:archiveme_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:archiveme_mobile/features/curiosity_loop/domain/models/weekly_telemetry_summary.dart';

/// Represents the directional trend of a user's cognitive state
/// during an analytical loop intervention.
enum CognitiveDirection {
  /// Signifies reliable baseline stabilization or reduction in distress markers.
  recovering,

  /// Indicates minimal statistical variance from the initial distressed state.
  stagnant,

  /// Signals increasing fragmentation, working memory load, or volatility.
  declining,
}

/// The vectorized assessment output encapsulating cognitive deltas.
class TrajectoryAssessment {

  const TrajectoryAssessment({
    required this.lexicalDelta,
    required this.driftDelta,
    required this.volatilityDelta,
    required this.direction,
  });
  final double lexicalDelta;
  final double driftDelta;
  final double volatilityDelta;
  final CognitiveDirection direction;

  @override
  String toString() {
    return 'TrajectoryAssessment(ΔLexical: ${lexicalDelta.toStringAsFixed(2)}, '
        'ΔDrift: ${driftDelta.toStringAsFixed(2)}, Direction: $direction)';
  }
}

/// Evaluates real-time recovery trajectory by measuring the delta vector
/// between a source entry baseline and the subsequent response metrics.
class CognitiveTrajectoryEvaluator {
  const CognitiveTrajectoryEvaluator();

  /// Calculates metric differentials and returns a clinical direction classification.
  TrajectoryAssessment evaluateRecovery({
    required CognitiveBiomarkers sourceMetrics,
    required CognitiveBiomarkers responseMetrics,
  }) {
    // Delta values: Positive lexical delta means richer vocabulary.
    // Negative drift delta means the narrative became more linear/stable.
    final lexicalDelta =
        responseMetrics.lexicalDiversity - sourceMetrics.lexicalDiversity;
    final driftDelta =
        responseMetrics.cohesionDrift - sourceMetrics.cohesionDrift;
    final volatilityDelta =
        responseMetrics.emotionalVolatility - sourceMetrics.emotionalVolatility;

    CognitiveDirection direction;

    // Evaluation Hierarchy Rules:
    // 1. Significant lowering of narrative fragmentation (drift) OR expansion of word variation (TTR)
    if (driftDelta <= -0.20 || lexicalDelta >= 0.15) {
      direction = CognitiveDirection.recovering;
    }
    // 2. Pronounced increase in structural narrative instability
    else if (driftDelta >= 0.15) {
      direction = CognitiveDirection.declining;
    }
    // 3. Trajectory remains within baseline safety bounds
    else {
      direction = CognitiveDirection.stagnant;
    }

    return TrajectoryAssessment(
      lexicalDelta: lexicalDelta,
      driftDelta: driftDelta,
      volatilityDelta: volatilityDelta,
      direction: direction,
    );
  }

  /// Calculates a rolling cognitive stability index across historical summaries.
  /// Returns a score from 0.0 (critical drift) to 100.0 (optimal stability).
  double calculateRollingHealthScore(
    List<WeeklyTelemetrySummary> weeklySummaries,
  ) {
    if (weeklySummaries.isEmpty) return 100;

    // Take up to the 4 most recent weeks to calculate a rolling trends index
    final recentWeeks = weeklySummaries.take(4).toList();
    var totalWeightedScore = 0.0;
    var totalWeight = 0.0;

    for (var i = 0; i < recentWeeks.length; i++) {
      final summary = recentWeeks[i];

      // Most recent weeks carry higher statistical weight (recency bias)
      final weight = 1.0 / (i + 1);

      // Component metrics
      final regulationFactor = summary.downRegulationSuccessRate / 100.0;

      // Penalize higher drift or lexical variance
      final deltaPenalty =
          (summary.averageLexicalDelta + summary.averageDriftDelta) / 2.0;
      final stabilityFactor = (1.0 - deltaPenalty).clamp(0.0, 1.0);

      // Combine into a baseline index for the week
      final weeklyIndex = (regulationFactor * 0.6) + (stabilityFactor * 0.4);

      totalWeightedScore += weeklyIndex * weight;
      totalWeight += weight;
    }

    return (totalWeightedScore / totalWeight) * 100.0;
  }
}