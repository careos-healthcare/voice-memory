import 'package:archiveme_mobile/features/early_archive/early_repeat_progress_model.dart';

/// Visibility gates for the early saved-moments review action on Record.
abstract final class EarlySavedMomentsGates {
  EarlySavedMomentsGates._();

  static bool shouldShow({
    required bool loaded,
    required int entryCount,
    required bool isReady,
    required bool isPostSave,
    required bool isRecording,
    required bool showEarlyRepeatProgress,
    EarlyRepeatProgressResult? progress,
  }) =>
      loaded &&
      isReady &&
      !isRecording &&
      !isPostSave &&
      showEarlyRepeatProgress &&
      entryCount >= 1 &&
      entryCount <= 2 &&
      progress != null;
}