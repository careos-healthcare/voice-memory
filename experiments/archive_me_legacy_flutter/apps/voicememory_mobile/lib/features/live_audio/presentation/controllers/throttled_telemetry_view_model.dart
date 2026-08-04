import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../application/live_voice_capture_service.dart';
import '../../application/live_voice_telemetry_source.dart';
import '../../domain/models/live_voice_session_fault.dart';

/// Throttles live-voice diagnostics before they reach adaptive UI surfaces.
class ThrottledTelemetryViewModel extends ChangeNotifier {
  ThrottledTelemetryViewModel({
    required LiveVoiceTelemetrySource captureService,
    Stream<LiveVoiceDiagnosticsSnapshot>? diagnosticsStream,
    this.refreshInterval = const Duration(milliseconds: 100),
  }) : _captureService = captureService,
       _diagnosticsStream =
           diagnosticsStream ?? captureService.diagnosticsStream {
    _initTelemetryLoop();
  }

  final LiveVoiceTelemetrySource _captureService;
  final Stream<LiveVoiceDiagnosticsSnapshot> _diagnosticsStream;
  final Duration refreshInterval;

  StreamSubscription<LiveVoiceDiagnosticsSnapshot>? _telemetrySubscription;
  LiveVoiceDiagnosticsSnapshot? _latestSnapshot;
  Timer? _throttleTimer;
  var _pendingNotify = false;

  LiveVoiceDiagnosticsSnapshot? get snapshot => _latestSnapshot;
  LiveVoiceCaptureState get engineState => _captureService.captureState;

  void _initTelemetryLoop() {
    _telemetrySubscription = _diagnosticsStream.listen(_onDiagnosticsUpdated);
    _captureService.addListener(_onCaptureServiceChanged);
  }

  void _onCaptureServiceChanged() {
    _onDiagnosticsUpdated(_captureService.diagnostics);
  }

  void _onDiagnosticsUpdated(LiveVoiceDiagnosticsSnapshot newSnapshot) {
    _latestSnapshot = newSnapshot;

    if (_throttleTimer?.isActive ?? false) {
      _pendingNotify = true;
      return;
    }

    _pendingNotify = false;
    notifyListeners();

    _throttleTimer = Timer(refreshInterval, () {
      if (_pendingNotify) {
        _pendingNotify = false;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _telemetrySubscription?.cancel();
    _captureService.removeListener(_onCaptureServiceChanged);
    _throttleTimer?.cancel();
    super.dispose();
  }
}
