/// Inspection metadata for theory ranking — local RAG context and scoring math.
class TheoryRankingInspection {
  const TheoryRankingInspection({
    required this.confidenceBreakdown,
    required this.rankBreakdown,
    required this.retrievedChunks,
    required this.finalConfidencePercent,
    required this.finalRankScore,
  });

  final TheoryConfidenceBreakdown confidenceBreakdown;
  final TheoryRankBreakdown rankBreakdown;
  final List<TheoryRetrievalChunk> retrievedChunks;
  final int finalConfidencePercent;
  final int finalRankScore;
}

/// Component scores for [ArchiveAnalystConfidenceEngine].
class TheoryConfidenceBreakdown {
  const TheoryConfidenceBreakdown({
    required this.volumePoints,
    required this.consistencyPoints,
    required this.recencyPoints,
    required this.contradictionPenalty,
    required this.counterPenalty,
    required this.lowEvidenceMultiplierApplied,
    required this.staleMultiplierApplied,
    required this.rawTotalBeforeModifiers,
    required this.finalPercent,
  });

  final int volumePoints;
  final int consistencyPoints;
  final int recencyPoints;
  final int contradictionPenalty;
  final int counterPenalty;
  final bool lowEvidenceMultiplierApplied;
  final bool staleMultiplierApplied;
  final int rawTotalBeforeModifiers;
  final int finalPercent;
}

/// Component scores for theory rank ordering.
class TheoryRankBreakdown {
  const TheoryRankBreakdown({
    required this.volumePoints,
    required this.consistencyPoints,
    required this.recencyPoints,
    required this.contradictionPoints,
    required this.surprisePoints,
    required this.counterQualityPoints,
    required this.finalScore,
  });

  final int volumePoints;
  final int consistencyPoints;
  final int recencyPoints;
  final int contradictionPoints;
  final int surprisePoints;
  final int counterQualityPoints;
  final int finalScore;
}

/// One retrieved context row shown in the X-Ray panel.
class TheoryRetrievalChunk {
  const TheoryRetrievalChunk({
    required this.entryId,
    required this.excerpt,
    required this.role,
    this.recordedAt,
    this.keywordOverlap,
    this.vectorSimilarity,
    this.hybridScore,
    this.keywordRank,
    this.vectorRank,
  });

  final String entryId;
  final String excerpt;
  final TheoryRetrievalRole role;
  final DateTime? recordedAt;
  final int? keywordOverlap;
  final double? vectorSimilarity;
  final double? hybridScore;
  final int? keywordRank;
  final int? vectorRank;

  TheoryRetrievalChunk copyWith({
    String? entryId,
    String? excerpt,
    TheoryRetrievalRole? role,
    DateTime? recordedAt,
    int? keywordOverlap,
    double? vectorSimilarity,
    double? hybridScore,
    int? keywordRank,
    int? vectorRank,
  }) {
    return TheoryRetrievalChunk(
      entryId: entryId ?? this.entryId,
      excerpt: excerpt ?? this.excerpt,
      role: role ?? this.role,
      recordedAt: recordedAt ?? this.recordedAt,
      keywordOverlap: keywordOverlap ?? this.keywordOverlap,
      vectorSimilarity: vectorSimilarity ?? this.vectorSimilarity,
      hybridScore: hybridScore ?? this.hybridScore,
      keywordRank: keywordRank ?? this.keywordRank,
      vectorRank: vectorRank ?? this.vectorRank,
    );
  }
}

enum TheoryRetrievalRole { supporting, counter, hybrid }
