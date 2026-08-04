import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:voicememory_mobile/features/voice_capture/audio/audio_level_monitor.dart';

void main() {
  test('flags likelySilent when max amplitude stays below threshold', () async {
    final monitor = AudioLevelMonitor();
    final controller = StreamController<Amplitude>();

    monitor.start(_FakeRecorder(controller.stream));
    controller.add(Amplitude(current: -60, max: -55));
    await pumpEventQueue();
    controller.add(Amplitude(current: -58, max: -50));
    await pumpEventQueue();

    final summary = monitor.stop(logSummary: false);

    expect(summary.sampleCount, 2);
    expect(summary.maxDb, -50);
    expect(summary.minDb, -60);
    expect(summary.avgDb, closeTo(-59, 0.01));
    expect(summary.likelySilent, isTrue);
  });

  test('flags non-silent when max amplitude exceeds threshold', () async {
    final monitor = AudioLevelMonitor();
    final controller = StreamController<Amplitude>();

    monitor.start(_FakeRecorder(controller.stream));
    controller.add(Amplitude(current: -40, max: -35));
    await pumpEventQueue();

    final summary = monitor.stop(logSummary: false);

    expect(summary.sampleCount, 1);
    expect(summary.maxDb, -35);
    expect(summary.likelySilent, isFalse);
  });

  test('flags likelySilent when no amplitude samples were received', () {
    final monitor = AudioLevelMonitor();
    final controller = StreamController<Amplitude>();

    monitor.start(_FakeRecorder(controller.stream));

    final summary = monitor.stop(logSummary: false);

    expect(summary.sampleCount, 0);
    expect(summary.likelySilent, isTrue);
  });

  test(
    'shouldRetryForInitialSilence when max stays below retry threshold',
    () async {
      final monitor = AudioLevelMonitor();
      final controller = StreamController<Amplitude>();

      monitor.start(_FakeRecorder(controller.stream));
      controller.add(Amplitude(current: -62, max: -58));
      await pumpEventQueue();

      expect(monitor.shouldRetryForInitialSilence(isIosPhysical: true), isTrue);
      expect(
        monitor.shouldRetryForInitialSilence(isIosPhysical: false),
        isFalse,
      );
    },
  );

  test('does not retry when max rises above retry threshold', () async {
    final monitor = AudioLevelMonitor();
    final controller = StreamController<Amplitude>();

    monitor.start(_FakeRecorder(controller.stream));
    controller.add(Amplitude(current: -30, max: -25));
    await pumpEventQueue();

    expect(monitor.shouldRetryForInitialSilence(isIosPhysical: true), isFalse);
  });
}

class _FakeRecorder implements AudioRecorder {
  _FakeRecorder(this._stream);

  final Stream<Amplitude> _stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) => _stream;
}
