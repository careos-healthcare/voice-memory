import '../../models/journal_entry.dart';
import '../../services/activation_funnel_analytics.dart';
import '../action_items/archive_action_item.dart';
import '../pressure_retention/pressure_check_in_record.dart';
import 'archive_evidence_record.dart';
import 'archive_evidence_type.dart';
import 'curated_memory_marker.dart';
import 'memory_scope.dart';
import 'memory_scope_policy.dart';

/// Central curated-memory preservation guard.
abstract class CuratedMemoryPreservationPolicy {
  CuratedMemoryPreservationPolicy._();

  static bool isPreservedEntry(
    JournalEntry entry, {
    List<ArchiveActionItem> actionItems = const [],
  }) => CuratedMemoryMarker.isCurated(
    entry,
    hasActionItem: CuratedMemoryMarker.hasActionItemForEntry(
      entry.id,
      actionItems,
    ),
  );

  static bool isPreservedRecord(PressureCheckInRecord record) =>
      record.preserveOriginal || record.keepExactDetails;

  static bool showsPreservedLabel(JournalEntry entry) =>
      CuratedMemoryMarker.showsPreservedChip(entry);

  static ArchiveEvidenceType evidenceTypeFor(PressureCheckInRecord record) {
    if (record.treatAsNew) return ArchiveEvidenceType.fresh;
    if (record.preserveOriginal) {
      return ArchiveEvidenceType.preservedOriginal;
    }
    if (record.keepExactDetails) {
      return ArchiveEvidenceType.userMarkedDetail;
    }
    return ArchiveEvidenceType.fact;
  }

  /// Generated summaries are views — never the only source when curated
  /// evidence exists behind a card.
  static bool requiresOriginalEvidenceSection(
    List<ArchiveEvidenceRecord> evidence,
  ) => evidence.any(
    (item) =>
        item.type == ArchiveEvidenceType.preservedOriginal ||
        item.type == ArchiveEvidenceType.userMarkedDetail,
  );

  static bool summarySeparatedFromOriginal(
    List<ArchiveEvidenceRecord> evidence,
  ) {
    final hasCurated = requiresOriginalEvidenceSection(evidence);
    final hasInterpretation = evidence.any(
      (e) => e.type == ArchiveEvidenceType.interpretation,
    );
    return hasCurated && hasInterpretation;
  }

  /// Generated interpretation can never become high-authority source evidence.
  static bool interpretationCanBeHighAuthority(
    List<ArchiveEvidenceRecord> evidence,
  ) => !evidence.any(
    (e) =>
        e.type == ArchiveEvidenceType.interpretation &&
        evidence.any(
          (other) =>
              other.type == ArchiveEvidenceType.preservedOriginal ||
              other.type == ArchiveEvidenceType.userMarkedDetail,
        ),
  );

  static bool blocksProactiveBoost(JournalEntry entry) =>
      entry.preserveOriginal || entry.keepExactDetails;

  static void noteKeepExactApplied({required int entryCount}) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.curatedMemoryPreservationApplied,
      entryCount: entryCount,
      memoryScope: MemoryScopePolicy.scope.id,
      source: 'record',
      preservationSource: CuratedPreservationSource.keepExactDetails.id,
    );
  }

  static void noteSummarySeparated({required String source, int? entryCount}) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.summarySeparatedFromOriginal,
      source: source,
      entryCount: entryCount,
      memoryScope: MemoryScopePolicy.scope.id,
    );
  }

  static void trackOriginalOpened({
    required String source,
    CuratedPreservationSource? preservationSource,
  }) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.originalEvidenceOpened,
      source: source,
      memoryScope: MemoryScopePolicy.scope.id,
      preservationSource: preservationSource?.id,
    );
  }
}
