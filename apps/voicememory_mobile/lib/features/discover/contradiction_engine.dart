import '../../models/journal_entry.dart';
import '../archive_state_object/archive_state_object.dart';
import '../contradiction_detection/contradiction_detection_service.dart';
import 'discover_models.dart';

/// Contradiction pairs for Discover Yourself.
class DiscoverContradictionEngine {
  const DiscoverContradictionEngine();

  List<DiscoverContradictionInsight> build({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
  }) {
    if (entries.length < 3) return const [];

    final result = const ContradictionDetectionService().detect(
      entries: entries,
      currentBelief: state?.belief,
    );

    final byId = {for (final e in entries) e.id: e};

    return result.reports
        .map(
          (r) => DiscoverContradictionInsight(
            statementA: r.originalStatement,
            statementB: r.conflictingStatement,
            dateA: byId[r.originalEntryId]?.createdAt ?? DateTime.now(),
            dateB: byId[r.conflictingEntryId]?.createdAt ?? DateTime.now(),
            confidenceScore: r.confidenceScore,
            entryIdA: r.originalEntryId,
            entryIdB: r.conflictingEntryId,
          ),
        )
        .take(5)
        .toList();
  }
}
