import 'early_repeat_progress_model.dart';

/// Visibility gates for the early repeat progress card on Record.
abstract final class EarlyRepeatProgressGates {
  EarlyRepeatProgressGates._();

  static bool shouldShow({
    required bool loaded,
    required int entryCount,
    required bool isReady,
    required bool isPostSave,
    required bool isRecording,
    EarlyRepeatProgressResult? progress,
  }) =>
      loaded &&
      isReady &&
      !isRecording &&
      !isPostSave &&
      entryCount >= 1 &&
      entryCount <= 2 &&
      progress != null;
}
