import 'package:flutter/foundation.dart';

/// Debug-first telemetry for the curiosity retention funnel.
class CuriosityTelemetryTracker {
  const CuriosityTelemetryTracker({this._sink});

  static const logPrefix = '[TELEMETRY][CURIOSITY_LOOP]';

  static const hookScheduledEvent = 'hook_scheduled';
  static const snapshotViewedEvent = 'snapshot_viewed';
  static const reactionTappedEvent = 'reaction_tapped';
  static const micAutostartedEvent = 'mic_autostarted';

  final void Function(String event, Map<String, Object> meta)? _sink;

  void trackHookScheduled({
    required String hookId,
    required String hookType,
    required Duration scheduleAfter,
  }) {
    _emit(hookScheduledEvent, {
      'hook_id': hookId,
      'hook_type': hookType,
      'schedule_after_minutes': scheduleAfter.inMinutes,
    });
  }

  void trackSnapshotViewed({required String hookId, required String hookType}) {
    _emit(snapshotViewedEvent, {'hook_id': hookId, 'hook_type': hookType});
  }

  void trackReactionTapped({required String hookId, required String reaction}) {
    _emit(reactionTappedEvent, {'hook_id': hookId, 'reaction': reaction});
  }

  void trackMicAutostarted({required String hookId, required String source}) {
    _emit(micAutostartedEvent, {'hook_id': hookId, 'source': source});
  }

  void _emit(String event, Map<String, Object> meta) {
    _sink?.call(event, Map<String, Object>.from(meta));
    if (kDebugMode) {
      debugPrint('$logPrefix -> Event: $event, Meta: $meta');
    }
  }
}
