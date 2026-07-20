import '../../../../models/journal_entry.dart';

/// Side-effect hook invoked after a journal entry is durably saved.
abstract class JournalSaveInterceptor {
  Future<void> onEntrySaved(JournalEntry entry);
}
