import 'dart:async';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/voice/data/voice_call_service.dart';
import 'package:archiveme_mobile/features/voice/data/voice_journal_pipeline.dart';
import 'package:archiveme_mobile/features/voice/presentation/dictation_mic_bar.dart';
import 'package:archiveme_mobile/features/voice/presentation/voice_call_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dictation mic writes partials and toggles with haptics', (
    tester,
  ) async {
    final engine = _ScriptEngine();
    final controller = TextEditingController(text: 'Today');
    var haptics = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DictationMicBar(
            controller: controller,
            engine: engine,
            haptic: () => haptics += 1,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('dictation_mic_button')));
    await tester.pump();
    engine.emitPartial('I felt steady');
    engine.emitLevel(0.8);
    await tester.pump();

    expect(haptics, 1);
    expect(controller.text, 'Today I felt steady');
    expect(find.byKey(const Key('dictation_sound_bars')), findsOneWidget);

    await tester.tap(find.byKey(const Key('dictation_mic_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(haptics, 2);
    expect(find.byKey(const Key('dictation_sound_bars')), findsNothing);
  });

  test('headset changes keep the socket and the reply stays under 500ms', () async {
    final transport = LoopbackVoiceTransport();
    final capture = ManualVoiceCapture();
    final routes = StreamController<VoiceAudioDevice>();
    final service = VoiceCallService(
      transport: transport,
      capture: capture,
      routes: routes.stream,
    );
    await service.start();
    capture.emit(Uint8List.fromList([0, 0, 40, 0]), 0.4);
    await Future<void>.delayed(Duration.zero);

    expect(service.lastTurnaround!.inMilliseconds, lessThan(500));
    expect(service.isConnected, isTrue);

    routes.add(const VoiceAudioDevice(id: 'bt-1', label: 'Bluetooth headphones'));
    await Future<void>.delayed(Duration.zero);
    expect(capture.rebindCount, 1);
    expect(service.isConnected, isTrue);
    expect(transport.isConnected, isTrue);

    service.addLine('I keep coming back to the same worry.');
    final transcript = await service.end();
    expect(transcript, contains('same worry'));
    expect(service.isConnected, isFalse);
    await routes.close();
  });

  test('ending a call saves the transcript and life patterns for indexing', () async {
    JournalEntryCapture? indexed;
    final pipeline = VoiceJournalPipeline(
      idFactory: () => 'call-1',
      clock: () => DateTime.utc(2026, 9, 22, 20),
      save: (entry) async {},
      index: (entry, patterns) async {
        indexed = JournalEntryCapture(entry.transcript, patterns);
      },
    );

    final result = await pipeline.complete(
      'I keep coming back to the same worry. The morning feels lighter.',
    );

    expect(result.entry.transcript, contains('same worry'));
    expect(result.lifePatterns, [
      'I keep coming back to the same worry',
      'The morning feels lighter',
    ]);
    expect(result.entry.reflection.recurringThemes, result.lifePatterns);
    expect(indexed?.transcript, result.entry.transcript);
    expect(indexed?.patterns, result.lifePatterns);
    expect(result.entry.toJson()['transcript'], result.entry.transcript);
  });

  testWidgets('voice call orb ends into a saved life pattern line', (
    tester,
  ) async {
    final transport = LoopbackVoiceTransport();
    final capture = ManualVoiceCapture();
    final service = VoiceCallService(transport: transport, capture: capture);
    final pipeline = VoiceJournalPipeline(
      idFactory: () => 'call-2',
      clock: () => DateTime.utc(2026, 9, 22, 21),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: VoiceCallScreen(service: service, pipeline: pipeline),
      ),
    );
    await tester.pump();
    service.addLine('I keep coming back to the same worry.');
    await tester.pump();
    expect(service.transcript, contains('same worry'));

    await tester.tap(find.byKey(const Key('voice_call_end')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('voice_call_life_patterns')), findsOneWidget);
    expect(find.textContaining('Life Patterns'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class JournalEntryCapture {
  JournalEntryCapture(this.transcript, this.patterns);

  final String transcript;
  final List<String> patterns;
}

class _ScriptEngine implements DictationEngine {
  final _partials = StreamController<String>.broadcast();
  final _levels = StreamController<double>.broadcast();
  var started = false;

  @override
  Stream<String> get partials => _partials.stream;

  @override
  Stream<double> get levels => _levels.stream;

  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<void> stop() async {
    started = false;
  }

  void emitPartial(String value) => _partials.add(value);

  void emitLevel(double value) => _levels.add(value);
}
