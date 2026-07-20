import 'package:flutter/foundation.dart';

/// Clinical cognitive drift telemetry for passive biomarker side-effects.
class ClinicalCognitiveTelemetry {
  const ClinicalCognitiveTelemetry({
    void Function(String event, Map<String, Object> meta)? sink,
  }) : _sink = sink;

  static const logPrefix = '[TELEMETRY][CLINICAL_COGNITIVE]';
  static const clinicalDriftDetectedEvent = 'clinical_drift_detected';

  final void Function(String event, Map<String, Object> meta)? _sink;

  void trackClinicalDriftDetected({
    required String entryId,
    required String driftType,
    required double score,
  }) {
    _emit(
      clinicalDriftDetectedEvent,
      {
        'entry_id': entryId,
        'drift_type': driftType,
        'score': score,
      },
    );
  }

  void _emit(String event, Map<String, Object> meta) {
    _sink?.call(event, Map<String, Object>.from(meta));
    if (kDebugMode) {
      debugPrint('$logPrefix -> Event: $event, Meta: $meta');
    }
  }
}
