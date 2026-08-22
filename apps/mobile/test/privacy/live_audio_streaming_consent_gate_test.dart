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
import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/models/attest_result.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:archiveme_mobile/security/remote_processing_consent_gate.dart';
import 'package:archiveme_mobile/services/capture_attest_service.dart';
import 'package:archiveme_mobile/storage/capture_token_cache.dart';
import 'package:archiveme_mobile/storage/device_id.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Live voice streams raw PCM to the backend proxy while the customer is still
/// speaking. That is the shape the onboarding brain dump used, and there it ran
/// with no consent check at all.
///
/// The negative cases here do not count sends after the fact — they `fail()`
/// from *inside* the socket, so a byte that escapes aborts the test at the
/// moment it escapes rather than at an assertion that might never be reached.
/// Each is paired with the positive control at the bottom, which proves the
/// same spy does fire when consent permits. A zero-call assertion whose call
/// could never have happened proves nothing.
///
/// Consent state is built here from a temp prefs file rather than through
/// `AppServices.resetForTest`, whose `grantRemoteProcessingConsentByDefault`
/// defaults to true and would make a "denied" case pass while actually
/// granted. Both halves — the purpose and the "Never send to server" toggle —
/// are set explicitly in every case below.
void main() {
  late Directory tempDir;
  late MobilePrefsStore prefs;
  late RemoteProcessingConsentStore consentStore;
  late RemoteProcessingConsentGate gate;
  late ApiUsageGuard usageGuard;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('live_audio_consent_');
    prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
    consentStore = RemoteProcessingConsentStore(prefs);
    gate = RemoteProcessingConsentGate(consentStore);
    usageGuard = ApiUsageGuard();
    ApiUsageGuard.resetForTest(replacement: usageGuard);
    await OnDeviceProcessingStore.resetForTest();
  });

  tearDown(() async {
    ApiUsageGuard.resetForTest();
    await OnDeviceProcessingStore.resetForTest();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  LiveAudioSessionCoordinator buildCoordinator({
    required _SpySessionApi sessionApi,
    required LiveAudioSocketConnectionFactory connectionFactory,
    RemoteProcessingConsentGate? consentGate,
  }) {
    return LiveAudioSessionCoordinator(
      sessionApi: sessionApi,
      attest: _attestForTest(),
      consentGate: consentGate,
      webSocketClient: LiveAudioWebSocketClient(
        connectionFactory: connectionFactory,
      ),
      captureSource: _FakeCaptureSource(),
      usageGuard: usageGuard,
    );
  }

  group('live audio streaming is refused without permission', () {
    test('no consent granted: nothing is minted and nothing is sent',
        () async {
      await OnDeviceProcessingStore.setEnabled(false);
      // Explicit: neither purpose granted.
      expect(
        await gate.isPurposePermittedNow(
          RemoteProcessingPurpose.remoteTranscription,
        ),
        isFalse,
      );

      final sessionApi = _SpySessionApi.failing();
      final coordinator = buildCoordinator(
        sessionApi: sessionApi,
        connectionFactory: _failingConnectionFactory,
        consentGate: gate,
      );

      await expectLater(
        coordinator.connect(),
        throwsA(isA<RemoteProcessingConsentRequired>()),
      );
      expect(coordinator.state, LiveSessionState.disconnected);

      // Even reached directly, the way the capture source reaches it, a frame
      // must not get out.
      coordinator.streamPcm16kChunk(const [1, 2, 3, 4]);
      await expectLater(
        coordinator.startMicrophoneCapture(),
        throwsA(isA<RemoteProcessingConsentRequired>()),
      );

      await coordinator.dispose();
    });

    test('"Never send to server" vetoes a granted purpose', () async {
      await consentStore.grant(
        purposes: {RemoteProcessingPurpose.remoteTranscription},
      );
      await OnDeviceProcessingStore.setEnabled(true);

      final sessionApi = _SpySessionApi.failing();
      final coordinator = buildCoordinator(
        sessionApi: sessionApi,
        connectionFactory: _failingConnectionFactory,
        consentGate: gate,
      );

      await expectLater(
        coordinator.connect(),
        throwsA(isA<RemoteProcessingConsentRequired>()),
      );
      coordinator.streamPcm16kChunk(const [1, 2, 3, 4]);

      await coordinator.dispose();
    });

    test('reflection consent alone does not license the audio stream',
        () async {
      // The stream carries audio, so it needs the transcription purpose.
      // Granting only reflection is the near-miss that a purpose-blind check
      // would wave through.
      await consentStore.grant(
        purposes: {RemoteProcessingPurpose.remoteReflection},
      );
      await OnDeviceProcessingStore.setEnabled(false);

      final coordinator = buildCoordinator(
        sessionApi: _SpySessionApi.failing(),
        connectionFactory: _failingConnectionFactory,
        consentGate: gate,
      );

      await expectLater(
        coordinator.connect(),
        throwsA(isA<RemoteProcessingConsentRequired>()),
      );
      coordinator.streamPcm16kChunk(const [1, 2, 3, 4]);

      await coordinator.dispose();
    });

    test('an unwired gate is read as refusal, not as absence of opinion',
        () async {
      // The composition root has to supply a gate. If it does not, the
      // coordinator must not fall back to streaming — that is exactly how the
      // brain-dump pipeline shipped.
      await consentStore.grant(
        purposes: {RemoteProcessingPurpose.remoteTranscription},
      );
      await OnDeviceProcessingStore.setEnabled(false);

      final coordinator = buildCoordinator(
        sessionApi: _SpySessionApi.failing(),
        connectionFactory: _failingConnectionFactory,
      );

      await expectLater(
        coordinator.connect(),
        throwsA(isA<RemoteProcessingConsentRequired>()),
      );
      coordinator.streamPcm16kChunk(const [1, 2, 3, 4]);

      await coordinator.dispose();
    });

    test('consent withdrawn mid-session stops the reconnect', () async {
      await consentStore.grant(
        purposes: {RemoteProcessingPurpose.remoteTranscription},
      );
      await OnDeviceProcessingStore.setEnabled(false);

      StreamController<dynamic>? events;
      final spySink = _SpySink();
      final coordinator = buildCoordinator(
        sessionApi: _SpySessionApi.permissive(),
        connectionFactory: (_, {headers}) {
          events = StreamController<dynamic>();
          return _RecordingConnection(events!, spySink);
        },
        consentGate: gate,
      );

      final connectFuture = coordinator.connect();
      await _completeSetup(() => events);
      await connectFuture;
      expect(coordinator.state, LiveSessionState.ready);

      // Prove the socket is live before withdrawing, so the silence after the
      // withdrawal is attributable to the gate.
      coordinator.streamPcm16kChunk(const [1, 1, 1, 1]);
      expect(spySink.frames, isNotEmpty);

      await consentStore.withdraw();
      spySink.armed = true;

      await expectLater(
        coordinator.reconnectSession(reason: 'socket_closed'),
        throwsA(isA<RemoteProcessingConsentRequired>()),
      );
      coordinator.streamPcm16kChunk(const [9, 9, 9, 9]);

      await coordinator.dispose();
      await events?.close();
    });
  });

  test('positive control: permitted configuration does stream PCM', () async {
    // The counterpart to every negative above. Same coordinator, same spy
    // socket, consent granted and the on-device-only toggle off — and the
    // frame arrives. Without this the zero-send assertions would be satisfied
    // by a coordinator that simply never sends anything.
    await consentStore.grant(
      purposes: {RemoteProcessingPurpose.remoteTranscription},
    );
    await OnDeviceProcessingStore.setEnabled(false);

    StreamController<dynamic>? events;
    final spySink = _SpySink();
    final sessionApi = _SpySessionApi.permissive();
    final coordinator = buildCoordinator(
      sessionApi: sessionApi,
      connectionFactory: (_, {headers}) {
        events = StreamController<dynamic>();
        return _RecordingConnection(events!, spySink);
      },
      consentGate: gate,
    );

    final connectFuture = coordinator.connect();
    await _completeSetup(() => events);
    await connectFuture;

    expect(sessionApi.mintCalls, 1, reason: 'a session must be minted');
    expect(coordinator.state, LiveSessionState.ready);

    coordinator.streamPcm16kChunk(const [5, 6, 7, 8]);

    expect(coordinator.state, LiveSessionState.streaming);
    expect(
      spySink.frames,
      isNotEmpty,
      reason: 'the spy socket must actually observe a frame here, otherwise '
          'the negative cases above are vacuous',
    );

    await coordinator.disconnect();
    await coordinator.dispose();
    await events?.close();
  });
}

/// Waits for the socket to exist, then hands it `setupComplete`.
///
/// The gate is consulted before the connection factory runs and reads prefs
/// off disk, so the socket is not available on the next microtask the way it
/// was before consent was checked.
Future<void> _completeSetup(
  StreamController<dynamic>? Function() events,
) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    final controller = events();
    if (controller != null) {
      controller.add(jsonEncode({'setupComplete': {}}));
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('the live audio socket was never opened');
}

// --------------------------------------------------------------------------
// Spies
// --------------------------------------------------------------------------

/// A socket that aborts the test from inside `add`, at the point of escape.
LiveAudioSocketConnection _failingConnectionFactory(
  Uri uri, {
  Map<String, dynamic>? headers,
}) {
  fail('a WebSocket was opened to $uri without a permitted consent decision');
}

class _RecordingConnection implements LiveAudioSocketConnection {
  _RecordingConnection(this._events, this._sink);

  final StreamController<dynamic> _events;
  final _SpySink _sink;

  @override
  Stream<dynamic> get stream => _events.stream;

  @override
  Sink<dynamic> get sink => _sink;

  @override
  Future<void> get ready => Future.value();

  @override
  Future<void> close([int? code, String? reason]) async {}
}

/// Records frames, or aborts the test from inside `add` once [armed].
///
/// Arming is what makes the mid-session case non-vacuous: the same sink is
/// shown recording a frame before consent is withdrawn, so an empty result
/// afterwards is the gate working rather than a socket that was never live.
class _SpySink implements Sink<dynamic> {
  final List<dynamic> frames = <dynamic>[];
  bool armed = false;

  @override
  void add(dynamic data) {
    if (armed) {
      fail('user audio reached the WebSocket after consent was withdrawn');
    }
    frames.add(data);
  }

  @override
  void close() {}
}

class _SpySessionApi implements LiveAudioSessionApiClient {
  _SpySessionApi._(this._failOnMint);

  /// Aborts the test if a session is minted at all.
  factory _SpySessionApi.failing() => _SpySessionApi._(true);

  factory _SpySessionApi.permissive() => _SpySessionApi._(false);

  final bool _failOnMint;
  int mintCalls = 0;

  @override
  Future<LiveAudioSessionConfig> mintSession({
    required String captureToken,
    String? idempotencyKey,
    String? systemInstruction,
  }) async {
    if (_failOnMint) {
      fail('a live audio session was minted without a permitted consent '
          'decision');
    }
    mintCalls++;
    return LiveAudioSessionConfig(
      sessionId: 'session_test',
      sessionToken: 'session-token',
      proxyWebSocketUrl: 'wss://example.test/api/live-audio/ws',
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      model: 'gemini-2.5-flash-native-audio-preview-12-2025',
      inputAudioMimeType: 'audio/pcm;rate=16000',
      outputAudioMimeType: 'audio/pcm;rate=24000',
    );
  }
}

class _FakeCaptureSource implements LivePcm16CaptureSource {
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

CaptureAttestService _attestForTest() {
  return CaptureAttestService(
    captureRepository: CaptureRepository(
      api: _FakeCaptureApiClient(),
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
  }) async => throw UnimplementedError('postAnalyzeRaw');

  @override
  Future<ApiResult<String>> postTranscribe({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async => throw UnimplementedError('postTranscribe');

  @override
  Future<ApiResult<VaultRecoveryServerResult>> postVaultRecovery({
    required File vaultFile,
    required String sessionId,
    required int durationSeconds,
    required String captureToken,
    required String idempotencyKey,
    List<int>? recoverySecretKeyBytes,
    NetworkCancelToken? cancelToken,
  }) async => throw UnimplementedError('postVaultRecovery');
}
