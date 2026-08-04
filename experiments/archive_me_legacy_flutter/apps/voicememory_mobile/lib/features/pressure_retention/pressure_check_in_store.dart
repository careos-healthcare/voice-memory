import '../../config/creator_demo_mode.dart';
import '../../models/journal_entry.dart';
import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import '../memory/memory_scope.dart';
import '../memory/memory_scope_policy.dart';
import 'pressure_check_in_record.dart';

/// Local store for structured pressure check-in records, keyed by entry id.
///
/// Backed by the same on-device prefs file as other ArchiveMe local state —
/// no backend dependency.
class PressureCheckInStore {
  PressureCheckInStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'pressureCheckIns';

  static PressureCheckInStore instance() =>
      PressureCheckInStore(AppServices.instance.prefs);

  static PressureCheckInStore forPrefs(MobilePrefsStore prefs) =>
      PressureCheckInStore(prefs);

  Future<void> save(PressureCheckInRecord record) async {
    // Creator demo mode: never write into the real archive store.
    if (CreatorDemoMode.isActive) return;
    await _prefs.updateMap(_key, (current) {
      final map = Map<String, dynamic>.from(current ?? {});
      // Memory scope "off": every brand-new record is saved as fresh, so
      // it can never feed a connection claim later. Existing records are
      // never altered.
      var toStore = record;
      if (!map.containsKey(record.entryId) &&
          MemoryScopePolicy.scope == MemoryScope.off &&
          !record.treatAsNew &&
          !record.keepSeparate) {
        toStore = PressureCheckInRecord(
          entryId: record.entryId,
          createdAt: record.createdAt,
          optionId: record.optionId,
          contextIds: record.contextIds,
          fear: record.fear,
          stopCostNote: record.stopCostNote,
          choseToStop: record.choseToStop,
          transcript: record.transcript,
          treatAsNew: true,
          keepSeparate: record.keepSeparate,
          archiveThreadId: record.archiveThreadId,
          archivePackId: record.archivePackId,
        );
      }
      map[record.entryId] = toStore.toJson();
      return map;
    });
  }

  /// Mirrors journal-entry memory metadata onto a pressure record so
  /// scope policy can read thread and separation flags for voice saves.
  Future<void> syncFromJournalEntry(JournalEntry entry) async {
    if (CreatorDemoMode.isActive) return;
    await _prefs.updateMap(_key, (current) {
      final map = Map<String, dynamic>.from(current ?? {});
      final existing = map[entry.id];
      if (existing is Map) {
        final record = PressureCheckInRecord.fromJson(
          Map<String, dynamic>.from(existing),
        );
        map[entry.id] = PressureCheckInRecord(
          entryId: record.entryId,
          createdAt: record.createdAt,
          optionId: record.optionId,
          contextIds: record.contextIds,
          fear: record.fear,
          stopCostNote: record.stopCostNote,
          choseToStop: record.choseToStop,
          transcript: record.transcript,
          treatAsNew: entry.treatAsNew,
          connectionApproved: entry.connectionApproved,
          keepExactDetails: entry.keepExactDetails,
          keepSeparate: entry.keepSeparate,
          isPinned: entry.isPinned,
          archiveThreadId: record.archiveThreadId,
          archivePackId: record.archivePackId,
          entryAboutness: entry.entryAboutness,
          memorySurfacing: entry.memorySurfacing,
          preserveOriginal: entry.preserveOriginal,
        ).toJson();
        return map;
      }
      map[entry.id] = PressureCheckInRecord(
        entryId: entry.id,
        createdAt: entry.createdAt,
        optionId: PressureCheckInRecord.contextOnlyOptionId,
        treatAsNew: entry.treatAsNew,
        connectionApproved: entry.connectionApproved,
        keepExactDetails: entry.keepExactDetails,
        keepSeparate: entry.keepSeparate,
        archiveThreadId: entry.archiveThreadId,
        archivePackId: entry.archivePackId,
        entryAboutness: entry.entryAboutness,
        memorySurfacing: entry.memorySurfacing,
        preserveOriginal: entry.preserveOriginal,
      ).toJson();
      return map;
    });
  }

  /// Stores one optional evidence context tag for a saved entry.
  ///
  /// When the entry already has a check-in record the tag is appended to its
  /// contexts; otherwise a minimal context-only record is created (marker
  /// option id, no notes) so future thread detection can use the tag without
  /// it ever being able to form belief-like phrases.
  /// [treatAsNew] carries the entry's "Treat this as new" metadata into a
  /// newly created context-only record so the tag can never become a
  /// connection claim for a fresh entry.
  Future<void> addContextTag({
    required String entryId,
    required String contextId,
    DateTime? now,
    bool treatAsNew = false,
  }) async {
    // Creator demo mode: never write into the real archive store.
    if (CreatorDemoMode.isActive) return;
    await _prefs.updateMap(_key, (current) {
      final map = Map<String, dynamic>.from(current ?? {});
      final existing = map[entryId];
      if (existing is Map) {
        final record = PressureCheckInRecord.fromJson(
          Map<String, dynamic>.from(existing),
        );
        if (record.contextIds.contains(contextId)) return map;
        map[entryId] = PressureCheckInRecord(
          entryId: record.entryId,
          createdAt: record.createdAt,
          optionId: record.optionId,
          contextIds: [...record.contextIds, contextId],
          fear: record.fear,
          stopCostNote: record.stopCostNote,
          choseToStop: record.choseToStop,
          transcript: record.transcript,
          treatAsNew: record.treatAsNew,
          connectionApproved: record.connectionApproved,
          keepExactDetails: record.keepExactDetails,
          keepSeparate: record.keepSeparate,
          archiveThreadId: record.archiveThreadId,
          archivePackId: record.archivePackId,
          entryAboutness: record.entryAboutness,
        ).toJson();
        return map;
      }
      map[entryId] = PressureCheckInRecord(
        entryId: entryId,
        createdAt: now ?? DateTime.now(),
        optionId: PressureCheckInRecord.contextOnlyOptionId,
        contextIds: [contextId],
        treatAsNew: treatAsNew,
      ).toJson();
      return map;
    });
  }

  /// Removes the records for [entryIds] — used when entries are deleted
  /// so removed entries can no longer back memory claims.
  Future<void> removeForEntries(Iterable<String> entryIds) async {
    if (CreatorDemoMode.isActive) return;
    final ids = entryIds.toSet();
    await _prefs.updateMap(_key, (current) {
      final map = Map<String, dynamic>.from(current ?? {});
      map.removeWhere((key, _) => ids.contains(key));
      return map;
    });
  }

  /// All saved records, newest first.
  Future<List<PressureCheckInRecord>> loadAll() async {
    // Creator demo mode: safe demo entries only — the real local archive
    // store is never read.
    if (CreatorDemoMode.isActive) return CreatorDemoMode.demoCheckIns();
    final raw = await _prefs.readMap(_key);
    if (raw == null) return [];
    final records = raw.values
        .whereType<Map>()
        .map(
          (m) => PressureCheckInRecord.fromJson(Map<String, dynamic>.from(m)),
        )
        .toList();
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }
}
