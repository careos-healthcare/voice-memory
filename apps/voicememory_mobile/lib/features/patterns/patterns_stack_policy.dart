/// Which block appears on the Patterns tab and in what order.
enum PatternsSectionType {
  activeCheckIn,
  archiveMemory,
  nextCheck,
  archiveNavigation,
  patternProfile,
  rangeReview,
  archiveCompression,
  patternProgress,
  timeline,
  recap,
  share,
  emptyState,
}

/// Visibility and ordering for the Patterns tab stack.
class PatternsStackDecision {
  const PatternsStackDecision({
    required this.sections,
    this.suppressSeparateAskArchiveCard = false,
    this.suppressSeparateFindMomentCard = false,
    this.suppressSeparatePatternMapCard = false,
    this.suppressSeparateTimelineCard = false,
    this.suppressLowerPriorityCtas = false,
    this.showCurrentObjectiveCard = false,
  });

  final List<PatternsSectionType> sections;
  final bool suppressSeparateAskArchiveCard;
  final bool suppressSeparateFindMomentCard;
  final bool suppressSeparatePatternMapCard;
  final bool suppressSeparateTimelineCard;

  /// When true, hide secondary "Use this check" CTAs (timeline, etc.).
  final bool suppressLowerPriorityCtas;

  /// Compact "what should I do now?" card near the top of Patterns.
  final bool showCurrentObjectiveCard;

  bool includes(PatternsSectionType type) => sections.contains(type);
}

/// Decides Patterns tab section order and duplicate suppression.
PatternsStackDecision decidePatternsStack({
  required bool hasActiveCheckIn,
  required bool hasArchiveMemory,
  required bool hasNextCheck,
  required bool hasArchiveCleanView,
  required bool hasPatternProfile,
  required bool hasRangeReview,
  required bool hasArchiveCompression,
  required bool hasTimeline,
  required bool hasProgress,
  required bool hasRecap,
  required bool hasShare,
  required bool hasAnyMoment,
  bool hasDueCheckStatusCard = false,
}) {
  final sections = <PatternsSectionType>[];

  if (hasActiveCheckIn) {
    sections.add(PatternsSectionType.activeCheckIn);
  }
  if (hasArchiveMemory) {
    sections.add(PatternsSectionType.archiveMemory);
  }
  if (hasNextCheck && !hasArchiveMemory) {
    sections.add(PatternsSectionType.nextCheck);
  }
  if (hasArchiveCleanView) {
    sections.add(PatternsSectionType.archiveNavigation);
  }
  if (hasPatternProfile) {
    sections.add(PatternsSectionType.patternProfile);
  }
  if (hasRangeReview) {
    sections.add(PatternsSectionType.rangeReview);
  }
  if (hasArchiveCompression) {
    sections.add(PatternsSectionType.archiveCompression);
  }
  if (hasProgress) {
    sections.add(PatternsSectionType.patternProgress);
  }
  if (hasTimeline && !hasPatternProfile) {
    sections.add(PatternsSectionType.timeline);
  }
  if (hasRecap) {
    sections.add(PatternsSectionType.recap);
  }
  if (hasShare) {
    sections.add(PatternsSectionType.share);
  }
  if (!hasAnyMoment && !hasArchiveMemory) {
    sections.add(PatternsSectionType.emptyState);
  }

  final suppressNav = hasArchiveCleanView;
  final suppressFromProfile = hasPatternProfile;

  return PatternsStackDecision(
    sections: sections,
    suppressSeparateAskArchiveCard: suppressNav,
    suppressSeparateFindMomentCard: suppressNav,
    suppressSeparatePatternMapCard: suppressNav || suppressFromProfile,
    suppressSeparateTimelineCard: suppressNav || suppressFromProfile,
    suppressLowerPriorityCtas:
        hasArchiveMemory && hasNextCheck,
    showCurrentObjectiveCard: !hasDueCheckStatusCard,
  );
}
