import 'archive_home_priority_models.dart';

/// Card-priority rules for a calm Archive Home during beta.
abstract final class ArchiveHomeCardPriority {
  ArchiveHomeCardPriority._();

  static const capacitySectionIds = {
    ArchiveHomeSectionId.capacityThreeMomentActivation,
    ArchiveHomeSectionId.capacityLoop,
    ArchiveHomeSectionId.capacityPullReason,
    ArchiveHomeSectionId.capacityDecisionOutcome,
    ArchiveHomeSectionId.capacityCostLaterCheckin,
    ArchiveHomeSectionId.capacityActivationFit,
    ArchiveHomeSectionId.beforeYouSayYesPause,
    ArchiveHomeSectionId.capacityWeeklyReview,
    ArchiveHomeSectionId.capacityBoundaryResponse,
  };

  /// Under 3 moments, hide daily change and competing capacity cards.
  static bool calmCapacityActivationMode({
    required bool capacityWedgeActive,
    required int capacityMomentCount,
    required int activationTarget,
  }) =>
      capacityWedgeActive && capacityMomentCount < activationTarget;

  static bool suppressArchiveDailyChange({
    required bool capacityWedgeActive,
    required int capacityMomentCount,
    required int activationTarget,
  }) =>
      calmCapacityActivationMode(
        capacityWedgeActive: capacityWedgeActive,
        capacityMomentCount: capacityMomentCount,
        activationTarget: activationTarget,
      );

  static int primaryCardLimit({
    required bool calmCapacityActivationMode,
  }) =>
      calmCapacityActivationMode ? 1 : 3;

  static int capacityPrimaryCardCount(ArchiveHomePriorityPlan plan) =>
      plan.primarySections
          .where((id) => capacitySectionIds.contains(id))
          .length;

  static bool onlyOneCapacityPrimaryCard(ArchiveHomePriorityPlan plan) =>
      capacityPrimaryCardCount(plan) <= 1;

  static List<ArchiveHomeSectionId> stickyLoopSectionsForInput(
    ArchiveHomePriorityInput input,
    List<ArchiveHomeSectionId> visibleStickySections,
  ) {
    if (!input.calmCapacityActivationMode) return visibleStickySections;
    return visibleStickySections
        .where(
          (id) => id == ArchiveHomeSectionId.capacityThreeMomentActivation,
        )
        .toList(growable: false);
  }
}
