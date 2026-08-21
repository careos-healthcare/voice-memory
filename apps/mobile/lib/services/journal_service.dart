import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';

/// Local journal — MVP uses on-device JSON only.
class JournalService {
  JournalService(this._store);

  final JournalStore _store;

  Future<List<JournalEntry>> listEntries() => _store.loadAll();

  Future<List<JournalEntry>> loadAll() => _store.loadAll();

  Future<List<JournalEntry>> loadEligible() => _store.loadEligible();

  Future<JournalEntry?> getEntry(String id) => _store.getById(id);

  Future<void> deleteEntry(String id) => _store.delete(id);

  Future<String> exportJson() => _store.exportJson();
}