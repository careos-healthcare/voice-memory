import 'package:archiveme_mobile/database/app_database.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_014_embedding_deferred_queue.dart';

export 'package:archiveme_mobile/database/daos/queue_dao.dart'
    show EmbeddingDeferredTask;

/// SQLite-backed queue for deferred reflection/transcript embedding work.
final class EmbeddingDeferredQueueStore {
  EmbeddingDeferredQueueStore(AppDatabase db) : _dao = QueueDao(db);

  final QueueDao _dao;

  static const String queueTable =
      Migration014EmbeddingDeferredQueue.queueTable;

  Future<void> enqueueReflection({
    required String entryId,
    required String text,
    required String contentHash,
    required String sqliteFilePath,
    String? keyAlias,
    String? encryptionPassword,
  }) => _dao.enqueueDeferredReflection(
    entryId: entryId,
    text: text,
    contentHash: contentHash,
    sqliteFilePath: sqliteFilePath,
    keyAlias: keyAlias,
    encryptionPassword: encryptionPassword,
  );

  Future<void> enqueueLlmSummary({
    required String entryId,
    required String llmSummary,
    required String sqliteFilePath,
    String? keyAlias,
    String? encryptionPassword,
  }) => _dao.enqueueDeferredLlmSummary(
    entryId: entryId,
    llmSummary: llmSummary,
    sqliteFilePath: sqliteFilePath,
    keyAlias: keyAlias,
    encryptionPassword: encryptionPassword,
  );

  @Deprecated('Use enqueueLlmSummary')
  Future<void> enqueueTranscript({
    required String entryId,
    required String text,
    required String sqliteFilePath,
    String? keyAlias,
    String? encryptionPassword,
  }) => enqueueLlmSummary(
    entryId: entryId,
    llmSummary: text,
    sqliteFilePath: sqliteFilePath,
    keyAlias: keyAlias,
    encryptionPassword: encryptionPassword,
  );

  Future<List<EmbeddingDeferredTask>> listPending({int? limit}) =>
      _dao.listDeferredPending(limit: limit);

  Future<int> pendingCount() => _dao.deferredPendingCount();

  Future<void> remove(String queueId) => _dao.removeDeferred(queueId);
}
