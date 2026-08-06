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
import 'package:voicememory_mobile/features/live_audio/presentation/controllers/live_audio_session_controller.dart';
import 'package:voicememory_mobile/security/api_usage_guard.dart';
import 'package:voicememory_mobile/services/capture_attest_service.dart';
import 'package:voicememory_mobile/storage/capture_token_cache.dart';
import 'package:voicememory_mobile/storage/device_id.dart';

void main() {
  test('controller mirrors coordinator state transitions', () async {
    ApiUsageGuard.resetForTest(
      replacement: ApiUsageGuard(maxAttemptsPerScope: 3),
    );

    final sinkController = StreamController<dynamic>();
    final coordinator = LiveAudioSessionCoordinator(
      sessionApi: _FakeSessionApi(),
      attest: CaptureAttestService(
        api: _FakeApiClientWithAttest(),
        deviceIds: _FakeDeviceIdStore(),
        tokenCache: CaptureTokenCache()
          ..setToken('capture-token', expiresInSeconds: 3600),
      ),
      webSocketClient: LiveAudioWebSocketClient(
        connectionFactory: (_, {headers}) =>
            _FakeSocketConnection(sinkController),
      ),
      captureSource: _FakeCaptureForController(),
      usageGuard: ApiUsageGuard.shared,
    );
    final controller = LiveAudioSessionController(coordinator);

    expect(controller.state, LiveSessionState.disconnected);

    final connectFuture = controller.connect();
    await Future<void>.delayed(Duration.zero);
    sinkController.add(jsonEncode({'setupComplete': {}}));
    await connectFuture;

    expect(controller.state, LiveSessionState.ready);
    expect(controller.canStreamAudio, isTrue);

    controller.streamPcm16kChunk(const [1, 2]);
    expect(controller.state, LiveSessionState.streaming);

    await controller.disconnect();
    expect(controller.state, LiveSessionState.disconnected);

    controller.dispose();
    await sinkController.close();
    ApiUsageGuard.resetForTest();
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
  @override
  Future<LiveAudioSessionConfig> mintSession({
    required String captureToken,
    String? idempotencyKey,
  }) async {
    return LiveAudioSessionConfig(
      sessionId: 'session_ui',
      sessionToken: 'session-token',
      proxyWebSocketUrl: 'wss://example.test/api/live-audio/ws',
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      model: 'gemini-2.5-flash-native-audio-preview-12-2025',
      inputAudioMimeType: liveInputAudioMime,
      outputAudioMimeType: liveOutputAudioMime,
    );
  }
}

class _FakeApiClientWithAttest extends ApiClient {
  _FakeApiClientWithAttest() : super(baseUrl: 'http://test.invalid');

  @override
  Future<AttestResult> postCaptureAttest(String deviceId) async {
    return AttestResult.capture(token: 'capture-token', expiresInSeconds: 3600);
  }
}

class _FakeDeviceIdStore extends DeviceIdStore {
  @override
  Future<String> getOrCreate() async => '00000000-0000-4000-8000-000000000001';
}

class _FakeCaptureForController implements LivePcm16CaptureSource {
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
