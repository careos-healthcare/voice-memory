import '../../models/journal_entry.dart';
import '../activation/belief_update_payoff.dart';
import '../activation/capture_context_tags.dart';
import '../activation/weekly_archive_review.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_heuristics.dart';

/// Safe metadata snapshot — no raw entry text.
class ArchiveReturnSnapshot {
  const ArchiveReturnSnapshot({
    required this.entryCount,
    required this.usableEvidenceCount,
    required this.beliefSummaryHash,
    required this.contextCount,
    required this.weeklyReviewAvailable,
  });

  final int entryCount;
  final int usableEvidenceCount;
  final String beliefSummaryHash;
  final int contextCount;
  final bool weeklyReviewAvailable;

  static const empty = ArchiveReturnSnapshot(
    entryCount: 0,
    usableEvidenceCount: 0,
    beliefSummaryHash: '',
    contextCount: 0,
    weeklyReviewAvailable: false,
  );

  factory ArchiveReturnSnapshot.fromEntries(List<JournalEntry> entries) {
    final realEntries = entries
        .where(
          (e) =>
              e.transcript.trim().isNotEmpty &&
              !e.transcript.startsWith('[draft]'),
        )
        .toList();
    final eligible = ArchiveEvidenceGuard.eligibleEntries(realEntries);
    final weekly = WeeklyArchiveReviewEngine.build(entries: realEntries);
    final beliefHash = _beliefSummaryHash(realEntries, eligible);
    final taggedCounts = CaptureContextTagAnalysis.tagCounts(eligible);
    final contextCount = taggedCounts.length;

    return ArchiveReturnSnapshot(
      entryCount: realEntries.length,
      usableEvidenceCount: eligible.length,
      beliefSummaryHash: beliefHash,
      contextCount: contextCount,
      weeklyReviewAvailable: weekly.hasEnoughEvidence,
    );
  }

  Map<String, dynamic> toJson() => {
        'entryCount': entryCount,
        'usableEvidenceCount': usableEvidenceCount,
        'beliefSummaryHash': beliefSummaryHash,
        'contextCount': contextCount,
        'weeklyReviewAvailable': weeklyReviewAvailable,
      };

  factory ArchiveReturnSnapshot.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return empty;
    return ArchiveReturnSnapshot(
      entryCount: json['entryCount'] as int? ?? 0,
      usableEvidenceCount: json['usableEvidenceCount'] as int? ?? 0,
      beliefSummaryHash: json['beliefSummaryHash'] as String? ?? '',
      contextCount: json['contextCount'] as int? ?? 0,
      weeklyReviewAvailable: json['weeklyReviewAvailable'] as bool? ?? false,
    );
  }

  static String _beliefSummaryHash(
    List<JournalEntry> entries,
    List<JournalEntry> eligible,
  ) {
    if (eligible.length < 4) return '';
    final payoff = BeliefUpdatePayoffEngine.build(entries: entries);
    final beliefLine = payoff?.currentBelief.trim().isNotEmpty == true
        ? payoff!.currentBelief.trim()
        : const ArchiveEvidenceHeuristics()
            .analyze(entries)
            .beliefLine
            .trim();
    if (beliefLine.isEmpty) return '';
    return _stableHash(beliefLine).toString();
  }

  static int _stableHash(String input) {
    var hash = 0;
    for (final unit in input.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }
}
