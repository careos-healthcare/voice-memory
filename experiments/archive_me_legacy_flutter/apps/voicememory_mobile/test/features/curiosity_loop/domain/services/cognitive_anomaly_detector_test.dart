import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/models/cognitive_biomarkers.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/services/cognitive_anomaly_detector.dart';

void main() {
  group('CognitiveAnomalyDetector', () {
    const detector = CognitiveAnomalyDetector();

    const baseline = CognitiveBiomarkers(
      lexicalDiversity: 0.55,
      cohesionDrift: 0.35,
      emotionalVolatility: 0.40,
    );

    test(
      'triggers grounding when drift rises significantly above baseline',
      () {
        const current = CognitiveBiomarkers(
          lexicalDiversity: 0.54,
          cohesionDrift: 0.52,
          emotionalVolatility: 0.41,
        );

        expect(
          detector.determineOverloadState(current: current, baseline: baseline),
          isTrue,
        );
      },
    );

    test('triggers grounding when lexical diversity drops below baseline', () {
      const current = CognitiveBiomarkers(
        lexicalDiversity: 0.42,
        cohesionDrift: 0.36,
        emotionalVolatility: 0.39,
      );

      expect(
        detector.determineOverloadState(current: current, baseline: baseline),
        isTrue,
      );
    });

    test('returns false for normal baseline-aligned variation', () {
      const current = CognitiveBiomarkers(
        lexicalDiversity: 0.50,
        cohesionDrift: 0.42,
        emotionalVolatility: 0.43,
      );

      expect(
        detector.determineOverloadState(current: current, baseline: baseline),
        isFalse,
      );
    });
  });
}
