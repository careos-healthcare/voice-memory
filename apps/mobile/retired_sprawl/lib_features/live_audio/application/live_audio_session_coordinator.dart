import 'dart:async';

import 'package:archiveme_mobile/features/live_audio/domain/models/live_audio_session_config.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/live_server_event.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/live_session_state.dart';
import 'package:archiveme_mobile/features/live_audio/domain/services/live_pcm16_capture_source.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/live_audio_pipeline_log.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/live_audio_session_api_client.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/live_audio_websocket_client.dart';
import 'package:archiveme_mobile/features/live_audio/infrastructure/record_live_pcm16_capture_source.dart';
import 'package:archiveme_mobile/features/live_audio/live_audio_constants.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:archiveme_mobile/security/remote_processing_consent_gate.dart';
import 'package:archiveme_mobile/services/capture_attest_service.dart';

class LiveAudioSessionFailure implements Exception {
  LiveAudioSessionFailure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// Orchestrates mint → proxy connect → setupComplete → PCM streaming lifecycle.
///
/// This feature is remote by nature: the microphone's PCM is streamed to the
/// backend proxy frame by frame while the customer is still speaking, and the
/// transcript comes back over the same socket. That is a legitimate design, but
/// it is still audio leaving the device, so it needs the same permission as any
/// other upload — [RemoteProcessingConsentGate], which composes consent for
/// [RemoteProcessingPurpose.remoteTranscription] with the "Never send to
/// server" toggle and fails closed.
///
/// The `consentGate` argument is nullable so the composition root can be wired
/// independently, but a null gate is read as *refusal*, not as absence of an
/// opinion: [connect] throws [RemoteProcessingConsentRequired] and no session
/// is minted. Streaming that nobody granted is the failure this class exists to
/// avoid, so the unwired case has to be the closed one.
class LiveAudioSessionCoordinator {
  LiveAudioSessionCoordinator({
    required this._sessionApi,
    required this._attest,
    this._consentGate,
    LiveAudioWebSocketClient? webSocketClient,
    LivePcm16CaptureSource? captureSource,
    ApiUsageGuard? usageGuard,
    this._usageScopeKey = liveAudioUsageScopePrefix,
  }) : _webSocketClient = webSocketClient ?? LiveAudioWebSocketClient(),
       _captureSource =
           captureSource ??
           RecordLivePcm16CaptureSource(configureIosAudioSession: false),
       _usageGuard = usageGuard ?? ApiUsageGuard.shared;

  /// The purpose live voice needs: raw audio leaves the device to be turned
  /// into text. The reflection the session produces is admitted separately by
  /// `LiveVoiceCaptureService.stopAndSave`, which checks its own purpose.
  static const RemoteProcessingPurpose streamingPurpose =
      RemoteProcessingPurpose.remoteTranscription;

  final LiveAudioSessionApiClient _sessionApi;
  final CaptureAttestService _attest;
  final RemoteProcessingConsentGate? _consentGate;
  final LiveAudioWebSocketClient _webSocketClient;
  final LivePcm16CaptureSource _captureSource;
  final ApiUsageGuard _usageGuard;
  final String _usageScopeKey;

  /// The gate's answer for the session being set up, captured at [connect].
  ///
  /// [streamPcm16kChunk] runs once per audio frame and cannot await, so the
  /// decision is taken before the socket opens and re-taken on every
  /// reconnect. It starts false, which is what makes a coordinator that never
  /// reached [connect] unable to put a frame on the wire.
  var _remoteStreamingPermitted = false;

  LiveSessionState _state = LiveSessionState.disconnected;
  LiveAudioSessionConfig? _activeSession;
  StreamSubscription<LiveServerEvent>? _serverEventsSubscription;
  var _isCapturingMicrophone = false;
  var _pausedByAudioFocus = false;

  void Function(List<int> chunk)? _pcmCaptureHandler;

  /// Routes microphone PCM to an upstream processor instead of the WebSocket.
  void setPcmCaptureHandler(void Function(List<int> chunk) handler) {
    _pcmCaptureHandler = handler;
  }

  void clearPcmCaptureHandler() {
    _pcmCaptureHandler = null;
  }

  LiveSessionState get state => _state;
  LiveAudioSessionConfig? get activeSession => _activeSession;
  Stream<LiveServerEvent> get serverEvents => _webSocketClient.serverEvents;
  bool get canStreamAudio =>
      _state == LiveSessionState.ready ||
      _state == LiveSessionState.streaming ||
      _state == LiveSessionState.reconnecting;
  bool get isCapturingMicrophone => _isCapturingMicrophone;
  bool get isPausedByAudioFocus => _pausedByAudioFocus;

  int get pcmChunksSent => _pcmChunkIndex;
  var _pcmChunkIndex = 0;
  var _reconnectInProgress = false;

  Future<void> connect({bool isReconnect = false}) async {
    if (_state != LiveSessionState.disconnected &&
        _state != LiveSessionState.error) {
      throw StateError('Live audio session already active');
    }

    // Before the usage guard, before minting, before the socket. A refused
    // session leaves the state untouched so nothing downstream sees a
    // half-started connection. Re-checked on reconnect too: consent withdrawn
    // mid-session must stop the stream coming back up.
    _remoteStreamingPermitted = false;
    final gate = _consentGate;
    if (gate == null ||
        !await gate.isPurposePermittedNow(streamingPurpose)) {
      throw const RemoteProcessingConsentRequired(
        RemoteProcessingPurpose.remoteTranscription,
      );
    }
    _remoteStreamingPermitted = true;

    _setState(LiveSessionState.connecting);

    String? idempotencyKey;
    if (!isReconnect) {
      final guardResult = _usageGuard.checkAttempt(
        scopeKey: _usageScopeKey,
        operation: ApiUsageOperation.liveAudioSession,
      );
      if (!guardResult.allowed) {
        _setState(LiveSessionState.error);
        throw LiveAudioSessionFailure(
          guardResult.reason ?? 'Live audio session blocked by usage guard.',
        );
      }
      idempotencyKey = _usageGuard.idempotencyKey(
        scopeKey: _usageScopeKey,
        operation: ApiUsageOperation.liveAudioSession,
      );
    } else {
      idempotencyKey =
          'live_audio_reconnect_${DateTime.now().millisecondsSinceEpoch}';
    }

    try {
      final captureToken = await _attest.ensureCaptureToken();
      final session = await _sessionApi.mintSession(
        captureToken: captureToken,
        idempotencyKey: idempotencyKey,
      );
      _activeSession = session;
      LiveAudioPipelineLog.sessionMinted(
        sessionId: session.sessionId,
        proxyWebSocketUrl: session.proxyWebSocketUrl,
      );

      _setState(LiveSessionState.awaitingSetupComplete);
      await _webSocketClient.connect(session);

      final setupComplete = await _waitForSetupComplete(
        timeout: const Duration(seconds: 15),
      );
      if (!setupComplete) {
        throw LiveAudioSessionFailure('Timed out waiting for setupComplete.');
      }

      if (!isReconnect) {
        _usageGuard.recordAttempt(
          scopeKey: _usageScopeKey,
          operation: ApiUsageOperation.liveAudioSession,
          success: true,
        );
      }
      _setState(LiveSessionState.ready);
    } catch (error, stackTrace) {
      if (!isReconnect) {
        _usageGuard.recordAttempt(
          scopeKey: _usageScopeKey,
          operation: ApiUsageOperation.liveAudioSession,
          success: false,
        );
      }
      LiveAudioPipelineLog.failure('connect', error);
      await _tearDownSocket(reason: 'connect_failed');
      _setState(LiveSessionState.error);
      Error.throwWithStackTrace(
        error is LiveAudioSessionFailure
            ? error
            : LiveAudioSessionFailure(
                'Live audio connect failed.',
                cause: error,
              ),
        stackTrace,
      );
    }
  }

  Future<void> startMicrophoneCapture() async {
    // Opening the microphone here means opening it *onto the socket*, so the
    // gate decision taken in `connect` has to hold before the first frame is
    // ever captured, not only before it is sent.
    if (!_remoteStreamingPermitted) {
      throw const RemoteProcessingConsentRequired(
        RemoteProcessingPurpose.remoteTranscription,
      );
    }
    if (!canStreamAudio) {
      throw StateError(
        'Live audio session is not ready for microphone capture',
      );
    }
    if (_isCapturingMicrophone) return;

    await _captureSource.start(
      onChunk: _pcmCaptureHandler ?? streamPcm16kChunk,
    );
    _isCapturingMicrophone = true;
  }

  Future<void> stopMicrophoneCapture() async {
    if (!_isCapturingMicrophone) return;

    await _captureSource.stop();
    _isCapturingMicrophone = false;
    _pausedByAudioFocus = false;
    await endAudioStream();
  }

  /// Stops microphone capture without ending the upstream audio stream.
  ///
  /// Used when native audio focus is lost (e.g. incoming call) while keeping
  /// the proxy WebSocket session alive.
  Future<void> pauseMicrophoneCaptureForFocus() async {
    if (!_isCapturingMicrophone) return;

    await _captureSource.stop();
    _isCapturingMicrophone = false;
    _pausedByAudioFocus = true;
  }

  Future<void> resumeMicrophoneCaptureAfterFocus() async {
    if (!_pausedByAudioFocus || _isCapturingMicrophone) return;
    if (!canStreamAudio) return;

    _pausedByAudioFocus = false;
    await startMicrophoneCapture();
  }

  Future<void> connectAndStartMicrophone() async {
    await connect();
    await startMicrophoneCapture();
  }

  Future<void> stopMicrophoneAndDisconnect() async {
    await stopMicrophoneCapture();
    await disconnect();
  }

  /// Re-mints and reconnects after a mid-session socket fault.
  ///
  /// Pauses microphone capture during reconnect, then resumes if it was active.
  Future<void> reconnectSession({required String reason}) async {
    if (_reconnectInProgress) {
      throw StateError('Live audio reconnect already in progress');
    }
    if (_state != LiveSessionState.streaming &&
        _state != LiveSessionState.ready) {
      throw StateError('Cannot reconnect from state $_state');
    }

    final sessionId = _activeSession?.sessionId ?? 'unknown';
    _reconnectInProgress = true;
    _setState(LiveSessionState.reconnecting);
    LiveAudioPipelineLog.reconnectStarted(
      sessionId: sessionId,
      attempt: 1,
      reason: reason,
    );

    final resumeMic = _isCapturingMicrophone || _pausedByAudioFocus;
    try {
      if (_isCapturingMicrophone) {
        await _captureSource.stop();
        _isCapturingMicrophone = false;
      }
      _pausedByAudioFocus = false;

      await _tearDownSocket(reason: 'reconnect');
      _activeSession = null;
      _pcmChunkIndex = 0;
      _setState(LiveSessionState.disconnected);

      await connect(isReconnect: true);

      if (resumeMic) {
        await startMicrophoneCapture();
      }

      LiveAudioPipelineLog.reconnectSucceeded(
        sessionId: _activeSession?.sessionId ?? sessionId,
        attempt: 1,
      );
    } finally {
      _reconnectInProgress = false;
    }
  }

  void streamPcm16kChunk(List<int> pcm16kBytes) {
    // Fail closed. Reached once per frame from the capture source, including
    // frames already in flight when a session is torn down, so it drops the
    // chunk rather than throwing.
    if (!_remoteStreamingPermitted) return;
    if (!canStreamAudio || _state == LiveSessionState.reconnecting) {
      return;
    }
    if (_state != LiveSessionState.ready &&
        _state != LiveSessionState.streaming) {
      throw StateError('Live audio session is not ready for streaming');
    }
    if (_state == LiveSessionState.ready) {
      final sessionId = _activeSession?.sessionId;
      if (sessionId != null) {
        LiveAudioPipelineLog.streamStarted(sessionId: sessionId);
      }
      _setState(LiveSessionState.streaming);
    }
    _pcmChunkIndex++;
    final sessionId = _activeSession?.sessionId;
    if (sessionId != null) {
      LiveAudioPipelineLog.pcmChunkSent(
        sessionId: sessionId,
        byteLength: pcm16kBytes.length,
        chunkIndex: _pcmChunkIndex,
      );
    }
    _webSocketClient.sendPcm16kChunk(pcm16kBytes);
  }

  Future<void> endAudioStream() async {
    if (!_remoteStreamingPermitted) return;
    if (!canStreamAudio) return;
    _webSocketClient.sendAudioStreamEnd();
  }

  Future<void> disconnect() async {
    if (_isCapturingMicrophone) {
      await _captureSource.stop();
      _isCapturingMicrophone = false;
    }
    _pausedByAudioFocus = false;
    _remoteStreamingPermitted = false;
    _setState(LiveSessionState.closing);
    await _tearDownSocket(reason: 'coordinator_disconnect');
    _activeSession = null;
    _pcmChunkIndex = 0;
    _setState(LiveSessionState.disconnected);
  }

  Future<void> dispose() async {
    await disconnect();
    _captureSource.dispose();
    await _webSocketClient.dispose();
  }

  Future<bool> _waitForSetupComplete({required Duration timeout}) {
    if (_webSocketClient.setupComplete) {
      return Future.value(true);
    }

    final completer = Completer<bool>();
    late StreamSubscription<LiveServerEvent> subscription;
    Timer? timer;

    subscription = _webSocketClient.serverEvents.listen((event) {
      if (event is LiveSetupCompleteEvent && !completer.isCompleted) {
        completer.complete(true);
      }
      if (event is LiveServerErrorEvent && !completer.isCompleted) {
        completer.complete(false);
      }
    });

    timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete(false);
    });

    return completer.future.whenComplete(() async {
      timer?.cancel();
      await subscription.cancel();
    });
  }

  Future<void> _tearDownSocket({required String reason}) async {
    await _serverEventsSubscription?.cancel();
    _serverEventsSubscription = null;
    await _webSocketClient.disconnect(reason: reason);
  }

  void _setState(LiveSessionState next) {
    _state = next;
  }
}