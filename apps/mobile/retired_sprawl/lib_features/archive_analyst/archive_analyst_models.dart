import 'package:archiveme_mobile/features/archive_analyst/archive_analyst_gate.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_models.dart';

/// Full periodic analyst report.
class ArchiveAnalystReport {
  const ArchiveAnalystReport({
    required this.level,
    required this.eligibleReflectionCount,
    required this.evidenceSummary,
    required this.currentBeliefs,
    required this.emergingBeliefs,
    required this.fadingBeliefs,
    required this.contradictions,
    required this.blindSpots,
    required this.competingBeliefs,
    required this.debates,
    this.primaryBeliefId,
  });

  final ArchiveAnalystLevel level;
  final int eligibleReflectionCount;
  final ArchiveAnalystEvidenceSummary evidenceSummary;
  final List<ArchiveAnalystBeliefRow> currentBeliefs;
  final List<ArchiveAnalystTrendBelief> emergingBeliefs;
  final List<ArchiveAnalystTrendBelief> fadingBeliefs;
  final List<ArchiveV1Contradiction> contradictions;
  final List<ArchiveV1BlindSpot> blindSpots;
  final List<ArchiveAnalystCompetingBelief> competingBeliefs;
  final List<ArchiveAnalystDebate> debates;
  final String? primaryBeliefId;

  bool get hasReport => level != ArchiveAnalystLevel.insufficient;
}

class ArchiveAnalystEvidenceSummary {
  const ArchiveAnalystEvidenceSummary({
    required this.eligibleReflectionCount,
    required this.dateSpanLabel,
    required this.uniqueBeliefCandidates,
    required this.contradictionCount,
    required this.blindSpotCount,
  });

  final int eligibleReflectionCount;
  final String dateSpanLabel;
  final int uniqueBeliefCandidates;
  final int contradictionCount;
  final int blindSpotCount;
}

class ArchiveAnalystBeliefRow {
  const ArchiveAnalystBeliefRow({
    required this.id,
    required this.statement,
    required this.confidencePercent,
    required this.evidenceCount,
    required this.counterEvidenceCount,
    required this.lastUpdated,
    required this.isPrimary,
  });

  final String id;
  final String statement;
  final int confidencePercent;
  final int evidenceCount;
  final int counterEvidenceCount;
  final DateTime? lastUpdated;
  final bool isPrimary;
}

class ArchiveAnalystTrendBelief {
  const ArchiveAnalystTrendBelief({
    required this.id,
    required this.statement,
    required this.confidencePercent,
    required this.trendLabel,
    required this.mentionSeries,
  });

  final String id;
  final String statement;
  final int confidencePercent;
  final String trendLabel;
  final List<int> mentionSeries;
}

class ArchiveAnalystCompetingBelief {
  const ArchiveAnalystCompetingBelief({
    required this.statement,
    required this.confidencePercent,
    required this.isPrimary,
  });

  final String statement;
  final int confidencePercent;
  final bool isPrimary;
}

class ArchiveAnalystDebate {
  const ArchiveAnalystDebate({
    required this.beliefStatement,
    required this.confidencePercent,
    required this.evidenceForCount,
    required this.evidenceAgainstCount,
    required this.supportingExcerpts,
    required this.counterExcerpts,
    required this.timelineNotes,
  });

  final String beliefStatement;
  final int confidencePercent;
  final int evidenceForCount;
  final int evidenceAgainstCount;
  final List<ArchiveAnalystExcerpt> supportingExcerpts;
  final List<ArchiveAnalystExcerpt> counterExcerpts;
  final List<String> timelineNotes;
}

class ArchiveAnalystExcerpt {
  const ArchiveAnalystExcerpt({
    required this.entryId,
    required this.dateLabel,
    required this.quote,
  });

  final String entryId;
  final String dateLabel;
  final String quote;
}

/// Internal candidate before ranking.
class ArchiveAnalystBeliefCandidate {
  const ArchiveAnalystBeliefCandidate({
    required this.id,
    required this.statement,
    required this.source,
    this.lastUpdated,
  });

  final String id;
  final String statement;
  final String source;
  final DateTime? lastUpdated;
}