import 'archive_home_card_priority.dart';
import 'archive_home_priority_models.dart';

/// Deterministic Archive Home priority stack — local, no persistence.
class ArchiveHomePriorityEngine {
  const ArchiveHomePriorityEngine();

  /// Sticky-loop surfaces in product order (#129–#136).
  static const stickyLoopSequence = [
    ArchiveHomeSectionId.firstWeekPath,
    ArchiveHomeSectionId.dailyArchiveExercise,
    ArchiveHomeSectionId.capacityThreeMomentActivation,
    ArchiveHomeSectionId.capacityLoop,
    ArchiveHomeSectionId.capacityPullReason,
    ArchiveHomeSectionId.capacityDecisionOutcome,
    ArchiveHomeSectionId.capacityCostLaterCheckin,
    ArchiveHomeSectionId.capacityActivationFit,
    ArchiveHomeSectionId.beforeYouSayYesPause,
    ArchiveHomeSectionId.capacityWeeklyReview,
    ArchiveHomeSectionId.capacityBoundaryResponse,
    ArchiveHomeSectionId.archiveClarityProgress,
    ArchiveHomeSectionId.thenVsNow,
    ArchiveHomeSectionId.archiveCalendar,
    ArchiveHomeSectionId.reviewRitual,
    ArchiveHomeSectionId.milestoneShare,
  ];

  /// Returns visible sticky-loop sections in canonical order.
  static List<ArchiveHomeSectionId> stickyLoopSections(
    ArchiveHomePriorityInput input,
  ) {
    final visible = stickyLoopSequence
        .where((id) => _isStickyLoopVisible(input, id))
        .toList();
    return ArchiveHomeCardPriority.stickyLoopSectionsForInput(input, visible);
  }

  static bool _isStickyLoopVisible(
    ArchiveHomePriorityInput input,
    ArchiveHomeSectionId id,
  ) => switch (id) {
    ArchiveHomeSectionId.firstWeekPath => input.firstWeekPathVisible,
    ArchiveHomeSectionId.dailyArchiveExercise =>
      input.dailyArchiveExerciseVisible,
    ArchiveHomeSectionId.archiveClarityProgress =>
      input.archiveClarityProgressVisible,
    ArchiveHomeSectionId.capacityThreeMomentActivation =>
      input.capacityThreeMomentActivationVisible,
    ArchiveHomeSectionId.capacityLoop => input.capacityLoopVisible,
    ArchiveHomeSectionId.capacityPullReason => input.capacityPullReasonVisible,
    ArchiveHomeSectionId.capacityDecisionOutcome =>
      input.capacityDecisionOutcomeVisible,
    ArchiveHomeSectionId.capacityCostLaterCheckin =>
      input.capacityCostLaterCheckinVisible,
    ArchiveHomeSectionId.capacityActivationFit =>
      input.capacityActivationFitVisible,
    ArchiveHomeSectionId.beforeYouSayYesPause =>
      input.beforeYouSayYesPauseVisible,
    ArchiveHomeSectionId.capacityWeeklyReview =>
      input.capacityWeeklyReviewVisible,
    ArchiveHomeSectionId.capacityBoundaryResponse =>
      input.capacityBoundaryResponseVisible,
    ArchiveHomeSectionId.thenVsNow => input.thenVsNowVisible,
    ArchiveHomeSectionId.archiveCalendar => input.archiveCalendarVisible,
    ArchiveHomeSectionId.reviewRitual => input.reviewRitualVisible,
    ArchiveHomeSectionId.milestoneShare => input.milestoneShareVisible,
    _ => false,
  };

  ArchiveHomePriorityPlan build(ArchiveHomePriorityInput input) {
    if (input.sampleMode) {
      return const ArchiveHomePriorityPlan(
        primarySections: [ArchiveHomeSectionId.archiveSummary],
        secondarySections: [],
        hiddenSections: {
          ArchiveHomeSectionId.introHint,
          ArchiveHomeSectionId.quickActions,
          ArchiveHomeSectionId.returnRitual,
          ArchiveHomeSectionId.proPreview,
          ArchiveHomeSectionId.returnChanges,
          ArchiveHomeSectionId.archiveDailyChange,
          ArchiveHomeSectionId.archiveDepth,
          ArchiveHomeSectionId.watchlist,
          ArchiveHomeSectionId.nextEvidencePlan,
          ArchiveHomeSectionId.firstWeekPath,
          ArchiveHomeSectionId.dailyArchiveExercise,
          ArchiveHomeSectionId.capacityThreeMomentActivation,
          ArchiveHomeSectionId.capacityLoop,
          ArchiveHomeSectionId.capacityPullReason,
          ArchiveHomeSectionId.capacityDecisionOutcome,
          ArchiveHomeSectionId.capacityCostLaterCheckin,
          ArchiveHomeSectionId.capacityActivationFit,
          ArchiveHomeSectionId.beforeYouSayYesPause,
          ArchiveHomeSectionId.capacityWeeklyReview,
          ArchiveHomeSectionId.capacityBoundaryResponse,
          ArchiveHomeSectionId.archiveClarityProgress,
          ArchiveHomeSectionId.thenVsNow,
          ArchiveHomeSectionId.archiveCalendar,
          ArchiveHomeSectionId.reviewRitual,
          ArchiveHomeSectionId.milestoneShare,
          ArchiveHomeSectionId.milestones,
          ArchiveHomeSectionId.betaFeedback,
          ArchiveHomeSectionId.proInterestLink,
          ArchiveHomeSectionId.needsAttention,
          ArchiveHomeSectionId.evidenceQuality,
          ArchiveHomeSectionId.reviewHistory,
          ArchiveHomeSectionId.controls,
          ArchiveHomeSectionId.sampleArchive,
        },
        showMoreArchiveTools: false,
        proPreviewProminent: false,
      );
    }

    final hidden = _hiddenForStage(input);
    final ranked = _rankedOrder(
      input,
    ).where((id) => !hidden.contains(id)).toList();

    final primaryCardLimit = ArchiveHomeCardPriority.primaryCardLimit(
      calmCapacityActivationMode: input.calmCapacityActivationMode,
    );
    final primary = <ArchiveHomeSectionId>[ArchiveHomeSectionId.archiveSummary];
    var addedCards = 0;
    for (final id in ranked) {
      if (id == ArchiveHomeSectionId.archiveSummary) continue;
      if (addedCards >= primaryCardLimit) break;
      primary.add(id);
      addedCards++;
    }

    final secondary = ranked
        .where((id) => !primary.contains(id))
        .toList(growable: false);

    return ArchiveHomePriorityPlan(
      primarySections: primary,
      secondarySections: secondary,
      hiddenSections: hidden,
      showMoreArchiveTools: secondary.isNotEmpty,
      proPreviewProminent: input.savedEntryCount >= 10,
    );
  }

  static Set<ArchiveHomeSectionId> _hiddenForStage(
    ArchiveHomePriorityInput input,
  ) {
    final hidden = <ArchiveHomeSectionId>{};

    for (final id in stickyLoopSequence) {
      if (!_isStickyLoopVisible(input, id)) {
        hidden.add(id);
      }
    }

    if (input.savedEntryCount <= 0) {
      hidden.addAll(const {
        ArchiveHomeSectionId.returnChanges,
        ArchiveHomeSectionId.milestones,
        ArchiveHomeSectionId.betaFeedback,
        ArchiveHomeSectionId.proInterestLink,
        ArchiveHomeSectionId.evidenceQuality,
        ArchiveHomeSectionId.reviewHistory,
        ArchiveHomeSectionId.controls,
        ArchiveHomeSectionId.needsAttention,
        ArchiveHomeSectionId.archiveDepth,
        ArchiveHomeSectionId.watchlist,
        ArchiveHomeSectionId.nextEvidencePlan,
        ArchiveHomeSectionId.returnRitual,
        ArchiveHomeSectionId.proPreview,
      });
      return hidden;
    }

    if (input.savedEntryCount == 1) {
      hidden.addAll(const {
        ArchiveHomeSectionId.returnChanges,
        ArchiveHomeSectionId.evidenceQuality,
        ArchiveHomeSectionId.reviewHistory,
        ArchiveHomeSectionId.controls,
        ArchiveHomeSectionId.needsAttention,
        ArchiveHomeSectionId.milestones,
        ArchiveHomeSectionId.betaFeedback,
        ArchiveHomeSectionId.proInterestLink,
      });
      return hidden;
    }

    if (input.savedEntryCount == 2) {
      hidden.addAll(const {
        ArchiveHomeSectionId.returnChanges,
        ArchiveHomeSectionId.reviewHistory,
        ArchiveHomeSectionId.controls,
        ArchiveHomeSectionId.milestones,
        ArchiveHomeSectionId.betaFeedback,
        ArchiveHomeSectionId.proInterestLink,
      });
      return hidden;
    }

    if (input.savedEntryCount <= 4) {
      hidden.add(ArchiveHomeSectionId.reviewHistory);
      if (!input.returnChangesAvailable) {
        hidden.add(ArchiveHomeSectionId.returnChanges);
      }
      return hidden;
    }

    if (input.savedEntryCount <= 9) {
      if (!input.weeklyReviewAvailable && !input.returnChangesAvailable) {
        hidden.add(ArchiveHomeSectionId.reviewHistory);
        hidden.add(ArchiveHomeSectionId.returnChanges);
      } else if (!input.weeklyReviewAvailable) {
        hidden.add(ArchiveHomeSectionId.reviewHistory);
      } else if (!input.returnChangesAvailable) {
        hidden.add(ArchiveHomeSectionId.returnChanges);
      }
      return hidden;
    }

    if (!input.proPreviewPromoVisible) {
      hidden.add(ArchiveHomeSectionId.proPreview);
    }
    return hidden;
  }

  static List<ArchiveHomeSectionId> _betaGrowthSections(
    ArchiveHomePriorityInput input,
  ) {
    if (input.savedEntryCount < 3) return const [];
    return const [
      ArchiveHomeSectionId.betaFeedback,
      ArchiveHomeSectionId.proInterestLink,
      ArchiveHomeSectionId.milestones,
    ];
  }

  static List<ArchiveHomeSectionId> _secondaryToolSections(
    ArchiveHomePriorityInput input,
  ) {
    final count = input.savedEntryCount;
    return [
      if (count >= 3 && input.returnChangesAvailable)
        ArchiveHomeSectionId.returnChanges,
      if (count >= 5 && input.weeklyReviewAvailable)
        ArchiveHomeSectionId.reviewHistory,
      if (count >= 1) ArchiveHomeSectionId.nextEvidencePlan,
      if (count >= 1) ArchiveHomeSectionId.watchlist,
      if (count >= 1) ArchiveHomeSectionId.archiveDepth,
      if (count >= 2) ArchiveHomeSectionId.evidenceQuality,
      if (count >= 1) ArchiveHomeSectionId.returnRitual,
      if (count >= 2) ArchiveHomeSectionId.needsAttention,
      if (count >= 5) ArchiveHomeSectionId.controls,
      if (input.proPreviewPromoVisible && count >= 1)
        ArchiveHomeSectionId.proPreview,
      ArchiveHomeSectionId.quickActions,
      ArchiveHomeSectionId.introHint,
    ];
  }

  static List<ArchiveHomeSectionId> _rankedOrder(
    ArchiveHomePriorityInput input,
  ) {
    if (input.savedEntryCount <= 0) {
      return [
        ArchiveHomeSectionId.archiveSummary,
        if (input.archiveDailyChangeVisible &&
            !input.calmCapacityActivationMode)
          ArchiveHomeSectionId.archiveDailyChange,
        ...stickyLoopSections(input),
        ArchiveHomeSectionId.sampleArchive,
        ArchiveHomeSectionId.quickActions,
        ArchiveHomeSectionId.introHint,
      ];
    }

    return [
      ArchiveHomeSectionId.archiveSummary,
      if (input.archiveDailyChangeVisible && !input.calmCapacityActivationMode)
        ArchiveHomeSectionId.archiveDailyChange,
      ...stickyLoopSections(input),
      ..._betaGrowthSections(input),
      ..._secondaryToolSections(input),
    ];
  }
}
