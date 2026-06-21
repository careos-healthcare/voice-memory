import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/voice_capture/audio/ios_native_recorder.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_environment.dart';

void main() {
  tearDown(() {
    IosNativeRecorder.testPlatform = null;
    IosNativeRecorder.platformIsIosOverride = null;
    MicrophonePermissionEnvironment.resetForTest();
  });

  test('shouldUseOnDevice is true for physical iOS when platform available', () async {
    MicrophonePermissionEnvironment.setIosPhysicalForTest(true);
    IosNativeRecorder.platformIsIosOverride = true;
    IosNativeRecorder.testPlatform = _AlwaysAvailableNativePlatform();

    expect(
      await IosNativeRecorder.shouldUseOnDevice(enabledOverride: true),
      isTrue,
    );
  });

  test('stop result maps to audio level summary', () {
    const result = NativeRecordingStopResult(
      path: '/tmp/native.m4a',
      bytes: 1000,
      durationMs: 2500,
      minDb: -40,
      maxDb: -20,
      avgDb: -28,
      likelySilent: false,
    );

    final summary = result.toAudioLevelSummary();
    expect(summary.maxDb, -20);
    expect(summary.avgDb, -28);
    expect(summary.likelySilent, isFalse);
  });
}

class _AlwaysAvailableNativePlatform implements IosNativeRecorderPlatform {
  @override
  Future<NativeRecordingLevel> currentNativeLevel() async {
    return const NativeRecordingLevel(
      currentDb: -30,
      peakDb: -25,
      maxDb: -25,
      avgDb: -30,
    );
  }

  @override
  Future<bool> isNativeRecorderAvailable() async => true;

  @override
  Future<NativeMicrophonePermission> nativeMicrophonePermission() async {
    return const NativeMicrophonePermission(
      status: 'granted',
      granted: true,
      canRequest: false,
    );
  }

  @override
  Future<NativeMicrophonePermission> requestNativeMicrophonePermission() async {
    return const NativeMicrophonePermission(
      status: 'granted',
      granted: true,
      canRequest: false,
    );
  }

  @override
  Future<String> startNativeRecording(
    String path, {
    required dynamic format,
  }) async => path;

  @override
  Future<NativeRecordingStopResult> stopNativeRecording() async {
    return const NativeRecordingStopResult(
      path: '/tmp/native.m4a',
      bytes: 1000,
      durationMs: 2500,
      minDb: -40,
      maxDb: -20,
      avgDb: -28,
      likelySilent: false,
    );
  }
}
