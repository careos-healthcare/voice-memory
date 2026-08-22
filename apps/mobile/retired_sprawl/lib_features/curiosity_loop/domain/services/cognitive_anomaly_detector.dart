import 'package:archiveme_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';

/// Flags personalized cognitive drops relative to a user's EWMA baseline.
class CognitiveAnomalyDetector {
  const CognitiveAnomalyDetector({
    this.driftVarianceThreshold = 0.15,
    this.lexicalVarianceThreshold = 0.10,
  });

  static const double defaultDriftVarianceThreshold = 0.15;
  static const double defaultLexicalVarianceThreshold = 0.10;

  final double driftVarianceThreshold;
  final double lexicalVarianceThreshold;

  /// Returns true when current biomarkers indicate allostatic overload
  /// and grounding intervention is warranted.
  bool determineOverloadState({
    required CognitiveBiomarkers current,
    required CognitiveBiomarkers baseline,
  }) {
    final driftVariance = current.cohesionDrift - baseline.cohesionDrift;
    final lexicalVariance =
        baseline.lexicalDiversity - current.lexicalDiversity;

    return driftVariance >= driftVarianceThreshold ||
        lexicalVariance >= lexicalVarianceThreshold;
  }
}