import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/journal_repository.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';

/// JSON-file backed [JournalRepository] — current production default.
class JsonFileJournalRepository implements JournalRepository {
  JsonFileJournalRepository(this._store);

  final JournalStore _store;

  @override
  Future<int> compactTombstonesBatch({
    Duration retention = const Duration(days: 30),
  }) {
    return _store.compactTombstonesBatch(retention: retention);
  }

  @override
  Future<List<JournalEntry>> loadAll() => _store.loadAll();

  @override
  Future<List<JournalEntry>> loadAllIncludingTombstones() =>
      _store.loadAllIncludingTombstones();

  @override
  Future<void> markSyncedBatch(Set<String> ids) => _store.markSyncedBatch(ids);

  @override
  Future<void> mergeRemoteBatch(List<JournalEntry> remote) =>
      _store.mergeRemoteBatch(remote);

  @override
  Future<void> save(JournalEntry entry) => _store.save(entry);
}