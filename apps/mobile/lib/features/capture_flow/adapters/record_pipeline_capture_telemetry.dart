import 'dart:async';

import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_hooks.dart';
import 'package:archiveme_mobile/features/capture_flow/capture_flow_phase.dart';
import 'package:archiveme_mobile/features/capture_flow/interfaces/capture_flow_ports.dart';
import 'package:archiveme_mobile/services/record_pipeline_log.dart';

/// Redacted telemetry for the strangler capture flow.
class RecordPipelineCaptureTelemetry implements CaptureTelemetry {
  final Map<String, Stopwatch> _localSaveTimers = {};
  final Map<String, Stopwatch> _remoteTimers = {};

  @override
  void permissionChecked({required String status}) {
    RecordPipelineLog.permission(status: status);
  }

  @override
  void permissionRequested({required String status}) {
    RecordPipelineLog.microphonePermission(
      before: 'unknown',
      after: status,
      prefix: 'request',
    );
  }

  @override
  void recorderStarted({required bool success}) {
    RecordPipelineLog.recorderStart(success: success);
  }

  @override
  void recorderStopped({required bool success}) {
    RecordPipelineLog.recorderStop(success: success);
  }

  @override
  void localSaveStarted({required String kind}) {
    RecordPipelineLog.localSaveStarted(kind: kind);
    _localSaveTimers[kind] = Stopwatch()..start();
  }

  @override
  void localSaveCompleted({required bool success, required String kind}) {
    RecordPipelineLog.localSaveCompleted(success: success, kind: kind);
    final elapsed = _localSaveTimers.remove(kind)?.elapsed ?? Duration.zero;
    unawaited(
      BetaAnalyticsHooks.localSaveResult(
        success: success,
        captureKind: kind,
        latency: elapsed,
      ),
    );
  }

  @override
  void remoteProcessingStarted({required String kind}) {
    RecordPipelineLog.remoteProcessingStarted(kind: kind);
    _remoteTimers[kind] = Stopwatch()..start();
  }

  @override
  void remoteProcessingCompleted({required bool success, required String kind}) {
    RecordPipelineLog.remoteProcessingCompleted(success: success, kind: kind);
    final elapsed = _remoteTimers.remove(kind)?.elapsed ?? Duration.zero;
    unawaited(
      BetaAnalyticsHooks.remoteProcessingResult(
        success: success,
        skipped: false,
        kind: kind,
        latency: elapsed,
      ),
    );
  }

  @override
  void illegalTransition({
    required CaptureFlowPhase from,
    required CaptureFlowPhase to,
  }) {
    RecordPipelineLog.illegalCaptureTransition(from: from.name, to: to.name);
  }

  @override
  void recoverableFailure({required String reason, required bool hasLocalSave}) {
    RecordPipelineLog.recoverableCaptureFailure(
      reason: reason,
      hasLocalSave: hasLocalSave,
    );
  }
}
