/// Visibility gates for capacity 3-moment activation.
abstract final class CapacityThreeMomentGates {
  CapacityThreeMomentGates._();

  static const activationTarget = 3;
  static const minCapacityEvidenceForGeneric = 2;

  static bool isEligible({
    required bool sampleMode,
    required bool capacityWedgeActive,
    required int capacityEvidenceCount,
  }) {
    if (sampleMode) return false;
    if (capacityWedgeActive) return true;
    return capacityEvidenceCount >= minCapacityEvidenceForGeneric;
  }

  static bool showOnArchiveHome({
    required bool hasCard,
    required int capacityMomentCount,
  }) =>
      hasCard && capacityMomentCount < activationTarget;

  static bool showOnRecordProgress({
    required bool eligible,
    required bool capacityWedgeActive,
    required int capacityMomentCount,
  }) =>
      eligible &&
      capacityWedgeActive &&
      capacityMomentCount < activationTarget;

  static bool showOnCapacityLoop({
    required bool eligible,
    required int capacityMomentCount,
  }) =>
      eligible && capacityMomentCount < activationTarget;
}
