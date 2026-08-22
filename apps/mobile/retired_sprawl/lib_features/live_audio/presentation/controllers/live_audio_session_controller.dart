import 'dart:async';

import 'package:archiveme_mobile/features/live_audio/application/live_audio_session_coordinator.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/live_audio_session_config.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/live_server_event.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/live_session_state.dart';
import 'package:archiveme_mobile/features/live_audio/domain/services/live_pcm16_capture_source.dart';
import 'package:flutter/foundation.dart';

/// Thin UI-facing adapter over [LiveAudioSessionCoordinator].
class LiveAudioSessionController extends ChangeNotifier {
  LiveAudioSessionController(this._coordinator) {
    _serverEventsSubscription = _coordinator.serverEvents.listen(
      _handleServerEvent,
    );
  }

  final LiveAudioSessionCoordinator _coordinator;
  StreamSubscription<LiveServerEvent>? _serverEventsSubscription;

  LiveSessionState get state => _coordinator.state;
  LiveAudioSessionConfig? get activeSession => _coordinator.activeSession;
  bool get canStreamAudio => _coordinator.canStreamAudio;
  bool get isCapturingMicrophone => _coordinator.isCapturingMicrophone;
  bool get isPausedByAudioFocus => _coordinator.isPausedByAudioFocus;
  int get pcmChunksSent => _coordinator.pcmChunksSent;
  Stream<LiveServerEvent> get serverEvents => _coordinator.serverEvents;

  LiveServerEvent? _lastEvent;
  LiveServerEvent? get lastEvent => _lastEvent;

  String? _lastErrorMessage;
  String? get lastErrorMessage => _lastErrorMessage;

  Future<void> connect({bool isReconnect = false}) async {
    _lastErrorMessage = null;
    notifyListeners();
    try {
      await _coordinator.connect(isReconnect: isReconnect);
    } on LiveAudioSessionFailure catch (error, stackTrace) {
      _lastErrorMessage = error.message;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  void streamPcm16kChunk(List<int> pcm16kBytes) {
    _coordinator.streamPcm16kChunk(pcm16kBytes);
    notifyListeners();
  }

  void setPcmCaptureHandler(void Function(List<int> chunk) handler) {
    _coordinator.setPcmCaptureHandler(handler);
  }

  void clearPcmCaptureHandler() {
    _coordinator.clearPcmCaptureHandler();
  }

  Future<void> startMicrophoneCapture() async {
    _lastErrorMessage = null;
    notifyListeners();
    try {
      await _coordinator.startMicrophoneCapture();
    } on LivePcm16CaptureException catch (error, stackTrace) {
      _lastErrorMessage = error.message;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> stopMicrophoneCapture() async {
    await _coordinator.stopMicrophoneCapture();
    notifyListeners();
  }

  Future<void> pauseMicrophoneCaptureForFocus() async {
    await _coordinator.pauseMicrophoneCaptureForFocus();
    notifyListeners();
  }

  Future<void> resumeMicrophoneCaptureAfterFocus() async {
    _lastErrorMessage = null;
    notifyListeners();
    try {
      await _coordinator.resumeMicrophoneCaptureAfterFocus();
    } on LivePcm16CaptureException catch (error, stackTrace) {
      _lastErrorMessage = error.message;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> connectAndStartMicrophone() async {
    _lastErrorMessage = null;
    notifyListeners();
    try {
      await _coordinator.connectAndStartMicrophone();
    } on LiveAudioSessionFailure catch (error, stackTrace) {
      _lastErrorMessage = error.message;
      rethrow;
    } on LivePcm16CaptureException catch (error, stackTrace) {
      _lastErrorMessage = error.message;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> stopMicrophoneAndDisconnect() async {
    await _coordinator.stopMicrophoneAndDisconnect();
    notifyListeners();
  }

  Future<void> endAudioStream() => _coordinator.endAudioStream();

  Future<void> disconnect() async {
    await _coordinator.disconnect();
    notifyListeners();
  }

  Future<void> reconnectSession({required String reason}) async {
    _lastErrorMessage = null;
    notifyListeners();
    try {
      await _coordinator.reconnectSession(reason: reason);
    } on LiveAudioSessionFailure catch (error, stackTrace) {
      _lastErrorMessage = error.message;
      rethrow;
    } on LivePcm16CaptureException catch (error, stackTrace) {
      _lastErrorMessage = error.message;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  void _handleServerEvent(LiveServerEvent event) {
    _lastEvent = event;
    if (event is LiveServerErrorEvent) {
      _lastErrorMessage = event.message;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_serverEventsSubscription?.cancel());
    unawaited(_coordinator.dispose());
    super.dispose();
  }
}