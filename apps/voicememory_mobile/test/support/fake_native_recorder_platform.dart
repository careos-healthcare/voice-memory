import 'package:voicememory_mobile/features/voice_capture/audio/ios_native_recorder.dart';
import 'package:voicememory_mobile/features/voice_capture/audio/ios_native_recorder_config.dart';

class ConfigurableFakeNativeMicPermissionPlatform
    implements IosNativeRecorderPlatform {
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
  Future<bool> isNativeRecorderAvailable() async => available;

  @override
  Future<NativeMicrophonePermission> nativeMicrophonePermission() async {
    return statusValue;
  }

  @override
  Future<NativeMicrophonePermission> requestNativeMicrophonePermission() async {
    requestCallCount += 1;
    final next = requestResult ?? statusValue;
    statusValue = next;
    return next;
  }

  @override
  Future<String> startNativeRecording(
    String path, {
    required IosRecordingFormat format,
  }) async {
    return path;
  }

  @override
  Future<NativeRecordingStopResult> stopNativeRecording() async {
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
  Future<NativeRecordingLevel> currentNativeLevel() async {
    return const NativeRecordingLevel(
      currentDb: -30,
      peakDb: -22,
      maxDb: -22,
      avgDb: -30,
    );
  }
}

mixin FakeNativeMicPermissionPlatform {
  Future<NativeMicrophonePermission> nativeMicrophonePermission() async {
    return const NativeMicrophonePermission(
      status: 'granted',
      granted: true,
      canRequest: false,
    );
  }

  Future<NativeMicrophonePermission> requestNativeMicrophonePermission() async {
    return const NativeMicrophonePermission(
      status: 'granted',
      granted: true,
      canRequest: false,
    );
  }
}
