import 'package:archiveme_mobile/features/journal/domain/interceptors/journal_save_interceptor.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_index_worker.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Queues reflection embedding work after a journal entry is durably saved.
class JournalReflectionEmbeddingInterceptor implements JournalSaveInterceptor {
  JournalReflectionEmbeddingInterceptor(this._worker);

  final ReflectionEmbeddingIndexWorker _worker;

  @override
  Future<void> onEntrySaved(JournalEntry entry) async {
    _worker.enqueue(entry);
  }
}
