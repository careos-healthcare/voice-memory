import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/cognitive_telemetry/application/cognitive_analyzer.dart';

void main() {
  group('CognitiveAnalyzer', () {
    final analyzer = CognitiveAnalyzer();

    test('computes lexical diversity from transcript tokens', () async {
      final metrics = await analyzer.analyzeSession(
        sessionId: 'session_1',
        transcript: 'the the the cat',
        pitchContour: const [],
      );

      expect(metrics.sessionId, 'session_1');
      expect(metrics.lexicalDiversity, 0.5);
      expect(metrics.emotionalVolatility, 0.0);
      expect(metrics.cohesionDrift, 0.1);
      expect(metrics.pauseDurationTotal, const Duration(seconds: 4));
    });

    test('computes emotional volatility from pitch contour', () async {
      final metrics = await analyzer.analyzeSession(
        sessionId: 'session_2',
        transcript: 'one two three four five six seven eight nine ten',
        pitchContour: const [100, 150, 100, 150],
      );

      expect(metrics.emotionalVolatility, greaterThan(0.0));
      expect(metrics.cohesionDrift, greaterThan(0.1));
    });

    test('uses short-transcript cohesion drift baseline', () async {
      final metrics = await analyzer.analyzeSession(
        sessionId: 'session_3',
        transcript: 'short transcript',
        pitchContour: const [],
      );

      expect(metrics.cohesionDrift, 0.1);
    });
  });
}
