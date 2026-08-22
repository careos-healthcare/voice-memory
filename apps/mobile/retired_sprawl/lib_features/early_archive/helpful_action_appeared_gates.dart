import 'package:archiveme_mobile/features/early_archive/helpful_action_appeared_model.dart';

/// Visibility gates for the helpful-action appeared card.
abstract final class HelpfulActionAppearedGates {
  HelpfulActionAppearedGates._();

  static bool shouldShow({
    required bool loaded,
    required int entryCount,
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required bool isDegradedPostSave,
    required bool viewingConfirmedRepeatOrTimeline,
    required bool hasConfirmedRepeatFoundation,
    HelpfulActionAppeared? result,
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