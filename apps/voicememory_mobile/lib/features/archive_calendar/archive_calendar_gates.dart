/// Visibility gates for Archive Calendar surfaces.
abstract final class ArchiveCalendarGates {
  ArchiveCalendarGates._();

  static bool showOnArchiveHome({
    required int realSavedMomentCount,
    required bool sampleMode,
  }) =>
      realSavedMomentCount >= 1 && !sampleMode;
}
