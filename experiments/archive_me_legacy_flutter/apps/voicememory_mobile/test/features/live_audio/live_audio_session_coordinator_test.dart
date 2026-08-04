import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/features/live_audio/application/live_audio_session_coordinator.dart';
import 'package:voicememory_mobile/features/live_audio/domain/models/live_audio_session_config.dart';
import 'package:voicememory_mobile/features/live_audio/domain/models/live_session_state.dart';
import 'package:voicememory_mobile/features/live_audio/domain/services/live_pcm16_capture_source.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/live_audio_session_api_client.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/live_audio_socket_connection.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/live_audio_websocket_client.dart';
import 'package:voicememory_mobile/features/live_audio/live_audio_constants.dart';
import 'package:voicememory_mobile/security/api_usage_guard.dart';
import 'package:voicememory_mobile/services/capture_attest_service.dart';
import 'package:voicememory_mobile/storage/capture_token_cache.dart';
import 'package:voicememory_mobile/storage/device_id.dart';

void main() {
  group('LiveAudioSessionCoordinator', () {
    late _FakeSessionApi sessionApi;
    late CaptureAttestService attest;
    late ApiUsageGuard usageGuard;

    setUp(() {
      sessionApi = _FakeSessionApi();
      usageGuard = ApiUsageGuard(maxAttemptsPerScope: 3);
      ApiUsageGuard.resetForTest(replacement: usageGuard);
      attest = CaptureAttestService(
        api: _FakeApiClientWithAttest(),
        deviceIds: _FakeDeviceIdStore(),
        tokenCache: CaptureTokenCache()
          ..setToken('capture-token', expiresInSeconds: 3600),
      );
    });

    tearDown(() {
      ApiUsageGuard.resetForTest();
    });

    test(
      'connect mints session, waits for setupComplete, then streams PCM',
      () async {
        final sinkController = StreamController<dynamic>();
        final webSocketClient = LiveAudioWebSocketClient(
          connectionFactory: (_, {headers}) =>
              _FakeSocketConnection(sinkController),
        );

        final coordinator = LiveAudioSessionCoordinator(
          sessionApi: sessionApi,
          attest: attest,
          webSocketClient: webSocketClient,
          captureSource: _FakeCaptureForCoordinator(),
          usageGuard: usageGuard,
        );

        final connectFuture = coordinator.connect();
        await Future<void>.delayed(Duration.zero);
        sinkController.add(jsonEncode({'setupComplete': {}}));
        await connectFuture;

        expect(coordinator.state, LiveSessionState.ready);
        expect(sessionApi.mintCalls, 1);

        coordinator.streamPcm16kChunk(const [5, 6, 7]);
        expect(coordinator.state, LiveSessionState.streaming);

        await coordinator.disconnect();
        await coordinator.dispose();
        await sinkController.close();
      },
    );

    test('reconnectSession re-mints and resumes microphone capture', () async {
      StreamController<dynamic>? activeSink;
      final webSocketClient = LiveAudioWebSocketClient(
        connectionFactory: (_, {headers}) {
          activeSink = StreamController<dynamic>();
          return _FakeSocketConnection(activeSink!);
        },
      );

      final coordinator = LiveAudioSessionCoordinator(
        sessionApi: sessionApi,
        attest: attest,
        webSocketClient: webSocketClient,
        captureSource: _FakeCaptureForCoordinator(),
        usageGuard: usageGuard,
      );

      final connectFuture = coordinator.connect();
      await Future<void>.delayed(Duration.zero);
      activeSink!.add(jsonEncode({'setupComplete': {}}));
      await connectFuture;
      await coordinator.startMicrophoneCapture();

      final reconnectFuture = coordinator.reconnectSession(
        reason: 'socket_closed',
      );
      await Future<void>.delayed(Duration.zero);
      activeSink!.add(jsonEncode({'setupComplete': {}}));
      await reconnectFuture;

      expect(sessionApi.mintCalls, 2);
      expect(coordinator.state, LiveSessionState.ready);
      expect(coordinator.isCapturingMicrophone, isTrue);

      await coordinator.disconnect();
      await coordinator.dispose();
      await activeSink!.close();
    });

    test('blocks connect when usage guard rejects attempt', () async {
      usageGuard.recordAttempt(
        scopeKey: liveAudioUsageScopePrefix,
        operation: ApiUsageOperation.liveAudioSession,
        success: false,
      );
      usageGuard.recordAttempt(
        scopeKey: liveAudioUsageScopePrefix,
        operation: ApiUsageOperation.liveAudioSession,
        success: false,
      );
      usageGuard.recordAttempt(
        scopeKey: liveAudioUsageScopePrefix,
        operation: ApiUsageOperation.liveAudioSession,
        success: false,
      );

      final coordinator = LiveAudioSessionCoordinator(
        sessionApi: sessionApi,
        attest: attest,
        webSocketClient: LiveAudioWebSocketClient(
          connectionFactory: (_, {headers}) =>
              _FakeSocketConnection(StreamController<dynamic>()),
        ),
        captureSource: _FakeCaptureForCoordinator(),
        usageGuard: usageGuard,
      );

      await expectLater(
        coordinator.connect(),
        throwsA(isA<LiveAudioSessionFailure>()),
      );
      expect(coordinator.state, LiveSessionState.error);
      expect(sessionApi.mintCalls, 0);
    });
  });
}

class _FakeSocketConnection implements LiveAudioSocketConnection {
  _FakeSocketConnection(this._events);

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

class _FakeSessionApi implements LiveAudioSessionApiClient {
  int mintCalls = 0;

  @override
  Future<LiveAudioSessionConfig> mintSession({
    required String captureToken,
    String? idempotencyKey,
  }) async {
    mintCalls++;
    return LiveAudioSessionConfig(
      sessionId: 'session_test',
      sessionToken: 'session-token',
      proxyWebSocketUrl: 'wss://example.test/api/live-audio/ws',
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      model: 'gemini-2.5-flash-native-audio-preview-12-2025',
      inputAudioMimeType: liveInputAudioMime,
      outputAudioMimeType: liveOutputAudioMime,
    );
  }
}

class _FakeApiClientWithAttest extends VoiceCaptureApiClient {
  _FakeApiClientWithAttest()
    : super(ApiTransport(baseUrl: 'http://test.invalid'));

  @override
  Future<AttestResult> postCaptureAttest(String deviceId) async {
    return AttestResult.capture(token: 'capture-token', expiresInSeconds: 3600);
  }
}

class _FakeDeviceIdStore extends DeviceIdStore {
  @override
  Future<String> getOrCreate() async => '00000000-0000-4000-8000-000000000001';
}

class _FakeCaptureForCoordinator implements LivePcm16CaptureSource {
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
