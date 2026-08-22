/// When the provisional “Your archive currently believes…” surface leads.
abstract final class ArchiveCurrentBeliefGates {
  ArchiveCurrentBeliefGates._();

  static const minEntryCount = 3;

  static bool shouldShow({
    required bool loaded,
    required int entryCount,
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required bool viewingConfirmedRepeatOrTimeline,
    required bool hasConfirmedRepeatFoundation,
    required bool hasCurrentBeliefSurface,
  }) =>
      loaded &&
      isReady &&
      !isRecording &&
      !isPostSave &&
      entryCount >= minEntryCount &&
      viewingConfirmedRepeatOrTimeline &&
      hasConfirmedRepeatFoundation &&
      hasCurrentBeliefSurface;
}