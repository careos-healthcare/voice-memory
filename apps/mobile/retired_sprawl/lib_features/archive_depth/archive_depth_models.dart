/// Archive depth band — based on saved moment count, not streaks or scores.
enum ArchiveDepthLevel {
  notStarted,
  firstEvidence,
  startingToCompare,
  cautiousBelief,
  weeklyReviewReady,
  longTermBuilding,
}

/// Deterministic depth readout from current journal entries.
class ArchiveDepthResult {
  const ArchiveDepthResult({
    required this.level,
    required this.levelLabel,
    required this.explanation,
    required this.progressLabel,
    required this.nextStep,
    required this.savedCount,
    required this.usableEvidenceCount,
    required this.showProLine,
  });

  final ArchiveDepthLevel level;
  final String levelLabel;
  final String explanation;
  final String progressLabel;
  final String nextStep;
  final int savedCount;
  final int usableEvidenceCount;
  final bool showProLine;
}
