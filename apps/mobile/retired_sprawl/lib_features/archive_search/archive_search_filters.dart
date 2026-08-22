/// Archive Search 2.0 — filters and consumer copy.
///
/// ArchiveMe is a searchable evidence archive, not a flat pile of
/// recordings. Filters are deterministic and local; they read entry
/// metadata only and never change memory state, scope, or entries.
library;

/// Relative date filter — the same buckets the evidence surfaces use.
enum ArchiveDateFilter {
  today,
  thisWeek,
  thisMonth,
  older;

  /// Stable analytics-safe id.
  String get id => switch (this) {
    ArchiveDateFilter.today => 'today',
    ArchiveDateFilter.thisWeek => 'this_week',
    ArchiveDateFilter.thisMonth => 'this_month',
    ArchiveDateFilter.older => 'older',
  };

  String get label => switch (this) {
    ArchiveDateFilter.today => 'Today',
    ArchiveDateFilter.thisWeek => 'This week',
    ArchiveDateFilter.thisMonth => 'This month',
    ArchiveDateFilter.older => 'Older',
  };

  /// Whether [createdAt] falls in this bucket relative to [now].
  bool contains(DateTime createdAt, DateTime now) {
    final days = now.difference(createdAt).inDays;
    return switch (this) {
      ArchiveDateFilter.today => days < 1,
      ArchiveDateFilter.thisWeek => days >= 1 && days <= 7,
      ArchiveDateFilter.thisMonth => days > 7 && days <= 30,
      ArchiveDateFilter.older => days > 30,
    };
  }

  /// The bucket [createdAt] falls in relative to [now].
  static ArchiveDateFilter bucketFor(DateTime createdAt, DateTime now) {
    final days = now.difference(createdAt).inDays;
    if (days < 1) return ArchiveDateFilter.today;
    if (days <= 7) return ArchiveDateFilter.thisWeek;
    if (days <= 30) return ArchiveDateFilter.thisMonth;
    return ArchiveDateFilter.older;
  }
}

/// Memory status filter — evidence framing labels, mirroring the
/// authority states memory cards already use. Derived read-only from
/// saved metadata; filtering never changes any memory state.
enum ArchiveMemoryStatus {
  stillCurrent,
  mayBeStale,
  changedLater,
  mixedEvidence,
  freshEntry,
  userConfirmed;

  /// Stable analytics-safe id.
  String get id => switch (this) {
    ArchiveMemoryStatus.stillCurrent => 'still_current',
    ArchiveMemoryStatus.mayBeStale => 'may_be_stale',
    ArchiveMemoryStatus.changedLater => 'changed_later',
    ArchiveMemoryStatus.mixedEvidence => 'mixed_evidence',
    ArchiveMemoryStatus.freshEntry => 'fresh_entry',
    ArchiveMemoryStatus.userConfirmed => 'user_confirmed',
  };

  String get label => switch (this) {
    ArchiveMemoryStatus.stillCurrent => 'Still current',
    ArchiveMemoryStatus.mayBeStale => 'May be stale',
    ArchiveMemoryStatus.changedLater => 'Changed later',
    ArchiveMemoryStatus.mixedEvidence => 'Mixed evidence',
    ArchiveMemoryStatus.freshEntry => 'Fresh entry',
    ArchiveMemoryStatus.userConfirmed => 'User confirmed',
  };
}

/// Stable filter-type ids for analytics — never the filter value, and
/// never any query text.
abstract class ArchiveSearchFilterType {
  ArchiveSearchFilterType._();

  static const String keyword = 'keyword';
  static const String contextTag = 'context_tag';
  static const String date = 'date';
  static const String memoryStatus = 'memory_status';
  static const String exactEvidence = 'exact_evidence';
  static const String pinned = 'pinned';
  static const String collection = 'collection';
  static const String thread = 'thread';
  static const String pack = 'pack';
  static const String archived = 'archived';
  static const String actionItems = 'action_items';
  static const String entryType = 'entry_type';
  static const String surfacing = 'surfacing';
  static const String preservedOriginal = 'preserved_original';
  static const String savedDetails = 'saved_details';
  static const String clear = 'clear';
}

/// All consumer copy for archive search — compile-time constants so
/// tests can sweep them and no private content can leak in.
abstract class ArchiveSearchCopy {
  ArchiveSearchCopy._();

  static const String searchPlaceholder = 'Search your archive';
  static const String emptyTitle = 'No matching entries';
  static const String emptyHelper = 'Try a different word, tag, or filter.';
  static const String filterHeading = 'Filter';
  static const String clearFilters = 'Clear filters';
  static const String exactEvidenceLabel = 'Exact evidence';
  static const String pinnedLabel = 'Pinned';
  static const String archivedLabel = 'Archived';
  static const String actionItemsLabel = 'Action items';
  static const String entryTypeLabel = 'Entry type';
  static const String surfacingLabel = 'Surfacing';
  static const String preservedOriginalLabel = 'Preserved original';
  static const String savedDetailsLabel = 'Saved details';
}