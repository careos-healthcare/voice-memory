/// Evidence-backed observation that challenges apparent self-image.
enum ArchiveSurpriseKind {
  themeDominanceGap,
  themeStoppedMentioning,
  repeatedDecisionLoop,
  statedImportanceGap,
}

class ArchiveSurpriseObservation {
  const ArchiveSurpriseObservation({
    required this.id,
    required this.kind,
    required this.observation,
    required this.evidenceCount,
    required this.evidenceEntryIds,
    required this.confidenceScore,
  });

  final String id;
  final ArchiveSurpriseKind kind;
  final String observation;
  final int evidenceCount;
  final List<String> evidenceEntryIds;
  final int confidenceScore;
}

class ArchiveSurprisesView {
  const ArchiveSurprisesView({required this.observations, this.emptyMessage});

  final List<ArchiveSurpriseObservation> observations;
  final String? emptyMessage;

  bool get hasObservations => observations.isNotEmpty;

  static const empty = ArchiveSurprisesView(
    observations: [],
    emptyMessage: null,
  );
}
