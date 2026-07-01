/// Visibility gates for the archive-watching micro-state.
abstract final class ArchiveWatchingGates {
  ArchiveWatchingGates._();

  static const minEntryCount = 3;

  static bool shouldShow({
    required bool loaded,
    required int entryCount,
    required bool isReady,
    required bool isRecording,
    required bool viewingConfirmedRepeatOrTimeline,
    required bool archiveSummaryVisible,
    required bool hasWatching,
  }) =>
      loaded &&
      isReady &&
      !isRecording &&
      entryCount >= minEntryCount &&
      viewingConfirmedRepeatOrTimeline &&
      archiveSummaryVisible &&
      hasWatching;
}
