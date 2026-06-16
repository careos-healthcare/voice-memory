import 'archive_search_filters.dart';

/// One local, deterministic entry-search request: an optional keyword
/// plus optional filters. The query lives only in widget state — it is
/// never logged, sent to analytics, or persisted.
class ArchiveEntrySearchQuery {
  const ArchiveEntrySearchQuery({
    this.keyword = '',
    this.contextTagId,
    this.dateFilter,
    this.memoryStatus,
    this.exactEvidenceOnly = false,
    this.pinnedOnly = false,
    this.collectionId,
    this.threadId,
    this.packId,
    this.archivedOnly = false,
    this.actionItemsOnly = false,
    this.entryAboutnessId,
    this.memorySurfacingId,
    this.preservedOriginalOnly = false,
    this.savedDetailsOnly = false,
  });

  /// Keyword matched over safe local entry text.
  final String keyword;

  /// Stable context-tag id (e.g. `work`), never free text.
  final String? contextTagId;

  final ArchiveDateFilter? dateFilter;
  final ArchiveMemoryStatus? memoryStatus;
  final bool exactEvidenceOnly;
  final bool pinnedOnly;

  /// Stable collection id, never the collection name.
  final String? collectionId;

  /// Stable archive-thread id, never the thread name.
  final String? threadId;

  /// Stable archive-pack id, never the pack name.
  final String? packId;

  /// Archived filter: archived entries are hidden by default and shown
  /// only when this is on.
  final bool archivedOnly;

  /// Action items filter: entries with a linked non-dismissed action item.
  final bool actionItemsOnly;

  /// Entry type filter — stable aboutness id only.
  final String? entryAboutnessId;

  /// Surfacing filter — stable surfacing id only.
  final String? memorySurfacingId;

  /// Preserved-original filter — entries with preserve-original metadata.
  final bool preservedOriginalOnly;

  /// Saved-details filter — entries with at least one linked fact.
  final bool savedDetailsOnly;

  bool get hasKeyword => keyword.trim().isNotEmpty;

  bool get hasActiveFilters =>
      contextTagId != null ||
      dateFilter != null ||
      memoryStatus != null ||
      exactEvidenceOnly ||
      pinnedOnly ||
      collectionId != null ||
      threadId != null ||
      packId != null ||
      archivedOnly ||
      actionItemsOnly ||
      entryAboutnessId != null ||
      memorySurfacingId != null ||
      preservedOriginalOnly ||
      savedDetailsOnly;

  bool get isEmpty => !hasKeyword && !hasActiveFilters;

  ArchiveEntrySearchQuery copyWith({
    String? keyword,
    String? Function()? contextTagId,
    ArchiveDateFilter? Function()? dateFilter,
    ArchiveMemoryStatus? Function()? memoryStatus,
    bool? exactEvidenceOnly,
    bool? pinnedOnly,
    String? Function()? collectionId,
    String? Function()? threadId,
    String? Function()? packId,
    bool? archivedOnly,
    bool? actionItemsOnly,
    String? Function()? entryAboutnessId,
    String? Function()? memorySurfacingId,
    bool? preservedOriginalOnly,
    bool? savedDetailsOnly,
  }) => ArchiveEntrySearchQuery(
    keyword: keyword ?? this.keyword,
    contextTagId: contextTagId != null ? contextTagId() : this.contextTagId,
    dateFilter: dateFilter != null ? dateFilter() : this.dateFilter,
    memoryStatus: memoryStatus != null ? memoryStatus() : this.memoryStatus,
    exactEvidenceOnly: exactEvidenceOnly ?? this.exactEvidenceOnly,
    pinnedOnly: pinnedOnly ?? this.pinnedOnly,
    collectionId: collectionId != null ? collectionId() : this.collectionId,
    threadId: threadId != null ? threadId() : this.threadId,
    packId: packId != null ? packId() : this.packId,
    archivedOnly: archivedOnly ?? this.archivedOnly,
    actionItemsOnly: actionItemsOnly ?? this.actionItemsOnly,
    entryAboutnessId: entryAboutnessId != null
        ? entryAboutnessId()
        : this.entryAboutnessId,
    memorySurfacingId: memorySurfacingId != null
        ? memorySurfacingId()
        : this.memorySurfacingId,
    preservedOriginalOnly: preservedOriginalOnly ?? this.preservedOriginalOnly,
    savedDetailsOnly: savedDetailsOnly ?? this.savedDetailsOnly,
  );

  /// All filters cleared; the typed keyword is kept.
  ArchiveEntrySearchQuery clearedFilters() =>
      ArchiveEntrySearchQuery(keyword: keyword);
}
