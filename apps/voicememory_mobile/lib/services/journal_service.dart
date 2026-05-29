import '../models/journal_entry.dart';
import '../storage/journal_store.dart';

/// Local journal — MVP uses on-device JSON only.
class JournalService {
  JournalService(this._store);

  final JournalStore _store;

  Future<List<JournalEntry>> listEntries() => _store.loadAll();

  Future<JournalEntry?> getEntry(String id) => _store.getById(id);

  Future<void> deleteEntry(String id) => _store.delete(id);

  Future<String> exportJson() => _store.exportJson();
}
