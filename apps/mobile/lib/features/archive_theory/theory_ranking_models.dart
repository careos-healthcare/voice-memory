import 'package:archiveme_mobile/features/archive_theory/theory_tracker_models.dart';
import 'package:archiveme_mobile/features/insights/theory_xray_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Result of unified primary theory ranking.
class TheoryRankingResult {
  const TheoryRankingResult({
    required this.primaryTheory,
    required this.secondaryTheories,
    required this.rejectedCandidates,
    required this.eligibleCandidateCount,
  });

  final RankedTheory? primaryTheory;
  final List<RankedTheory> secondaryTheories;
  final int rejectedCandidates;
  final int eligibleCandidateCount;

  String? get primaryStatement => primaryTheory?.statement;
  String? get primaryCandidateId => primaryTheory?.candidateId;
}

/// One scored belief hypothesis.
class RankedTheory {
  const RankedTheory({
    required this.candidateId,
    required this.statement,
    required this.source,
    required this.confidencePercent,
    required this.evidenceCount,
    required this.counterEvidenceCount,
    required this.rankScore,
    required this.supportingEntries,
    required this.supportingEvidence,
    required this.lastUpdated,
    this.inspection,
  });

  final String candidateId;
  final String statement;
  final String source;
  final int confidencePercent;
  final int evidenceCount;
  final int counterEvidenceCount;
  final int rankScore;
  final List<JournalEntry> supportingEntries;
  final List<TheoryEvidenceQuote> supportingEvidence;
  final DateTime? lastUpdated;
  final TheoryRankingInspection? inspection;
}