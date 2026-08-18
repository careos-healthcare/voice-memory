import 'package:archiveme_mobile/features/journal/domain/interceptors/journal_save_interceptor.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/sync/background_sync_queue_worker.dart';

/// Registers journal entries with the background sync queue after durable save.
class JournalSaveSyncEnqueueInterceptor implements JournalSaveInterceptor {
  JournalSaveSyncEnqueueInterceptor(this._worker);

  final BackgroundSyncQueueWorker _worker;

  @override
  Future<void> onEntrySaved(JournalEntry entry) async {
    _worker.enqueue(entry);
  }
}
