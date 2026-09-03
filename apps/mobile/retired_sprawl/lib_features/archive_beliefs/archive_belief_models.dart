/// Belief surfaced by the archive — user-facing card + detail payload.
enum ArchiveBeliefSection { current, emerging, changing, hiddenPattern }

class BeliefEvidenceQuote {
  const BeliefEvidenceQuote({required this.periodLabel, required this.quote});

  final String periodLabel;
  final String quote;
}

class ArchiveBeliefCardModel {
  const ArchiveBeliefCardModel({
    required this.id,
    required this.statement,
    required this.confidencePercent,
    required this.evidenceSummary,
    required this.whyExplanation,
    required this.section,
    this.timeline = const [],
    this.sourceEntryIds = const [],
    this.conclusion,
  });

  final String id;
  final String statement;
  final int confidencePercent;
  final String evidenceSummary;
  final String whyExplanation;
  final ArchiveBeliefSection section;
  final List<BeliefEvidenceQuote> timeline;

  /// Journal entry ids that already supported this card in the presenter.
  final List<String> sourceEntryIds;
  final String? conclusion;
}

class ArchiveBeliefsSnapshot {
  const ArchiveBeliefsSnapshot({
    required this.homeBeliefs,
    required this.current,
    required this.emerging,
    required this.changing,
    required this.hiddenPatterns,
    required this.stats,
  });

  final List<ArchiveBeliefCardModel> homeBeliefs;
  final List<ArchiveBeliefCardModel> current;
  final List<ArchiveBeliefCardModel> emerging;
  final List<ArchiveBeliefCardModel> changing;
  final List<ArchiveBeliefCardModel> hiddenPatterns;
  final ArchiveBeliefStats stats;

  ArchiveBeliefCardModel? beliefById(String id) {
    for (final b in [
      ...homeBeliefs,
      ...current,
      ...emerging,
      ...changing,
      ...hiddenPatterns,
    ]) {
      if (b.id == id) return b;
    }
    return null;
  }
}

class ArchiveBeliefStats {
  const ArchiveBeliefStats({
    required this.beliefsIdentified,
    required this.strongestBelief,
    required this.archiveAgeDays,
    required this.reflectionsAnalysed,
    required this.evidencePoints,
  });

  final int beliefsIdentified;
  final String? strongestBelief;
  final int archiveAgeDays;
  final int reflectionsAnalysed;
  final int evidencePoints;
}