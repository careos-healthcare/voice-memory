import 'package:archiveme_mobile/features/entry_detail/entry_read_aloud_copy.dart';
import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/offline_tts/offline_tts_config.dart';
import 'package:archiveme_mobile/services/offline_tts/offline_tts_service.dart';
import 'package:archiveme_mobile/services/offline_tts/stub_offline_tts_backend.dart';
import 'package:archiveme_mobile/widgets/entry_detail/entry_read_aloud_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({required String transcript}) => JournalEntry(
      id: 'entry-1',
      createdAt: DateTime(2026, 6, 12),
      transcript: transcript,
      durationSeconds: 12,
      reflection: Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: const [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    );

void main() {
  group('entrySpeakableText', () {
    test('returns transcript when present', () {
      const transcript = 'I want to remember this thought about boundaries.';
      final text = entrySpeakableText(_entry(transcript: transcript));
      expect(text, transcript);
    });

    test('returns null for pending transcript states', () {
      final text = entrySpeakableText(
        _entry(
          transcript:
              '[draft] Recording saved locally — transcribe when connected',
        ),
      );
      expect(text, isNull);
    });
  });

  group('EntryReadAloudButton', () {
    late OfflineTtsService offlineTts;

    setUp(() async {
      offlineTts = OfflineTtsService(
        backend: StubOfflineTtsBackend(chunkDurationSeconds: 0.01),
      );
      await offlineTts.loadModel(
        const OfflineTtsConfig(
          vitsModelPath: '/tmp/stub-model.onnx',
          tokensPath: '/tmp/stub-tokens.txt',
        ),
      );
      offlineTts.bindPlayback(
        OfflineTtsService.createPlayback(sampleRateHz: 24000, testMode: true),
      );
    });

    tearDown(() async {
      await offlineTts.dispose();
    });

    testWidgets('speaks injected text when tapped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryReadAloudButton(
              text: 'Listen to this reflection.',
              offlineTts: offlineTts,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('entry_read_aloud_button')), findsOneWidget);
      expect(find.text(EntryReadAloudCopy.listen), findsOneWidget);

      await tester.tap(find.byKey(const Key('entry_read_aloud_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text(EntryReadAloudCopy.listen), findsOneWidget);
    });

    testWidgets('hides when offline TTS is unavailable', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryReadAloudButton(
              text: 'Hidden without a voice model.',
              resolveOfflineTts: () async => null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('entry_read_aloud_button')), findsNothing);
    });
  });
}
