import 'what_changed_since_last_time_model.dart';

/// Visibility gates for the Patterns longitudinal change card.
abstract final class WhatChangedSinceLastTimeGates {
  WhatChangedSinceLastTimeGates._();

  static bool shouldShow({
    required bool loaded,
    required int entryCount,
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required bool isDegradedPostSave,
    required bool viewingConfirmedRepeatOrTimeline,
    required bool hasConfirmedRepeatFoundation,
    WhatChangedSinceLastTime? result,
  }) =>
      loaded &&
      isReady &&
      !isRecording &&
      !isPostSave &&
      !isDegradedPostSave &&
      entryCount >= 4 &&
      viewingConfirmedRepeatOrTimeline &&
      hasConfirmedRepeatFoundation &&
      result != null;
}
