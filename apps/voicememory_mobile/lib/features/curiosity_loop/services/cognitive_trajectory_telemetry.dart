import 'package:flutter/foundation.dart';

import '../domain/services/cognitive_trajectory_evaluator.dart';

/// Recorded trajectory payload emitted after hook response saves.
class CognitiveTrajectoryRecord {
  const CognitiveTrajectoryRecord({
    required this.entryId,
    required this.hookId,
    required this.sourceEntryId,
    required this.assessment,
    this.wasGrounded = false,
  });

  final String entryId;
  final String hookId;
  final String sourceEntryId;
  final TrajectoryAssessment assessment;
  final bool wasGrounded;
}

/// Telemetry sink for curiosity loop recovery trajectory assessments.
class CognitiveTrajectoryTelemetry {
  const CognitiveTrajectoryTelemetry({this._sink});

  static const logPrefix = '[TELEMETRY][COGNITIVE_TRAJECTORY]';
  static const trajectoryAssessedEvent = 'cognitive_trajectory_assessed';

  final void Function(String event, Map<String, Object> meta)? _sink;

  void trackTrajectoryAssessed({
    required String entryId,
    required String hookId,
    required String sourceEntryId,
    required TrajectoryAssessment assessment,
    bool wasGrounded = false,
  }) {
    _emit(trajectoryAssessedEvent, {
      'entry_id': entryId,
      'hook_id': hookId,
      'source_entry_id': sourceEntryId,
      'direction': assessment.direction.name,
      'lexical_delta': assessment.lexicalDelta,
      'drift_delta': assessment.driftDelta,
      'volatility_delta': assessment.volatilityDelta,
      if (wasGrounded) 'wasGrounded': true,
    });
  }

  void _emit(String event, Map<String, Object> meta) {
    _sink?.call(event, Map<String, Object>.from(meta));
    if (kDebugMode) {
      debugPrint('$logPrefix -> Event: $event, Meta: $meta');
    }
  }
}
