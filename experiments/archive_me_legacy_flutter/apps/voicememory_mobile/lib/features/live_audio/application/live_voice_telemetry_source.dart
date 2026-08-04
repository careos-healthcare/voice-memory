import 'package:flutter/foundation.dart';

import '../domain/models/live_voice_session_fault.dart';
import 'live_voice_capture_service.dart';

/// Read-only telemetry surface consumed by throttled UI monitors.
abstract class LiveVoiceTelemetrySource implements Listenable {
  LiveVoiceCaptureState get captureState;
  LiveVoiceDiagnosticsSnapshot get diagnostics;
  Stream<LiveVoiceDiagnosticsSnapshot> get diagnosticsStream;
}
