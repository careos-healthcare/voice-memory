/// Evidence-backed change since last archive review.
class ArchiveChangeFeedView {
  const ArchiveChangeFeedView({
    required this.hasBaseline,
    required this.reviewedAt,
    required this.newReflectionCount,
    required this.beliefsStrengthened,
    required this.beliefsWeakened,
    required this.contradictionsAppeared,
    required this.contradictionsResolved,
    required this.themesIncreasing,
    required this.themesDecreasing,
    this.emptyMessage,
  });

  final bool hasBaseline;
  final DateTime? reviewedAt;
  final int newReflectionCount;
  final List<ArchiveChangeBeliefRow> beliefsStrengthened;
  final List<ArchiveChangeBeliefRow> beliefsWeakened;
  final List<ArchiveChangeContradictionRow> contradictionsAppeared;
  final List<ArchiveChangeContradictionRow> contradictionsResolved;
  final List<ArchiveChangeThemeRow> themesIncreasing;
  final List<ArchiveChangeThemeRow> themesDecreasing;
  final String? emptyMessage;

  bool get hasChanges =>
      beliefsStrengthened.isNotEmpty ||
      beliefsWeakened.isNotEmpty ||
      contradictionsAppeared.isNotEmpty ||
      contradictionsResolved.isNotEmpty ||
      themesIncreasing.isNotEmpty ||
      themesDecreasing.isNotEmpty;

  int get totalChangeCount =>
      beliefsStrengthened.length +
      beliefsWeakened.length +
      contradictionsAppeared.length +
      contradictionsResolved.length +
      themesIncreasing.length +
      themesDecreasing.length;

  static const empty = ArchiveChangeFeedView(
    hasBaseline: false,
    reviewedAt: null,
    newReflectionCount: 0,
    beliefsStrengthened: [],
    beliefsWeakened: [],
    contradictionsAppeared: [],
    contradictionsResolved: [],
    themesIncreasing: [],
    themesDecreasing: [],
  );
}

class ArchiveChangeBeliefRow {
  const ArchiveChangeBeliefRow({
    required this.statement,
    required this.confidenceBefore,
    required this.confidenceNow,
    required this.evidenceCount,
    required this.counterEvidenceCount,
  });

  final String statement;
  final int confidenceBefore;
  final int confidenceNow;
  final int evidenceCount;
  final int counterEvidenceCount;

  int get confidenceDelta => confidenceNow - confidenceBefore;
}

class ArchiveChangeContradictionRow {
  const ArchiveChangeContradictionRow({
    required this.youSay,
    required this.but,
    required this.confidenceScore,
    required this.evidenceCount,
  });

  final String youSay;
  final String but;
  final int confidenceScore;
  final int evidenceCount;
}

class ArchiveChangeThemeRow {
  const ArchiveChangeThemeRow({
    required this.label,
    required this.mentionSeries,
    required this.mentionsAtReview,
    required this.mentionsNow,
    required this.newMentionsSinceReview,
  });

  final String label;
  final List<int> mentionSeries;
  final int mentionsAtReview;
  final int mentionsNow;
  final int newMentionsSinceReview;
}