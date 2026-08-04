import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/voice_capture/audio/audio_capture_diagnostics.dart';
import 'package:voicememory_mobile/features/voice_capture/audio/native_audio_recorder.dart';

void main() {
  test('NativeRecorderException parses native failure step from platform', () {
    final exception = NativeRecorderException.fromPlatform(
      PlatformException(
        code: 'native_recorder_start',
        message: 'OSStatus error -50.',
        details: const {
          'step': 'recorder_init_failed',
          'reason': 'OSStatus error -50.',
        },
      ),
    );

    expect(exception.step, 'recorder_init_failed');
    expect(exception.reason, contains('-50'));
  });

  test('native AAC start success returns resolved path', () async {
    final recorder = NativeAudioRecorder(
      platform: _ResolvedPathPlatform('/tmp/vm_native.m4a'),
      config: const NativeAudioCaptureConfig(format: NativeAudioFormat.aac),
    );

    expect(
      await recorder.startRecording('/tmp/vm_native.m4a'),
      '/tmp/vm_native.m4a',
    );
  });

  test('native start can resolve wav path after AAC fallback', () async {
    final recorder = NativeAudioRecorder(
      platform: _ResolvedPathPlatform('/tmp/vm_native.wav'),
      config: const NativeAudioCaptureConfig(format: NativeAudioFormat.aac),
    );

    expect(
      await recorder.startRecording('/tmp/vm_native.m4a'),
      '/tmp/vm_native.wav',
    );
  });

  test('native start failure remains a clean NativeRecorderException', () {
    final recorder = NativeAudioRecorder(platform: _BothFailPlatform());

    expect(
      () => recorder.startRecording('/tmp/vm_native.wav'),
      throwsA(
        isA<NativeRecorderException>().having(
          (error) => error.step,
          'step',
          'record_start_failed',
        ),
      ),
    );
  });

  test('upload content type supports m4a and wav native paths', () {
    expect(
      AudioCaptureDiagnostics.uploadContentTypeForPath('/tmp/vm_native.m4a'),
      'audio/mp4',
    );
    expect(
      AudioCaptureDiagnostics.uploadContentTypeForPath('/tmp/vm_native.wav'),
      'audio/wav',
    );
  });

  test('stop result preserves wav format metadata', () {
    const result = NativeRecordingStopResult(
      path: '/tmp/vm_native.wav',
      bytes: 8192,
      durationMs: 3000,
      minDb: -30,
      maxDb: -18,
      avgDb: -24,
      likelySilent: false,
      format: 'wav',
    );

    expect(result.format, 'wav');
    expect(result.toAudioLevelSummary().likelySilent, isFalse);
  });
}

abstract class _BaseNativePlatform implements NativeAudioRecorderPlatform {
  @override
  Future<NativeRecordingLevel> currentLevel() async {
    return const NativeRecordingLevel(
      currentDb: -25,
      peakDb: -20,
      maxDb: -20,
      avgDb: -25,
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
  Future<NativeRecordingStopResult> stop() async {
    return const NativeRecordingStopResult(
      path: '/tmp/vm_native.wav',
      bytes: 4096,
      durationMs: 2500,
      minDb: -28,
      maxDb: -16,
      avgDb: -22,
      likelySilent: false,
      format: 'wav',
    );
  }
}

class _ResolvedPathPlatform extends _BaseNativePlatform {
  _ResolvedPathPlatform(this.resolvedPath);

  final String resolvedPath;

  @override
  Future<NativeAudioStartResult> start(
    String path,
    NativeAudioCaptureConfig config,
  ) async {
    return NativeAudioStartResult(
      path: resolvedPath,
      format: resolvedPath.endsWith('.m4a') ? 'aac' : 'wav',
    );
  }
}

class _BothFailPlatform extends _BaseNativePlatform {
  @override
  Future<NativeAudioStartResult> start(
    String path,
    NativeAudioCaptureConfig config,
  ) async {
    throw const NativeRecorderException(
      step: 'record_start_failed',
      reason: 'Native recorder returned false',
      format: 'wav',
    );
  }
}
