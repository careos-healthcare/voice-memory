import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/voice_capture/audio/audio_capture_diagnostics.dart';
import 'package:voicememory_mobile/features/voice_capture/audio/ios_native_recorder.dart';

void main() {
  tearDown(() {
    IosNativeRecorder.testPlatform = null;
  });

  test('NativeRecorderException parses native failure step from platform', () {
    final exception = NativeRecorderException.fromPlatform(
      PlatformException(
        code: 'native_recorder_start',
        message: 'OSStatus error -50.',
        details: const {'step': 'recorder_init_failed', 'reason': 'OSStatus error -50.'},
      ),
    );

    expect(exception.step, 'recorder_init_failed');
    expect(exception.reason, contains('-50'));
  });

  test('native AAC start success returns resolved path', () async {
    IosNativeRecorder.testPlatform = _AacSuccessPlatform();

    final path = await IosNativeRecorder.startRecording('/tmp/vm_native.m4a');

    expect(path, '/tmp/vm_native.m4a');
  });

  test('native start can resolve wav path after AAC fallback on device', () async {
    IosNativeRecorder.testPlatform = _FallbackSuccessPlatform();

    final path = await IosNativeRecorder.startRecording('/tmp/vm_native.m4a');

    expect(path, '/tmp/vm_native.wav');
  });

  test('native both formats fail returns clean NativeRecorderException', () async {
    IosNativeRecorder.testPlatform = _BothFailPlatform();

    expect(
      () => IosNativeRecorder.startRecording('/tmp/vm_native.m4a'),
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

class _AacSuccessPlatform implements IosNativeRecorderPlatform {
  @override
  Future<NativeRecordingLevel> currentNativeLevel() async {
    return const NativeRecordingLevel(
      currentDb: -25,
      peakDb: -20,
      maxDb: -20,
      avgDb: -25,
    );
  }

  @override
  Future<bool> isNativeRecorderAvailable() async => true;

  @override
  Future<String> startNativeRecording(String path) async => path;

  @override
  Future<NativeRecordingStopResult> stopNativeRecording() async {
    return const NativeRecordingStopResult(
      path: '/tmp/vm_native.m4a',
      bytes: 2048,
      durationMs: 2500,
      minDb: -30,
      maxDb: -20,
      avgDb: -25,
      likelySilent: false,
      format: 'aac',
    );
  }
}

class _FallbackSuccessPlatform implements IosNativeRecorderPlatform {
  @override
  Future<NativeRecordingLevel> currentNativeLevel() async {
    return const NativeRecordingLevel(
      currentDb: -25,
      peakDb: -20,
      maxDb: -20,
      avgDb: -25,
    );
  }

  @override
  Future<bool> isNativeRecorderAvailable() async => true;

  @override
  Future<String> startNativeRecording(String path) async {
    return path.replaceAll('.m4a', '.wav');
  }

  @override
  Future<NativeRecordingStopResult> stopNativeRecording() async {
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

class _BothFailPlatform implements IosNativeRecorderPlatform {
  @override
  Future<NativeRecordingLevel> currentNativeLevel() async {
    return const NativeRecordingLevel(
      currentDb: -160,
      peakDb: -160,
      maxDb: -160,
      avgDb: -160,
    );
  }

  @override
  Future<bool> isNativeRecorderAvailable() async => true;

  @override
  Future<String> startNativeRecording(String path) async {
    throw const NativeRecorderException(
      step: 'record_start_failed',
      reason: 'AVAudioRecorder.record() returned false for wav',
      format: 'wav',
    );
  }

  @override
  Future<NativeRecordingStopResult> stopNativeRecording() async {
    throw const NativeRecorderException(
      step: 'stop',
      reason: 'No active native recording',
    );
  }
}
