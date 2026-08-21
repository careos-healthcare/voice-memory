import 'package:archiveme_mobile/features/search/offline_reflection_search_guard.dart';
import 'package:archiveme_mobile/services/automated_graph/automated_graph_models.dart';
import 'package:archiveme_mobile/workers/embedding/embedding_index_worker_service.dart';

/// Builds automated semantic knowledge-graph edges after a journal entry is saved.
///
/// All embedding, vector upsert, similarity search, and edge persistence run in
/// the embedding worker isolate via [EmbeddingIndexWorkerService].
final class AutomatedGraphService {
  AutomatedGraphService({
    required String sqliteFilePath,
    String? sqliteKeyAlias,
    String? sqliteEncryptionPassword,
    EmbeddingIndexWorkerService? embeddingWorker,
  }) : _sqliteFilePath = sqliteFilePath,
       _sqliteKeyAlias = sqliteKeyAlias,
       _sqliteEncryptionPassword = sqliteEncryptionPassword,
       _embeddingWorker = embeddingWorker ?? EmbeddingIndexWorkerService.instance;

  final String _sqliteFilePath;
  final String? _sqliteKeyAlias;
  final String? _sqliteEncryptionPassword;
  final EmbeddingIndexWorkerService _embeddingWorker;

  /// Embeds [text], stores the vector, finds top similar entries, and writes edges.
  Future<AutomatedGraphResult?> buildGraphForEntry({
    required String entryId,
    required String text,
    required String contentHash,
  }) {
    return OfflineReflectionSearchGuard.runOffline(() async {
      final payload = await _embeddingWorker.automateGraphForEntry(
        filePath: _sqliteFilePath,
        entryId: entryId,
        text: text,
        contentHash: contentHash,
        keyAlias: _sqliteKeyAlias,
        encryptionPassword: _sqliteEncryptionPassword,
      );
      if (payload == null) return null;
      return AutomatedGraphResult(
        entryId: entryId,
        embeddingStored: payload.embeddingStored,
        similarEntries: payload.similarEntries,
        edgesStored: payload.edgesStored,
      );
    });
  }
}
