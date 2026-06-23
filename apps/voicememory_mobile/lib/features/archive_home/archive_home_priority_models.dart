import '../archive_depth/archive_depth_models.dart';

/// Archive Home surface identifiers for priority stacking.
enum ArchiveHomeSectionId {
  archiveSummary,
  introHint,
  quickActions,
  returnRitual,
  proPreview,
  returnChanges,
  archiveDepth,
  watchlist,
  nextEvidencePlan,
  firstWeekPath,
  dailyArchiveExercise,
  archiveClarityProgress,
  thenVsNow,
  milestones,
  betaFeedback,
  proInterestLink,
  needsAttention,
  evidenceQuality,
  reviewHistory,
  controls,
  sampleArchive,
}

/// Inputs for deterministic Archive Home priority — metadata only.
class ArchiveHomePriorityInput {
  const ArchiveHomePriorityInput({
    required this.savedEntryCount,
    required this.usableEvidenceCount,
    required this.depthLevel,
    required this.returnChangesAvailable,
    required this.weeklyReviewAvailable,
    required this.sampleMode,
    required this.proPreviewPromoVisible,
    required this.showEmptySample,
    required this.firstWeekPathVisible,
    required this.dailyArchiveExerciseVisible,
    required this.archiveClarityProgressVisible,
    required this.thenVsNowVisible,
  });

  final int savedEntryCount;
  final int usableEvidenceCount;
  final ArchiveDepthLevel depthLevel;
  final bool returnChangesAvailable;
  final bool weeklyReviewAvailable;
  final bool sampleMode;
  final bool proPreviewPromoVisible;
  final bool showEmptySample;
  final bool firstWeekPathVisible;
  final bool dailyArchiveExerciseVisible;
  final bool archiveClarityProgressVisible;
  final bool thenVsNowVisible;
}

/// Ordered Archive Home layout plan — primary first, then optional collapse.
class ArchiveHomePriorityPlan {
  const ArchiveHomePriorityPlan({
    required this.primarySections,
    required this.secondarySections,
    required this.hiddenSections,
    required this.showMoreArchiveTools,
    required this.proPreviewProminent,
  });

  final List<ArchiveHomeSectionId> primarySections;
  final List<ArchiveHomeSectionId> secondarySections;
  final Set<ArchiveHomeSectionId> hiddenSections;
  final bool showMoreArchiveTools;
  final bool proPreviewProminent;

  bool isHidden(ArchiveHomeSectionId id) => hiddenSections.contains(id);

  bool isPrimary(ArchiveHomeSectionId id) => primarySections.contains(id);
}
