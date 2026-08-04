import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/features/live_audio/application/live_audio_focus_gateway.dart';
import 'package:voicememory_mobile/features/live_audio/application/live_audio_session_coordinator.dart';
import 'package:voicememory_mobile/features/live_audio/application/live_voice_capture_service.dart';
import 'package:voicememory_mobile/features/live_audio/domain/models/live_audio_session_config.dart';
import 'package:voicememory_mobile/features/live_audio/domain/services/live_pcm16_capture_source.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/native_audio_lifecycle_bridge.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/live_audio_session_api_client.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/live_audio_socket_connection.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/live_audio_websocket_client.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/live_pcm24_playback_engine.dart';
import 'package:voicememory_mobile/features/live_audio/live_audio_constants.dart';
import 'package:voicememory_mobile/features/live_audio/presentation/controllers/live_audio_session_controller.dart';
import 'package:voicememory_mobile/security/api_usage_guard.dart';
import 'package:voicememory_mobile/services/capture_attest_service.dart';
import 'package:voicememory_mobile/services/capture_pipeline_service.dart';
import 'package:voicememory_mobile/storage/capture_token_cache.dart';
import 'package:voicememory_mobile/storage/device_id.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LiveAudioFocusGateway', () {
    test('liveVoiceAudioSessionConfiguration uses voice chat routing', () {
      const config = LiveAudioFocusGateway.liveVoiceAudioSessionConfiguration;
      expect(
        config.avAudioSessionCategory,
        AVAudioSessionCategory.playAndRecord,
      );
      expect(config.avAudioSessionMode, AVAudioSessionMode.voiceChat);
      expect(
        config.androidAudioAttributes?.usage,
        AndroidAudioUsage.voiceCommunication,
      );
      expect(
        config.androidAudioFocusGainType,
        AndroidAudioFocusGainType.gainTransientExclusive,
      );
    });

    test('shouldResumeAfterInterruption resumes pause and duck endings', () {
      expect(
        LiveAudioFocusGateway.shouldResumeAfterInterruption(
          AudioInterruptionEvent(false, AudioInterruptionType.pause),
        ),
        isTrue,
      );
      expect(
        LiveAudioFocusGateway.shouldResumeAfterInterruption(
          AudioInterruptionEvent(false, AudioInterruptionType.duck),
        ),
        isTrue,
      );
      expect(
        LiveAudioFocusGateway.shouldResumeAfterInterruption(
          AudioInterruptionEvent(true, AudioInterruptionType.pause),
        ),
        isFalse,
      );
      expect(
        LiveAudioFocusGateway.shouldResumeAfterInterruption(
          AudioInterruptionEvent(false, AudioInterruptionType.unknown),
        ),
        isFalse,
      );
    });

    test('resumeCaptureIfPossible defers when app is backgrounded', () async {
      final built = _buildCaptureService();
      final service = built.service;
      final sinkController = built.sinkController;
      final session = _FakeAudioSession();
      final gateway = LiveAudioFocusGateway(
        captureService: service,
        resolveSession: () async => session,
        interruptionEventsForTest: const Stream<AudioInterruptionEvent>.empty(),
        initialAppLifecycle: AppLifecycleState.paused,
      );

      await gateway.initializeAndRequestFocus();
      await _startConnected(service, sinkController);
      await service.pauseLiveCapture();
      final callsBeforeDeferredResume = session.setActiveTrueCalls;

      await gateway.resumeCaptureIfPossible();

      expect(gateway.deferredFocusResume, isTrue);
      expect(service.isPausedByAudioFocus, isTrue);
      expect(session.setActiveTrueCalls, callsBeforeDeferredResume);

      gateway.updateAppLifecycle(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(gateway.deferredFocusResume, isFalse);
      expect(service.isPausedByAudioFocus, isFalse);
      expect(
        session.setActiveTrueCalls,
        greaterThan(callsBeforeDeferredResume),
      );

      await gateway.dispose();
      await service.dispose();
      await sinkController.close();
    });

    test(
      'interruption end reactivates focus before resuming capture',
      () async {
        final interruptions = StreamController<AudioInterruptionEvent>();
        final built = _buildCaptureService();
        final service = built.service;
        final sinkController = built.sinkController;
        final session = _FakeAudioSession();
        final gateway = LiveAudioFocusGateway(
          captureService: service,
          resolveSession: () async => session,
          interruptionEventsForTest: interruptions.stream,
          initialAppLifecycle: AppLifecycleState.resumed,
        );

        await gateway.initializeAndRequestFocus();
        await _startConnected(service, sinkController);

        interruptions.add(
          AudioInterruptionEvent(true, AudioInterruptionType.pause),
        );
        await Future<void>.delayed(Duration.zero);
        expect(service.isPausedByAudioFocus, isTrue);
        final callsBeforeInterruptionEnd = session.setActiveTrueCalls;

        interruptions.add(
          AudioInterruptionEvent(false, AudioInterruptionType.pause),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          session.setActiveTrueCalls,
          greaterThan(callsBeforeInterruptionEnd),
        );
        expect(service.isPausedByAudioFocus, isFalse);

        await gateway.dispose();
        await service.dispose();
        await interruptions.close();
        await sinkController.close();
      },
    );

    test(
      'native lifecycle bridge is attached during focus initialization',
      () async {
        final built = _buildCaptureService();
        final service = built.service;
        final sinkController = built.sinkController;
        final session = _FakeAudioSession();
        final bridge = NativeAudioLifecycleBridge(service);
        final gateway = LiveAudioFocusGateway(
          captureService: service,
          resolveSession: () async => session,
          interruptionEventsForTest:
              const Stream<AudioInterruptionEvent>.empty(),
          nativeLifecycleBridge: bridge,
          initialAppLifecycle: AppLifecycleState.resumed,
        );

        await gateway.initializeAndRequestFocus();
        await _startConnected(service, sinkController);

        await bridge.handleNativeEvent(
          const MethodCall('onAudioInterruptionBegan'),
        );
        expect(service.isPausedByAudioFocus, isTrue);

        await bridge.handleNativeEvent(
          const MethodCall('onAudioInterruptionEnded'),
        );
        expect(service.isPausedByAudioFocus, isFalse);

        await gateway.dispose();
        await service.dispose();
        await sinkController.close();
      },
    );
  });
}

Future<void> _startConnected(
  LiveVoiceCaptureService service,
  StreamController<dynamic> sinkController,
) async {
  final startFuture = service.start();
  await Future<void>.delayed(Duration.zero);
  sinkController.add(jsonEncode({'setupComplete': {}}));
  await startFuture;
}

({LiveVoiceCaptureService service, StreamController<dynamic> sinkController})
_buildCaptureService() {
  ApiUsageGuard.resetForTest(
    replacement: ApiUsageGuard(maxAttemptsPerScope: 3),
  );
  final sinkController = StreamController<dynamic>();
  final journalFile = File(
    '${Directory.systemTemp.path}/live_focus_test_${DateTime.now().microsecondsSinceEpoch}.json',
  );

  final coordinator = LiveAudioSessionCoordinator(
    sessionApi: _FakeSessionApi(),
    attest: CaptureAttestService(
      api: _FakeApi(),
      deviceIds: _FakeDeviceIdStore(),
      tokenCache: CaptureTokenCache()
        ..setToken('capture-token', expiresInSeconds: 3600),
    ),
    webSocketClient: LiveAudioWebSocketClient(
      connectionFactory: (_, {headers}) => _FakeSocket(sinkController),
    ),
    captureSource: _FakeCapture(),
    usageGuard: ApiUsageGuard.shared,
  );

  return (
    service: LiveVoiceCaptureService(
      controller: LiveAudioSessionController(coordinator),
      pipeline: _NoopPipeline(journalFile: journalFile),
      playback: _SilentPlayback(),
    ),
    sinkController: sinkController,
  );
}

class _FakeAudioSession implements AudioSession {
  var setActiveTrueCalls = 0;

  @override
  Future<void> configure(AudioSessionConfiguration configuration) async {}

  @override
  Future<bool> setActive(
    bool active, {
    AVAudioSessionSetActiveOptions? avAudioSessionSetActiveOptions,
    AndroidAudioFocusGainType? androidAudioFocusGainType,
    AndroidAudioAttributes? androidAudioAttributes,
    bool? androidWillPauseWhenDucked,
    AudioSessionConfiguration fallbackConfiguration =
        const AudioSessionConfiguration.music(),
  }) async {
    if (active) setActiveTrueCalls++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCapture implements LivePcm16CaptureSource {
  @override
  bool isCapturing = false;

  @override
  Future<void> start({required void Function(List<int> chunk) onChunk}) async {
    isCapturing = true;
  }

  @override
  Future<void> stop() async {
    isCapturing = false;
  }

  @override
  void dispose() {}
}

class _FakeSessionApi implements LiveAudioSessionApiClient {
  @override
  Future<LiveAudioSessionConfig> mintSession({
    required String captureToken,
    String? idempotencyKey,
  }) async {
    return LiveAudioSessionConfig(
      sessionId: 'session_focus',
      sessionToken: 'token',
      proxyWebSocketUrl: 'wss://example.test/api/live-audio/ws',
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      model: 'gemini-2.5-flash-native-audio-preview-12-2025',
      inputAudioMimeType: liveInputAudioMime,
      outputAudioMimeType: liveOutputAudioMime,
    );
  }
}

class _FakeSocket implements LiveAudioSocketConnection {
  _FakeSocket(this._events);

  final StreamController<dynamic> _events;

  @override
  Stream<dynamic> get stream => _events.stream;

  @override
  Sink<dynamic> get sink => _events.sink;

  @override
  Future<void> get ready => Future.value();

  @override
  Future<void> close([int? code, String? reason]) async {}
}

class _SilentPlayback extends LivePcm24PlaybackEngine {
  @override
  Future<void> prepare() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class _NoopPipeline extends CapturePipelineService {
  _NoopPipeline({required File journalFile})
    : super(
        api: _FakeApi(),
        attest: CaptureAttestService(
          api: _FakeApi(),
          deviceIds: _FakeDeviceIdStore(),
          tokenCache: CaptureTokenCache(),
        ),
        journalStore: JournalStore(file: journalFile),
      );
}

class _FakeApi extends VoiceCaptureApiClient {
  _FakeApi() : super(ApiTransport(baseUrl: 'http://test.invalid'));

  @override
  Future<AttestResult> postCaptureAttest(String deviceId) async {
    return AttestResult.capture(token: 'capture-token', expiresInSeconds: 3600);
  }
}

class _FakeDeviceIdStore extends DeviceIdStore {
  @override
  Future<String> getOrCreate() async => '00000000-0000-4000-8000-000000000001';
}
