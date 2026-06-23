import '../../models/journal_entry.dart';
import '../../storage/mobile_prefs_store.dart';
import 'archive_return_changes_engine.dart';
import 'archive_return_snapshot.dart';

/// Local last-seen archive snapshot for return-change detection.
class ArchiveReturnChangesStore {
  ArchiveReturnChangesStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const stateKey = 'archiveReturnLastSeenSnapshot';

  Future<ArchiveReturnSnapshot?> loadLastSeen() async {
    final raw = await _prefs.readJsonMap(stateKey);
    if (raw == null || raw.isEmpty) return null;
    return ArchiveReturnSnapshot.fromJson(raw);
  }

  Future<void> markSeen(ArchiveReturnSnapshot snapshot) async {
    await _prefs.writeJsonMap(stateKey, snapshot.toJson());
  }

  /// Seeds baseline on first visit with 2+ entries — card stays hidden until later change.
  Future<void> seedBaselineIfNeeded(ArchiveReturnSnapshot current) async {
    if (current.entryCount < 2) return;
    final lastSeen = await loadLastSeen();
    if (lastSeen != null) return;
    await markSeen(current);
  }

  static Future<ArchiveReturnChangesStore> open(String prefsPath) async {
    final prefs = await MobilePrefsStore.open(prefsPath);
    return ArchiveReturnChangesStore(prefs);
  }

  static ArchiveReturnChangesStore fromAppPrefs(MobilePrefsStore prefs) =>
      ArchiveReturnChangesStore(prefs);
}

/// Resolves return changes from journal entries and prefs.
Future<({
  ArchiveReturnSnapshot current,
  ArchiveReturnChangesResult? result,
})> resolveArchiveReturnChanges({
  required List<JournalEntry> entries,
  required ArchiveReturnChangesStore store,
  ArchiveReturnChangesEngine engine = const ArchiveReturnChangesEngine(),
}) async {
  final current = ArchiveReturnSnapshot.fromEntries(entries);
  final lastSeen = await store.loadLastSeen();
  if (lastSeen == null && current.entryCount >= 2) {
    await store.markSeen(current);
    return (current: current, result: null);
  }
  final result = engine.evaluate(lastSeen: lastSeen, current: current);
  return (current: current, result: result);
}
