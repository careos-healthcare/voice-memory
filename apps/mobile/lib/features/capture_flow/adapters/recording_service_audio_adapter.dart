import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/audio/recording_service.dart';
import 'package:archiveme_mobile/audio/recording_types.dart';
import 'package:archiveme_mobile/features/capture_flow/interfaces/capture_flow_ports.dart';

/// Production adapter over [RecordingService].
class RecordingServiceAudioAdapter implements AudioRecorderAdapter {
  RecordingServiceAudioAdapter(this._recording);

  final RecordingService _recording;

  @override
  Future<MicPermissionResolution> evaluatePermission() =>
      _recording.evaluateMicrophonePermission();

  @override
  Future<MicPermissionResolution> requestPermission() async {
    await _recording.requestMicrophone();
    return _recording.evaluateMicrophonePermission();
  }

  @override
  Future<void> startRecording({required bool permissionVerified}) =>
      _recording.startRecording(permissionVerified: permissionVerified);

  @override
  Future<AudioStopResult> stopRecording() async {
    final result = await _recording.stopRecording();
    return AudioStopResult(
      file: result.file,
      durationSeconds: result.durationSeconds,
      likelySilentInput: result.likelySilentInput,
    );
  }

  @override
  Future<void> cancelRecording() async {
    if (_recording.state.phase == RecordingPhase.recording) {
      final result = await _recording.stopRecording();
      if (await result.file.exists()) {
        await result.file.delete();
      }
    }
  }

  @override
  Stream<int> get durationSeconds async* {
    while (true) {
      yield _recording.state.currentDuration.inSeconds;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  @override
  bool get supportsPause => false;

  @override
  Future<void> pauseRecording() async {}

  @override
  Future<void> resumeRecording() async {}
}
