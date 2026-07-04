import 'record_capture_mode_copy.dart';

/// One permissive capture mode — opens typed capture with prompt/helper only.
enum RecordCaptureModeId {
  somethingHappened,
  keptThinking,
  smallWin,
  pressureMoment,
  nothingMuchToday,
}

class RecordCaptureMode {
  const RecordCaptureMode({
    required this.id,
    required this.label,
    required this.helper,
    required this.prompt,
  });

  final RecordCaptureModeId id;
  final String label;
  final String helper;
  final String prompt;

  bool get isQuietDay => id == RecordCaptureModeId.nothingMuchToday;

  String get analyticsId => id.name;

  static const List<RecordCaptureMode> all = [
    RecordCaptureMode(
      id: RecordCaptureModeId.somethingHappened,
      label: RecordCaptureModeCopy.somethingHappenedLabel,
      helper: RecordCaptureModeCopy.somethingHappenedHelper,
      prompt: RecordCaptureModeCopy.somethingHappenedPrompt,
    ),
    RecordCaptureMode(
      id: RecordCaptureModeId.keptThinking,
      label: RecordCaptureModeCopy.keptThinkingLabel,
      helper: RecordCaptureModeCopy.keptThinkingHelper,
      prompt: RecordCaptureModeCopy.keptThinkingPrompt,
    ),
    RecordCaptureMode(
      id: RecordCaptureModeId.smallWin,
      label: RecordCaptureModeCopy.smallWinLabel,
      helper: RecordCaptureModeCopy.smallWinHelper,
      prompt: RecordCaptureModeCopy.smallWinPrompt,
    ),
    RecordCaptureMode(
      id: RecordCaptureModeId.pressureMoment,
      label: RecordCaptureModeCopy.pressureMomentLabel,
      helper: RecordCaptureModeCopy.pressureMomentHelper,
      prompt: RecordCaptureModeCopy.pressureMomentPrompt,
    ),
    RecordCaptureMode(
      id: RecordCaptureModeId.nothingMuchToday,
      label: RecordCaptureModeCopy.nothingMuchTodayLabel,
      helper: RecordCaptureModeCopy.nothingMuchTodayHelper,
      prompt: RecordCaptureModeCopy.nothingMuchTodayPrompt,
    ),
  ];
}
