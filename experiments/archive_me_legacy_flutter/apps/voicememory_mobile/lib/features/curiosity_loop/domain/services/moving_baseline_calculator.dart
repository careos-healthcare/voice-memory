import '../models/cognitive_biomarkers.dart';

/// Calculates an Exponentially Weighted Moving Average (EWMA) baseline
/// across sequential biomarker tracking points to reveal long-term shifts.
class MovingBaselineCalculator {
  /// The smoothing factor parameter (alpha).
  /// Closer to 1.0 weights recent entries heavily; closer to 0.0 prioritizes long-term history.
  final double alpha;

  const MovingBaselineCalculator({this.alpha = 0.30})
    : assert(
        alpha > 0.0 && alpha <= 1.0,
        'Alpha smoothing factor must fall within (0.0, 1.0]',
      );

  /// Computes a cumulative historical baseline across a chronological sequence of logs.
  ///
  /// Returns `null` if the historical data set is empty.
  CognitiveBiomarkers? calculateMacroBaseline(
    List<CognitiveBiomarkers> history,
  ) {
    if (history.isEmpty) return null;

    // Seed the moving baseline with the oldest historical data point
    var cumulativeBaseline = history.first;

    // Iteratively blend subsequent entries chronologically
    for (int i = 1; i < history.length; i++) {
      cumulativeBaseline = updateBaseline(cumulativeBaseline, history[i]);
    }

    return cumulativeBaseline;
  }

  /// Blends a single new biomarker observation into a previously calculated baseline state.
  ///
  /// Formula implemented:
  /// EMA_t = (alpha * X_t) + ((1 - alpha) * EMA_{t-1})
  CognitiveBiomarkers updateBaseline(
    CognitiveBiomarkers previousBaseline,
    CognitiveBiomarkers newObservation,
  ) {
    final updatedLexical =
        (alpha * newObservation.lexicalDiversity) +
        ((1.0 - alpha) * previousBaseline.lexicalDiversity);

    final updatedCohesion =
        (alpha * newObservation.cohesionDrift) +
        ((1.0 - alpha) * previousBaseline.cohesionDrift);

    final updatedVolatility =
        (alpha * newObservation.emotionalVolatility) +
        ((1.0 - alpha) * previousBaseline.emotionalVolatility);

    return CognitiveBiomarkers(
      lexicalDiversity: updatedLexical,
      cohesionDrift: updatedCohesion,
      emotionalVolatility: updatedVolatility,
    );
  }
}
