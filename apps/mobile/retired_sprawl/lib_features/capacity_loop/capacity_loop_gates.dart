/// Visibility gates for capacity loop surfaces.
abstract final class CapacityLoopGates {
  CapacityLoopGates._();

  static const minRealMomentsForFullCard = 3;
  static const minRealMomentsForWedgeHint = 2;
  static const minCapacityEvidenceForGeneric = 2;

  static bool showOnArchiveHome({
    required bool hasCard,
    required bool sampleMode,
  }) => hasCard && !sampleMode;

  static bool shouldBuildCard(CapacityLoopGateInput input) {
    if (input.sampleMode) return false;
    if (input.realSavedMomentCount <= 0) return false;
    if (input.realSavedMomentCount >= minRealMomentsForFullCard) {
      if (input.capacityWedgeActive) return true;
      return input.capacityEvidenceCount >= minCapacityEvidenceForGeneric;
    }
    if (input.realSavedMomentCount >= minRealMomentsForWedgeHint &&
        input.capacityWedgeActive) {
      return true;
    }
    return false;
  }

  static bool showRecordPrompt({
    required bool capacityWedgeActive,
    required bool sampleMode,
  }) => capacityWedgeActive && !sampleMode;
}

/// Gate input without journal text.
class CapacityLoopGateInput {
  const CapacityLoopGateInput({
    required this.realSavedMomentCount,
    required this.capacityEvidenceCount,
    required this.capacityWedgeActive,
    required this.sampleMode,
  });

  final int realSavedMomentCount;
  final int capacityEvidenceCount;
  final bool capacityWedgeActive;
  final bool sampleMode;
}
