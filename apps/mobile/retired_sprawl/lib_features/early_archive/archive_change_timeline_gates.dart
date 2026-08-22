import 'package:archiveme_mobile/features/early_archive/archive_change_timeline_model.dart';

/// Visibility gates for the evidence timeline on Patterns / Archive.
abstract final class ArchiveChangeTimelineGates {
  ArchiveChangeTimelineGates._();

  static const minEntryCount = 3;

  static bool shouldShow({
    required bool loaded,
    required int entryCount,
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required bool viewingConfirmedRepeatOrTimeline,
    required ArchiveChangeTimeline? timeline,
  }) =>
      loaded &&
      isReady &&
      !isRecording &&
      !isPostSave &&
      entryCount >= minEntryCount &&
      viewingConfirmedRepeatOrTimeline &&
      timeline != null &&
      timeline.hasContent;
}