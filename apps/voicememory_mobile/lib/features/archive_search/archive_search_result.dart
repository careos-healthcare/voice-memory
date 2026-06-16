import '../../models/journal_entry.dart';
import 'archive_search_filters.dart';

/// One matching entry plus the safe display metadata the result card
/// shows: relative time bucket, context tag labels, pin state, exact
/// evidence state, and the derived memory status.
class ArchiveEntrySearchResult {
  const ArchiveEntrySearchResult({
    required this.entry,
    required this.timeBucket,
    this.contextTagLabels = const [],
    this.isPinned = false,
    this.isExactEvidence = false,
    this.memoryStatus,
    this.collectionNames = const [],
    this.threadLabel,
    this.packLabel,
    this.entryTypeLabel,
    this.surfacingLabel,
    this.preservedOriginalLabel,
    this.savedDetailLabel,
  });

  final JournalEntry entry;
  final ArchiveDateFilter timeBucket;

  /// Fixed tag labels from the context enum — never free text.
  final List<String> contextTagLabels;

  final bool isPinned;
  final bool isExactEvidence;
  final ArchiveMemoryStatus? memoryStatus;

  /// Names of the collections this entry belongs to — user-private
  /// text, shown in the UI only and never logged.
  final List<String> collectionNames;

  /// Thread name when assigned — user-private text, never logged.
  final String? threadLabel;

  /// Pack name when assigned — user-private text, never logged.
  final String? packLabel;

  /// Entry type label — fixed copy from aboutness enum, never free text.
  final String? entryTypeLabel;

  /// Surfacing label — fixed copy; null when normal.
  final String? surfacingLabel;

  /// Preserved-original chip — fixed copy; null when not preserved.
  final String? preservedOriginalLabel;

  /// Saved-detail chip — fixed copy; null when no linked fact.
  final String? savedDetailLabel;

  String get timeBucketLabel => timeBucket.label;
}
