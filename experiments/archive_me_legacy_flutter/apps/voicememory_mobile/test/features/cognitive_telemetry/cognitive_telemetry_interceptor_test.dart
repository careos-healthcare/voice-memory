import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/cognitive_telemetry/application/live_voice_acoustic_session_bridge.dart';
import 'package:voicememory_mobile/features/cognitive_telemetry/domain/cognitive_metrics.dart';
import 'package:voicememory_mobile/features/cognitive_telemetry/infrastructure/interceptors/cognitive_telemetry_interceptor.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';

void main() {
  const reflection = Reflection(
    mood: 'calm',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up again today.',
    repeatedSignal: '',
  );

  JournalEntry liveVoiceEntry({
    required String id,
    String transcript = 'one two three four five six seven eight nine ten',
  }) {
    return JournalEntry(
      id: id,
      createdAt: DateTime.utc(2026, 7, 20, 12),
      transcript: transcript,
      durationSeconds: 20,
      reflection: reflection,
      syncStatus: SyncStatus.localOnly,
      captureContextTag: CognitiveTelemetryInterceptor.liveVoiceCaptureTag,
    );
  }

  group('CognitiveTelemetryInterceptor', () {
    test('analyzes staged live-voice session after journal save', () async {
      final bridge = LiveVoiceAcousticSessionBridge();
      CognitiveMetrics? captured;
      final interceptor = CognitiveTelemetryInterceptor(
        sessionBridge: bridge,
        onMetricsAnalyzed: (metrics) => captured = metrics,
      );

      bridge.stageAfterVaultCommit(
        sessionId: 'live_session_1',
        pitchContour: const [120, 130, 125],
      );

      await interceptor.onEntrySaved(liveVoiceEntry(id: 'entry_1'));

      expect(captured, isNotNull);
      expect(captured!.sessionId, 'live_session_1');
      expect(captured!.lexicalDiversity, 1.0);
      expect(captured!.emotionalVolatility, greaterThan(0.0));
    });

    test('ignores non-live-voice entries', () async {
      final bridge = LiveVoiceAcousticSessionBridge();
      var analyzed = false;
      final interceptor = CognitiveTelemetryInterceptor(
        sessionBridge: bridge,
        onMetricsAnalyzed: (_) => analyzed = true,
      );

      bridge.stageAfterVaultCommit(
        sessionId: 'live_session_1',
        pitchContour: const [120],
      );

      await interceptor.onEntrySaved(
        JournalEntry(
          id: 'typed_entry',
          createdAt: DateTime.utc(2026, 7, 20, 12),
          transcript: 'typed thought',
          durationSeconds: 5,
          reflection: reflection,
          syncStatus: SyncStatus.localOnly,
        ),
      );

      expect(analyzed, isFalse);
      expect(bridge.consumePending(), isNotNull);
    });

    test('no-ops when no staged session exists', () async {
      var analyzed = false;
      final interceptor = CognitiveTelemetryInterceptor(
        onMetricsAnalyzed: (_) => analyzed = true,
      );

      await interceptor.onEntrySaved(liveVoiceEntry(id: 'entry_2'));

      expect(analyzed, isFalse);
    });
  });
}
