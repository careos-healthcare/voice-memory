import 'dart:async';

import 'package:archiveme_mobile/audio/record_capture_events.dart';
import 'package:archiveme_mobile/features/voice_capture/audio/audio_level_monitor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

void main() {
  test('forwards amplitude samples and record state events', () async {
    final controller = StreamController<RecordState>();
    final recorder = _FakeAudioRecorder(stateStream: controller.stream);
    final events = RecordCaptureEvents(
      recorder: recorder,
      levelMonitor: AudioLevelMonitor(),
    );

    RecordState? latestState;
    events.start(
      onAmplitudeSample: (_) {},
      onState: (state) => latestState = state,
    );

    controller.add(RecordState.record);
    await pumpEventQueue();
    expect(latestState, RecordState.record);

    events.stop(clearLevelSummary: false);
    controller.add(RecordState.stop);
    await pumpEventQueue();
    expect(latestState, RecordState.record);
  });
}

class _FakeAudioRecorder implements AudioRecorder {
  _FakeAudioRecorder({required this.stateStream});

  final Stream<RecordState> stateStream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<RecordState> onStateChanged() => stateStream;

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) =>
      const Stream.empty();
}
