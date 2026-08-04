import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/cognitive_telemetry/domain/cognitive_metrics.dart';

void main() {
  group('CognitiveMetrics', () {
    test('toJson emits snake_case telemetry envelope', () {
      final metrics = CognitiveMetrics(
        sessionId: 'session_abc',
        timestamp: DateTime.utc(2026, 7, 20, 8, 55),
        lexicalDiversity: 0.72,
        emotionalVolatility: 0.31,
        cohesionDrift: 0.18,
        pauseDurationTotal: Duration(milliseconds: 4200),
      );

      expect(metrics.toJson(), {
        'session_id': 'session_abc',
        'timestamp': '2026-07-20T08:55:00.000Z',
        'lexical_diversity': 0.72,
        'emotional_volatility': 0.31,
        'cohesion_drift': 0.18,
        'pause_duration_ms': 4200,
      });
    });

    test('fromJson round-trips structured telemetry payload', () {
      final restored = CognitiveMetrics.fromJson({
        'session_id': 'session_live_1',
        'timestamp': '2026-07-20T08:55:00.000Z',
        'lexical_diversity': 0.64,
        'emotional_volatility': 0.22,
        'cohesion_drift': 0.41,
        'pause_duration_ms': 1500,
      });

      expect(restored.sessionId, 'session_live_1');
      expect(restored.timestamp, DateTime.utc(2026, 7, 20, 8, 55));
      expect(restored.lexicalDiversity, 0.64);
      expect(restored.emotionalVolatility, 0.22);
      expect(restored.cohesionDrift, 0.41);
      expect(restored.pauseDurationTotal, const Duration(milliseconds: 1500));
    });
  });
}
