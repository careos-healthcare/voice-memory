import 'capacity_weekly_review_models.dart';

/// Visibility gates for capacity weekly review surfaces.
abstract final class CapacityWeeklyReviewGates {
  CapacityWeeklyReviewGates._();

  static const minCapacityMoments = 3;
  static const minOutcomeOrCostRecords = 2;
  static const minCapacityEvidenceForGeneric = 2;

  static bool shouldBuildReview(CapacityWeeklyReviewGateInput input) {
    if (input.sampleMode) return false;
    if (input.realSavedMomentCount <= 0) return false;
    if (!_hasWedgeOrEvidence(input)) return false;
    return input.capacityMomentCount >= minCapacityMoments ||
        input.outcomeOrCostRecordCount >= minOutcomeOrCostRecords;
  }

  static bool showOnArchiveHome({
    required bool hasReview,
    required bool sampleMode,
    required bool pendingDecisionOutcome,
    required bool pendingCostCheckin,
    required bool beforeYesPauseOnHome,
  }) =>
      hasReview &&
      !sampleMode &&
      !pendingDecisionOutcome &&
      !pendingCostCheckin &&
      !beforeYesPauseOnHome;

  static bool showOnCapacityLoop({
    required bool hasReview,
    required bool sampleMode,
  }) =>
      hasReview && !sampleMode;

  static bool _hasWedgeOrEvidence(CapacityWeeklyReviewGateInput input) {
    if (input.capacityWedgeActive) return true;
    return input.capacityEvidenceCount >= minCapacityEvidenceForGeneric;
  }
}
