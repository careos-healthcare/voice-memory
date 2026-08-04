import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:voicememory_mobile/audio/recording_service.dart';
import 'package:voicememory_mobile/features/voice_capture/audio/native_audio_recorder.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_environment.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_gateway.dart';

class FakeNativeAudioRecorderPlatform implements NativeAudioRecorderPlatform {
  int startCallCount = 0;
  int stopCallCount = 0;
  String? lastPath;
  bool failStart = false;
  NativeRecordingStopResult stopResult = const NativeRecordingStopResult(
    path: '/tmp/vm_native_test.m4a',
    bytes: 2048,
    durationMs: 3500,
    minDb: -38,
    maxDb: -22,
    avgDb: -30,
    likelySilent: false,
  );

  @override
  Future<NativeRecordingLevel> currentLevel() async {
    return NativeRecordingLevel(
      currentDb: stopResult.avgDb,
      peakDb: stopResult.maxDb,
      maxDb: stopResult.maxDb,
      avgDb: stopResult.avgDb,
    );
  }

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
    return const NativeMicrophonePermission(
      status: 'granted',
      granted: true,
      canRequest: false,
    );
  }

  @override
  Future<NativeAudioStartResult> start(
    String path,
    NativeAudioCaptureConfig config,
  ) async {
    startCallCount += 1;
    if (failStart) {
      throw const NativeRecorderException(
        step: 'record_start_failed',
        reason: 'synthetic failure',
      );
    }
    lastPath = path;
    final file = File(path);
    if (!file.parent.existsSync()) {
      await file.parent.create(recursive: true);
    }
    if (!file.existsSync()) {
      await file.writeAsBytes(List<int>.filled(128, 1));
    }
    return NativeAudioStartResult(path: path);
  }

  @override
  Future<NativeRecordingStopResult> stop() async {
    stopCallCount += 1;
    return stopResult.copyWith(path: lastPath ?? stopResult.path);
  }

  int disposeCallCount = 0;

  @override
  Future<void> dispose() async {
    disposeCallCount += 1;
  }
}

class DelegatingAudioRecorderPlatform implements AudioRecorderPlatform {
  DelegatingAudioRecorderPlatform(this._delegate, {required this.useOnDevice});

  final bool useOnDevice;
  final NativeAudioRecorder _delegate;

  @override
  NativeAudioCaptureConfig get config => _delegate.config;

  @override
  Future<bool> shouldUseOnDevice() async => useOnDevice;

  @override
  Future<NativeMicrophonePermission> microphonePermission() =>
      _delegate.microphonePermission();

  @override
  Future<NativeMicrophonePermission> requestMicrophonePermission() =>
      _delegate.requestMicrophonePermission();

  @override
  Future<String> startRecording(
    String path, {
    NativeAudioCaptureConfig? config,
  }) => _delegate.startRecording(path, config: config);

  @override
  Future<NativeAudioStartResult> start(
    String path, {
    NativeAudioCaptureConfig? config,
  }) => _delegate.start(path, config: config);

  @override
  Future<NativeRecordingStopResult> stopRecording() =>
      _delegate.stopRecording();

  @override
  Future<NativeRecordingLevel> currentLevel() => _delegate.currentLevel();

  @override
  Future<void> dispose() => _delegate.dispose();
}

extension on NativeRecordingStopResult {
  NativeRecordingStopResult copyWith({String? path}) {
    return NativeRecordingStopResult(
      path: path ?? this.path,
      bytes: bytes,
      durationMs: durationMs,
      minDb: minDb,
      maxDb: maxDb,
      avgDb: avgDb,
      likelySilent: likelySilent,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeNativeAudioRecorderPlatform nativePlatform;

  setUp(() {
    nativePlatform = FakeNativeAudioRecorderPlatform();
    MicrophonePermissionEnvironment.setIosPhysicalForTest(true);
  });

  tearDown(() {
    MicrophonePermissionEnvironment.resetForTest();
  });

  AudioRecorderPlatform audioPlatform({bool useOnDevice = true}) {
    return DelegatingAudioRecorderPlatform(
      NativeAudioRecorder(platform: nativePlatform),
      useOnDevice: useOnDevice,
    );
  }

  test('physical iOS uses native recorder when flag enabled', () async {
    final recording = RecordingService(
      testMode: true,
      permissionGateway: FakeMicrophonePermissionGateway(
        statusValue: PermissionStatus.granted,
        hasRecorder: true,
      ),
      audioRecorderPlatform: audioPlatform(),
    );

    await recording.startRecording();
    expect(recording.usingNativeRecorder, isTrue);
    expect(recording.nativeStartCallCount, 1);
    expect(nativePlatform.startCallCount, 1);
    expect(nativePlatform.lastPath, isNotNull);
  });

  test('native stop preserves path bytes duration and levels', () async {
    final recording = RecordingService(
      testMode: true,
      audioRecorderPlatform: audioPlatform(),
    );

    await recording.startRecording();
    final result = await recording.stopRecording();

    expect(nativePlatform.stopCallCount, 1);
    expect(result.file.path, nativePlatform.lastPath);
    expect(result.durationSeconds, greaterThan(0));
    expect(result.likelySilentInput, isFalse);
    expect(result.audioLevelSummary?.maxDb, -22);
  });

  test('silent native result routes likelySilent=true', () async {
    nativePlatform.stopResult = const NativeRecordingStopResult(
      path: '/tmp/vm_native_silent.m4a',
      bytes: 1024,
      durationMs: 2000,
      minDb: -90,
      maxDb: -52,
      avgDb: -80,
      likelySilent: true,
    );

    final recording = RecordingService(
      testMode: true,
      audioRecorderPlatform: audioPlatform(),
    );

    await recording.startRecording();
    final result = await recording.stopRecording();

    expect(result.likelySilentInput, isTrue);
    expect(result.audioLevelSummary?.likelySilent, isTrue);
  });

  test('healthy native levels are not marked silent', () async {
    expect(
      const NativeRecordingStopResult(
        path: '/tmp/healthy.m4a',
        bytes: 4096,
        durationMs: 4000,
        minDb: -35,
        maxDb: -18,
        avgDb: -25,
        likelySilent: false,
      ).likelySilent,
      isFalse,
    );
  });

  test('shouldUseOnDevice is false on non-physical platform', () async {
    MicrophonePermissionEnvironment.setIosPhysicalForTest(false);
    expect(
      await NativeAudioRecorder(platform: nativePlatform).shouldUseOnDevice(),
      isFalse,
    );
  });

  test('native start failure disposes platform state', () async {
    nativePlatform.failStart = true;
    final recording = RecordingService(
      testMode: true,
      audioRecorderPlatform: audioPlatform(),
    );

    await expectLater(
      recording.startRecording(),
      throwsA(isA<NativeRecorderException>()),
    );
    expect(nativePlatform.disposeCallCount, 1);

    recording.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(nativePlatform.disposeCallCount, 1);
  });

  test('dispose releases an active native capture', () async {
    final recording = RecordingService(
      testMode: true,
      audioRecorderPlatform: audioPlatform(),
    );
    await recording.startRecording();

    recording.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(nativePlatform.disposeCallCount, 1);
  });

  test('injected selection is isolated between service instances', () async {
    final nativePlatformA = FakeNativeAudioRecorderPlatform();
    final nativePlatformB = FakeNativeAudioRecorderPlatform();
    final nativeService = RecordingService(
      testMode: true,
      audioRecorderPlatform: DelegatingAudioRecorderPlatform(
        NativeAudioRecorder(platform: nativePlatformA),
        useOnDevice: true,
      ),
    );
    final fallbackService = RecordingService(
      testMode: true,
      audioRecorderPlatform: DelegatingAudioRecorderPlatform(
        NativeAudioRecorder(platform: nativePlatformB),
        useOnDevice: false,
      ),
    );

    await Future.wait([
      nativeService.startRecording(),
      fallbackService.startRecording(),
    ]);

    expect(nativeService.usingNativeRecorder, isTrue);
    expect(fallbackService.usingNativeRecorder, isFalse);
    expect(nativePlatformA.startCallCount, 1);
    expect(nativePlatformB.startCallCount, 0);

    nativeService.dispose();
    fallbackService.dispose();
  });
}
