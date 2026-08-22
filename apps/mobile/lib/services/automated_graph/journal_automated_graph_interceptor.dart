import 'package:archiveme_mobile/features/journal/domain/interceptors/journal_save_interceptor.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/automated_graph/automated_graph_index_worker.dart';

/// Queues automated knowledge-graph edge building after a journal entry is saved.
class JournalAutomatedGraphInterceptor implements JournalSaveInterceptor {
  JournalAutomatedGraphInterceptor(this._worker);

  final AutomatedGraphIndexWorker _worker;

  @override
  Future<void> onEntrySaved(JournalEntry entry) async {
    _worker.enqueue(entry);
  }
}
