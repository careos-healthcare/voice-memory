import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/services/moving_baseline_calculator.dart';

void main() {
  group('MovingBaselineCalculator EWMA Verification Tests', () {
    test('should return null when parsing an empty history payload', () {
      const calculator = MovingBaselineCalculator();
      final result = calculator.calculateMacroBaseline([]);
      expect(result, isNull);
    });

    test(
      'should return the exact initial entry when history contains a single data point',
      () {
        const calculator = MovingBaselineCalculator();
        const singleLog = CognitiveBiomarkers(
          lexicalDiversity: 0.45,
          cohesionDrift: 0.35,
          emotionalVolatility: 0.25,
        );

        final result = calculator.calculateMacroBaseline([singleLog]);

        expect(result, isNotNull);
        expect(result!.lexicalDiversity, equals(0.45));
        expect(result.cohesionDrift, equals(0.35));
        expect(result.emotionalVolatility, equals(0.25));
      },
    );

    test(
      'should mathematically compute smoothed values across a chronological list',
      () {
        const calculator = MovingBaselineCalculator(alpha: 0.50);

        const chronologicalHistory = [
          CognitiveBiomarkers(
            lexicalDiversity: 0.40,
            cohesionDrift: 0.60,
            emotionalVolatility: 0.20,
          ),
          CognitiveBiomarkers(
            lexicalDiversity: 0.60,
            cohesionDrift: 0.20,
            emotionalVolatility: 0.60,
          ),
        ];

        final result = calculator.calculateMacroBaseline(chronologicalHistory);

        expect(result, isNotNull);
        expect(result!.lexicalDiversity, closeTo(0.50, 0.001));
        expect(result.cohesionDrift, closeTo(0.40, 0.001));
        expect(result.emotionalVolatility, closeTo(0.40, 0.001));
      },
    );

    test('should maintain stability over multiple sequential updates', () {
      const calculator = MovingBaselineCalculator(alpha: 0.30);

      var baseline = const CognitiveBiomarkers(
        lexicalDiversity: 0.50,
        cohesionDrift: 0.40,
        emotionalVolatility: 0.30,
      );

      const newObservation = CognitiveBiomarkers(
        lexicalDiversity: 0.60,
        cohesionDrift: 0.30,
        emotionalVolatility: 0.50,
      );

      baseline = calculator.updateBaseline(baseline, newObservation);

      expect(baseline.lexicalDiversity, closeTo(0.53, 0.001));
      expect(baseline.cohesionDrift, closeTo(0.37, 0.001));
      expect(baseline.emotionalVolatility, closeTo(0.36, 0.001));
    });
  });
}
