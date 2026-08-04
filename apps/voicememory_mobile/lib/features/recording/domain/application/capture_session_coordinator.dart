import 'dart:async';

import '../../../../audio/recording_service.dart';
import '../../../record/recording_duration_policy.dart';

typedef RecordingTick = void Function(int seconds);

final class CaptureSessionCoordinator {
  CaptureSessionCoordinator({
    required this._recording,
    this.maximumSeconds = RecordingDurationPolicy.maxSeconds,
  });

  final RecordingService _recording;
  final int maximumSeconds;
  StreamSubscription<int>? _durationSubscription;
  int _seconds = 0;

  int get seconds => _seconds;
  Stream<double> get audioLevels => _recording.audioDecibels;

  void listen(
    RecordingTick onTick, {
    required Future<void> Function() onLimit,
  }) {
    unawaited(_durationSubscription?.cancel());
    _durationSubscription = _recording.durationSeconds.listen((seconds) {
      _seconds = seconds;
      onTick(seconds);
      if (RecordingDurationPolicy.shouldAutoStop(
        seconds,
        maxDurationSeconds: maximumSeconds,
      )) {
        unawaited(onLimit());
      }
    });
  }

  Future<void> start() async {
    _seconds = 0;
    await _recording.startRecording(
      permissionVerified: true,
      maxDurationSeconds: maximumSeconds,
    );
  }

  Future<RecordingResult> stop() => _recording.stopRecording();

  void reset() => _seconds = 0;

  Future<void> dispose() async {
    await _durationSubscription?.cancel();
    _durationSubscription = null;
  }
}
