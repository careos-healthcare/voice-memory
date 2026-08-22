import 'dart:async';

import 'package:archiveme_mobile/features/voice_capture/audio/audio_level_monitor.dart';
import 'package:record/record.dart';

/// Bridges `record` amplitude and state streams into capture diagnostics.
class RecordCaptureEvents {
  RecordCaptureEvents({
    required AudioRecorder recorder,
    required AudioLevelMonitor levelMonitor,
  }) : _recorder = recorder,
       _levelMonitor = levelMonitor;

  final AudioRecorder _recorder;
  final AudioLevelMonitor _levelMonitor;

  StreamSubscription<RecordState>? _stateSubscription;

  void start({
    required void Function(double currentDb) onAmplitudeSample,
    required void Function(RecordState state) onState,
  }) {
    stop(clearLevelSummary: false);
    _levelMonitor.start(_recorder, onSample: onAmplitudeSample);
    _stateSubscription = _recorder.onStateChanged().listen(onState);
  }

  AudioLevelSummary stop({bool clearLevelSummary = true}) {
    _stateSubscription?.cancel();
    _stateSubscription = null;
    return _levelMonitor.stop(logSummary: clearLevelSummary);
  }

  AudioLevelMonitor get levelMonitor => _levelMonitor;
}
