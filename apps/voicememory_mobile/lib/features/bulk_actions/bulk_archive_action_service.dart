import '../../models/journal_entry.dart';
import '../../services/app_services.dart';
import '../../storage/journal_store.dart';
import '../collections/archive_collection_store.dart';
import '../pressure_retention/pressure_check_in_record.dart';
import '../pressure_retention/pressure_check_in_store.dart';

/// Bulk actions over explicitly selected entries.
///
/// Every method acts on the given ids only. Metadata actions (archive,
/// pin, treat as new, keep exact details) write safe flags and leave
/// the entry text untouched. Nothing here reads or writes Memory Scope
/// Controls, and nothing here logs entry text or collection names.
class BulkArchiveActionService {
  BulkArchiveActionService({
    required JournalStore journal,
    PressureCheckInStore? checkIns,
    ArchiveCollectionStore? collections,
  }) : _journal = journal,
       _checkIns = checkIns,
       _collections = collections;

  final JournalStore _journal;
  final PressureCheckInStore? _checkIns;
  final ArchiveCollectionStore? _collections;

  static BulkArchiveActionService instance() => BulkArchiveActionService(
    journal: AppServices.instance.journalStore,
    checkIns: PressureCheckInStore.instance(),
    collections: ArchiveCollectionStore.instance(),
  );

  /// Records that may back memory claims: records whose entry is
  /// archived (or no longer present) are excluded by default.
  static List<PressureCheckInRecord> recordsEligibleForMemory(
    List<PressureCheckInRecord> records,
    List<JournalEntry> entries,
  ) {
    final visible = {
      for (final e in entries)
        if (!e.isArchived) e.id,
    };
    return records.where((r) => visible.contains(r.entryId)).toList();
  }

  /// Sets archived metadata on the selected entries. Text untouched.
  Future<int> archiveEntries(Set<String> entryIds, {DateTime? now}) =>
      _setFlags(
        entryIds,
        (e) => _copy(e, isArchived: true, archivedAt: now ?? DateTime.now()),
        skip: (e) => e.isArchived,
      );

  /// Deletes the selected entries and their check-in records, so a
  /// deleted entry can no longer back any memory claim.
  Future<int> deleteEntries(Set<String> entryIds) async {
    var deleted = 0;
    for (final id in entryIds) {
      if (await _journal.getById(id) == null) continue;
      await _journal.delete(id);
      deleted++;
    }
    await _checkIns?.removeForEntries(entryIds);
    return deleted;
  }

  /// Pin metadata only.
  Future<int> pinEntries(Set<String> entryIds, {DateTime? now}) => _setFlags(
    entryIds,
    (e) => _copy(e, isPinned: true, pinnedAt: now ?? DateTime.now()),
    skip: (e) => e.isPinned,
  );

  /// Pin metadata only.
  Future<int> unpinEntries(Set<String> entryIds) => _setFlags(
    entryIds,
    (e) => _copy(e, isPinned: false, clearPinnedAt: true),
    skip: (e) => !e.isPinned,
  );

  /// "Treat this as new" metadata — fresh flag only, content untouched.
  Future<int> treatEntriesAsNew(Set<String> entryIds) => _setFlags(
    entryIds,
    (e) => _copy(e, treatAsNew: true),
    skip: (e) => e.treatAsNew,
  );

  /// "Keep exact details" metadata — exact evidence flag only.
  Future<int> keepExactDetailsForEntries(Set<String> entryIds) => _setFlags(
    entryIds,
    (e) => _copy(e, keepExactDetails: true),
    skip: (e) => e.keepExactDetails,
  );

  /// Adds the selected entries to one collection. The collection name
  /// never leaves the local store.
  Future<int> addEntriesToCollection(
    String collectionId,
    Set<String> entryIds,
  ) async {
    final store = _collections;
    if (store == null) return 0;
    var added = 0;
    for (final id in entryIds) {
      final updated = await store.addEntry(collectionId, id);
      if (updated != null) added++;
    }
    return added;
  }

  Future<int> _setFlags(
    Set<String> entryIds,
    JournalEntry Function(JournalEntry) transform, {
    required bool Function(JournalEntry) skip,
  }) async {
    var changed = 0;
    for (final id in entryIds) {
      final entry = await _journal.getById(id);
      if (entry == null || skip(entry)) continue;
      await _journal.save(transform(entry), first25Source: 'bulk_action');
      changed++;
    }
    return changed;
  }

  /// Copy with safe metadata only — id, text, and timestamps untouched.
  static JournalEntry _copy(
    JournalEntry e, {
    bool? treatAsNew,
    bool? keepExactDetails,
    bool? isPinned,
    DateTime? pinnedAt,
    bool clearPinnedAt = false,
    bool? isArchived,
    DateTime? archivedAt,
  }) => JournalEntry(
    id: e.id,
    createdAt: e.createdAt,
    transcript: e.transcript,
    durationSeconds: e.durationSeconds,
    reflection: e.reflection,
    syncStatus: e.syncStatus,
    localAudioPath: e.localAudioPath,
    treatAsNew: treatAsNew ?? e.treatAsNew,
    connectionApproved: e.connectionApproved,
    keepExactDetails: keepExactDetails ?? e.keepExactDetails,
    isPinned: isPinned ?? e.isPinned,
    pinnedAt: clearPinnedAt ? null : (pinnedAt ?? e.pinnedAt),
    isArchived: isArchived ?? e.isArchived,
    archivedAt: archivedAt ?? e.archivedAt,
  );
}
