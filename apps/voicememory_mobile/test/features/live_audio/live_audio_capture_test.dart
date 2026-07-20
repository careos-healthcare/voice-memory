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
import 'package:voicememory_mobile/features/live_audio/infrastructure/record_live_pcm16_capture_source.dart';
import 'package:voicememory_mobile/features/live_audio/live_audio_constants.dart';
import 'package:voicememory_mobile/security/api_usage_guard.dart';
import 'package:voicememory_mobile/services/capture_attest_service.dart';
import 'package:voicememory_mobile/storage/capture_token_cache.dart';
import 'package:voicememory_mobile/storage/device_id.dart';

void main() {
  group('RecordLivePcm16CaptureSource', () {
    test('captureConfig uses 16 kHz mono PCM16', () {
      final config = RecordLivePcm16CaptureSource.captureConfig;
      expect(config.sampleRate, liveInputSampleRateHz);
      expect(config.numChannels, liveInputNumChannels);
      expect(config.encoder.name, 'pcm16bits');
    });
  });

  group('LiveAudioSessionCoordinator microphone capture', () {
    test('forwards capture chunks to websocket after setupComplete', () async {
      final capture = _FakeLivePcm16CaptureSource();
      final socketEvents = StreamController<dynamic>();
      final chunksSent = <List<int>>[];
      final coordinator = _buildCoordinator(
        capture: capture,
        socketEvents: socketEvents,
        onPcmSent: chunksSent.add,
      );

      final connectFuture = coordinator.connect();
      await Future<void>.delayed(Duration.zero);
      socketEvents.add(jsonEncode({'setupComplete': {}}));
      await connectFuture;

      await coordinator.startMicrophoneCapture();
      expect(coordinator.isCapturingMicrophone, isTrue);

      capture.emitChunk(const [1, 2, 3, 4]);
      expect(chunksSent, [const [1, 2, 3, 4]]);
      expect(coordinator.state, LiveSessionState.streaming);

      await coordinator.stopMicrophoneCapture();
      expect(coordinator.isCapturingMicrophone, isFalse);
      expect(capture.stopCalls, 1);

      await coordinator.dispose();
    });

    test('requires ready session before microphone capture', () {
      final capture = _FakeLivePcm16CaptureSource();
      final coordinator = _buildCoordinator(
        capture: capture,
        socketEvents: StreamController<dynamic>(),
      );

      expect(coordinator.state, LiveSessionState.disconnected);
      expect(coordinator.canStreamAudio, isFalse);
      expect(coordinator.isCapturingMicrophone, isFalse);
      expect(capture.startCalls, 0);
    });

    test('connectAndStartMicrophone runs connect then capture', () async {
      final capture = _FakeLivePcm16CaptureSource();
      final socketEvents = StreamController<dynamic>();
      final coordinator = _buildCoordinator(
        capture: capture,
        socketEvents: socketEvents,
      );

      final future = coordinator.connectAndStartMicrophone();
      await Future<void>.delayed(Duration.zero);
      socketEvents.add(jsonEncode({'setupComplete': {}}));
      await future;

      expect(coordinator.state, LiveSessionState.ready);
      expect(coordinator.isCapturingMicrophone, isTrue);
      expect(capture.startCalls, 1);

      capture.emitChunk(const [9, 9]);
      expect(coordinator.state, LiveSessionState.streaming);

      await coordinator.stopMicrophoneAndDisconnect();
      expect(coordinator.state, LiveSessionState.disconnected);
      expect(capture.stopCalls, 1);
    });

    test('pauseMicrophoneCaptureForFocus stops mic without ending stream', () async {
      final capture = _FakeLivePcm16CaptureSource();
      final socketEvents = StreamController<dynamic>();
      final coordinator = _buildCoordinator(
        capture: capture,
        socketEvents: socketEvents,
      );

      final connectFuture = coordinator.connect();
      await Future<void>.delayed(Duration.zero);
      socketEvents.add(jsonEncode({'setupComplete': {}}));
      await connectFuture;

      await coordinator.startMicrophoneCapture();
      expect(coordinator.isCapturingMicrophone, isTrue);

      await coordinator.pauseMicrophoneCaptureForFocus();
      expect(coordinator.isCapturingMicrophone, isFalse);
      expect(coordinator.isPausedByAudioFocus, isTrue);
      expect(capture.stopCalls, 1);

      await coordinator.resumeMicrophoneCaptureAfterFocus();
      expect(coordinator.isCapturingMicrophone, isTrue);
      expect(coordinator.isPausedByAudioFocus, isFalse);
      expect(capture.startCalls, 2);

      await coordinator.dispose();
    });
  });
}

LiveAudioSessionCoordinator _buildCoordinator({
  required _FakeLivePcm16CaptureSource capture,
  required StreamController<dynamic> socketEvents,
  void Function(List<int> chunk)? onPcmSent,
}) {
  ApiUsageGuard.resetForTest(replacement: ApiUsageGuard(maxAttemptsPerScope: 3));

  final webSocketClient = _InstrumentedWebSocketClient(
    socketEvents: socketEvents,
    onPcmSent: onPcmSent,
  );

  return LiveAudioSessionCoordinator(
    sessionApi: _FakeSessionApiForCapture(),
    attest: _FakeAttestForCapture(),
    captureSource: capture,
    webSocketClient: webSocketClient,
    usageGuard: ApiUsageGuard.shared,
  );
}

class _InstrumentedWebSocketClient extends LiveAudioWebSocketClient {
  _InstrumentedWebSocketClient({
    required StreamController<dynamic> socketEvents,
    this.onPcmSent,
  }) : super(
          connectionFactory: (_, {headers}) =>
              _FakeSocketForCapture(socketEvents),
        );

  final void Function(List<int> chunk)? onPcmSent;

  @override
  void sendPcm16kChunk(List<int> pcm16kBytes) {
    onPcmSent?.call(pcm16kBytes);
    super.sendPcm16kChunk(pcm16kBytes);
  }
}

class _FakeLivePcm16CaptureSource implements LivePcm16CaptureSource {
  int startCalls = 0;
  int stopCalls = 0;
  void Function(List<int> chunk)? _onChunk;

  @override
  bool isCapturing = false;

  @override
  Future<void> start({required void Function(List<int> chunk) onChunk}) async {
    startCalls++;
    isCapturing = true;
    _onChunk = onChunk;
  }

  void emitChunk(List<int> chunk) {
    _onChunk?.call(chunk);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    isCapturing = false;
    _onChunk = null;
  }

  @override
  void dispose() {
    unawaited(stop());
  }
}

class _FakeSocketForCapture implements LiveAudioSocketConnection {
  _FakeSocketForCapture(this._events);

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

class _FakeSessionApiForCapture implements LiveAudioSessionApiClient {
  @override
  Future<LiveAudioSessionConfig> mintSession({
    required String captureToken,
    String? idempotencyKey,
  }) async {
    return LiveAudioSessionConfig(
      sessionId: 'session_capture',
      sessionToken: 'token',
      proxyWebSocketUrl: 'wss://example.test/api/live-audio/ws',
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      model: 'gemini-2.5-flash-native-audio-preview-12-2025',
      inputAudioMimeType: liveInputAudioMime,
      outputAudioMimeType: liveOutputAudioMime,
    );
  }
}

class _FakeAttestForCapture extends CaptureAttestService {
  _FakeAttestForCapture()
      : super(
          api: _FakeApiForCapture(),
          deviceIds: _FakeDeviceIdForCapture(),
          tokenCache: CaptureTokenCache()
            ..setToken('capture-token', expiresInSeconds: 3600),
        );
}

class _FakeApiForCapture extends ApiClient {
  _FakeApiForCapture() : super(baseUrl: 'http://test.invalid');

  @override
  Future<AttestResult> postCaptureAttest(String deviceId) async {
    return AttestResult.capture(token: 'capture-token', expiresInSeconds: 3600);
  }
}

class _FakeDeviceIdForCapture extends DeviceIdStore {
  @override
  Future<String> getOrCreate() async =>
      '00000000-0000-4000-8000-000000000001';
}
