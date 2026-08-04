import '../../../models/journal_entry.dart';
import '../../../storage/journal_store.dart';

/// Journal lookup boundary for curiosity hook prompt synthesis.
abstract interface class CuriosityHookJournalStore {
  Future<JournalEntry?> getEntryById(String entryId);
}

/// [JournalStore] adapter for curiosity hook orchestration.
class JournalStoreCuriosityHookJournalStore
    implements CuriosityHookJournalStore {
  JournalStoreCuriosityHookJournalStore(this._journalStore);

  final JournalStore _journalStore;

  @override
  Future<JournalEntry?> getEntryById(String entryId) =>
      _journalStore.getById(entryId);
}
