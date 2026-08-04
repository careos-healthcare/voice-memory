import 'dart:math';

import '../domain/cognitive_metrics.dart';

class CognitiveAnalyzer {
  /// Evaluates transcript tokens and acoustic pitch contour to compute cognitive markers
  Future<CognitiveMetrics> analyzeSession({
    required String sessionId,
    required String transcript,
    required List<double> pitchContour,
  }) async {
    final tokens = transcript
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    final uniqueTokens = tokens.toSet();
    final lexicalDiversity = tokens.isEmpty
        ? 0.0
        : (uniqueTokens.length / tokens.length).clamp(0.0, 1.0);

    double volatility = 0.0;
    if (pitchContour.isNotEmpty) {
      final mean = pitchContour.reduce((a, b) => a + b) / pitchContour.length;
      if (mean > 0) {
        final variance =
            pitchContour
                .map((f0) => pow(f0 - mean, 2))
                .reduce((a, b) => a + b) /
            pitchContour.length;
        volatility = (sqrt(variance) / mean).clamp(0.0, 1.0);
      }
    }

    final cohesionDrift = tokens.length < 10
        ? 0.1
        : min(1.0, 0.15 + (1.0 - lexicalDiversity) * 0.4);

    return CognitiveMetrics(
      sessionId: sessionId,
      timestamp: DateTime.now(),
      lexicalDiversity: double.parse(lexicalDiversity.toStringAsFixed(2)),
      emotionalVolatility: double.parse(volatility.toStringAsFixed(2)),
      cohesionDrift: double.parse(cohesionDrift.toStringAsFixed(2)),
      pauseDurationTotal: const Duration(seconds: 4),
    );
  }
}
