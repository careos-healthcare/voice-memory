import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:voicememory_mobile/audio/recording_service.dart';
import 'package:voicememory_mobile/features/voice_capture/audio/ios_native_recorder.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_environment.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_gateway.dart';

class FakeIosNativeRecorderPlatform implements IosNativeRecorderPlatform {
  int startCallCount = 0;
  int stopCallCount = 0;
  String? lastPath;
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
  Future<NativeRecordingLevel> currentNativeLevel() async {
    return NativeRecordingLevel(
      currentDb: stopResult.avgDb,
      peakDb: stopResult.maxDb,
      maxDb: stopResult.maxDb,
      avgDb: stopResult.avgDb,
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
  }) async {
    startCallCount += 1;
    lastPath = path;
    final file = File(path);
    if (!file.parent.existsSync()) {
      await file.parent.create(recursive: true);
    }
    if (!file.existsSync()) {
      await file.writeAsBytes(List<int>.filled(128, 1));
    }
    return path;
  }

  @override
  Future<NativeRecordingStopResult> stopNativeRecording() async {
    stopCallCount += 1;
    return stopResult.copyWith(path: lastPath ?? stopResult.path);
  }
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

  late FakeIosNativeRecorderPlatform nativePlatform;

  setUp(() {
    nativePlatform = FakeIosNativeRecorderPlatform();
    IosNativeRecorder.testPlatform = nativePlatform;
    MicrophonePermissionEnvironment.setIosPhysicalForTest(true);
  });

  tearDown(() {
    IosNativeRecorder.testPlatform = null;
    MicrophonePermissionEnvironment.resetForTest();
  });

  test('physical iOS uses native recorder when flag enabled', () async {
    final recording = RecordingService.create(
      testMode: true,
      permissionGateway: FakeMicrophonePermissionGateway(
        statusValue: PermissionStatus.granted,
        hasRecorder: true,
      ),
      useNativeRecorderOverride: true,
    );

    await recording.startRecording();
    expect(recording.usingNativeRecorder, isTrue);
    expect(recording.nativeStartCallCount, 1);
    expect(nativePlatform.startCallCount, 1);
    expect(nativePlatform.lastPath, isNotNull);
  });

  test('native stop preserves path bytes duration and levels', () async {
    final recording = RecordingService.create(
      testMode: true,
      useNativeRecorderOverride: true,
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

    final recording = RecordingService.create(
      testMode: true,
      useNativeRecorderOverride: true,
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
      await IosNativeRecorder.shouldUseOnDevice(enabledOverride: true),
      isFalse,
    );
  });
}
