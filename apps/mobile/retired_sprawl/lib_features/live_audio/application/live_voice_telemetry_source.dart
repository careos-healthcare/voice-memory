import 'package:archiveme_mobile/features/live_audio/application/live_voice_capture_service.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/live_voice_session_fault.dart';
import 'package:flutter/foundation.dart';

/// Read-only telemetry surface consumed by throttled UI monitors.
abstract class LiveVoiceTelemetrySource implements Listenable {
  LiveVoiceCaptureState get captureState;
  LiveVoiceDiagnosticsSnapshot get diagnostics;
  Stream<LiveVoiceDiagnosticsSnapshot> get diagnosticsStream;
}