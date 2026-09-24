/// Visibility gates for share-safe milestone cards.
abstract final class MilestoneShareGates {
  MilestoneShareGates._();

  static bool showOnArchiveHome({
    required int realSavedMomentCount,
    required int milestoneCount,
    required bool sampleMode,
  }) => !sampleMode && realSavedMomentCount >= 1 && milestoneCount >= 1;
}
