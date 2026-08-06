import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../../services/capture_pipeline_service.dart';
import 'live_voice_telemetry_source.dart';
import '../domain/models/live_server_event.dart';
import '../domain/models/live_voice_error_classifier.dart';
import '../domain/models/live_voice_error_messages.dart';
import '../domain/models/live_voice_error_state.dart';
import '../domain/models/live_voice_session_fault.dart';
import '../domain/models/live_session_state.dart';
import '../domain/services/live_audio_transcript_collector.dart';
import '../infrastructure/isolate_audio_pipeline.dart';
import '../infrastructure/local_audio_vault.dart';
import '../infrastructure/local_audio_vault_reader.dart';
import '../infrastructure/live_audio_pipeline_log.dart';
import '../infrastructure/live_pcm24_playback_engine.dart';
import '../infrastructure/offline_vault_recovery_store.dart';
import '../live_audio_constants.dart';
import '../presentation/controllers/live_audio_session_controller.dart';

typedef IsolateAudioPipelineFactory =
    IsolateAudioPipeline Function(PipelineConfig config);

/// High-level capture lifecycle for live voice mic + isolate processing.
enum LiveVoiceCaptureState { idle, starting, active, paused, failure }

/// Record-screen orchestration: live mic → proxy → playback + journal transcript.
class LiveVoiceCaptureService implements Listenable, LiveVoiceTelemetrySource {
  LiveVoiceCaptureService({
    required this._controller,
    required this._pipeline,
    LivePcm24PlaybackEngine? playback,
    LiveAudioTranscriptCollector? transcriptCollector,
    IsolateAudioPipelineFactory? pipelineFactory,
    LocalAudioVault? offlineAudioVault,
    OfflineVaultRecoveryStore? recoveryStore,
    this.useIsolateAudioPipeline = false,
    this.maxReconnectAttempts = 1,
  }) : _playback = playback ?? LivePcm24PlaybackEngine(),
       _transcripts = transcriptCollector ?? LiveAudioTranscriptCollector(),
       _pipelineFactory =
           pipelineFactory ?? ((config) => IsolateAudioPipeline(config)),
       _localVault = offlineAudioVault ?? LocalAudioVault(),
       _recoveryStore = recoveryStore ?? OfflineVaultRecoveryStore() {
    _controller.addListener(_emitDiagnostics);
  }

  final LiveAudioSessionController _controller;
  final CapturePipelineService _pipeline;
  final LivePcm24PlaybackEngine _playback;
  final LiveAudioTranscriptCollector _transcripts;
  final IsolateAudioPipelineFactory _pipelineFactory;
  final LocalAudioVault _localVault;
  final OfflineVaultRecoveryStore _recoveryStore;
  final bool useIsolateAudioPipeline;
  final int maxReconnectAttempts;
  final _durationController = StreamController<int>.broadcast();
  final _sessionFaultController =
      StreamController<LiveVoiceSessionFault>.broadcast();
  final _transcriptController = StreamController<String>.broadcast();
  final _errorStateController =
      StreamController<LiveVoiceErrorState>.broadcast();
  final _diagnosticsController =
      StreamController<LiveVoiceDiagnosticsSnapshot>.broadcast();

  StreamSubscription<LiveServerEvent>? _serverEventsSubscription;
  Timer? _durationTimer;
  DateTime? _startedAt;
  DateTime? _firstAudioSentAt;
  var _active = false;
  var _starting = false;
  var _pausedByAudioFocus = false;
  var _pipelineActive = false;
  var _handlingFault = false;
  var _reconnectAttempts = 0;
  var _sessionFaultCount = 0;
  var _audioChunksReceived = 0;
  var _audioBytesReceived = 0;
  int? _firstAudioLatencyMs;
  LiveVoiceErrorState _errorState = LiveVoiceErrorState.none;
  final List<VoidCallback> _listeners = <VoidCallback>[];

  IsolateAudioPipeline? _audioPipeline;
  StreamSubscription<Int16List>? _pipelineSubscription;
  int _hardwareSampleRate = liveInputSampleRateHz;
  var _offlineVaultActive = false;
  File? _closedOfflineVaultFile;

  LocalAudioVault get localVault => _localVault;

  @override
  void addListener(VoidCallback listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }

  LiveAudioSessionController get controller => _controller;
  Stream<List<int>> get audioOutputStream => _playback.audioOutputStream;
  Stream<int> get durationSeconds => _durationController.stream;
  Stream<LiveVoiceSessionFault> get sessionFaults =>
      _sessionFaultController.stream;
  Stream<LiveVoiceErrorState> get errorStateChanges =>
      _errorStateController.stream;
  @override
  Stream<LiveVoiceDiagnosticsSnapshot> get diagnosticsStream =>
      _diagnosticsController.stream;
  Stream<String> get transcriptUpdates => _transcriptController.stream;
  Stream<int> get playbackQueueDepthStream => _playback.queueDepthStream;
  int get playbackQueueDepth => _playback.activeQueueDepth;
  bool get isActive => _active;
  bool get isPausedByAudioFocus => _pausedByAudioFocus;
  bool get isPipelineActive => _pipelineActive;
  bool get isOfflineVaultActive => _localVault.isActive;
  File? get offlineVaultFile =>
      _closedOfflineVaultFile ?? _localVault.activeFile;
  int get vaultedFrameCount => _localVault.frameCount;
  int get hardwareSampleRate => _hardwareSampleRate;
  @override
  LiveVoiceCaptureState get captureState {
    if (hasError && !_localVault.isActive) return LiveVoiceCaptureState.failure;
    if (_starting) return LiveVoiceCaptureState.starting;
    if (!_active) return LiveVoiceCaptureState.idle;
    if (_pausedByAudioFocus) return LiveVoiceCaptureState.paused;
    return LiveVoiceCaptureState.active;
  }

  bool get isRecording => captureState == LiveVoiceCaptureState.active;
  bool get isPaused => captureState == LiveVoiceCaptureState.paused;
  LiveVoiceErrorState get errorState => _errorState;
  bool get hasError => _errorState != LiveVoiceErrorState.none;
  int get reconnectAttemptsUsed => _reconnectAttempts;
  String get accumulatedTranscript => _transcripts.bestTranscript;

  @override
  LiveVoiceDiagnosticsSnapshot get diagnostics => LiveVoiceDiagnosticsSnapshot(
    pcmChunksSent: _controller.pcmChunksSent,
    audioChunksReceived: _audioChunksReceived,
    audioBytesReceived: _audioBytesReceived,
    reconnectAttempts: _reconnectAttempts,
    sessionFaults: _sessionFaultCount,
    firstAudioLatencyMs: _firstAudioLatencyMs,
    playbackQueueDepth: _playback.activeQueueDepth,
  );

  Future<void> start({
    int hardwareSampleRate = liveInputSampleRateHz,
    bool? enableIsolatePipeline,
  }) async {
    if (_active || _starting) {
      throw StateError('Live voice capture is already active');
    }

    _starting = true;
    _notifyListeners();
    _hardwareSampleRate = hardwareSampleRate;
    final shouldUsePipeline =
        enableIsolatePipeline ??
        useIsolateAudioPipeline || hardwareSampleRate != liveInputSampleRateHz;

    try {
      _resetDiagnostics();
      _transcripts.reset();
      if (!_transcriptController.isClosed) {
        _transcriptController.add('');
      }
      await _playback.prepare();
      _serverEventsSubscription ??= _controller.serverEvents.listen(
        _handleServerEvent,
      );

      _controller.setPcmCaptureHandler(_onCapturePcmBytes);
      await _controller.connect();
      if (shouldUsePipeline) {
        await _startAudioPipeline();
      }
      await _controller.startMicrophoneCapture();

      _firstAudioSentAt = DateTime.now();
      _startedAt = DateTime.now();
      _active = true;
      _durationController.add(0);
      _durationTimer?.cancel();
      _durationTimer = null;
      _restartDurationTimer();
      LiveAudioPipelineLog.diagnostics(
        'capture started pipeline=$shouldUsePipeline ${diagnostics.toString()}',
      );
      _emitDiagnostics();
    } catch (error) {
      await _stopAudioPipeline();
      _controller.clearPcmCaptureHandler();
      rethrow;
    } finally {
      _starting = false;
      _notifyListeners();
    }
  }

  /// Binds raw hardware recorder callbacks when the isolate pipeline is active.
  void handleRawHardwareChunk(Int16List rawBuffer) {
    if (!_active || _audioPipeline == null) {
      return;
    }
    if (!_localVault.isActive && _pausedByAudioFocus) {
      return;
    }
    _audioPipeline!.pushRawHardwareBuffer(rawBuffer);
  }

  void _onCapturePcmBytes(List<int> chunk) {
    if (!_active) {
      return;
    }
    if (_localVault.isActive) {
      if (!_pipelineActive) {
        _localVault.appendPcm16LeBytes(chunk);
        _emitDiagnostics();
      }
      return;
    }
    if (_pausedByAudioFocus) {
      return;
    }
    if (_pipelineActive) {
      handleRawHardwareChunk(_pcmBytesToInt16List(chunk));
    } else if (_controller.canStreamAudio) {
      _controller.streamPcm16kChunk(chunk);
    }
  }

  /// Routes a processed 16 kHz PCM frame to the emergency vault or live proxy.
  @visibleForTesting
  void handleIncomingPipelineFrame(Int16List frame) {
    if (!_active) {
      return;
    }
    if (_localVault.isActive) {
      _localVault.appendFrame(frame);
      _emitDiagnostics();
      return;
    }
    if (_pausedByAudioFocus || hasError) {
      return;
    }
    _streamProcessedFrameToProxy(frame);
  }

  void _streamProcessedFrameToProxy(Int16List frame) {
    if (!_controller.canStreamAudio) {
      return;
    }
    _controller.streamPcm16kChunk(_int16FrameToBytes(frame));
  }

  Future<void> _startAudioPipeline() async {
    await _stopAudioPipeline();

    final pipelineConfig = PipelineConfig(
      inputSampleRate: _hardwareSampleRate,
      targetSampleRate: liveInputSampleRateHz,
      frameDurationMs: 20,
    );

    _audioPipeline = _pipelineFactory(pipelineConfig);
    await _audioPipeline!.start();

    _pipelineSubscription = _audioPipeline!.processedAudioStream.listen(
      handleIncomingPipelineFrame,
      onError: (Object error) {
        unawaited(
          handleSessionFailure(
            LiveVoiceErrorState.networkTimeout,
            reason: 'audio_pipeline:$error',
          ),
        );
      },
    );
    _pipelineActive = true;
  }

  Future<void> _stopAudioPipeline() async {
    _pipelineActive = false;
    await _pipelineSubscription?.cancel();
    _pipelineSubscription = null;
    await _audioPipeline?.dispose();
    _audioPipeline = null;
  }

  /// Pauses mic ingestion immediately when native audio focus is lost.
  Future<void> pauseMicrophoneCaptureForFocus() async {
    await pauseLiveCapture();
  }

  /// Pauses mic capture and flushes playback while keeping the proxy session open.
  Future<void> pauseLiveCapture() async {
    if (!_active || _pausedByAudioFocus) return;

    _pausedByAudioFocus = true;
    _durationTimer?.cancel();
    _durationTimer = null;
    await _controller.pauseMicrophoneCaptureForFocus();
    await _playback.flush();
    LiveAudioPipelineLog.audioFocusPaused();
  }

  /// Resumes mic capture after native audio focus is restored.
  Future<void> resumeLiveCapture() async {
    if (!_active || !_pausedByAudioFocus) return;

    _pausedByAudioFocus = false;
    await _controller.resumeMicrophoneCaptureAfterFocus();
    _restartDurationTimer();
    LiveAudioPipelineLog.audioFocusResumed();
  }

  /// Resumes capture only when the proxy session is still healthy.
  Future<void> resumeLiveCaptureIfActive() async {
    if (!_active || !_pausedByAudioFocus || hasError) return;
    if (!_controller.canStreamAudio) {
      LiveAudioPipelineLog.diagnostics(
        'resume skipped sessionNotStreamable=${!_controller.canStreamAudio}',
      );
      return;
    }
    await resumeLiveCapture();
  }

  /// Stops an in-flight live session without saving (screen exit / teardown).
  Future<void> terminateActiveSession() async {
    if (!_active) return;
    LiveAudioPipelineLog.sessionTerminated();
    await _deactivateOfflineVault();
    await _stopAudioPipeline();
    _controller.clearPcmCaptureHandler();
    await cancel();
  }

  /// Deploys the encrypted disk vault when the proxy session is unrecoverable.
  Future<void> triggerEmergencyNetworkFallback({String? reason}) async {
    if (_localVault.isActive || !_active) {
      return;
    }

    final sessionId = _currentSessionId;
    LiveAudioPipelineLog.emergencyNetworkFallbackDeployed(sessionId: sessionId);

    final recoverySecret = LocalAudioVault.decodeRecoverySecret(
      _controller.activeSession?.vaultRecoverySecret,
    );
    await _localVault.initializeVault(
      sessionId,
      recoverySecretKeyBytes: recoverySecret,
    );
    _offlineVaultActive = true;
    _closedOfflineVaultFile = null;
    LiveAudioPipelineLog.offlineVaultActivated(
      reason: reason ?? LiveVoiceErrorState.networkTimeout.name,
    );

    if (_pausedByAudioFocus) {
      _pausedByAudioFocus = false;
      await _controller.resumeMicrophoneCaptureAfterFocus();
      _restartDurationTimer();
    }
    _notifyListeners();
    _emitDiagnostics();
  }

  String get _currentSessionId =>
      _controller.activeSession?.sessionId ??
      'offline_${DateTime.now().millisecondsSinceEpoch}';

  /// Closes the active vault and queues non-empty recordings for recovery upload.
  Future<void> _deactivateOfflineVault() async {
    if (!_localVault.isActive && !_offlineVaultActive) {
      return;
    }

    final frames = _localVault.frameCount;
    final sessionId = _currentSessionId;
    final file = await _localVault.closeVault();
    _offlineVaultActive = false;
    _closedOfflineVaultFile = file;

    if (file == null || !await file.exists()) {
      _closedOfflineVaultFile = null;
      return;
    }

    if (frames > 0) {
      await _recoveryStore.registerVault(
        sessionId: sessionId,
        vaultFile: file,
        frameCount: frames,
        durationSeconds: LocalAudioVaultReader.estimateDurationSeconds(
          frameCount: frames,
        ),
        recoverySecretKeyBytes: _localVault.uploadableRecoverySecretBytes,
      );
      _closedOfflineVaultFile = null;
      return;
    }

    await file.delete();
    _closedOfflineVaultFile = null;
  }

  /// Enters a hard error boundary: pauses hardware capture and surfaces UI recovery.
  Future<void> handleSessionFailure(
    LiveVoiceErrorState failureType, {
    String? reason,
  }) async {
    if (failureType == LiveVoiceErrorState.none) return;

    _errorState = failureType;
    _notifyErrorState();
    LiveAudioPipelineLog.sessionFailure(
      errorState: failureType,
      reason: reason ?? failureType.name,
    );

    if (failureType == LiveVoiceErrorState.networkTimeout && _active) {
      await triggerEmergencyNetworkFallback(reason: reason);
    } else if (_active && !_pausedByAudioFocus) {
      await pauseLiveCapture();
    }

    _emitSessionFault(
      reason: reason ?? failureType.name,
      errorState: failureType,
      recoverable: true,
    );
  }

  /// Clears the error boundary and re-mints/reconnects the proxy session.
  Future<void> retrySessionRecovery() async {
    if (_errorState == LiveVoiceErrorState.none) return;

    LiveAudioPipelineLog.manualRecoveryStarted();
    await _deactivateOfflineVault();
    _errorState = LiveVoiceErrorState.none;
    _notifyErrorState();
    _reconnectAttempts = 0;
    _handlingFault = false;

    try {
      if (_controller.canStreamAudio) {
        if (_pausedByAudioFocus) {
          await resumeLiveCaptureIfActive();
        } else if (!_controller.isCapturingMicrophone) {
          await _controller.startMicrophoneCapture();
        }
      } else {
        if (_controller.state != LiveSessionState.disconnected) {
          await _controller.disconnect();
        }
        await _controller.connect(isReconnect: true);
        await _controller.startMicrophoneCapture();
        _pausedByAudioFocus = false;
        _restartDurationTimer();
      }
      LiveAudioPipelineLog.manualRecoverySucceeded();
    } catch (error) {
      LiveAudioPipelineLog.failure('manual_recovery', error);
      await handleSessionFailure(
        LiveVoiceErrorState.networkTimeout,
        reason: 'manual_recovery_failed',
      );
    }
  }

  Future<CapturePipelineResult> stopAndSave({
    void Function(PipelineStage stage)? onStage,
  }) async {
    if (!_active) {
      throw StateError('Live voice capture is not active');
    }

    await _controller.stopMicrophoneAndDisconnect();
    await _playback.stop();
    final vaultedFrames = _localVault.isActive ? _localVault.frameCount : 0;
    await _deactivateOfflineVault();
    _durationTimer?.cancel();
    _durationTimer = null;

    final durationSeconds = _startedAt == null
        ? 1
        : DateTime.now().difference(_startedAt!).inSeconds.clamp(1, 999999);
    _active = false;
    _pausedByAudioFocus = false;
    _errorState = LiveVoiceErrorState.none;
    _notifyErrorState();
    _startedAt = null;
    LiveAudioPipelineLog.diagnostics('stopAndSave ${diagnostics.toString()}');

    final transcript = _transcripts.bestTranscript;
    if (transcript.isEmpty) {
      if (vaultedFrames > 0) {
        throw CapturePipelineFailure(
          'Your recording was saved offline. Recover it from the prompt when you reopen the app.',
        );
      }
      throw CapturePipelineFailure(
        'No live transcript was captured. Try speaking a little longer.',
      );
    }

    return _pipeline.saveLiveVoiceTranscript(
      transcript: transcript,
      durationSeconds: durationSeconds,
      onStage: onStage,
    );
  }

  Future<void> cancel() async {
    if (!_active) return;
    await _deactivateOfflineVault();
    await _stopAudioPipeline();
    _controller.clearPcmCaptureHandler();
    await _controller.stopMicrophoneAndDisconnect();
    await _playback.stop();
    _durationTimer?.cancel();
    _durationTimer = null;
    _active = false;
    _pausedByAudioFocus = false;
    _errorState = LiveVoiceErrorState.none;
    _notifyErrorState();
    _startedAt = null;
    _transcripts.reset();
    LiveAudioPipelineLog.diagnostics('cancel ${diagnostics.toString()}');
  }

  void _handleServerEvent(LiveServerEvent event) {
    if (!_active || _handlingFault || hasError) {
      _ingestNonFaultEvent(event);
      return;
    }

    switch (event) {
      case LiveSocketClosedEvent():
        unawaited(_handleSessionFault('socket_closed'));
      case LiveGoAwayEvent():
        unawaited(_handleSessionFault('go_away'));
      case LiveServerErrorEvent(:final message):
        unawaited(_handleSessionFault('server_error:$message'));
      default:
        _ingestNonFaultEvent(event);
    }
  }

  void _ingestNonFaultEvent(LiveServerEvent event) {
    if (event is LiveInterruptedEvent) {
      LiveAudioPipelineLog.bargeIn(source: 'server_interrupted');
      unawaited(_playback.flush());
      return;
    }

    _transcripts.ingest(event);
    if (event is LiveInputTranscriptionEvent ||
        event is LiveOutputTranscriptionEvent) {
      if (!_transcriptController.isClosed) {
        _transcriptController.add(_transcripts.bestTranscript);
      }
    }
    if (event is LiveAudioOutputEvent) {
      _audioChunksReceived++;
      _audioBytesReceived += event.pcmBytes.length;
      if (_firstAudioLatencyMs == null && _firstAudioSentAt != null) {
        _firstAudioLatencyMs = DateTime.now()
            .difference(_firstAudioSentAt!)
            .inMilliseconds;
      }
      LiveAudioPipelineLog.audioChunkReceived(
        byteLength: event.pcmBytes.length,
        chunkIndex: _audioChunksReceived,
        latencyMs: _firstAudioLatencyMs,
      );
      _playback.feed(event.pcmBytes);
      _emitDiagnostics();
    }
  }

  Future<void> _handleSessionFault(String reason) async {
    if (!_active || _handlingFault) return;
    _handlingFault = true;
    _sessionFaultCount++;
    LiveAudioPipelineLog.sessionFault(
      reason: reason,
      attempt: _reconnectAttempts,
      recoverable: _reconnectAttempts < maxReconnectAttempts,
    );

    if (_reconnectAttempts < maxReconnectAttempts) {
      _reconnectAttempts++;
      try {
        await _controller.reconnectSession(reason: reason);
        _handlingFault = false;
        LiveAudioPipelineLog.diagnostics(
          'reconnect ok ${diagnostics.toString()}',
        );
        return;
      } catch (error) {
        LiveAudioPipelineLog.failure('reconnect', error);
      }
    }

    final failureType = classifyLiveVoiceFailure(reason, error: reason);
    await handleSessionFailure(failureType, reason: reason);
    _handlingFault = false;
  }

  void _emitSessionFault({
    required String reason,
    required LiveVoiceErrorState errorState,
    bool recoverable = false,
  }) {
    if (_sessionFaultController.isClosed) return;
    _sessionFaultController.add(
      LiveVoiceSessionFault(
        reason: reason,
        userMessage: LiveVoiceErrorMessages.forState(errorState),
        errorState: errorState,
        recoverable: recoverable,
      ),
    );
  }

  void _notifyErrorState() {
    if (!_errorStateController.isClosed) {
      _errorStateController.add(_errorState);
    }
    _notifyListeners();
    _emitDiagnostics();
  }

  void _emitDiagnostics() {
    if (_diagnosticsController.isClosed) {
      return;
    }
    _diagnosticsController.add(diagnostics);
  }

  void _restartDurationTimer() {
    if (!_active || _startedAt == null || _durationTimer != null) return;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_active || _startedAt == null) return;
      if (_pausedByAudioFocus && !_localVault.isActive) return;
      final elapsed = DateTime.now().difference(_startedAt!).inSeconds;
      if (!_durationController.isClosed) {
        _durationController.add(elapsed);
      }
    });
  }

  void _resetDiagnostics() {
    _handlingFault = false;
    _pausedByAudioFocus = false;
    _errorState = LiveVoiceErrorState.none;
    _notifyErrorState();
    _reconnectAttempts = 0;
    _sessionFaultCount = 0;
    _audioChunksReceived = 0;
    _audioBytesReceived = 0;
    _firstAudioLatencyMs = null;
    _firstAudioSentAt = null;
  }

  Future<void> dispose() async {
    _listeners.clear();
    _controller.removeListener(_emitDiagnostics);
    await _stopAudioPipeline();
    _controller.clearPcmCaptureHandler();
    await cancel();
    await _serverEventsSubscription?.cancel();
    _serverEventsSubscription = null;
    await _playback.dispose();
    await _durationController.close();
    await _sessionFaultController.close();
    await _errorStateController.close();
    await _transcriptController.close();
    await _diagnosticsController.close();
    _controller.dispose();
  }

  static Int16List _pcmBytesToInt16List(List<int> chunk) {
    final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
    final sampleCount = bytes.length ~/ 2;
    return bytes.buffer.asInt16List(bytes.offsetInBytes, sampleCount);
  }

  static Uint8List _int16FrameToBytes(Int16List frame) {
    return frame.buffer.asUint8List(frame.offsetInBytes, frame.lengthInBytes);
  }
}
