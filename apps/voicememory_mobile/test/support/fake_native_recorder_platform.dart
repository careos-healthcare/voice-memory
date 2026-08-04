import 'package:voicememory_mobile/features/voice_capture/audio/native_audio_recorder.dart';

class ConfigurableFakeNativeMicPermissionPlatform
    implements NativeAudioRecorderPlatform {
  ConfigurableFakeNativeMicPermissionPlatform({
    this.statusValue = const NativeMicrophonePermission(
      status: 'granted',
      granted: true,
      canRequest: false,
    ),
    this.requestResult,
    this.available = true,
  });

  NativeMicrophonePermission statusValue;
  NativeMicrophonePermission? requestResult;
  bool available;
  int requestCallCount = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<NativeMicrophonePermission> microphonePermission() async {
    return statusValue;
  }

  @override
  Future<NativeMicrophonePermission> requestMicrophonePermission() async {
    requestCallCount += 1;
    final next = requestResult ?? statusValue;
    statusValue = next;
    return next;
  }

  @override
  Future<NativeAudioStartResult> start(
    String path,
    NativeAudioCaptureConfig config,
  ) async => NativeAudioStartResult(path: path);

  @override
  Future<NativeRecordingStopResult> stop() async {
    return const NativeRecordingStopResult(
      path: '/tmp/vm_native_test.wav',
      bytes: 2048,
      durationMs: 3500,
      minDb: -38,
      maxDb: -22,
      avgDb: -30,
      likelySilent: false,
    );
  }

  @override
  Future<NativeRecordingLevel> currentLevel() async {
    return const NativeRecordingLevel(
      currentDb: -30,
      peakDb: -22,
      maxDb: -22,
      avgDb: -30,
    );
  }

  @override
  Future<void> dispose() async {}
}

mixin FakeNativeMicPermissionPlatform {
  Future<NativeMicrophonePermission> microphonePermission() async {
    return const NativeMicrophonePermission(
      status: 'granted',
      granted: true,
      canRequest: false,
    );
  }

  Future<NativeMicrophonePermission> requestMicrophonePermission() async {
    return const NativeMicrophonePermission(
      status: 'granted',
      granted: true,
      canRequest: false,
    );
  }
}
