import 'dart:typed_data';

import 'package:archiveme_mobile/features/audio/dual_mode_audio_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a pause of 1.2s keeps the turn open and a longer pause closes it', () {
    final buffer = RollingSpeechBuffer();
    final speech = Float32List(1600)..fillRange(0, 1600, 1);
    final silence = Float32List(1600);

    expect(buffer.push(frame: speech, speech: true), isNull);
    for (var i = 0; i < 12; i++) {
      expect(buffer.push(frame: silence, speech: false), isNull);
    }
    expect(buffer.trailingSilence, DualModeAudioTiming.pause);

    final turn = buffer.push(frame: silence, speech: false);
    expect(turn, isNotNull);
    expect(turn!.isNotEmpty, isTrue);
  });

  test('the rolling window drops samples older than 30 seconds', () {
    final buffer = RollingSpeechBuffer();
    final frame = Float32List(DualModeAudioTiming.sampleRateHz);
    for (var i = 0; i < 31; i++) {
      buffer.push(frame: frame, speech: false);
    }
    expect(
      buffer.rollingSampleCount,
      DualModeAudioTiming.sampleRateHz *
          DualModeAudioTiming.rollingWindow.inSeconds,
    );
  });

  test('interactive mode replies and keeps recording open', () async {
    final played = <String>[];
    var recordingWhilePlaying = false;
    late final ProviderContainer container;
    container = ProviderContainer(
      overrides: [
        dualModeAudioPortsProvider.overrideWithValue(
          DualModeAudioPorts(
            isSpeech: (samples) => samples.any((sample) => sample > 0.5),
            transcribe: (samples) async => 'Walked after lunch.',
            reply: (transcript) async => 'Heard that.',
            play: (text) async {
              final snapshot = container
                  .read(dualModeAudioEngineProvider)
                  .value;
              recordingWhilePlaying = snapshot?.recording ?? false;
              played.add(text);
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(dualModeAudioEngineProvider.future);
    final engine = container.read(dualModeAudioEngineProvider.notifier);

    await engine.selectMode(DualAudioMode.interactive);
    await engine.start();
    final speech = Float32List(1600)..fillRange(0, 1600, 1);
    final silence = Float32List(1600);
    await engine.pushSamples(speech);
    for (var i = 0; i < 13; i++) {
      await engine.pushSamples(silence);
    }

    final snapshot = container.read(dualModeAudioEngineProvider).value!;
    expect(snapshot.recording, isTrue);
    expect(snapshot.playingResponse, isFalse);
    expect(recordingWhilePlaying, isTrue);
    expect(played, ['Heard that.']);
    expect(snapshot.turns.single.transcript, 'Walked after lunch.');
    expect(snapshot.lastReply, 'Heard that.');
  });

  test(
    'passive mode transcribes the whole take when recording stops',
    () async {
      Float32List? captured;
      final container = ProviderContainer(
        overrides: [
          dualModeAudioPortsProvider.overrideWithValue(
            DualModeAudioPorts(
              isSpeech: (_) => false,
              transcribe: (samples) async {
                captured = samples;
                return 'A quiet evening.';
              },
              reply: (_) async => '',
              play: (_) async {},
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(dualModeAudioEngineProvider.future);
      final engine = container.read(dualModeAudioEngineProvider.notifier);

      await engine.start();
      await engine.pushSamples(Float32List.fromList(const [0.1, 0.2]));
      await engine.stop();

      final snapshot = container.read(dualModeAudioEngineProvider).value!;
      expect(snapshot.recording, isFalse);
      expect(snapshot.mode, DualAudioMode.passive);
      expect(snapshot.partialTranscript, 'A quiet evening.');
      expect(captured, isNotNull);
      expect(captured!.length, 2);
    },
  );
}
