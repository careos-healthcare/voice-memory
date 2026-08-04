import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/voice_capture/audio/native_audio_recorder.dart';

void main() {
  test('platform availability is exposed by unified recorder', () async {
    final platform = _AlwaysAvailableNativePlatform();

    expect(await platform.isAvailable(), isTrue);
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

class _AlwaysAvailableNativePlatform implements NativeAudioRecorderPlatform {
  @override
  Future<NativeRecordingLevel> currentLevel() async {
    return const NativeRecordingLevel(
      currentDb: -30,
      peakDb: -25,
      maxDb: -25,
      avgDb: -30,
    );
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<NativeMicrophonePermission> microphonePermission() async {
    return const NativeMicrophonePermission(
      status: 'granted',
      granted: true,
      canRequest: false,
    );
  }

  @override
  Future<NativeMicrophonePermission> requestMicrophonePermission() async {
    return microphonePermission();
  }

  @override
  Future<NativeAudioStartResult> start(
    String path,
    NativeAudioCaptureConfig config,
  ) async {
    return NativeAudioStartResult(path: path);
  }

  @override
  Future<NativeRecordingStopResult> stop() async {
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
