import 'belief_change_moment_model.dart';

/// Visibility gates for the belief change moment card.
abstract final class BeliefChangeMomentGates {
  BeliefChangeMomentGates._();

  static const minEntryCount = 4;

  static bool shouldShow({
    required bool loaded,
    required int entryCount,
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required bool isDegradedPostSave,
    required bool viewingConfirmedRepeatOrTimeline,
    required BeliefChangeMoment? moment,
  }) =>
      loaded &&
      isReady &&
      !isRecording &&
      !isPostSave &&
      !isDegradedPostSave &&
      entryCount >= minEntryCount &&
      viewingConfirmedRepeatOrTimeline &&
      moment != null;
}
