import 'archive_home_priority_models.dart';

/// Deterministic Archive Home priority stack — local, no persistence.
class ArchiveHomePriorityEngine {
  const ArchiveHomePriorityEngine();

  static const _primaryCardLimit = 3;

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
          ArchiveHomeSectionId.archiveDepth,
          ArchiveHomeSectionId.watchlist,
          ArchiveHomeSectionId.nextEvidencePlan,
          ArchiveHomeSectionId.firstWeekPath,
          ArchiveHomeSectionId.dailyArchiveExercise,
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
    final ranked = _rankedOrder(input).where((id) => !hidden.contains(id)).toList();

    final primary = <ArchiveHomeSectionId>[ArchiveHomeSectionId.archiveSummary];
    var addedCards = 0;
    for (final id in ranked) {
      if (id == ArchiveHomeSectionId.archiveSummary) continue;
      if (addedCards >= _primaryCardLimit) break;
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

  static Set<ArchiveHomeSectionId> _hiddenForStage(ArchiveHomePriorityInput input) {
    final hidden = <ArchiveHomeSectionId>{};

    if (!input.firstWeekPathVisible) {
      hidden.add(ArchiveHomeSectionId.firstWeekPath);
    }

    if (!input.dailyArchiveExerciseVisible) {
      hidden.add(ArchiveHomeSectionId.dailyArchiveExercise);
    }

    if (input.savedEntryCount <= 0) {
      hidden.addAll(const {
        ArchiveHomeSectionId.returnChanges,
        ArchiveHomeSectionId.milestones,
        ArchiveHomeSectionId.betaFeedback,
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
      }
      return hidden;
    }

    if (!input.proPreviewPromoVisible) {
      hidden.add(ArchiveHomeSectionId.proPreview);
    }
    return hidden;
  }

  static List<ArchiveHomeSectionId> _rankedOrder(ArchiveHomePriorityInput input) {
    if (input.savedEntryCount <= 0) {
      return [
        ArchiveHomeSectionId.archiveSummary,
        if (input.firstWeekPathVisible) ArchiveHomeSectionId.firstWeekPath,
        if (input.dailyArchiveExerciseVisible)
          ArchiveHomeSectionId.dailyArchiveExercise,
        ArchiveHomeSectionId.quickActions,
        ArchiveHomeSectionId.introHint,
        ArchiveHomeSectionId.sampleArchive,
      ];
    }

    if (input.savedEntryCount == 1) {
      return [
        ArchiveHomeSectionId.archiveSummary,
        if (input.firstWeekPathVisible) ArchiveHomeSectionId.firstWeekPath,
        ArchiveHomeSectionId.nextEvidencePlan,
        if (input.dailyArchiveExerciseVisible)
          ArchiveHomeSectionId.dailyArchiveExercise,
        ArchiveHomeSectionId.returnRitual,
        ArchiveHomeSectionId.archiveDepth,
        ArchiveHomeSectionId.watchlist,
        ArchiveHomeSectionId.quickActions,
        ArchiveHomeSectionId.introHint,
        ArchiveHomeSectionId.proPreview,
      ];
    }

    if (input.savedEntryCount == 2) {
      return [
        ArchiveHomeSectionId.archiveSummary,
        if (input.firstWeekPathVisible) ArchiveHomeSectionId.firstWeekPath,
        ArchiveHomeSectionId.nextEvidencePlan,
        if (input.dailyArchiveExerciseVisible)
          ArchiveHomeSectionId.dailyArchiveExercise,
        ArchiveHomeSectionId.watchlist,
        ArchiveHomeSectionId.archiveDepth,
        ArchiveHomeSectionId.evidenceQuality,
        ArchiveHomeSectionId.returnRitual,
        ArchiveHomeSectionId.needsAttention,
        ArchiveHomeSectionId.quickActions,
        ArchiveHomeSectionId.introHint,
      ];
    }

    if (input.savedEntryCount <= 4) {
      return [
        ArchiveHomeSectionId.archiveSummary,
        if (input.firstWeekPathVisible) ArchiveHomeSectionId.firstWeekPath,
        if (input.returnChangesAvailable) ArchiveHomeSectionId.returnChanges,
        ArchiveHomeSectionId.nextEvidencePlan,
        if (input.dailyArchiveExerciseVisible)
          ArchiveHomeSectionId.dailyArchiveExercise,
        ArchiveHomeSectionId.watchlist,
        ArchiveHomeSectionId.milestones,
        ArchiveHomeSectionId.betaFeedback,
        ArchiveHomeSectionId.proInterestLink,
        ArchiveHomeSectionId.evidenceQuality,
        ArchiveHomeSectionId.archiveDepth,
        ArchiveHomeSectionId.returnRitual,
        ArchiveHomeSectionId.needsAttention,
        ArchiveHomeSectionId.quickActions,
        ArchiveHomeSectionId.introHint,
        ArchiveHomeSectionId.proPreview,
      ];
    }

    if (input.savedEntryCount <= 9) {
      return [
        ArchiveHomeSectionId.archiveSummary,
        if (input.firstWeekPathVisible) ArchiveHomeSectionId.firstWeekPath,
        if (input.weeklyReviewAvailable)
          ArchiveHomeSectionId.reviewHistory
        else if (input.returnChangesAvailable)
          ArchiveHomeSectionId.returnChanges,
        ArchiveHomeSectionId.nextEvidencePlan,
        if (input.dailyArchiveExerciseVisible)
          ArchiveHomeSectionId.dailyArchiveExercise,
        ArchiveHomeSectionId.evidenceQuality,
        ArchiveHomeSectionId.watchlist,
        ArchiveHomeSectionId.milestones,
        ArchiveHomeSectionId.betaFeedback,
        ArchiveHomeSectionId.proInterestLink,
        ArchiveHomeSectionId.returnChanges,
        ArchiveHomeSectionId.archiveDepth,
        ArchiveHomeSectionId.needsAttention,
        ArchiveHomeSectionId.returnRitual,
        ArchiveHomeSectionId.controls,
        ArchiveHomeSectionId.quickActions,
        ArchiveHomeSectionId.proPreview,
      ];
    }

    return [
      ArchiveHomeSectionId.archiveSummary,
      ArchiveHomeSectionId.reviewHistory,
      ArchiveHomeSectionId.nextEvidencePlan,
      if (input.dailyArchiveExerciseVisible)
        ArchiveHomeSectionId.dailyArchiveExercise,
      ArchiveHomeSectionId.evidenceQuality,
      if (input.proPreviewPromoVisible) ArchiveHomeSectionId.proPreview,
      ArchiveHomeSectionId.watchlist,
      ArchiveHomeSectionId.milestones,
      ArchiveHomeSectionId.betaFeedback,
      ArchiveHomeSectionId.proInterestLink,
      ArchiveHomeSectionId.returnChanges,
      ArchiveHomeSectionId.archiveDepth,
      ArchiveHomeSectionId.needsAttention,
      ArchiveHomeSectionId.returnRitual,
      ArchiveHomeSectionId.controls,
      ArchiveHomeSectionId.quickActions,
    ];
  }
}
