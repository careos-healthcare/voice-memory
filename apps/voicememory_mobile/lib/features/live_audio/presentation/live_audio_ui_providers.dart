import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/live_voice_capture_service.dart';
import '../application/live_voice_telemetry_source.dart';
import '../domain/models/live_voice_session_fault.dart';

import '../../../audio/playback_service.dart';

/// Throttled live-voice diagnostics for adaptive UI surfaces.
class ThrottledTelemetryState {
  const ThrottledTelemetryState({
    this.snapshot,
    this.engineState = LiveVoiceCaptureState.idle,
  });

  final LiveVoiceDiagnosticsSnapshot? snapshot;
  final LiveVoiceCaptureState engineState;

  ThrottledTelemetryState copyWith({
    LiveVoiceDiagnosticsSnapshot? snapshot,
    LiveVoiceCaptureState? engineState,
  }) {
    return ThrottledTelemetryState(
      snapshot: snapshot ?? this.snapshot,
      engineState: engineState ?? this.engineState,
    );
  }
}

class ThrottledTelemetryConfig {
  const ThrottledTelemetryConfig({
    required this.captureService,
    this.diagnosticsStream,
    this.refreshInterval = const Duration(milliseconds: 100),
  });

  final LiveVoiceTelemetrySource captureService;
  final Stream<LiveVoiceDiagnosticsSnapshot>? diagnosticsStream;
  final Duration refreshInterval;
}

final throttledTelemetryConfigProvider = Provider<ThrottledTelemetryConfig?>(
  (ref) => null,
);

class ThrottledTelemetryNotifier extends Notifier<ThrottledTelemetryState> {
  static ThrottledTelemetryNotifier create({
    required LiveVoiceTelemetrySource captureService,
    Stream<LiveVoiceDiagnosticsSnapshot>? diagnosticsStream,
    Duration refreshInterval = const Duration(milliseconds: 100),
  }) {
    final container = ProviderContainer(
      overrides: [
        throttledTelemetryConfigProvider.overrideWithValue(
          ThrottledTelemetryConfig(
            captureService: captureService,
            diagnosticsStream: diagnosticsStream,
            refreshInterval: refreshInterval,
          ),
        ),
      ],
    );
    return container.read(throttledTelemetryProvider.notifier);
  }

  late LiveVoiceTelemetrySource _captureService;
  late Stream<LiveVoiceDiagnosticsSnapshot> _diagnosticsStream;
  late Duration _refreshInterval;

  LiveVoiceDiagnosticsSnapshot? _latestSnapshot;
  StreamSubscription<LiveVoiceDiagnosticsSnapshot>? _telemetrySubscription;
  Timer? _throttleTimer;
  var _pendingNotify = false;
  VoidCallback? _captureListener;
  var _telemetryBound = false;

  @override
  ThrottledTelemetryState build() {
    final config = ref.read(throttledTelemetryConfigProvider);
    if (config == null) {
      return const ThrottledTelemetryState();
    }
    if (!_telemetryBound) {
      _telemetryBound = true;
      _captureService = config.captureService;
      _diagnosticsStream =
          config.diagnosticsStream ?? config.captureService.diagnosticsStream;
      _refreshInterval = config.refreshInterval;
      _initTelemetryLoop();
      ref.onDispose(_tearDown);
    }
    return ThrottledTelemetryState(
      engineState: _captureService.captureState,
    );
  }

  void _initTelemetryLoop() {
    _telemetrySubscription = _diagnosticsStream.listen(_onDiagnosticsUpdated);
    _captureListener = () {
      _onDiagnosticsUpdated(_captureService.diagnostics);
    };
    _captureService.addListener(_captureListener!);
  }

  void _onDiagnosticsUpdated(LiveVoiceDiagnosticsSnapshot newSnapshot) {
    _latestSnapshot = newSnapshot;

    if (_throttleTimer?.isActive ?? false) {
      _pendingNotify = true;
      return;
    }

    _pendingNotify = false;
    state = state.copyWith(
      snapshot: newSnapshot,
      engineState: _captureService.captureState,
    );

    _throttleTimer = Timer(_refreshInterval, () {
      if (_pendingNotify) {
        _pendingNotify = false;
        state = state.copyWith(
          snapshot: _latestSnapshot,
          engineState: _captureService.captureState,
        );
      }
    });
  }

  void _tearDown() {
    _telemetryBound = false;
    _telemetrySubscription?.cancel();
    final listener = _captureListener;
    if (listener != null) {
      _captureService.removeListener(listener);
    }
    _throttleTimer?.cancel();
  }
}

final throttledTelemetryProvider =
    NotifierProvider<ThrottledTelemetryNotifier, ThrottledTelemetryState>(
      ThrottledTelemetryNotifier.new,
    );

/// Scoped playback queue depth for live voice UI (reads shared [PlaybackService]).
final liveVoicePlaybackQueueDepthProvider = Provider<int>((ref) {
  return ref.watch(playbackQueueDepthProvider);
});
