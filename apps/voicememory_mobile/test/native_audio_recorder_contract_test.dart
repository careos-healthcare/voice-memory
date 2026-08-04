import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/voice_capture/audio/native_audio_recorder.dart';
import 'package:voicememory_mobile/services/analytics/ffi_safety_monitor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(NativeAudioRecorder.channelName);

  tearDown(() {
    FFISafetyMonitor.install(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('default config serializes platform-neutral capture values', () {
    expect(const NativeAudioCaptureConfig().toMap(), {
      'format': 'wav',
      'sampleRate': 16000,
      'channels': 1,
      'bitDepth': 16,
      'bufferDurationMs': 20.0,
      'sessionMode': 'spokenAudio',
      'acousticEchoCancellation': 'default',
      'noiseSuppression': 'default',
      'automaticGainControl': 'default',
    });
  });

  test('processing controls serialize, normalize, and copy unchanged', () {
    const config = NativeAudioCaptureConfig(
      acousticEchoCancellation: NativeAudioProcessingControl.enabled,
      noiseSuppression: NativeAudioProcessingControl.disabled,
      automaticGainControl: NativeAudioProcessingControl.enabled,
    );

    expect(
      config.normalized().toMap(),
      containsPair('noiseSuppression', 'disabled'),
    );
    expect(
      config
          .copyWith(
            acousticEchoCancellation: NativeAudioProcessingControl.disabled,
          )
          .toMap(),
      containsPair('acousticEchoCancellation', 'disabled'),
    );
  });

  test('invalid config values normalize to shared native bounds', () {
    final normalized = NativeAudioCaptureConfig(
      sampleRate: -1,
      channels: 99,
      bitDepth: 2,
      bufferDuration: Duration.zero,
    ).normalized();

    expect(normalized.sampleRate, 8000);
    expect(normalized.channels, 2);
    expect(normalized.bitDepth, 8);
    expect(normalized.bufferDuration, const Duration(milliseconds: 1));
  });

  test('availability and unknown format fallback are stable', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'isNativeRecorderAvailable');
          return true;
        });

    expect(
      await MethodChannelNativeAudioRecorderPlatform().isAvailable(),
      isTrue,
    );
    expect(
      NativeAudioFormat.fromChannelValue('unsupported'),
      NativeAudioFormat.wavPcm16,
    );
  });

  test(
    'method channel sends config and maps applied start diagnostics',
    () async {
      MethodCall? received;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            received = call;
            return {
              'path': '/tmp/applied.wav',
              'format': 'wav',
              'sampleRate': 16000,
              'channels': 1,
              'bitDepth': 16,
              'bufferDurationMs': 24.0,
              'audioSource': 'VOICE_RECOGNITION',
              'processing': {
                'requested': {
                  'acousticEchoCancellation': 'enabled',
                  'noiseSuppression': 'disabled',
                  'automaticGainControl': 'default',
                },
                'applied': {
                  'acousticEchoCancellation': 'enabled',
                  'noiseSuppression': 'disabled',
                  'automaticGainControl': 'default',
                },
                'supported': {
                  'acousticEchoCancellation': true,
                  'noiseSuppression': true,
                  'automaticGainControl': false,
                },
                'enabled': {
                  'acousticEchoCancellation': true,
                  'noiseSuppression': false,
                },
                'voiceProcessingMode': false,
                'platformManaged': false,
              },
            };
          });

      final result = await MethodChannelNativeAudioRecorderPlatform().start(
        '/tmp/requested.wav',
        const NativeAudioCaptureConfig(),
      );

      expect(received?.method, 'startNativeRecording');
      expect((received?.arguments as Map)['config']['sampleRate'], 16000);
      expect(
        (received?.arguments as Map)['config']['acousticEchoCancellation'],
        'default',
      );
      expect(result.path, '/tmp/applied.wav');
      expect(result.bufferDurationMs, 24);
      expect(result.audioSource, 'VOICE_RECOGNITION');
      expect(result.processing.acousticEchoCancellationEnabled, isTrue);
      expect(result.processing.automaticGainControlEnabled, isNull);
    },
  );

  test('level and stop metadata map without losing diagnostics', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'currentNativeLevel') {
            return {
              'currentDb': -27.5,
              'peakDb': -18,
              'maxDb': -18,
              'avgDb': -25,
            };
          }
          return {
            'path': '/tmp/native.wav',
            'bytes': 32044,
            'durationMs': 1000,
            'minDb': -40,
            'maxDb': -18,
            'avgDb': -25,
            'likelySilent': false,
            'sampleRate': 16000,
            'bufferBytes': 2048,
            'audioSessionId': 42,
            'inputPortName': 'Built-in mic',
          };
        });

    final platform = MethodChannelNativeAudioRecorderPlatform();
    expect((await platform.currentLevel()).currentDb, -27.5);
    final stopped = await platform.stop();
    expect(stopped.sampleRate, 16000);
    expect(stopped.bufferBytes, 2048);
    expect(stopped.audioSessionId, 42);
    expect(stopped.inputPortName, 'Built-in mic');
  });

  test('legacy result payloads tolerate absent processing metadata', () {
    final start = NativeAudioStartResult.fromMap(const {
      'path': '/tmp/legacy.wav',
    }, fallbackPath: '/tmp/fallback.wav');
    final stop = NativeRecordingStopResult.fromMap(const {
      'path': '/tmp/legacy.wav',
    });

    expect(start.processing.voiceProcessingMode, isNull);
    expect(stop.processing.acousticEchoCancellationSupported, isNull);
  });

  test('start platform failure is normalized', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(
            code: 'native_recorder_start',
            message: 'failed',
            details: {'step': 'record_start_failed', 'format': 'wav'},
          );
        });

    expect(
      () => MethodChannelNativeAudioRecorderPlatform().start(
        '/tmp/native.wav',
        const NativeAudioCaptureConfig(),
      ),
      throwsA(
        isA<NativeRecorderException>().having(
          (error) => error.step,
          'step',
          'record_start_failed',
        ),
      ),
    );
  });

  test('dispose reaches native cleanup', () async {
    var disposed = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          disposed = call.method == 'disposeNativeRecorder';
          return null;
        });

    await MethodChannelNativeAudioRecorderPlatform().dispose();
    expect(disposed, isTrue);
  });

  test('Apex ledger balances native recorder start and stop', () async {
    final monitor = FFISafetyMonitor(rssPressureThresholdBytes: 1 << 40);
    FFISafetyMonitor.install(monitor);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'startNativeRecording') {
            return {'path': '/tmp/apex.wav'};
          }
          if (call.method == 'stopNativeRecording') {
            return {
              'path': '/tmp/apex.wav',
              'bytes': 44,
              'durationMs': 1,
              'minDb': -40,
              'maxDb': -20,
              'avgDb': -30,
              'likelySilent': false,
            };
          }
          return null;
        });
    final recorder = NativeAudioRecorder();

    await recorder.startRecording('/tmp/apex.wav');
    expect(monitor.snapshot.byKind[FFIResourceKind.nativeAudioRecorder], 1);
    await recorder.stopRecording();

    monitor.assertNoLeaks();
    await recorder.dispose();
    await monitor.dispose();
  });
}
