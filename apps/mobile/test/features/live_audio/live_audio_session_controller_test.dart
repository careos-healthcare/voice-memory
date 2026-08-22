import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/capture_api_client.dart';
import 'package:archiveme_mobile/data/repositories/capture_repository.dart';
import 'package:archiveme_mobile/features/live_audio/application/live_audio_session_coordinator.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/live_audio_session_config.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/live_session_state.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/offline_vault_manifest.dart';
import 'package:archiveme_mobile/features/live_audio/domain/services/live_pcm16_capture_source.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/live_audio_session_api_client.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/live_audio_socket_connection.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/live_audio_websocket_client.dart';
import 'package:archiveme_mobile/features/live_audio/live_audio_constants.dart';
import 'package:archiveme_mobile/features/live_audio/presentation/controllers/live_audio_session_controller.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/models/attest_result.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:archiveme_mobile/services/capture_attest_service.dart';
import 'package:archiveme_mobile/storage/capture_token_cache.dart';
import 'package:archiveme_mobile/storage/device_id.dart';
import 'package:flutter_test/flutter_test.dart';

import 'live_audio_consent_test_gate.dart';

void main() {
  test('controller mirrors coordinator state transitions', () async {
    ApiUsageGuard.resetForTest(
      replacement: ApiUsageGuard(),
    );

    final sinkController = StreamController<dynamic>();
    final coordinator = LiveAudioSessionCoordinator(
      sessionApi: _FakeSessionApi(),
      attest: _attestForTest(),
      consentGate: PermittingLiveAudioConsentGate(),
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
    String? systemInstruction,
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

class _FakeCaptureApiClient implements CaptureApiClient {
  @override
  Future<ApiResult<AttestResult>> postCaptureAttest(
    String deviceId, {
    NetworkCancelToken? cancelToken,
  }) async {
    return ApiSuccess(
      AttestResult.capture(token: 'capture-token', expiresInSeconds: 3600),
    );
  }

  @override
  Future<ApiResult<RawModelResponse>> postAnalyzeRaw({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async {
    throw UnimplementedError('postAnalyzeRaw');
  }

  @override
  Future<ApiResult<String>> postTranscribe({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async {
    throw UnimplementedError('postTranscribe');
  }

  @override
  Future<ApiResult<VaultRecoveryServerResult>> postVaultRecovery({
    required File vaultFile,
    required String sessionId,
    required int durationSeconds,
    required String captureToken,
    required String idempotencyKey,
    List<int>? recoverySecretKeyBytes,
    NetworkCancelToken? cancelToken,
  }) async {
    throw UnimplementedError('postVaultRecovery');
  }
}

CaptureAttestService _attestForTest() {
  final api = _FakeCaptureApiClient();
  return CaptureAttestService(
    captureRepository: CaptureRepository(
      api: api,
      requestScope: NetworkRequestScope(),
    ),
    deviceIds: _FakeDeviceIdStore(),
    tokenCache: CaptureTokenCache()
      ..setToken('capture-token', expiresInSeconds: 3600),
  );
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