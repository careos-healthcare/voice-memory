import 'package:flutter/foundation.dart';

import '../domain/models/cognitive_biomarkers.dart';

/// Payload emitted when the macro EWMA baseline advances.
class CognitiveBaselineUpdateRecord {
  const CognitiveBaselineUpdateRecord({
    required this.entryId,
    required this.observation,
    required this.previousBaseline,
    required this.updatedBaseline,
    required this.observationCount,
  });

  final String entryId;
  final CognitiveBiomarkers observation;
  final CognitiveBiomarkers? previousBaseline;
  final CognitiveBiomarkers updatedBaseline;
  final int observationCount;
}

/// Telemetry sink for long-term cognitive baseline updates.
class CognitiveBaselineTelemetry {
  const CognitiveBaselineTelemetry({this._sink});

  static const logPrefix = '[TELEMETRY][COGNITIVE_BASELINE]';
  static const baselineUpdatedEvent = 'cognitive_baseline_updated';

  final void Function(String event, Map<String, Object> meta)? _sink;

  void trackBaselineUpdated({
    required String entryId,
    required CognitiveBiomarkers updatedBaseline,
    required int observationCount,
    CognitiveBiomarkers? previousBaseline,
  }) {
    _emit(baselineUpdatedEvent, {
      'entry_id': entryId,
      'observation_count': observationCount,
      'lexical_diversity': updatedBaseline.lexicalDiversity,
      'cohesion_drift': updatedBaseline.cohesionDrift,
      'emotional_volatility': updatedBaseline.emotionalVolatility,
      if (previousBaseline != null)
        'previous_lexical_diversity': previousBaseline.lexicalDiversity,
      if (previousBaseline != null)
        'previous_cohesion_drift': previousBaseline.cohesionDrift,
      if (previousBaseline != null)
        'previous_emotional_volatility': previousBaseline.emotionalVolatility,
    });
  }

  void _emit(String event, Map<String, Object> meta) {
    _sink?.call(event, Map<String, Object>.from(meta));
    if (kDebugMode) {
      debugPrint('$logPrefix -> Event: $event, Meta: $meta');
    }
  }
}
