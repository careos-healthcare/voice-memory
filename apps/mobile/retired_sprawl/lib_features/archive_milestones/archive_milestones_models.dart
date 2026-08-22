/// Stable milestone identifiers — ordered for display progression.
enum ArchiveMilestoneId {
  firstMomentSaved,
  firstComparisonPossible,
  firstCautiousBelief,
  firstWeeklyReviewReady,
  firstWatchlistTheme,
  firstReturnRitual,
  firstShareSafeProof,
  longTermArchiveBuilding,
}

/// Row state label shown beside each milestone.
enum ArchiveMilestoneRowState { done, now, next }

/// One milestone row in the compact card.
class ArchiveMilestoneRow {
  const ArchiveMilestoneRow({
    required this.id,
    required this.label,
    required this.state,
    required this.isComplete,
  });

  final ArchiveMilestoneId id;
  final String label;
  final ArchiveMilestoneRowState state;
  final bool isComplete;
}

/// Card-level milestone readout — computed locally, never persisted.
class ArchiveMilestonesResult {
  const ArchiveMilestonesResult({
    required this.title,
    required this.body,
    required this.rows,
    required this.showProLine,
    required this.primaryActionLabel,
    required this.primaryActionRoute,
  });

  final String title;
  final String body;
  final List<ArchiveMilestoneRow> rows;
  final bool showProLine;
  final String primaryActionLabel;
  final String primaryActionRoute;
}