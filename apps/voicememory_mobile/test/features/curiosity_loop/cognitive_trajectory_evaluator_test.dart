import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/models/weekly_telemetry_summary.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/services/cognitive_trajectory_evaluator.dart';

void main() {
  late CognitiveTrajectoryEvaluator evaluator;

  setUp(() {
    evaluator = const CognitiveTrajectoryEvaluator();
  });

  group('CognitiveTrajectoryEvaluator Tests', () {
    test('should classify as recovering when cohesion drift drops significantly', () {
      const source = CognitiveBiomarkers(
        lexicalDiversity: 0.40,
        cohesionDrift: 0.85, // High initial cognitive drift
        emotionalVolatility: 0.50,
      );

      const response = CognitiveBiomarkers(
        lexicalDiversity: 0.42,
        cohesionDrift: 0.60, // Drops by 0.25 (Passes <= -0.20 rule)
        emotionalVolatility: 0.40,
      );

      final assessment = evaluator.evaluateRecovery(
        sourceMetrics: source,
        responseMetrics: response,
      );

      expect(assessment.direction, CognitiveDirection.recovering);
      expect(assessment.driftDelta, closeTo(-0.25, 0.001));
    });

    test('should classify as recovering when lexical diversity expands notably', () {
      const source = CognitiveBiomarkers(
        lexicalDiversity: 0.35, // Restricted working vocabulary
        cohesionDrift: 0.50,
        emotionalVolatility: 0.60,
      );

      const response = CognitiveBiomarkers(
        lexicalDiversity: 0.55, // Increases by 0.20 (Passes >= 0.15 rule)
        cohesionDrift: 0.52,
        emotionalVolatility: 0.45,
      );

      final assessment = evaluator.evaluateRecovery(
        sourceMetrics: source,
        responseMetrics: response,
      );

      expect(assessment.direction, CognitiveDirection.recovering);
      expect(assessment.lexicalDelta, closeTo(0.20, 0.001));
    });

    test('should classify as declining when cohesion drift worsens significantly', () {
      const source = CognitiveBiomarkers(
        lexicalDiversity: 0.60,
        cohesionDrift: 0.30,
        emotionalVolatility: 0.20,
      );

      const response = CognitiveBiomarkers(
        lexicalDiversity: 0.58,
        cohesionDrift: 0.50, // Increases by 0.20 (Passes >= 0.15 rule)
        emotionalVolatility: 0.40,
      );

      final assessment = evaluator.evaluateRecovery(
        sourceMetrics: source,
        responseMetrics: response,
      );

      expect(assessment.direction, CognitiveDirection.declining);
      expect(assessment.driftDelta, closeTo(0.20, 0.001));
    });

    test('should default to stagnant when metric fluctuations stay within safety bounds',
        () {
      const source = CognitiveBiomarkers(
        lexicalDiversity: 0.50,
        cohesionDrift: 0.40,
        emotionalVolatility: 0.30,
      );

      const response = CognitiveBiomarkers(
        lexicalDiversity: 0.52, // +0.02 delta
        cohesionDrift: 0.45, // +0.05 delta
        emotionalVolatility: 0.32,
      );

      final assessment = evaluator.evaluateRecovery(
        sourceMetrics: source,
        responseMetrics: response,
      );

      expect(assessment.direction, CognitiveDirection.stagnant);
    });
  });

  group('calculateRollingHealthScore', () {
    test('returns 100.0 when no weekly summaries exist', () {
      expect(evaluator.calculateRollingHealthScore([]), 100.0);
    });

    test('weights recent weeks more heavily in the rolling index', () {
      final score = evaluator.calculateRollingHealthScore([
        WeeklyTelemetrySummary(
          weekStartDate: DateTime.utc(2026, 6, 9),
          totalObservations: 2,
          groundedInterventionsCount: 2,
          downRegulationSuccessRate: 100,
          averageLexicalDelta: 0.0,
          averageDriftDelta: 0.0,
        ),
        WeeklyTelemetrySummary(
          weekStartDate: DateTime.utc(2026, 6, 2),
          totalObservations: 1,
          groundedInterventionsCount: 0,
          downRegulationSuccessRate: 0,
          averageLexicalDelta: 0.5,
          averageDriftDelta: 0.5,
        ),
      ]);

      expect(score, closeTo(73.33, 0.01));
    });
  });
}
