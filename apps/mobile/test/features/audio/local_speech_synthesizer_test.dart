import 'dart:async';
import 'dart:typed_data';

import 'package:archiveme_mobile/core/execution/cancel_token.dart';
import 'package:archiveme_mobile/core/llm/llm_router.dart';
import 'package:archiveme_mobile/features/audio/dual_mode_audio_engine.dart';
import 'package:archiveme_mobile/features/audio/local_speech_synthesizer.dart';
import 'package:archiveme_mobile/features/chat/archive_chat_screen.dart';
import 'package:archiveme_mobile/features/chat/archive_chat_service.dart';
import 'package:archiveme_mobile/features/chat/chat_notifier.dart';
import 'package:archiveme_mobile/features/reflection/guided_reflection_call_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a finished sentence is spoken before the next sentence is synthesized',
    () async {
      final played = <String>[];
      final second = Completer<SpeechPcmBuffer>();
      final container = ProviderContainer(
        overrides: [
          localSpeechBindingsProvider.overrideWithValue(
            LocalSpeechBindings(
              synthesizeSentence: (sentence) async {
                if (sentence.startsWith('Second')) return second.future;
                return SpeechPcmBuffer.fallback(sentence);
              },
            ),
          ),
          speechBufferPlayerProvider.overrideWithValue((buffer) async {
            played.add(buffer.sentence);
          }),
        ],
      );
      addTearDown(container.dispose);
      final speech = container.read(localSpeechSynthesizerProvider.notifier);
      final pending = speech.speakRouted(
        LlmRouter(local: (_) async => 'First sentence. Second sentence.'),
        workload: LlmWorkload.chatReply,
        prompt: 'First sentence. Second sentence.',
      );

      await _until(() => played.isNotEmpty);
      expect(played, ['First sentence.']);
      expect(second.isCompleted, isFalse);
      expect(container.read(localSpeechSynthesizerProvider).speaking, isTrue);

      second.complete(SpeechPcmBuffer.fallback('Second sentence.'));
      await pending;
      expect(played, ['First sentence.', 'Second sentence.']);
      expect(container.read(localSpeechSynthesizerProvider).speaking, isFalse);
    },
  );

  test('decimals stay inside a sentence', () {
    final buffer = StringBuffer('Pi is 3.14 today. Next');
    expect(takeCompleteSentences(buffer), ['Pi is 3.14 today.']);
    expect(buffer.toString(), ' Next');
  });

  test('voice activity stops playback during a reflection call', () async {
    final gate = Completer<void>();
    late final ProviderContainer container;
    container = ProviderContainer(
      overrides: [
        speechBufferPlayerProvider.overrideWithValue((buffer) => gate.future),
        dualModeAudioPortsProvider.overrideWithValue(
          DualModeAudioPorts(
            isSpeech: (samples) => samples.any((sample) => sample > 0.5),
            transcribe: (_) async => 'Walking.',
            reply: (_) async => 'Heard that.',
            play: (_) async {},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(dualModeAudioEngineProvider.future);
    final engine = container.read(dualModeAudioEngineProvider.notifier);
    await engine.selectMode(DualAudioMode.interactive);
    await engine.start();

    final speech = container.read(localSpeechSynthesizerProvider.notifier);
    final pending = speech.speakText('Hello there. The recording stays open.');
    await _until(
      () => container.read(localSpeechSynthesizerProvider).speaking,
    );

    final loud = Float32List(1600)..fillRange(0, 1600, 1);
    await engine.pushSamples(loud);

    expect(container.read(localSpeechSynthesizerProvider).interrupted, isTrue);
    expect(container.read(localSpeechSynthesizerProvider).speaking, isFalse);
    expect(container.read(localSpeechSynthesizerProvider).queuedCount, 0);
    await pending;
  });

  testWidgets('a reflection reply is spoken from router tokens', (
    tester,
  ) async {
    final played = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          speechBufferPlayerProvider.overrideWithValue((buffer) async {
            played.add(buffer.sentence);
          }),
          dualModeAudioPortsProvider.overrideWithValue(
            DualModeAudioPorts(
              isSpeech: (samples) => samples.any((sample) => sample > 0.5),
              transcribe: (_) async => 'Walked after lunch.',
              reply: (_) async => 'Hello there. Glad you said it.',
              play: (_) async {},
            ),
          ),
        ],
        child: const MaterialApp(
          home: GuidedReflectionCallScreen(promptTitle: 'Evening'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final context = tester.element(find.byType(GuidedReflectionCallScreen));
    final container = ProviderScope.containerOf(context);
    await _until(
      () =>
          container.read(dualModeAudioEngineProvider).value?.recording ?? false,
    );
    final engine = container.read(dualModeAudioEngineProvider.notifier);
    final speech = Float32List(1600)..fillRange(0, 1600, 1);
    final silence = Float32List(1600);
    await engine.pushSamples(speech);
    for (var i = 0; i < 13; i++) {
      await engine.pushSamples(silence);
    }
    await tester.pump();
    await _until(() => played.length == 2);

    expect(played, ['Hello there.', 'Glad you said it.']);
    expect(find.byKey(const Key('guided_reflection_call')), findsOneWidget);
  });

  testWidgets('an assistant bubble can read the reply aloud', (tester) async {
    final played = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          speechBufferPlayerProvider.overrideWithValue((buffer) async {
            played.add(buffer.sentence);
          }),
          chatNotifierProvider.overrideWith(
            () => ChatNotifier(
              service: _QuietChat(chunks: const ['You saw Ada. Yesterday.']),
            ),
          ),
        ],
        child: const MaterialApp(home: ArchiveChatScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat_suggestion_ada')));
    await tester.pump();
    await tester.pump(Duration.zero);

    expect(find.text('Read aloud'), findsOneWidget);
    await tester.tap(find.text('Read aloud'));
    await tester.pump();
    await _until(() => played.length == 2);

    expect(played, ['You saw Ada.', 'Yesterday.']);

    await tester.tap(find.text('Read aloud'));
    await tester.pump();
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(ArchiveChatScreen)),
      ).read(readAloudSelectionProvider),
      isNull,
    );
  });
}

Future<void> _until(bool Function() ready) async {
  for (var i = 0; i < 20; i++) {
    if (ready()) return;
    await Future<void>.delayed(Duration.zero);
  }
  expect(ready(), isTrue);
}

class _QuietChat extends ArchiveChatService {
  _QuietChat({required this.chunks});

  final List<String> chunks;

  @override
  Future<ArchiveChatRetrieval> retrieve(
    String prompt, {
    List<ChatTurn> history = const [],
  }) async {
    return ArchiveChatRetrieval(
      moments: const [],
      synthesized: prompt,
      target: LlmExecutionTarget.localOffline,
    );
  }

  @override
  Stream<String> streamReply({
    required String synthesized,
    required ExecutionCancelToken cancel,
  }) async* {
    cancel.throwIfCancelled();
    for (final chunk in chunks) {
      yield chunk;
    }
  }
}
